# Portly Feature Proposals

Here are several new feature ideas for Portly to enhance its utility as a developer tool:

## 1. One-Click Public Tunnels (ngrok / Cloudflare) (Implemented)
Allow users to instantly expose a local dev server to the internet.
* **How it works**: A new quick-action button on hover (e.g., a "globe" icon). Clicking it spins up an `ngrok` or `cloudflared` tunnel in the background and copies the public URL to the clipboard.
* **Why it's useful**: Developers frequently need to share local progress with clients/teammates or test webhooks (like Stripe or GitHub). This removes the need to open a terminal and type tunnel commands.

## 2. Real-Time Network Activity & Connection Counts (Implemented)
Show how much data is flowing through a port and inspect active client connections.
* **How it works**: Displays active established TCP connections with client IP, port, origin (Localhost, LAN, WAN), and client process resolution. Provides live connection traffic sparklines and an Active Connections inspector in Process Details.
* **Why it's useful**: Helps developers immediately identify if their dev server is hanging due to being hammered by requests, or if a websocket connection is successfully pushing data.

## 3. "Open in Terminal" & Log Tailing (Implemented)
Provide quick access to the process's environment.
* **How it works**: A right-click context menu option to "Open in Terminal," which opens the user's preferred terminal emulator (Terminal.app, iTerm2, Ghostty) at the **Working Directory** of the process.
* **Why it's useful**: When a port throws an error or needs restarting, the developer usually needs to interact with its source code or restart it. Taking them straight to the directory saves time.

## 4. Kubernetes & Docker Compose Integration (Implemented)
Enhance the current Docker support to understand broader orchestration tools.
* **How it works**: 
  * If a port is opened by `kubectl port-forward`, label it with the remote pod/service name.
  * If opened by Docker Compose, show the compose service name and allow restarting that specific service directly from Portly.
* **Why it's useful**: Developers working in microservice architectures often have dozens of forwarded or containerized ports. Naming them accurately is a huge quality-of-life improvement.

## 5. Environment Variable (.env) Inspector (Implemented)
See the configuration a process was launched with.
* **How it works**: In the "Process Details" popover, add an "Environment" tab that displays the environment variables the process was launched with (reading via `libproc` or similar). 
* **Why it's useful**: Helps debug issues like "Why is this server connecting to the staging DB instead of local?" by letting the developer verify `DATABASE_URL` at a glance.

## 6. Port History & Analytics (Implemented)
A look back at what was running.
* **How it works**: Expand the "Ghost rows" feature into a persistent local SQLite log. A new "History" tab could show what ports were active over the past week and what processes owned them.
* **Why it's useful**: "What was that weird auth service running on 5050 last Tuesday?" - Solves the problem of ephemeral developer knowledge.

## 7. Custom Scripts / Actions (Implemented)
Extensibility for power users.
* **How it works**: Allow users to attach a custom shell script to a specific pinned port or globally, with variable interpolation (`$PORT`, `$PID`, `$CWD`, `$URL`, `$NAME`, `$HOST`).
* **Why it's useful**: Turns Portly from a read-only monitoring tool into a personalized command center for their specific project.

## 8. Dev Profiles & Project Stacks (Implemented)
Group ports into named stacks (e.g. "Full Stack Web", "Microservices").
* **How it works**: Dedicated Settings tab to create profiles with custom or selected active ports. Menu view filter allows focusing on a single project stack while alerting to any stopped or missing dependencies.
* **Why it's useful**: Developers juggling multiple projects can instantly see if all required dependencies for a specific repo or feature branch are running.

## 9. One-Click Process & Service Restarter (Implemented)
Restart native servers or Docker containers directly from the UI.
* **How it works**: Reads the original command arguments and working directory, issues a graceful SIGTERM, verifies port clearance, and re-spawns the server via the user's login shell. For Docker, executes a graceful container restart.
* **Why it's useful**: Eliminates the cycle of having to switch to a terminal to kill and restart unresponsive dev servers.

## 10. HTTP Latency Probing & Port Benchmarking (Implemented)
Measure real-time server responsiveness and benchmark throughput.
* **How it works**: HTTP health probes now track latency in milliseconds. Dedicated benchmark window sends rapid request batches (5x, 10x, 25x) to measure minimum, average, maximum response times, requests per second, and assigns a responsiveness rating.
* **Why it's useful**: Quickly identify performance bottlenecks or frozen event loops during development.

## 11. Built-in Static Folder HTTP Server ("Serve Folder on Port") (Implemented)
Instantly host arbitrary folders over HTTP.
* **How it works**: Accessible from the gear menu, spins up macOS's built-in Python 3 HTTP server (`python3 -m http.server <port> --directory <path>`) with a suggested free port, directory picker, and live server management.
* **Why it's useful**: Perfect for testing static HTML/JS builds, documentation preview sites, or serving local test fixtures without installing additional tools.

## 12. Network Interface & Exposure Security Inspector (Implemented)
Audit whether listening ports are isolated to loopback or exposed across your local Wi-Fi.
* **How it works**: Detects binding interfaces (`0.0.0.0` / `*` vs `127.0.0.1` / `::1`). Adds visual security badges and tooltips to rows, details popovers, and list filters.
* **Why it's useful**: Working on shared Wi-Fi (coffee shops, coworking spaces, conferences) poses risks if dev databases or unauthenticated APIs bind to `0.0.0.0`. Portly immediately flags exposed listeners.

## 13. Common Endpoints & Quick Route Launcher (Implemented)
Jump directly to key documentation, API, and monitoring endpoints in one click.
* **How it works**: Adds a Quick Routes bar in Process Details and an "Open Route…" submenu in the port context menu for common presets (`/docs`, `/swagger`, `/api`, `/graphql`, `/health`, `/metrics`, `/admin`).
* **Why it's useful**: Developers rarely only navigate to root `/`. Instant access to Swagger UI, GraphiQL, or health checks saves repeated URL typing.

## 14. Multi-Language Request Code Snippet Generator (Implemented)
Export tested HTTP requests into reproducible code in seconds.
* **How it works**: Integrated in the Quick API Tester, one-click exports requests to cURL, JavaScript `fetch()`, Python `requests`, and Swift `URLSession`.
* **Why it's useful**: Developers can test an endpoint interactively in Portly, verify it works, and immediately paste the exact working request code into frontend or backend codebases.

## 15. Response Headers Inspector (Implemented)
Inspect HTTP response headers directly inside the Quick API Tester.
* **How it works**: Adds an expandable Response Headers viewer showing all response headers with key-value alignment and a "Copy Headers" clipboard action.
* **Why it's useful**: Crucial for debugging CORS (`Access-Control-Allow-Origin`), caching policies (`Cache-Control`, `ETag`), authentication cookies (`Set-Cookie`), and content types.

## 16. Developer Sticky Notes & Runbook Annotations (Implemented)
Persist custom notes, credentials, and runbook reminders per port.
* **How it works**: Adds persistent notes stored per port number, editable directly in Process Details with full-text search integration and row tooltips.
* **Why it's useful**: Helps remember test accounts (`admin/password`), mock server purposes, or operational instructions across dev sessions.

## 17. Configurable Port Sorting & Exposure Filtering (Implemented)
Customize port display order and quickly isolate high-risk or containerized services.
* **How it works**: Added an interactive Sort & Filter menu in the panel header to sort by Port (Asc/Desc), Process Name, Active Connections, or Exposure, with quick filter pills for "All", "LAN Exposed", and "Docker".
* **Why it's useful**: Quickly locate noisy services under heavy traffic or audit exposed services at a glance when running dozens of microservices.
