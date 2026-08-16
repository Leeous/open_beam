# Smart TV Control Protocols, Ports, and Communication Reference

This document serves as an technical reference for IP-based remote control, discovery, and network management across major Smart TV platforms.

---

## Brand-Specific Protocol Summary

| Brand | Operating System | Primary API Protocol | Key Ports | Discovery | Auth / Security |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Roku** | Roku OS | External Control Protocol (ECP / REST) | `8060` (HTTP) | SSDP (`1900/UDP`) | None (Unauthenticated) |
| **Vizio** | SmartCast | HTTPS REST API | `9000` (HTTPS) | mDNS (`5353/UDP`), SSDP | Pair/PIN handshake $\rightarrow$ Auth Token |
| **Sony** | Android TV / Google TV | IRCC (XML over HTTP) / REST JSON-RPC | `80`, `443` (HTTP/S) | SSDP, mDNS | Pre-Shared Key (PSK) or OAuth PIN |
| **LG** | webOS | WebSockets / IP Control | `3000` (WS), `3001` (WSS), `9761` (Encrypted TCP) | SSDP, SDDP | Client Key Handshake / AES-128 |
| **Samsung**| Tizen OS | REST API & WebSockets | `8001` (WS), `8002` (WSS) | SSDP, mDNS | Token Pairing / On-Screen Prompt |
| **Apple** | tvOS | Media Remote Protocol (MRP) / AirPlay 2 | `7000`, `7100`, `3689` (TCP) | mDNS (`_mediaremotetv._tcp`) | SRP / HomeKit Pair Verification |
| **Android** | Android TV / Google TV | Android TV Remote Control Protocol v2 | `6466` (TLS), `6467` (HTTP) | mDNS (`_androidtvremote2._tcp`) | TLS Certificate / PIN Pairing |

---

## Detailed OS Implementations

### 1. Roku OS (External Control Protocol)
Roku uses an unauthenticated HTTP REST interface for control commands, app execution, and status queries.

* **Network Ports:**
  * **`8060` (TCP):** Main ECP REST API. Accepts `POST` requests for keypresses and `GET` requests for device info/apps.
  * **`1900` (UDP):** SSDP discovery listener (`M-SEARCH` target `urn:roku-com:device:common:1`).
  * **`8080` (TCP):** Developer server (sideloading apps, debug logs).
* **Control Examples:**
  * Keypress: `POST http://<TV_IP>:8060/keypress/Home`
  * Launch App: `POST http://<TV_IP>:8060/launch/12` (Netflix)

---

### 2. Vizio SmartCast
Vizio set-top boxes and Smart TVs utilize a RESTful API wrapped over HTTPS. Because Vizio uses a self-signed SSL certificate locally, clients must bypass SSL/TLS verification during HTTP client setup.

* **Network Ports:**
  * **`9000` (TCP):** Default HTTPS port for control commands and pairing endpoints.
  * **`7000` (TCP):** Alternate HTTP port on older SmartCast models.
  * **`5353` (UDP):** mDNS discovery (`_viziocast._tcp.local`).
* **Authentication Flow:**
  1. Trigger PIN prompt on TV screen (`/pairing/start`).
  2. Send user-entered PIN to obtain `AUTH_TOKEN` (`/pairing/pair`).
  3. Attach `AUTH_TOKEN` header to all subsequent HTTP requests.

---

### 3. Sony Bravia (Android TV / Google TV)
Sony TVs support direct local IP control using either Infrared Compatible Control (IRCC) commands over HTTP or direct JSON-RPC calls.

* **Network Ports:**
  * **`80` / `443` (TCP):** Main API endpoints (`http://<TV_IP>/sony/ircc` or `/sony/system`).
  * **`1900` (UDP):** SSDP discovery (`urn:schemas-sony-com:service:IRCC:1`).
* **Authentication:**
  * **PSK Mode (Easiest):** Enable *Pre-Shared Key* in TV settings (`Settings -> Network -> IP Control`) and supply custom `X-Auth-PSK` header in requests.
  * **PIN Mode:** OAuth2 style handshake returning a cookie token.

---

### 4. LG webOS
Modern LG TVs use a WebSocket connection for user interface commands and media control, alongside an encrypted IP Control interface (often used by commercial integration systems).

* **Network Ports:**
  * **`3000` (TCP):** Plaintext WebSocket (legacy models / unsecure mode).
  * **`3001` (TCP):** Secure WebSocket (`wss://`).
  * **`9761` (TCP):** Encrypted Network IP Control (requires AES-128 key generation via TV settings).
  * **`1900` (UDP):** SSDP discovery (`urn:schemas-upnp-org:device:MediaRenderer:1`).

---

### 5. Samsung Tizen
Samsung uses a combination of standard HTTP endpoints for discovery and metadata, and WebSockets for real-time remote key inputs.

* **Network Ports:**
  * **`8001` (TCP):** Plaintext WebSocket / REST API endpoint (`http://<TV_IP>:8001/api/v2/`).
  * **`8002` (TCP):** Secure WebSocket endpoint (`wss://<TV_IP>:8002/api/v2/channels/samsung.remote.control`).
  * **`1900` (UDP):** SSDP discovery (`urn:samsung.com:device:RemoteControlReceiver:1`).
* **Authentication:**
  * Connecting to the WebSocket triggers a confirmation prompt on the TV screen. Upon approval, the TV issues an explicit `token` string used for future WebSocket connection parameters.

---

## Universal Network Utilities

### Discovery Protocols
* **SSDP (Simple Service Discovery Protocol):** Multicast address `239.255.255.250:1900` (UDP). Used by Roku, Sony, LG, Samsung, and Vizio.
* **mDNS / DNS-SD (Multicast DNS):** Multicast address `224.0.0.251:5353` (UDP). Used by Vizio, Apple TV, Google TV, and Sony.

### Power Management
* **Wake-on-LAN (WoL):** **`7` or `9` (UDP)**. Broadcasts a Magic Packet containing the TV's MAC address to power on sets from standby/sleep states when network interfaces are powered down.