import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case forbidden(String)
    case server(status: Int, message: String?)
    case decoding(Error)
    case transport(Error)
    case invalidCredentials
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden(let msg):
            return msg.isEmpty ? "You don't have permission to do that." : msg
        case .server(let status, let message):
            return message ?? "Server error (\(status)). Please try again."
        case .decoding:
            return "Could not read the server response."
        case .transport(let err):
            return err.localizedDescription
        case .invalidCredentials:
            return "Incorrect email or password."
        case .custom(let msg):
            return msg
        }
    }
}

/// Shape of a JSON error body: { "error": "..." }
struct APIErrorBody: Decodable {
    let error: String?
}
