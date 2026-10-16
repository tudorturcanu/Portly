//
//  QuickRequestView.swift
//  Portly
//

import SwiftUI

/// Embedded API & HTTP endpoint tester inside Process Details.
struct QuickRequestView: View {
    let port: ListeningPort

    @State private var method = "GET"
    @State private var path = "/"
    @State private var requestBody = ""
    @State private var isSending = false
    @State private var response: HTTPTestResponse?
    @State private var errorMessage: String?
    @State private var showingBodyEditor = false
    @State private var showingHeaders = false

    private let methods = ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD"]
    private let commonRoutes = ["/", "/api", "/docs", "/swagger", "/graphql", "/health"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Picker("Method", selection: $method) {
                    ForEach(methods, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                .labelsHidden()
                .frame(width: 85)

                TextField("/path", text: $path)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))

                Button(isSending ? "Sending…" : "Send", systemImage: "paperplane.fill") {
                    sendRequest()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isSending)
            }

            // Quick preset routes picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    Text("Presets:")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    ForEach(commonRoutes, id: \.self) { r in
                        Button(r) {
                            path = r
                        }
                        .buttonStyle(.borderless)
                        .font(.system(.caption2, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary.opacity(path == r ? 0.9 : 0.4), in: .capsule)
                    }
                }
            }

            HStack {
                if ["POST", "PUT", "PATCH"].contains(method) {
                    Button(showingBodyEditor ? "Hide JSON Body" : "Edit JSON Body", systemImage: "text.alignleft") {
                        showingBodyEditor.toggle()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                }

                Spacer()

                Menu {
                    ForEach(CodeSnippetLanguage.allCases) { lang in
                        Button(lang.rawValue, systemImage: lang.icon) {
                            let snippet = CodeSnippetGenerator.generate(
                                language: lang,
                                port: port.port,
                                method: method,
                                path: path,
                                headers: [:],
                                body: requestBody
                            )
                            copyToPasteboard(snippet)
                        }
                    }
                } label: {
                    Label("Copy Snippet", systemImage: "curlybraces")
                        .font(.caption2)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            if showingBodyEditor && ["POST", "PUT", "PATCH"].contains(method) {
                TextEditor(text: $requestBody)
                    .font(.system(.caption2, design: .monospaced))
                    .frame(height: 60)
                    .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 4))
            }

            if let error = errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                .padding(.vertical, 2)
            }

            if let resp = response {
                responseCard(resp)
            }
        }
    }

    private func responseCard(_ resp: HTTPTestResponse) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("\(resp.statusCode)")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(resp.isSuccess ? Color.green : (resp.isServerError ? Color.red : Color.orange))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        (resp.isSuccess ? Color.green : (resp.isServerError ? Color.red : Color.orange)).opacity(0.15),
                        in: .capsule
                    )

                Text(String(format: "%.1f ms", resp.latencyMilliseconds))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)

                if let type = resp.contentType {
                    Text(type)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                Button("Copy Body", systemImage: "doc.on.doc") {
                    copyToPasteboard(resp.formattedBody)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .font(.caption2)
            }

            if !resp.headers.isEmpty {
                DisclosureGroup("Response Headers (\(resp.headers.count))", isExpanded: $showingHeaders) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Spacer()
                            Button("Copy Headers", systemImage: "doc.on.doc") {
                                let formatted = resp.headers.sorted(by: { $0.key < $1.key })
                                    .map { "\($0.key): \($0.value)" }
                                    .joined(separator: "\n")
                                copyToPasteboard(formatted)
                            }
                            .font(.caption2)
                            .buttonStyle(.borderless)
                        }

                        ForEach(resp.headers.keys.sorted(), id: \.self) { key in
                            HStack(alignment: .top, spacing: 4) {
                                Text(key + ":")
                                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(resp.headers[key] ?? "")
                                    .font(.system(.caption2, design: .monospaced))
                                    .lineLimit(2)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .font(.caption2)
            }

            if !resp.rawBody.isEmpty {
                ScrollView {
                    Text(resp.formattedBody)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                }
                .frame(maxHeight: 120)
                .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 4))
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 6))
    }

    private func sendRequest() {
        guard !isSending else { return }
        isSending = true
        errorMessage = nil
        response = nil

        let config = HTTPRequestConfig(
            method: method,
            path: path,
            headers: [:],
            body: requestBody
        )

        Task {
            do {
                let res = try await HTTPTester.send(port: port.port, config: config)
                await MainActor.run {
                    self.response = res
                    self.isSending = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSending = false
                }
            }
        }
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
