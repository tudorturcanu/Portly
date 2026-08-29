//
//  HTTPTester.swift
//  Portly
//

import Foundation

struct HTTPRequestConfig {
    var method: String = "GET"
    var path: String = "/"
    var headers: [String: String] = [:]
    var body: String = ""
}

struct HTTPTestResponse {
    let statusCode: Int
    let latencyMilliseconds: Double
    let contentType: String?
    let headers: [String: String]
    let rawBody: String

    var isSuccess: Bool {
        statusCode >= 200 && statusCode < 300
    }

    var isClientError: Bool {
        statusCode >= 400 && statusCode < 500
    }

    var isServerError: Bool {
        statusCode >= 500
    }

    var formattedBody: String {
        guard let data = rawBody.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return rawBody
        }
        return prettyString
    }
}

enum HTTPTester {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8.0
        return URLSession(configuration: config)
    }()

    static func send(port: Int, config: HTTPRequestConfig) async throws -> HTTPTestResponse {
        var cleanPath = config.path.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanPath.hasPrefix("/") {
            cleanPath = "/" + cleanPath
        }

        guard let url = URL(string: "http://localhost:\(port)\(cleanPath)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = config.method

        for (k, v) in config.headers {
            request.setValue(v, forHTTPHeaderField: k)
        }

        if ["POST", "PUT", "PATCH"].contains(config.method.uppercased()) && !config.body.isEmpty {
            request.httpBody = config.body.data(using: .utf8)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            }
        }

        let start = CFAbsoluteTimeGetCurrent()
        let (data, response) = try await session.data(for: request)
        let latency = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.cannotParseResponse)
        }

        var responseHeaders: [String: String] = [:]
        for (k, v) in http.allHeaderFields {
            responseHeaders[String(describing: k)] = String(describing: v)
        }

        let bodyString = String(decoding: data, as: UTF8.self)

        return HTTPTestResponse(
            statusCode: http.statusCode,
            latencyMilliseconds: latency,
            contentType: http.mimeType,
            headers: responseHeaders,
            rawBody: bodyString
        )
    }
}
