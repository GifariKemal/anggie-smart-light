<p align="center">
  <img src="assets/banner.svg" alt="Anggie Smart Light" width="100%">
</p>

<h1 align="center">📱 App Guide (Saqelar)</h1>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-stable-38BDF8?style=flat-square&logo=flutter&logoColor=white" alt="flutter">
  <img src="https://img.shields.io/badge/theme-dark%20control%20room-0F172A?style=flat-square" alt="theme">
  <img src="https://img.shields.io/badge/analyze-no%20issues-22C55E?style=flat-square" alt="analyze">
</p>

Saqelar is the Flutter front end for Anggie. It presents the device as a dark "control room" dashboard with an animated lux gauge, live trends, PID and safety panels, and a control surface. It reads real device data over WiFi and uses a built in simulator when no device is connected.

---

## 📋 Table of contents

| Section | Content |
| :-- | :-- |
| [Design system](#-design-system) | Colors, type, motion |
| [Screens](#-screens) | Every screen and its job |
| [Code structure](#-code-structure) | Modules and responsibilities |
| [Data source](#-data-source) | Live device and simulator |
| [Build and run](#-build-and-run) | Commands |
| [Quality](#-quality) | Accessibility and testing |

---

## 🎨 Design system

| Token | Value | Use |
| :-- | :-- | :-- |
| Background | `#0F172A` | Deep slate canvas |
| Surface | `#1E293B` | Cards and panels |
| Accent | `#22C55E` | Status ok, live, on |
| Warning | `#F59E0B` | Standby, night |
| Danger | `#EF4444` | Fault |
| Info | `#38BDF8` | Neutral data |
| Display font | FiraSans | Labels and headings |
| Mono font | FiraMono | All numeric HUD values |

The single green accent doubles as the firmware `safetyState` of `ok`. Numbers use a monospace face for a tidy instrument feel. Motion respects the system reduced motion setting.

---

## 🧱 Screens

| Screen | Purpose |
| :-- | :-- |
| 🟢 Splash | Brand boot bar with INIT, LINK, READY stages |
| 🟢 Onboarding | Three slides with a live telemetry preview card |
| 🟢 Dashboard | Lux gauge, dimmer bar, metrics, trends, PID, safety guard |
| 🟢 Control panel | Mode selector, target and PID sliders, demo scenarios |
| 🟢 Settings | Device connection, source switch, status |

A full screenshot tour is in [flow/README.md](flow/README.md).

---

## 🗃️ Code structure

<p align="center">
  <img src="assets/diagrams/app-structure.svg" alt="App code structure" width="100%">
</p>

| Path | Responsibility |
| :-- | :-- |
| `lib/app/app_theme.dart` | Theme tokens, radius scale, motion helper |
| `lib/models/telemetry.dart` | Contract model, `FirmwareConstants`, JSON |
| `lib/services/device_simulator.dart` | Telemetry source, simulation, MQTT subscribe |
| `lib/services/device_scope.dart` | Provider via InheritedNotifier |
| `lib/services/sfx.dart` | Sound effects and haptics |
| `lib/widgets/hud_widgets.dart` | Gauge, sparkline, metric tile, grid background |
| `lib/screens/` | Splash, onboarding, dashboard, control, settings |

---

## 🔌 Data source

The app has one source object that can run in two modes:

<p align="center">
  <img src="assets/diagrams/app-source.svg" alt="Live device or simulator source" width="100%">
</p>

The app auto-connects to the default broker and topic on launch, so integration is hands off. When telemetry arrives the dashboard shows real values, the header badge flips to DEVICE, and a floating notification confirms the live link. If the stream goes quiet for six seconds it falls back to simulation and notifies again. You only open Settings to use a different broker or topic, or to force the simulator with Putuskan. Choices are saved with `shared_preferences`.

| Signal | Where |
| :-- | :-- |
| Indicator | Header badge: `SIM` or `DEVICE` |
| Notification | Floating SnackBar on connect, fallback, and command ack |
| Command ack | Device confirms each command on the ack topic |
| Activity log | Settings screen keeps a timestamped feed of every step |
| Fallback | Local simulator, automatic after a six second silence |

---

## 🏃 Build and run

```powershell
cd Apps/saqelar/saqelar/saqelar
flutter pub get
flutter analyze
flutter test
flutter run                 # debug on a connected device
flutter build apk --release # release build
```

> 💡 The app talks to the broker over a plain MQTT TCP socket. Only the INTERNET permission is needed, already declared in the Android manifest.

---

## ♿ Quality

| Check | Status |
| :-- | :-- |
| Static analysis | No issues found |
| Unit tests | Telemetry getters, safety palette, `fromJson` |
| Accessibility | Semantic labels, reduced motion, text scaling clamp |
| Touch targets | Minimum 48 dp on primary controls |
| Color use | Status backed by text, not color alone |

---

<p align="center">
  <sub>© 2026 PT Surya Inovasi Prioritas (SURIOTA). Author: Gifari Kemal Suryo. MIT License.</sub>
</p>
