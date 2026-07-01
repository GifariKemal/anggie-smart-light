/// Data contract mirrored from `Anggie.ino` (`device.telemetry.v1`).
///
/// Field names + safety semantics match the firmware so the app stays
/// drop-in compatible when a real ESP32 link replaces the simulator.
library;

/// Hard limits / defaults baked into the firmware. Single source of truth so
/// the UI never invents numbers the device doesn't actually use.
class FirmwareConstants {
  static const String deviceId = 'anggie-001';
  static const String deviceName = 'Anggie Demo Lamp';
  static const String hardwareModel = 'DOIT ESP32 DEVKIT V1';
  static const String firmwareVersion = '0.6.0';

  static const double defaultTargetLux = 500; // SETPOINT
  static const double maxTargetLux = 1000; // UI tuning range ceiling
  static const double maxSafeCurrentMa = 5000; // MAX_SAFE_CURRENT (5 A)
  static const int ldrDaylightRaw = 3000; // LDR_DAYLIGHT
  static const int ldrFeedforwardRaw = 1000; // feed-forward threshold
  static const int dimmerMaxPct = 80; // anti-flicker ceiling
  static const int nightDimmerPct = 40; // static dimmer during night mode
  static const int nightStartHour = 22; // 22:00..05:59 -> night mode
  static const int nightEndHour = 6;
  static const double currentFloorMa = 30; // firmware: mA < 30 -> 0
  static const double mainsVoltage = 220;
  static const String telemetrySchema = 'device.telemetry.v1';

  // MQTT transport (public broker, no TLS). One telemetry topic to read,
  // one command topic to write (control is a future feature).
  static const String mqttBroker = 'broker.emqx.io';
  static const int mqttPort = 1883;
  static const String mqttTelemetryTopic = 'suriota/anggie-001/telemetry';
  static const String mqttCommandTopic = 'suriota/anggie-001/command';

  // Initial PID tuning (Kp/Ki/Kd) from the firmware.
  static const double kp = 0.15;
  static const double ki = 0.05;
  static const double kd = 0.01;
}

enum DeviceMode { auto, manual, off }

extension DeviceModeLabel on DeviceMode {
  String get wire => switch (this) {
    DeviceMode.auto => 'auto',
    DeviceMode.manual => 'manual',
    DeviceMode.off => 'off',
  };

  String get label => switch (this) {
    DeviceMode.auto => 'Auto (PID)',
    DeviceMode.manual => 'Manual',
    DeviceMode.off => 'Off',
  };
}

/// One immutable telemetry snapshot, shaped like the firmware JSON payload.
class Telemetry {
  const Telemetry({
    required this.seq,
    required this.timestamp,
    required this.mode,
    required this.relayOn,
    required this.safetyState,
    required this.faultReason,
    required this.lux,
    required this.targetLux,
    required this.ldrRaw,
    required this.currentMa,
    required this.powerW,
    required this.dimmerPct,
    required this.kp,
    required this.ki,
    required this.kd,
    required this.pidOutput,
    required this.uptime,
    this.schema = FirmwareConstants.telemetrySchema,
    this.deviceId = FirmwareConstants.deviceId,
    this.firmware = FirmwareConstants.firmwareVersion,
  });

  /// Parse a real firmware `device.telemetry.v1` payload (drop-in for ESP32).
  factory Telemetry.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    final pid = (j['pid'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Telemetry(
      seq: (j['seq'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.tryParse('${j['ts']}') ?? DateTime.now(),
      mode: '${j['mode'] ?? 'auto'}',
      relayOn: j['relayOn'] == true,
      safetyState: '${j['safetyState'] ?? 'ok'}',
      faultReason: j['faultReason'] as String?,
      lux: d(j['lux']),
      targetLux: d(j['targetLux']),
      ldrRaw: (j['ldrRaw'] as num?)?.toInt() ?? 0,
      currentMa: d(j['currentMa']),
      powerW: d(j['powerW']),
      dimmerPct: (j['dimmerPct'] as num?)?.toInt() ?? 0,
      kp: d(pid['kp']),
      ki: d(pid['ki']),
      kd: d(pid['kd']),
      pidOutput: d(pid['output']),
      uptime: Duration(milliseconds: (j['uptimeMs'] as num?)?.toInt() ?? 0),
      schema: '${j['schema'] ?? FirmwareConstants.telemetrySchema}',
      deviceId: '${j['deviceId'] ?? FirmwareConstants.deviceId}',
      firmware: '${j['firmware'] ?? FirmwareConstants.firmwareVersion}',
    );
  }

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'deviceId': deviceId,
    'seq': seq,
    'ts': timestamp.toIso8601String(),
    'mode': mode,
    'relayOn': relayOn,
    'safetyState': safetyState,
    'faultReason': faultReason,
    'lux': lux,
    'targetLux': targetLux,
    'ldrRaw': ldrRaw,
    'currentMa': currentMa,
    'powerW': powerW,
    'dimmerPct': dimmerPct,
    'pid': {'kp': kp, 'ki': ki, 'kd': kd, 'output': pidOutput},
    'uptimeMs': uptime.inMilliseconds,
    'firmware': firmware,
  };

  final int seq;
  final DateTime timestamp;
  final String schema;
  final String deviceId;
  final String firmware;
  final String mode;
  final bool relayOn;
  final String safetyState; // ok | standby | fault
  final String? faultReason; // OVERCURRENT | DAYLIGHT_STANDBY | null
  final double lux;
  final double targetLux;
  final int ldrRaw;
  final double currentMa;
  final double powerW;
  final int dimmerPct;
  final double kp;
  final double ki;
  final double kd;
  final double pidOutput;
  final Duration uptime;

  bool get isFault => safetyState == 'fault';
  bool get isStandby => safetyState == 'standby';
  bool get isOk => safetyState == 'ok';

  /// 0..1 progress of actual lux toward the target (clamped).
  double get luxProgress =>
      targetLux <= 0 ? 0 : (lux / targetLux).clamp(0.0, 1.0);
}
