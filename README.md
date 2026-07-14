# Portly 🔭

**See every local dev server on your Mac — and open, copy, or kill it in one click.**

Portly is a tiny open-source macOS menu bar app for developers. It shows a live list of every TCP port something is listening on, which process owns it, and gives you one-click actions:

- 🌐 **Open** `localhost:<port>` in your browser
- 📋 **Copy** the URL (or the PID)
- 🛑 **Stop** the process — `SIGTERM` by default, hold <kbd>⌥ Option</kbd> to force-kill

No more `Error: listen EADDRINUSE :::3000` → `lsof -i :3000` → `kill -9 <pid>` dance.

<!-- TODO: screenshot — docs/screenshot.png -->

## Features

- **Live port list** — refreshes every 3 seconds while open, sorted by port
- **Pinned ports** — pin `:3000` and `:5432` to the top; when nothing is listening there you get an explicit "nothing listening" row, so *"did my stack come up?"* is one glance away
- **Recently stopped** — listeners that vanished stay visible as ghost rows for 5 minutes ("node · :3000 · stopped 2 min ago")
- **Connection counts** — see how many clients are connected to each listener
- **HTTP health dots** — optionally probe localhost ports and show a green/orange dot for HTTP 2xx/5xx responses (opt-in, skips databases)
- **Menu bar badge** — see how many dev servers are running without opening the panel; the icon turns into a warning when a pinned port goes dark
- **Process details** — click a row for uptime, memory, CPU time, the full command line, sibling ports, and Reveal in Finder
- **Stop All Dev Servers** — end-of-day cleanup in one confirmed click (direct edition)
- **Copy Port List** — the whole panel as a Markdown table, ready for a bug report or standup note
- **Smart hints** — recognizes well-known ports (`5173 · Vite`, `8000 · Django`, `5432 · PostgreSQL`, `11434 · Ollama`, …)
- **Docker-aware** — container-published ports show the container name (`myapp-db`) instead of `com.docker.backend`
- **Notifications** — optionally get notified when something starts or stops listening on a port
- **Dev-focused by default** — macOS system daemons (`rapportd`, `ControlCenter`, …) are hidden unless you enable *Show macOS System Processes*; UDP ports are one toggle away
- **Filter** by port number, process name, protocol, or framework hint
- **Copy as command** — right-click a port to copy a ready-made `curl` or `lsof` command
- **Launch at Login** toggle
- **Native and tiny** — pure SwiftUI, zero dependencies, no Electron, no network access, nothing leaves your Mac

## Editions

Portly builds as two targets from the same codebase:

| | **Portly** (direct download) | **Portly App Store** |
| --- | --- | --- |
| Port list, hints, filter, badge, notifications, pins, ghosts, health probe | ✅ | ✅ |
| Data source | `lsof` | kernel socket tables via `sysctl` (sandbox-safe) |
| Stop / force-kill a process | ✅ one click | 📋 copies a `kill <pid>` command to paste in Terminal (the App Sandbox forbids signaling other processes) |
| Docker container names | ✅ | — (sandbox can't reach the Docker socket) |
| Sees other users' / root listeners | — (`lsof` limitation) | ✅ |
| Sandboxed | no | yes — Mac App Store eligible |

## Install

### Build from source

Requires Xcode 16 or later, runs on macOS 14 (Sonoma) or later.

```sh
git clone https://github.com/tudorturcanu/Portly.git
cd Portly
xcodebuild -project Portly.xcodeproj -scheme Portly -configuration Release build
```

Or just open `Portly.xcodeproj` in Xcode and hit **⌘R**.

## How it works

The direct-download edition shells out to the `lsof` that ships with macOS:

```sh
lsof -nP -iTCP -sTCP:LISTEN
```

…parses its machine-readable (`-F`) output, and resolves each PID to its executable path via `libproc` to tell your dev servers apart from macOS system daemons. Stopping a process sends a plain POSIX signal. That's the whole trick — no kernel extensions, no elevated privileges, no daemons. It only ever sends signals to processes you explicitly click, and only your own processes — anything owned by another user shows a 🔒 instead.

The App Store edition can't spawn `lsof` (a sandboxed child inherits the sandbox and sees nothing), so it reads the kernel's socket tables directly via `sysctl net.inet.{tcp,udp}.pcblist_n` — the same data source `netstat` uses — and resolves pids with `proc_pidpath()`. Both are permitted inside the App Sandbox, and the parser (`SysctlPortScanner.swift`) is validated against `lsof` output.

## Roadmap

- [ ] Global hotkey to open the panel (blocked on SwiftUI: `MenuBarExtra` has no API to open programmatically)
- [ ] Unit tests for the `lsof` and `sysctl` parsers
- [ ] Homebrew cask (`brew install --cask portly`)
- [ ] Notarized release builds via GitHub Actions

## Contributing

Issues and PRs welcome. The codebase is intentionally small:

| File | What it does |
| --- | --- |
| `Models/PortScanner.swift` | Scan facade; runs `lsof` and parses its `-F` output (pure `parse()` function, easy to test) |
| `Models/SysctlPortScanner.swift` | Sandbox-safe scanner for the App Store build (kernel socket tables via `sysctl`) |
| `Models/AppCapabilities.swift` | Compile-time feature switches between the two editions |
| `Models/PortMonitor.swift` | `@Observable` state: port list, background refresh, terminate, change detection |
| `Models/ListeningPort.swift` | Value type for one listening socket |
| `Models/DockerResolver.swift` | Maps container-published host ports to container names via `docker ps` |
| `Models/PortNotifier.swift` | macOS notifications when ports open or close |
| `Models/ProcessInspector.swift` | On-demand process facts (uptime, memory, CPU, argv) via libproc |
| `Views/MenuView.swift` | The menu bar panel |
| `Views/PortRowView.swift` | One row: port, process, hover actions |

## License

[MIT](LICENSE) © 2026 Tudor Turcanu
