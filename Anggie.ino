// ============================================================================
//  Anggie — Smart Light Controller (ESP32 / DOIT DEVKIT V1)
//  PID lux control + EMA filtering + safety state machine + night mode.
//  Exposes telemetry over Serial AND WiFi HTTP (device.telemetry.v1) so the
//  Saqelar app can consume real data without a simulator.
//
//  Board : DOIT ESP32 DEVKIT V1  (esp32:esp32:esp32doit-devkit-v1)
//  Based on FIXDIMMER.ino; telemetry contract + WiFi added for app integration.
// ============================================================================

#include <RBDdimmer.h>
#include <ACS712.h>
#include <Wire.h>
#include <BH1750.h>
#include <RTClib.h>
#include <ArduinoJson.h>
#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>

// ---------------------------------------------------------------------------
// Pin map
// ---------------------------------------------------------------------------
#define ACS_PIN   34
#define LDR_PIN   35
#define RELAY_PIN 25
#define ZC_PIN    26
#define DIM_PIN   33

#define RELAY_ON  HIGH   // active-high relay module
#define RELAY_OFF LOW

// ---------------------------------------------------------------------------
// WiFi — fill these in before flashing real hardware.
// Leave blank to run offline (Serial telemetry still works).
// ---------------------------------------------------------------------------
const char* WIFI_SSID = "";          // TODO: your 2.4GHz SSID
const char* WIFI_PASS = "";          // TODO: your WiFi password
const char* MDNS_HOST = "saqelar";   // -> http://saqelar.local/telemetry

// ---------------------------------------------------------------------------
// System limits / tuning
// ---------------------------------------------------------------------------
const float  MAX_SAFE_CURRENT = 5000.0;  // mA — trip relay above 5 A
const int    LDR_DAYLIGHT     = 3000;    // filtered LDR -> daylight cutoff
const double SETPOINT         = 500.0;   // target lux
const int    DIMMER_CEILING   = 80;      // anti-flicker max dimmer %
const int    NIGHT_DIMMER     = 40;      // static dimmer % during night
const int    NIGHT_START_HOUR = 22;      // 22:00 .. 05:59 -> night mode
const int    NIGHT_END_HOUR   = 6;

double Kp = 0.15, Ki = 0.05, Kd = 0.01;
double error = 0, lastError = 0, integral = 0, derivative = 0, pidOutput = 0;
int    currentBrightness = 0;

// Exponential moving average (DSP smoothing).
float       emaLDR = 0, emaCurrent = 0;
const float ALPHA_LDR = 0.2f, ALPHA_CURRENT = 0.1f;

const unsigned long PID_INTERVAL   = 200;
const unsigned long PRINT_INTERVAL = 1000;
unsigned long lastPidTime = 0, lastPrintTime = 0;

// ---------------------------------------------------------------------------
// Telemetry contract (device.telemetry.v1)
// ---------------------------------------------------------------------------
const char DEVICE_ID[]        = "anggie-001";
const char FIRMWARE_VERSION[] = "0.2.0";
const char TELEMETRY_SCHEMA[] = "device.telemetry.v1";
uint32_t   telemetrySeq       = 0;

enum SystemState { SAFE_PID_ACTIVE, NIGHT_MODE, DAYLIGHT_OFF, OVERCURRENT_TRIP };
SystemState currentState = SAFE_PID_ACTIVE;

// Most recent readings, cached each loop for the telemetry snapshot.
float lastLux = 0, lastPowerW = 0;

// ---------------------------------------------------------------------------
// Objects
// ---------------------------------------------------------------------------
dimmerLamp dimmer(DIM_PIN, ZC_PIN);
ACS712     acs(ACS_PIN, 3.3, 4095, 185);
BH1750     lightMeter;
RTC_DS3231 rtc;
WebServer  server(80);

// ---------------------------------------------------------------------------
// Contract mapping helpers
// ---------------------------------------------------------------------------
const char* modeForState(SystemState s) {
  return (s == NIGHT_MODE) ? "night" : "auto";
}

const char* safetyForState(SystemState s) {
  switch (s) {
    case OVERCURRENT_TRIP: return "fault";
    case DAYLIGHT_OFF:     return "standby";
    default:               return "ok";
  }
}

const char* faultReasonForState(SystemState s) {
  switch (s) {
    case OVERCURRENT_TRIP: return "OVERCURRENT";
    case DAYLIGHT_OFF:     return "DAYLIGHT_STANDBY";
    default:               return nullptr;
  }
}

void buildTimestamp(const DateTime& now, char* buf, size_t len) {
  snprintf(buf, len, "%04u-%02u-%02uT%02u:%02u:%02u+07:00",
           now.year(), now.month(), now.day(),
           now.hour(), now.minute(), now.second());
}

// Serialize the current state into a device.telemetry.v1 document.
void buildTelemetry(JsonDocument& doc) {
  char ts[32];
  buildTimestamp(rtc.now(), ts, sizeof(ts));

  doc["schema"]      = TELEMETRY_SCHEMA;
  doc["deviceId"]    = DEVICE_ID;
  doc["seq"]         = ++telemetrySeq;
  doc["ts"]          = ts;
  doc["mode"]        = modeForState(currentState);
  doc["relayOn"]     = (digitalRead(RELAY_PIN) == RELAY_ON);
  doc["safetyState"] = safetyForState(currentState);

  const char* reason = faultReasonForState(currentState);
  if (reason == nullptr) {
    doc["faultReason"] = nullptr;
  } else {
    doc["faultReason"] = reason;
  }

  doc["lux"]       = lastLux;
  doc["targetLux"] = SETPOINT;
  doc["ldrRaw"]    = (int)emaLDR;
  doc["currentMa"] = emaCurrent;
  doc["powerW"]    = lastPowerW;
  doc["dimmerPct"] = currentBrightness;

  JsonObject pid = doc["pid"].to<JsonObject>();
  pid["kp"]     = Kp;
  pid["ki"]     = Ki;
  pid["kd"]     = Kd;
  pid["output"] = pidOutput;

  doc["uptimeMs"] = millis();
  doc["firmware"] = FIRMWARE_VERSION;
}

// ---------------------------------------------------------------------------
// HTTP handlers
// ---------------------------------------------------------------------------
void handleTelemetry() {
  JsonDocument doc;
  buildTelemetry(doc);
  String out;
  serializeJson(doc, out);
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", out);
}

void handleHealth() {
  JsonDocument doc;
  doc["status"]   = "ok";
  doc["deviceId"] = DEVICE_ID;
  doc["firmware"] = FIRMWARE_VERSION;
  doc["uptimeMs"] = millis();
  String out;
  serializeJson(doc, out);
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", out);
}

void handleNotFound() {
  server.send(404, "application/json",
              "{\"status\":\"error\",\"message\":\"not found\"}");
}

void startNetwork() {
  if (strlen(WIFI_SSID) == 0) {
    Serial.println("WiFi: SSID kosong -> jalan offline (Serial only).");
    return;
  }
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print("WiFi: menyambung");
  const unsigned long deadline = millis() + 12000;
  while (WiFi.status() != WL_CONNECTED && millis() < deadline) {
    delay(300);
    Serial.print('.');
  }
  Serial.println();

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi: gagal -> jalan offline (Serial only).");
    return;
  }

  Serial.print("WiFi: terhubung, IP = ");
  Serial.println(WiFi.localIP());
  if (MDNS.begin(MDNS_HOST)) {
    Serial.printf("mDNS: http://%s.local/telemetry\n", MDNS_HOST);
  }

  server.on("/telemetry", HTTP_GET, handleTelemetry);
  server.on("/health", HTTP_GET, handleHealth);
  server.onNotFound(handleNotFound);
  server.begin();
  Serial.println("HTTP: server siap di port 80 (/telemetry, /health).");
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);

  // Slow I2C (50 kHz) for noise tolerance on long sensor wiring.
  Wire.begin();
  Wire.setClock(50000);

  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, RELAY_OFF);

  Serial.println("Memulai Anggie Smart Light (I2C 50kHz)...");
  delay(1000);

  if (!rtc.begin()) {
    Serial.println("Error: Modul RTC tidak terdeteksi!");
  } else {
    Serial.println("Modul RTC siap.");
    // If the clock drifts, uncomment, set the time, flash once, then re-comment:
    // rtc.adjust(DateTime(2026, 7, 1, 8, 0, 0));
  }
  delay(1000);

  if (lightMeter.begin(BH1750::CONTINUOUS_HIGH_RES_MODE)) {
    Serial.println("Sensor BH1750 siap.");
  } else {
    Serial.println("Error: BH1750 gagal dikonfigurasi!");
  }

  dimmer.begin(NORMAL_MODE, ON);
  dimmer.setPower(0);

  Serial.println("Kalibrasi ACS712... (pastikan lampu padam)");
  acs.autoMidPoint();
  Serial.println("Kalibrasi selesai.");

  emaLDR = analogRead(LDR_PIN);
  emaCurrent = 0;

  digitalWrite(RELAY_PIN, RELAY_ON);

  startNetwork();
}

// ---------------------------------------------------------------------------
// Loop
// ---------------------------------------------------------------------------
void loop() {
  const unsigned long currentMillis = millis();
  const DateTime now = rtc.now();

  // 1. Read + filter (EMA).
  const int rawLDR = analogRead(LDR_PIN);
  emaLDR = (ALPHA_LDR * rawLDR) + ((1.0f - ALPHA_LDR) * emaLDR);

  float rawCurrent = acs.mA_AC();
  if (rawCurrent < 30) rawCurrent = 0;
  emaCurrent = (ALPHA_CURRENT * rawCurrent) + ((1.0f - ALPHA_CURRENT) * emaCurrent);

  lastLux = lightMeter.readLightLevel();
  lastPowerW = (emaCurrent / 1000.0f) * 220.0f;

  // 2. Safety / mode state machine.
  if (emaCurrent > MAX_SAFE_CURRENT) {
    currentState = OVERCURRENT_TRIP;
  } else if (now.hour() >= NIGHT_START_HOUR || now.hour() < NIGHT_END_HOUR) {
    currentState = NIGHT_MODE;
  } else if (emaLDR > LDR_DAYLIGHT) {
    currentState = DAYLIGHT_OFF;
  } else {
    currentState = SAFE_PID_ACTIVE;
  }

  // 3. Drive hardware.
  if (currentState == OVERCURRENT_TRIP || currentState == DAYLIGHT_OFF) {
    dimmer.setPower(0);
    digitalWrite(RELAY_PIN, RELAY_OFF);
    currentBrightness = 0;
    integral = 0;
    lastError = 0;
    pidOutput = 0;
  } else if (currentState == NIGHT_MODE) {
    digitalWrite(RELAY_PIN, RELAY_ON);
    dimmer.setPower(NIGHT_DIMMER);
    currentBrightness = NIGHT_DIMMER;
    integral = 0;
    lastError = 0;
    pidOutput = 0;
  } else { // SAFE_PID_ACTIVE
    if (currentMillis - lastPidTime >= PID_INTERVAL) {
      lastPidTime = currentMillis;
      digitalWrite(RELAY_PIN, RELAY_ON);

      error = SETPOINT - lastLux;
      if (emaLDR < 1000) {
        error += (float)map((long)emaLDR, 0, 1000, 100, 0); // feed-forward
      }

      integral += error * (PID_INTERVAL / 1000.0);
      derivative = (error - lastError) / (PID_INTERVAL / 1000.0);
      if (integral > 100) integral = 100;
      if (integral < -100) integral = -100;

      pidOutput = (Kp * error) + (Ki * integral) + (Kd * derivative);
      currentBrightness += (int)pidOutput;
      if (currentBrightness > DIMMER_CEILING) currentBrightness = DIMMER_CEILING;
      if (currentBrightness < 0) currentBrightness = 0;

      dimmer.setPower(currentBrightness);
      lastError = error;
    }
  }

  // 4. Service HTTP clients.
  if (WiFi.status() == WL_CONNECTED) server.handleClient();

  // 5. Periodic report (human-readable + telemetry JSON).
  if (currentMillis - lastPrintTime >= PRINT_INTERVAL) {
    lastPrintTime = currentMillis;

    Serial.println("\n==================================");
    Serial.printf("Waktu      : %02d:%02d:%02d\n", now.hour(), now.minute(), now.second());
    Serial.print("Status     : ");
    switch (currentState) {
      case SAFE_PID_ACTIVE:  Serial.println("PID AKTIF (target 500 lux)"); break;
      case NIGHT_MODE:       Serial.println("MALAM (statis 40%)"); break;
      case DAYLIGHT_OFF:     Serial.println("SIANG (padam)"); break;
      case OVERCURRENT_TRIP: Serial.println("OVERCURRENT (>5A) - RELAY PUTUS"); break;
    }
    Serial.printf("Lux        : %.0f  | LDR(EMA): %.0f\n", lastLux, emaLDR);
    Serial.printf("Dimmer     : %d%%\n", currentBrightness);
    Serial.printf("Arus/Daya  : %.1f mA / %.2f W\n", emaCurrent, lastPowerW);

    JsonDocument doc;
    buildTelemetry(doc);
    Serial.print("Telemetry  : ");
    serializeJson(doc, Serial);
    Serial.println();
    Serial.println("==================================");
  }
}
