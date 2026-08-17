<div align="center">
  <img src="assets/icon/app_icon.png" width="120" alt="FPSWatcher Logo">
  
  # FPSWatcher Next
  
  **The Ultimate Android Game Telemetry & Performance Profiler**
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.4+-02569B?logo=flutter)](https://flutter.dev)
  [![Rust](https://img.shields.io/badge/Rust-Core-000000?logo=rust)](https://www.rust-lang.org)
  [![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

**FPSWatcher Next** is an advanced, lightweight Android game telemetry and session-analysis tool. Built with a beautiful **Flutter** interface and a blazing-fast **Rust** analytics core, it gives you PC-level performance metrics right on your mobile device. 

The app intentionally relies on only two secure, privileged telemetry backends: **Shizuku** and **Root**. No messy hacks, just pure, accurate data.

## 🚀 Key Features

### 🎮 Frame Performance
Get absolute clarity on your gaming fluidity.
- **SurfaceFlinger FPS** with accurate `gfxinfo` fallbacks.
- **Micro-stutter & Lows:** Rolling 5%, 1%, and 0.1% low FPS metrics.
- **Frame Analytics:** Average, P95, P99, best, and worst frame times.
- **Visuals:** Frame-time histograms and live FPS history graphs.
- **Stability:** Frame-pacing, frame-stability scores, and frozen-frame detection.

### 🧠 CPU, GPU & Process Telemetry
Understand what's bottlenecking your device.
- **Per-core CPU Tracking:** Load, frequency, policy clocks, and governor states.
- **GPU Discovery:** Supports Qualcomm KGSL, generic devfreq, Arm Mali, MediaTek GED, and select debugfs nodes.
- **Process Deep-Dive:** Thread counts, nice values, CPU affinity, and scheduler policies.
- **Headroom Analysis:** Load-aware CPU/GPU throttling detection.

### 🔋 Power, Thermals & Memory
Monitor your device's physical limits.
- **Battery Health:** Discharge power, current, voltage, and temperature.
- **Efficiency:** Real-time FPS-per-watt efficiency and estimated remaining game time.
- **Thermal Zones:** Automatic matching of SoC/CPU/GPU thermal zones with throttling alerts.
- **Memory Pressure:** Game PSS/RSS, system RAM, swap, ZRAM, and PSI memory pressure.

### 📡 Network & Display
- **Network Probing:** Non-blocking ping, jitter, packet-loss, and RX/TX throughput.
- **Connection Details:** Wi-Fi RSSI, link speed, and cellular signal summary.
- **Display Sync:** Refresh rate, refresh/FPS ratio, and VSync drop estimation.

---

## 🛠️ Under the Hood

FPSWatcher is engineered for **minimal overhead**. The native monitor never gets in the way of your gaming:
- **Rust Analytics Core:** The telemetry parser is written entirely in Rust, utilizing `OnceLock` cached regexes, zero-allocation string splits, and pre-allocated capacity vectors to ensure near-zero CPU and memory footprint.
- **Smart Sampling:** Fast counters (FPS) use short intervals, while expensive probes (like `dumpsys`) are independently cached.
- **Native Overlay:** The in-game overlay is rendered via native Android APIs (not Flutter) to ensure square-corner, zero-latency drawing. Includes multiple presets (minimal, thermal, network, full).

## 📊 Sessions and Reports
Record sessions natively in the background without interrupting your game.
- **Manual Markers:** Add markers to split your session (e.g., "Boss Fight", "Menu").
- **Drift Analysis:** Automatically compare first-half vs. second-half performance to detect thermal throttling over time.
- **Export Everywhere:** Export your raw data or formatted reports in **CSV**, **JSON**, **HTML**, or **PNG** dashboards.

---

## 🤝 Contributing
We love community contributions! If you'd like to help improve FPSWatcher:
1. Check out our [Contributing Guidelines](CONTRIBUTING.md).
2. Review the [Code of Conduct](CODE_OF_CONDUCT.md).
3. Open an issue or submit a Pull Request!

## 🛡️ Security
If you discover a vulnerability, please refer to our [Security Policy](SECURITY.md) for reporting guidelines.

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
