//
//  SmartProcessDescriptor.swift
//  Portly
//

import Foundation

/// Analyzes process metadata and arguments to provide human-readable tags
/// for Kubernetes port-forwards, SSH tunnels, Docker services, and frameworks.
enum SmartProcessDescriptor {
    /// Inferred human-friendly description of the service/process.
    static func describe(
        processName: String,
        executablePath: String? = nil,
        arguments: [String]
    ) -> String? {
        let name = processName.lowercased()
        let cmdLine = arguments.joined(separator: " ")
        let cmdLower = cmdLine.lowercased()

        // 1. Kubernetes port-forward
        if name == "kubectl" || cmdLower.contains("kubectl") {
            if let k8s = parseKubectl(arguments: arguments) {
                return k8s
            }
        }

        // 2. SSH Port Forwarding / Tunnels
        if name == "ssh" || name == "autossh" {
            if let ssh = parseSSH(arguments: arguments) {
                return ssh
            }
        }

        // 3. Tunnels: Cloudflare, Localtunnel, Ngrok
        if name == "cloudflared" || cmdLower.contains("cloudflared") {
            return "Cloudflare Tunnel"
        }
        if name == "ngrok" || cmdLower.contains("ngrok") {
            return "ngrok Tunnel"
        }
        if cmdLower.contains("localtunnel") || cmdLower.contains("lt --port") {
            return "localtunnel"
        }

        // 4. Node / Bun / Deno runtimes
        if name == "node" || name == "bun" || name == "deno" || name == "pnpm" || name == "yarn" || name == "npm" {
            if let framework = parseNodeRuntime(arguments: arguments, cmdLower: cmdLower) {
                return framework
            }
        }

        // 5. Python frameworks
        if name.hasPrefix("python") || name == "uv" || name == "poetry" || name == "pipenv" {
            if let py = parsePythonRuntime(arguments: arguments, cmdLower: cmdLower) {
                return py
            }
        }

        // 6. Ruby frameworks
        if name == "ruby" || name == "bundle" || name == "puma" || name == "rails" {
            if cmdLower.contains("rails") { return "Ruby on Rails" }
            if cmdLower.contains("puma") { return "Puma" }
            if cmdLower.contains("sidekiq") { return "Sidekiq" }
            if cmdLower.contains("sinatra") { return "Sinatra" }
        }

        // 7. Go, Rust, Java
        if name == "go" || cmdLower.contains("go run") {
            return "Go Server"
        }
        if name == "cargo" || cmdLower.contains("cargo run") {
            return "Rust App"
        }
        if name == "java" || name == "javaw" {
            if cmdLower.contains("spring-boot") || cmdLower.contains("springframework") {
                return "Spring Boot"
            }
            if cmdLower.contains("quarkus") { return "Quarkus" }
            if cmdLower.contains("gradle") { return "Gradle Daemon" }
        }

        return nil
    }

    private static func parseKubectl(arguments: [String]) -> String? {
        guard let pfIndex = arguments.firstIndex(where: { $0 == "port-forward" || $0.hasSuffix("/port-forward") }) else {
            return "kubectl"
        }
        let rest = Array(arguments.suffix(from: arguments.index(after: pfIndex)))
        var target: String?
        var namespace: String?

        var idx = 0
        while idx < rest.count {
            let arg = rest[idx]
            if arg == "-n" || arg == "--namespace", idx + 1 < rest.count {
                namespace = rest[idx + 1]
                idx += 2
                continue
            } else if arg.hasPrefix("--namespace=") {
                namespace = String(arg.dropFirst("--namespace=".count))
                idx += 1
                continue
            } else if !arg.hasPrefix("-") && target == nil {
                target = arg
            }
            idx += 1
        }

        if let target {
            if let namespace {
                return "k8s: \(target) (\(namespace))"
            }
            return "k8s: \(target)"
        }
        return "kubectl port-forward"
    }

    private static func parseSSH(arguments: [String]) -> String? {
        var forwardSpec: String?
        var remoteHost: String?

        var idx = 0
        while idx < arguments.count {
            let arg = arguments[idx]
            if (arg == "-L" || arg == "-R" || arg == "-D"), idx + 1 < arguments.count {
                forwardSpec = arguments[idx + 1]
                idx += 2
                continue
            } else if !arg.hasPrefix("-") && idx > 0 {
                if arg.contains("@") || !arg.contains("/") {
                    remoteHost = arg
                }
            }
            idx += 1
        }

        if let remoteHost {
            if let forwardSpec {
                return "ssh: \(remoteHost) (\(forwardSpec))"
            }
            return "ssh: \(remoteHost)"
        }
        return "ssh tunnel"
    }

    private static func parseNodeRuntime(arguments: [String], cmdLower: String) -> String? {
        if cmdLower.contains("next") { return "Next.js" }
        if cmdLower.contains("vite") { return "Vite" }
        if cmdLower.contains("remix") { return "Remix" }
        if cmdLower.contains("astro") { return "Astro" }
        if cmdLower.contains("nuxt") { return "Nuxt" }
        if cmdLower.contains("svelte") { return "SvelteKit" }
        if cmdLower.contains("nest") { return "NestJS" }
        if cmdLower.contains("storybook") { return "Storybook" }

        for arg in arguments.dropFirst() {
            if !arg.hasPrefix("-") {
                let url = URL(fileURLWithPath: arg)
                let ext = url.pathExtension.lowercased()
                if ext == "js" || ext == "ts" || ext == "mjs" || ext == "cjs" {
                    return url.lastPathComponent
                }
            }
        }
        return nil
    }

    private static func parsePythonRuntime(arguments: [String], cmdLower: String) -> String? {
        if cmdLower.contains("runserver") || cmdLower.contains("manage.py") {
            return "Django"
        }
        if cmdLower.contains("uvicorn") { return "FastAPI / Uvicorn" }
        if cmdLower.contains("gunicorn") { return "Gunicorn" }
        if cmdLower.contains("flask") { return "Flask" }
        if cmdLower.contains("celery") { return "Celery" }
        if cmdLower.contains("streamlit") { return "Streamlit" }

        for arg in arguments.dropFirst() {
            if !arg.hasPrefix("-") {
                let url = URL(fileURLWithPath: arg)
                if url.pathExtension.lowercased() == "py" {
                    return url.lastPathComponent
                }
            }
        }
        return nil
    }
}
