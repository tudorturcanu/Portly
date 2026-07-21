# Portly

> Every local dev server, one click away.

Portly is a lightweight macOS menu bar app that shows every process currently listening on a network port — refreshed live, without opening a Terminal. It's built for developers who run multiple local services and want to see, open, copy, or stop them at a glance.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)
![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=flat-square)

---

## What it does

Click the connected-dots icon in your menu bar and instantly see every port with something listening on it — process name, PID, protocol, address, and active connections. No Terminal, no `lsof` one-liners, no polling.

**Key features:**

- **Live port list** — rescans every 3 seconds while the panel is open; keeps a slower background loop running when it's closed so the badge stays current.
- **One-click actions** — hover any row to open `localhost:<port>` in your browser, copy the URL, or stop the process (SIGTERM / SIGKILL). Hold ⌥ to force-kill.
- **Port pinning** — right-click any port to pin it. The menu bar icon switches to a warning triangle the moment a pinned port goes dark.
- **Ghost rows** — recently-closed ports linger for 5 minutes so you can see what just went down.
- **Docker support** — the direct-download build resolves Docker's port-proxy entries to the actual container name, so you see `myapp-db` instead of `com.docker.backend`.
- **HTTP health probing** — optionally polls your dev servers every 15 seconds and shows a green/orange dot per port based on the HTTP status code. Database ports are skipped automatically.
- **Notifications** — opt-in system notifications whenever a port opens or closes.
- **Process details** — click any row for a popover with the executable path, PID, user, start time, CPU time, memory usage, full command line, and any other ports the same process holds.
- **"Stop All Dev Servers"** — one confirmation to SIGTERM every non-system TCP listener you own.
- **Copy port list** — copies the visible ports as a Markdown table, useful for pasting into issues or runbooks.

---

## Requirements

| | |
|---|---|
| **macOS** | 14 Sonoma or later |
| **Architecture** | Apple Silicon & Intel |
| **Xcode** | 15+ (to build from source) |

---

## Installation

### Direct download (recommended)

Download the latest `.dmg` from [Releases](../../releases) and drag Portly into `/Applications`.

The default build uses `lsof` to scan ports and can stop processes directly from the UI.

### Build from source

```bash
git clone https://github.com/<you>/Portly.git
cd Portly
open Portly.xcodeproj
```

Select the **Portly** scheme, choose your Mac as the run destination, and press **⌘R**.

---

## Sandboxed Mode vs. Standard Mode

Portly supports two execution modes:

- **Standard Mode (Default)**: Uses `lsof` to scan ports and resolves Docker container names. It allows terminating processes directly from the UI using the Stop button (or holding `⌥` to force-kill).
- **Sandboxed Mode**: Activated by building with the `APPSTORE` compilation flag (e.g., if you run Portly inside an App Sandbox). Since sandboxed applications cannot inspect other processes via `lsof` or signal them directly, this mode reads kernel socket tables via `sysctl` and replaces the Stop button with a "Copy kill command" helper that copies the command to your clipboard.

---

## Usage

1. **Launch** — Portly lives exclusively in the menu bar. There is no Dock icon. First launch shows a short onboarding window.
2. **Browse ports** — click the menu bar icon to open the panel. Ports are sorted by number, with pinned ports at the top.
3. **Search / filter** — a search field appears automatically when you have more than six ports. Type a port number, process name, or well-known service hint (e.g. "Postgres", "Redis") to filter.
4. **Act on a port** — hover a row to reveal quick-action buttons, or right-click for the full context menu:
   - Open in Browser
   - Copy URL
   - Copy `curl` / `lsof` command
   - Copy PID
   - Reveal executable in Finder
   - Pin / Unpin
   - Stop / Force Kill (Standard mode) or Copy kill command (Sandboxed mode)
5. **Settings** — open via the gear icon → Settings… (⌘,):
   - *General* — Launch at Login, menu bar badge count
   - *Filtering* — show/hide macOS system processes and UDP ports
   - *Notifications* — port open/close notifications, HTTP health probing

---

## Architecture

```
Portly/
├── Models/
│   ├── PortMonitor.swift        # Observable state: ports, pinned, ghosts, health
│   ├── PortScanner.swift        # lsof backend (Standard mode)
│   ├── SysctlPortScanner.swift  # sysctl backend (Sandboxed mode)
│   ├── DockerResolver.swift     # Maps Docker proxy ports → container names
│   ├── ListeningPort.swift      # Core value type for a listening socket
│   ├── ClosedPort.swift         # Ghost record for recently-closed ports
│   ├── PortHint.swift           # Well-known port → service name mapping
│   ├── PortNotifier.swift       # System notification posting
│   ├── ProcessInspector.swift   # Reads CPU time, memory, argv via libproc
│   ├── ProcessDetails.swift     # Value type returned by ProcessInspector
│   ├── AppCapabilities.swift    # Compile-time Standard vs. Sandboxed flags
│   └── LaunchAtLogin.swift      # SMAppService wrapper
└── Views/
    ├── MenuView.swift           # Main panel (search, port list, footer)
    ├── PortRowView.swift        # Individual port row with hover actions
    ├── ProcessDetailView.swift  # Click-to-open detail popover
    ├── DeadPinnedRowView.swift  # Placeholder row for a pinned port with no listener
    ├── ClosedPortRowView.swift  # Ghost row for recently-closed ports
    ├── SettingsView.swift       # Three-tab Settings window
    ├── OnboardingView.swift     # First-launch welcome screen
    ├── LaunchToast.swift        # Brief banner on subsequent launches
    ├── AboutView.swift          # About screen
    ├── AboutWindow.swift        # NSWindow wrapper for About
    └── OnboardingWindow.swift   # NSWindow wrapper for Onboarding
```

### How scanning works

**Standard Mode** — `PortScanner` runs `/usr/sbin/lsof -nP -iTCP -iUDP +c 0 -FpcLnPT` asynchronously and parses the field-per-line output. It then enriches each entry with the full executable path via `proc_pidpath`, and resolves Docker port-proxy entries to container names by calling `docker ps --format '{{json .}}'`.

**Sandboxed Mode** — `SysctlPortScanner` reads `net.inet.tcp.pcblist_n` and `net.inet.udp.pcblist_n` directly from the kernel via `sysctl` (activated when compiling with the `APPSTORE` flag). It parses the binary `xinpcb_n` / `xsocket_n` / `xtcpcb_n` structures to extract local ports, PIDs, and TCP states, then resolves process names and executable paths with `proc_pidpath`.

Both backends return the same `[ListeningPort]` array, deduplicated per `pid:port:protocol`. `PortMonitor` owns the list, runs the refresh loop, tracks ghost ports, fires notifications, and runs the optional HTTP health probe.

---

## Contributing

Pull requests are welcome. For significant changes, please open an issue first to discuss what you'd like to change.

```bash
# Run a local build
open Portly.xcodeproj   # ⌘R to run
```

There are no external Swift package dependencies — the project uses only system frameworks (`SwiftUI`, `Foundation`, `Observation`, `ServiceManagement`).

---

## License

[MIT](LICENSE) © 2026 Tudor Turcanu
