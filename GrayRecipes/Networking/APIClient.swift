import Foundation

/// Async HTTP client for the Gray Recipes API.
///
/// Handles bearer-token injection and transparent access-token refresh: if a
/// request comes back 401 and we hold a refresh token, it refreshes once and
/// retries. If refresh fails, it publishes a sign-out via `onAuthExpired`.
actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    /// Called (on the main actor) when auth can no longer be recovered.
    var onAuthExpired: (@Sendable () async -> Void)?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.requestTimeout
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
    }

    func setAuthExpiredHandler(_ handler: @escaping @Sendable () async -> Void) {
        onAuthExpired = handler
    }

    // MARK: Token storage keys
    private static let accessKey = "access_token"
    private static let refreshKey = "refresh_token"

    var accessToken: String? { KeychainStore.get(Self.accessKey) }
    var refreshToken: String? { KeychainStore.get(Self.refreshKey) }

    func storeTokens(_ tokens: TokenResponse) {
        KeychainStore.set(tokens.accessToken, for: Self.accessKey)
        KeychainStore.set(tokens.refreshToken, for: Self.refreshKey)
    }

    func clearTokens() {
        KeychainStore.delete(Self.accessKey)
        KeychainStore.delete(Self.refreshKey)
    }

    // MARK: - Public API

    /// GET a decodable resource.
    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], authenticated: Bool = true) async throws -> T {
        let request = try makeRequest(path: path, method: "GET", query: query, authenticated: authenticated)
        let data = try await perform(request, authenticated: authenticated)
        return try decode(T.self, from: data)
    }

    /// POST a JSON body and decode the response.
    func postJSON<T: Decodable, B: Encodable>(_ path: String, body: B, authenticated: Bool = true) async throws -> T {
        var request = try makeRequest(path: path, method: "POST", authenticated: authenticated)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let data = try await perform(request, authenticated: authenticated)
        return try decode(T.self, from: data)
    }

    /// POST a multipart/form-data body (fields + optional files) and decode the response.
    func postMultipart<T: Decodable>(
        _ path: String,
        fields: [String: String],
        files: [MultipartFile],
        authenticated: Bool = true,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        var request = try makeRequest(path: path, method: "POST", authenticated: authenticated)
        if let timeout { request.timeoutInterval = timeout }
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.multipartBody(fields: fields, files: files, boundary: boundary)
        let data = try await perform(request, authenticated: authenticated)
        return try decode(T.self, from: data)
    }

    // MARK: - Request building

    private func makeRequest(path: String, method: String, query: [URLQueryItem] = [], authenticated: Bool) throws -> URLRequest {
        guard var components = URLComponents(url: AppConfig.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.custom("Invalid URL path: \(path)")
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.custom("Invalid URL for path: \(path)") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if authenticated, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // MARK: - Execution with refresh-on-401

    private func perform(_ request: URLRequest, authenticated: Bool, isRetry: Bool = false) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            // Attempt one transparent refresh for authenticated calls.
            if authenticated, !isRetry, refreshToken != nil {
                let refreshed = await tryRefresh()
                if refreshed, let token = accessToken {
                    var retried = request
                    retried.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    return try await perform(retried, authenticated: authenticated, isRetry: true)
                }
            }
            if authenticated {
                await onAuthExpired?()
            }
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden(Self.errorMessage(from: data) ?? "")
        default:
            throw APIError.server(status: http.statusCode, message: Self.errorMessage(from: data))
        }
    }

    /// Refresh the access token using the stored refresh token. Returns success.
    private func tryRefresh() async -> Bool {
        guard let refresh = refreshToken else { return false }
        do {
            var request = try makeRequest(path: "api/auth/mobile/refresh", method: "POST", authenticated: false)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["refresh_token": refresh])
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return false
            }
            let tokens = try decoder.decode(TokenResponse.self, from: data)
            storeTokens(tokens)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Helpers

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        if T.self == EmptyResponse.self, let empty = EmptyResponse() as? T { return empty }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let body = try? JSONDecoder().decode(APIErrorBody.self, from: data) else { return nil }
        return body.error
    }

    private static func multipartBody(fields: [String: String], files: [MultipartFile], boundary: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        for (key, value) in fields {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak)\(lineBreak)")
            body.append("\(value)\(lineBreak)")
        }
        for file in files {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(file.field)\"; filename=\"\(file.filename)\"\(lineBreak)")
            body.append("Content-Type: \(file.mimeType)\(lineBreak)\(lineBreak)")
            body.append(file.data)
            body.append(lineBreak)
        }
        body.append("--\(boundary)--\(lineBreak)")
        return body
    }
}

struct MultipartFile {
    let field: String
    let filename: String
    let mimeType: String
    let data: Data
}

/// Placeholder for endpoints that return a body we don't need to decode.
struct EmptyResponse: Decodable {}

private extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }
}
