import Foundation

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case missingAPIKey
    case unauthorized
    case server(status: Int, detail: String?)
    case decoding(Error)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The server URL is not valid. Set it in Settings, e.g. http://192.168.1.10:8000."
        case .missingAPIKey:
            return "Enter your iOS API key in Settings first."
        case .unauthorized:
            return "Unauthorized. Check the API key in Settings."
        case .server(let status, let detail):
            if let detail, !detail.isEmpty {
                return "Server error (\(status)): \(detail)"
            }
            return "Server error (\(status))."
        case .decoding(let error):
            return "Could not read the server response: \(error.localizedDescription)"
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Client

/// async/await URLSession client for the paper-trading bot's FastAPI server.
///
/// - `GET /health` and `GET /api/trades` need no auth (same as the web dashboard).
/// - All `POST/GET /api/trading/*` calls send `Authorization: Bearer <apiKey>`.
final class APIClient {
    private let baseURL: URL
    private let apiKey: String?

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    init(baseURL: URL, apiKey: String? = nil) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    private func endpointURL(_ path: String) throws -> URL {
        let base = baseURL.absoluteString
        let trimmed = base.hasSuffix("/") ? String(base.dropLast()) : base
        guard let url = URL(string: trimmed + "/" + path) else {
            throw APIError.invalidURL
        }
        return url
    }

    private func makeRequest(path: String, method: String = "GET", body: Data? = nil, requiresAuth: Bool) throws -> URLRequest {
        var request = URLRequest(url: try endpointURL(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if requiresAuth {
            guard let apiKey, !apiKey.isEmpty else { throw APIError.missingAPIKey }
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.network(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }
        switch http.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error)
            }
        case 401, 403:
            throw APIError.unauthorized
        default:
            let detail = String(data: data, encoding: .utf8)
            throw APIError.server(status: http.statusCode, detail: detail)
        }
    }

    // MARK: Public endpoints (no auth)

    func health() async throws -> HealthResponse {
        let request = try makeRequest(path: "health", requiresAuth: false)
        return try await send(request)
    }

    func trades() async throws -> TradesResponse {
        let request = try makeRequest(path: "api/trades", requiresAuth: false)
        return try await send(request)
    }

    // MARK: Trading endpoints (require the iOS API key)

    func account() async throws -> AccountResponse {
        let request = try makeRequest(path: "api/trading/account", requiresAuth: true)
        return try await send(request)
    }

    func orders(limit: Int = 50) async throws -> OrdersResponse {
        let request = try makeRequest(path: "api/trading/orders?limit=\(limit)", requiresAuth: true)
        return try await send(request)
    }

    func previewOrder(_ preview: OrderPreviewRequest) async throws -> OrderPreviewResponse {
        let body = try encoder.encode(preview)
        let request = try makeRequest(path: "api/trading/orders/preview", method: "POST", body: body, requiresAuth: true)
        return try await send(request)
    }

    func submitOrder(_ submit: OrderSubmitRequest) async throws -> OrderSubmitResponse {
        let body = try encoder.encode(submit)
        let request = try makeRequest(path: "api/trading/orders", method: "POST", body: body, requiresAuth: true)
        return try await send(request)
    }
}