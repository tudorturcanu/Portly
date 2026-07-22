# Contributing to Portly

Thank you for your interest in contributing to **Portly**! Portly is a lightweight macOS menu bar utility that gives developers live visibility into every active listening network port.

## Getting Started

### Requirements
- **macOS**: 14.0 Sonoma or later
- **Xcode**: 15.0 or later
- **Node.js**: 18+ (only if working on the screenshot builder in `src/`)

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/tudorturcanu/Portly.git
   cd Portly
   ```

2. Open in Xcode:
   ```bash
   open Portly.xcodeproj
   ```

3. Select the **Portly** scheme, select your Mac as the destination, and press **⌘R** to build and run locally.

---

## Code Quality & Architecture Standards

- **Swift Concurrency**: All state ownership in `@Observable` classes should follow main actor isolation (`@MainActor`) or explicit structured concurrency (`Task`, `async/await`).
- **No External Dependencies**: The macOS app relies strictly on Apple standard frameworks (`SwiftUI`, `Foundation`, `Observation`, `ServiceManagement`). Avoid adding third-party Swift package dependencies unless discussed in an issue first.
- **Unit Tests**: Place tests under `PortlyTests/`. Run unit tests in Xcode via **⌘U** or with `xcodebuild test`.

---

## Submitting Pull Requests

1. Fork the repo and create a new branch (`feature/my-cool-feature` or `fix/port-parser`).
2. Implement your changes with clear, focused commit messages.
3. Ensure the project builds without warnings or errors.
4. Run unit tests to verify no regressions:
   ```bash
   xcodebuild test -project Portly.xcodeproj -scheme Portly -destination 'platform=macOS'
   ```
5. Open a Pull Request on GitHub with a description of the problem solved and visual screenshots/GIFs for any UI modifications.

Thank you for helping make local development on macOS cleaner and faster!
