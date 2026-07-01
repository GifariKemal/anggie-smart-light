<p align="center">
  <img src="assets/banner.svg" alt="Anggie Smart Light" width="100%">
</p>

<h1 align="center">🔗 Integration Guide</h1>

<p align="center">
  <img src="https://img.shields.io/badge/contract-device.telemetry.v1-22C55E?style=flat-square" alt="contract">
  <img src="https://img.shields.io/badge/transport-WiFi%20HTTP-F59E0B?style=flat-square" alt="transport">
  <img src="https://img.shields.io/badge/direction-device%20to%20app-38BDF8?style=flat-square" alt="direction">
</p>

How the ESP32 device and the Saqelar app connect into one working system over WiFi, using a single JSON contract.

---

## 📋 Table of contents

| Section | Content |
| :-- | :-- |
| [Data flow](#-data-flow) | The end to end picture |
| [Topics](#-topics) | MQTT topics and payload |
| [Sequence](#-sequence) | Request and response timing |
| [Connect steps](#-connect-steps) | Bring it online |
| [Requirements](#-requirements) | What must be true |
| [Troubleshooting](#-troubleshooting) | Common issues |
| [Two way control](#-two-way-control) | Command topic and payloads |

---

## 🌊 Data flow

<p align="center">
  <img src="assets/dataflow.svg" alt="Data flow from hardware to app" width="100%">
</p>

The device publishes telemetry to a broker. The app subscribes and consumes it. There is one shared contract, so when telemetry arrives the app shows real data and stops simulating.

---

## 🧪 Topics

Public broker `broker.emqx.io` on plain TCP port `1883` (no TLS).

| Topic | Direction | Payload |
| :-- | :-- | :-- |
| `suriota/anggie-001/telemetry` | device publishes, app reads | `device.telemetry.v1` JSON, once per second |
| `suriota/anggie-001/command` | app publishes, device reads | JSON command (future control feature) |

All device data is carried in the single telemetry topic. Control adds a second topic later, so read and write stay cleanly separated.

```bash
# watch live telemetry from any machine with mosquitto tools
mosquitto_sub -h broker.emqx.io -p 1883 -t "suriota/anggie-001/telemetry" -v
```

---

## ⏱️ Sequence

<p align="center">
  <img src="assets/diagrams/int-sequence.svg" alt="Integration request sequence" width="100%">
</p>

---

## ✅ Connect steps

1. 🔧 Flash the ESP32. On first boot join its `Anggie-Setup` WiFi from a phone and pick your network in the captive portal (see [FIRMWARE.md](FIRMWARE.md)).
2. 🖥️ Open Serial Monitor at 115200 and confirm `MQTT connected` plus a published telemetry line.
3. 📱 The app auto-connects to the default broker and topic on launch. To use different values, open Settings from the gear icon, edit them, and tap Sambungkan.
4. 🟢 When telemetry arrives the header badge flips SIM to DEVICE and a notification confirms the live link.

To force the simulator, tap Putuskan. The app also falls back on its own after six seconds without data.

---

## 📐 Requirements

| Requirement | Why |
| :-- | :-- |
| Internet access on both sides | Device and phone reach the public broker, they do not need the same LAN |
| 2.4 GHz WiFi for the ESP32 | The ESP32 radio does not use 5 GHz |
| WiFi credentials set | The device needs to join a network before publishing |
| Same broker and topic | The app must subscribe to the exact topic the device publishes |

---

## 🧯 Troubleshooting

| Symptom | Likely cause | Fix |
| :-- | :-- | :-- |
| Badge stays SIM | Broker or topic empty or wrong | Re enter broker and topic in Settings |
| No data after connect | App and device on different topics | Make both use the exact same topic string |
| Device never publishes | WiFi not joined | Redo the captive portal (join `Anggie-Setup`), watch Serial Monitor |
| Values go stale then SIM | Device or broker dropped | App auto falls back after 6 seconds, then resumes on reconnect |

---

## 🔁 Two way control

Control is live. When the app is connected to a device, the Control panel publishes commands to the command topic, and the firmware applies them. The on device safety state machine always keeps final authority, so overcurrent still trips the relay no matter what is sent.

<p align="center">
  <img src="assets/diagrams/int-control.svg" alt="Two way control flow" width="100%">
</p>

Command topic: `suriota/anggie-001/command`. Send any subset of these fields as JSON:

| Field | Type | Effect |
| :-- | :-- | :-- |
| `mode` | string | `auto`, `manual`, or `off` |
| `targetLux` | number | PID setpoint, clamped 0 to 1000 |
| `dimmer` | int | Manual dimmer percent, clamped 0 to 80, used in manual mode |
| `kp` / `ki` / `kd` | number | Live PID tuning |

```bash
# from any machine, set the device to manual at 55 percent
mosquitto_pub -h broker.emqx.io -p 1883 -t "suriota/anggie-001/command" \
  -m '{"mode":"manual","dimmer":55}'
```

In the app you never touch this directly. Moving a slider or picking a mode in the Control panel publishes the matching command automatically while connected, and drives the simulator when offline.

---

<p align="center">
  <sub>© 2026 PT Surya Inovasi Prioritas (SURIOTA). Author: Gifari Kemal Suryo. MIT License.</sub>
</p>
