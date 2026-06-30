<p align="center">
  <img src="../docs/assets/banner.svg" alt="Anggie Smart Light" width="100%">
</p>

<h1 align="center">🧪 Backend Scaffold (optional)</h1>

<p align="center">
  <img src="https://img.shields.io/badge/runtime-Node%20+%20Express-22C55E?style=flat-square&logo=node.js&logoColor=white" alt="node">
  <img src="https://img.shields.io/badge/status-reference%20harness-64748B?style=flat-square" alt="status">
</p>

A small Express and TypeScript contract harness kept for reference. It mirrors the device endpoints (`/telemetry`, `/lights`, `/health`) and was used for early end to end tests.

> ℹ️ This is not used by the app at runtime. The app talks directly to the ESP32 over WiFi, or runs its built in simulator. Keep this only if you want a desktop stand in for the device during development.

## 🏃 Run

```powershell
npm install
npm run build
npm start        # serves on port 3000
```

## 🔗 Related

| Topic | Link |
| :-- | :-- |
| How the app and device integrate | [../docs/INTEGRATION.md](../docs/INTEGRATION.md) |
| Project overview | [../README.md](../README.md) |

---

<p align="center">
  <sub>© 2026 PT Surya Inovasi Prioritas (SURIOTA). Author: Gifari Kemal Suryo. MIT License.</sub>
</p>
