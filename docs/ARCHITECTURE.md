<p align="center">
  <img src="assets/banner.svg" alt="Anggie Smart Light" width="100%">
</p>

<h1 align="center">🧭 Architecture</h1>

<p align="center">
  <img src="https://img.shields.io/badge/system-firmware%20+%20app-22C55E?style=flat-square" alt="system">
  <img src="https://img.shields.io/badge/pattern-one%20contract-38BDF8?style=flat-square" alt="pattern">
</p>

A high level view of how Anggie is put together, from the silicon to the screen.

---

## 📋 Table of contents

| Section | Content |
| :-- | :-- |
| [System map](#-system-map) | The big picture |
| [Components](#-components) | Each part and its role |
| [The shared contract](#-the-shared-contract) | One model on both sides |
| [Control loop](#-control-loop) | How the device decides |
| [App layers](#-app-layers) | How the UI is organized |
| [Design principles](#-design-principles) | The rules we follow |

---

## 🗺️ System map

<p align="center">
  <img src="assets/dataflow.svg" alt="Data flow from hardware to app" width="100%">
</p>

```mermaid
flowchart TB
  subgraph FW["Firmware (ESP32)"]
    direction TB
    sense["Sense: BH1750, LDR, ACS712, RTC"]
    think["Think: EMA, PID, state machine"]
    act["Act: relay, AC dimmer"]
    serve["Serve: telemetry over Serial and HTTP"]
    sense --> think --> act
    think --> serve
  end
  subgraph APP["App (Flutter)"]
    direction TB
    source["Source: poll device or simulate"]
    model["Model: device.telemetry.v1"]
    ui["UI: dashboard, control, settings"]
    source --> model --> ui
  end
  serve -->|JSON over WiFi| source
```

---

## 🧩 Components

| Layer | Element | Responsibility |
| :-- | :-- | :-- |
| Sense | BH1750, LDR, ACS712, DS3231 | Measure lux, ambient, current, time |
| Think | EMA filter, PID, state machine | Smooth, control, and protect |
| Act | Relay, AC dimmer | Switch and dim the lamp |
| Serve | Serial, WiFi HTTP | Publish telemetry |
| Source | DeviceSimulator | Poll the device or simulate locally |
| Model | Telemetry, FirmwareConstants | Parse and hold the contract |
| UI | Screens and HUD widgets | Present and interact |

---

## 🤝 The shared contract

Both sides speak `device.telemetry.v1`. The firmware writes it with ArduinoJson. The app reads it with `Telemetry.fromJson`. The numeric limits live in one place per side and are kept in sync.

| Concept | Firmware | App |
| :-- | :-- | :-- |
| Target lux | `SETPOINT` 500 | `defaultTargetLux` 500 |
| Overcurrent | `MAX_SAFE_CURRENT` 5000 mA | `maxSafeCurrentMa` 5000 |
| Daylight cutoff | `LDR_DAYLIGHT` 3000 | `ldrDaylightRaw` 3000 |
| Dimmer ceiling | `DIMMER_CEILING` 80 | `dimmerMaxPct` 80 |
| Night window | 22 to 6 | `nightStartHour` to `nightEndHour` |

This is the single most important rule of the project. One contract, two faithful implementations.

---

## 🔁 Control loop

```mermaid
stateDiagram-v2
  [*] --> SAFE_PID_ACTIVE
  SAFE_PID_ACTIVE --> OVERCURRENT_TRIP: current > 5 A
  SAFE_PID_ACTIVE --> NIGHT_MODE: hour in night window
  SAFE_PID_ACTIVE --> DAYLIGHT_OFF: filtered LDR > 3000
  NIGHT_MODE --> OVERCURRENT_TRIP: current > 5 A
  DAYLIGHT_OFF --> SAFE_PID_ACTIVE: ambient drops
  OVERCURRENT_TRIP --> SAFE_PID_ACTIVE: current safe again
```

Safety always wins. Remote commands, when they arrive, will be advisory and the device keeps final authority.

---

## 🧱 App layers

```mermaid
flowchart TD
  scope["DeviceScope (InheritedNotifier)"] --> sim["DeviceSimulator (ChangeNotifier)"]
  sim --> poll["HTTP poller"]
  sim --> gen["Local simulation"]
  scope --> screens["Screens"]
  screens --> widgets["HUD widgets and painters"]
```

State flows from one notifier down through an inherited widget, so screens rebuild on each telemetry tick while custom painters stay isolated with repaint boundaries.

---

## 🎯 Design principles

| Principle | In practice |
| :-- | :-- |
| One contract | `device.telemetry.v1` on both sides |
| Safety first | The device, not the app, controls the relay |
| Always demonstrable | Simulator fallback when no hardware |
| Minimal footprint | Standard library and platform features before new dependencies |
| Honest UI | Status shown with text and icon, not color alone |

---

<p align="center">
  <sub>© 2026 PT Surya Inovasi Prioritas (SURIOTA). Author: Gifari Kemal Suryo. MIT License.</sub>
</p>
