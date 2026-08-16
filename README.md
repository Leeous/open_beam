<div align="center">


<img src="https://raw.githubusercontent.com/Leeous/open_beam/main/assets/icon/icon.svg" width="96">

# Open Beam

A cross-platform Smart TV remote control application built with Flutter.

![Status](https://img.shields.io/badge/Status-WIP-yellow)
![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=flat&logo=dart&logoColor=white)
![Platforms](https://img.shields.io/badge/platform-Linux%20%7C%20Android-blue)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
</div>

### Target Brand & Protocol Support
| Brand / OS | Protocol | Local Discovery | Auth Method | D-Pad / Nav | App Launching | WoL (Power On) | Status / Implementation |
| :--- | :--- | :--- | :--- | :---: | :---: | :---: | :--- |
| **Roku** *(Roku OS)* | ECP (HTTP REST) | SSDP (`1900/UDP`) | None (Unauthenticated) | 🟡 | 📋 | 📋 | **WIP** |
| **Vizio** *(SmartCast)* | HTTPS REST | mDNS (`5353/UDP`) / SSDP | PIN Handshake $\rightarrow$ Token | ✅ | 📋 | ❓ | **Supported** |
| **Sony** *(Android/Google TV)* | IRCC / JSON-RPC (HTTP/S) | SSDP (`1900/UDP`) / mDNS | Pre-Shared Key (PSK) | 📋 | 📋 | 📋 | **Experimental** *(Untested hardware)* |
| **Samsung** *(Tizen)* | WebSockets (`8002/WSS`) | SSDP / mDNS | Token Pairing Prompt | 📋 | 📋 | 📋 | **Planned** |
| **LG** *(webOS)* | WebSockets (`3001/WSS`) | SSDP (`1900/UDP`) | Client Key Handshake | 📋 | 📋 | 📋 | **Planned** |
---

### Legend
* ✅ **Supported:** Fully implemented and verified.
* 🟡 **In Progress / Experimental:** API abstraction logic implemented, but awaiting local device testing or active code execution.
* ❌ **Not Supported:** Not yet implemented for this protocol.
* 📋 **Planned:** On the roadmap for future releases.