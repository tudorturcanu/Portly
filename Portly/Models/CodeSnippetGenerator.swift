//
//  CodeSnippetGenerator.swift
//  Portly
//

import Foundation

enum CodeSnippetLanguage: String, CaseIterable, Identifiable {
    case curl = "cURL"
    case fetch = "JavaScript (fetch)"
    case python = "Python (requests)"
    case swift = "Swift (URLSession)"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .curl: return "terminal"
        case .fetch: return "chevron.left.forwardslash.chevron.right"
        case .python: return "curlybraces"
        case .swift: return "swift"
        }
    }
}

enum CodeSnippetGenerator {
    static func generate(
        language: CodeSnippetLanguage,
        port: Int,
        method: String,
        path: String,
        headers: [String: String] = [:],
        body: String = ""
    ) -> String {
        var cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanPath.hasPrefix("/") {
            cleanPath = "/" + cleanPath
        }
        let urlString = "http://localhost:\(port)\(cleanPath)"
        let upperMethod = method.uppercased()
        let hasBody = ["POST", "PUT", "PATCH"].contains(upperMethod) && !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        switch language {
        case .curl:
            return generateCurl(method: upperMethod, urlString: urlString, headers: headers, body: body, hasBody: hasBody)
        case .fetch:
            return generateFetch(method: upperMethod, urlString: urlString, headers: headers, body: body, hasBody: hasBody)
        case .python:
            return generatePython(method: upperMethod, urlString: urlString, headers: headers, body: body, hasBody: hasBody)
        case .swift:
            return generateSwift(method: upperMethod, urlString: urlString, headers: headers, body: body, hasBody: hasBody)
        }
    }

    private static func generateCurl(
        method: String,
        urlString: String,
        headers: [String: String],
        body: String,
        hasBody: Bool
    ) -> String {
        var lines: [String] = []
        if method == "GET" && !hasBody && headers.isEmpty {
            return "curl \"\(urlString)\""
        }

        lines.append("curl -X \(method) \"\(urlString)\" \\")

        var allHeaders = headers
        if hasBody && allHeaders["Content-Type"] == nil {
            allHeaders["Content-Type"] = "application/json"
        }

        for (key, value) in allHeaders.sorted(by: { $0.key < $1.key }) {
            lines.append("  -H \"\(key): \(value)\" \\")
        }

        if hasBody {
            let escapedBody = body.replacingOccurrences(of: "'", with: "'\\''")
            lines.append("  -d '\(escapedBody)'")
        } else if let last = lines.popLast() {
            // Remove trailing backslash from the last line
            if last.hasSuffix(" \\") {
                lines.append(String(last.dropLast(2)))
            } else {
                lines.append(last)
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func generateFetch(
        method: String,
        urlString: String,
        headers: [String: String],
        body: String,
        hasBody: Bool
    ) -> String {
        var options: [String] = []
        options.append("  method: '\(method)'")

        var allHeaders = headers
        if hasBody && allHeaders["Content-Type"] == nil {
            allHeaders["Content-Type"] = "application/json"
        }

        if !allHeaders.isEmpty {
            let headerLines = allHeaders.sorted(by: { $0.key < $1.key }).map { "    '\($0.key)': '\($0.value)'" }
            options.append("  headers: {\n" + headerLines.joined(separator: ",\n") + "\n  }")
        }

        if hasBody {
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
                options.append("  body: JSON.stringify(\(trimmed))")
            } else {
                let escaped = trimmed.replacingOccurrences(of: "`", with: "\\`")
                options.append("  body: `\(escaped)`")
            }
        }

        return """
        const response = await fetch('\(urlString)', {
        \(options.joined(separator: ",\n"))
        });
        const data = await response.json();
        console.log(data);
        """
    }

    private static func generatePython(
        method: String,
        urlString: String,
        headers: [String: String],
        body: String,
        hasBody: Bool
    ) -> String {
        var allHeaders = headers
        if hasBody && allHeaders["Content-Type"] == nil {
            allHeaders["Content-Type"] = "application/json"
        }

        var lines = ["import requests", ""]

        if !allHeaders.isEmpty {
            let headerEntries = allHeaders.sorted(by: { $0.key < $1.key }).map { "    \"\($0.key)\": \"\($0.value)\"" }
            lines.append("headers = {\n" + headerEntries.joined(separator: ",\n") + "\n}")
        }

        let headersArg = allHeaders.isEmpty ? "" : ", headers=headers"
        let pyMethod = method.lowercased()

        if hasBody {
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
                lines.append("payload = \(trimmed)")
                lines.append("response = requests.\(pyMethod)(\"\(urlString)\", json=payload\(headersArg))")
            } else {
                let escaped = trimmed.replacingOccurrences(of: "\"\"\"", with: "\\\"\\\"\\\"")
                lines.append("payload = \"\"\"\(escaped)\"\"\"")
                lines.append("response = requests.\(pyMethod)(\"\(urlString)\", data=payload\(headersArg))")
            }
        } else {
            lines.append("response = requests.\(pyMethod)(\"\(urlString)\"\(headersArg))")
        }

        lines.append("print(response.status_code, response.text)")
        return lines.joined(separator: "\n")
    }

    private static func generateSwift(
        method: String,
        urlString: String,
        headers: [String: String],
        body: String,
        hasBody: Bool
    ) -> String {
        var lines: [String] = []
        lines.append("guard let url = URL(string: \"\(urlString)\") else { return }")
        lines.append("var request = URLRequest(url: url)")
        lines.append("request.httpMethod = \"\(method)\"")

        var allHeaders = headers
        if hasBody && allHeaders["Content-Type"] == nil {
            allHeaders["Content-Type"] = "application/json"
        }

        for (k, v) in allHeaders.sorted(by: { $0.key < $1.key }) {
            lines.append("request.setValue(\"\(v)\", forHTTPHeaderField: \"\(k)\")")
        }

        if hasBody {
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            let escaped = trimmed.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            lines.append("request.httpBody = Data(\"\(escaped)\".utf8)")
        }

        lines.append("")
        lines.append("let (data, response) = try await URLSession.shared.data(for: request)")
        lines.append("let responseString = String(decoding: data, as: UTF8.self)")
        lines.append("print(responseString)")

        return lines.joined(separator: "\n")
    }
}
