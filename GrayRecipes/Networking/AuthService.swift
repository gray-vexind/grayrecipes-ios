import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Drives the native "Sign in with Vex" flow: an OAuth 2.0 authorization-code
/// exchange with PKCE, presented in an in-app browser
/// (`ASWebAuthenticationSession`, backed by SafariViewController).
///
/// Flow:
///  1. Generate a PKCE `code_verifier` + `code_challenge`.
///  2. Open the Keycloak hosted login for the `customers` realm in the in-app
///     browser. Because the session shares the user's Safari cookies (unless
///     `prefersEphemeralWebBrowserSession` is set), a user already signed in to
///     Vex is recognized (SSO) and may not need to re-enter credentials.
///  3. Keycloak redirects to `grayrecipes://auth-callback?code=...&state=...`.
///  4. We validate `state`, then return the `code` + `code_verifier` so the
///     caller can complete the exchange server-side.
///
/// This never sees the user's password and supports MFA/SSO/federation, unlike
/// the legacy password grant.
@MainActor
final class AuthService: NSObject {
    /// The authorization code plus the PKCE verifier needed to redeem it.
    struct AuthCode {
        let code: String
        let codeVerifier: String
        let redirectURI: String
    }

    enum AuthServiceError: LocalizedError {
        case cancelled
        case invalidCallback
        case stateMismatch
        case providerError(String)

        var errorDescription: String? {
            switch self {
            case .cancelled: return "Sign in was cancelled."
            case .invalidCallback: return "Vex Authentication returned an unexpected response."
            case .stateMismatch: return "Sign in could not be verified. Please try again."
            case .providerError(let msg): return msg
            }
        }
    }

    /// Retained for the lifetime of the presented session.
    private var currentSession: ASWebAuthenticationSession?

    /// Begin the interactive login. Returns the authorization code on success.
    func authenticate() async throws -> AuthCode {
        let verifier = Self.makeCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)
        let state = Self.randomURLSafeString(count: 32)

        var components = URLComponents(
            url: AppConfig.Auth.authorizationEndpoint,
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: AppConfig.Auth.clientID),
            URLQueryItem(name: "redirect_uri", value: AppConfig.Auth.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: AppConfig.Auth.scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let authURL = components.url else {
            throw AuthServiceError.invalidCallback
        }

        let callbackURL = try await presentSession(
            authURL: authURL,
            callbackScheme: AppConfig.Auth.redirectScheme
        )

        // Parse the redirect: grayrecipes://auth-callback?code=...&state=...
        guard
            let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        else {
            throw AuthServiceError.invalidCallback
        }
        let items = comps.queryItems ?? []

        if let error = items.first(where: { $0.name == "error" })?.value {
            let desc = items.first(where: { $0.name == "error_description" })?.value
            throw AuthServiceError.providerError(desc ?? error)
        }
        guard let returnedState = items.first(where: { $0.name == "state" })?.value,
              returnedState == state else {
            throw AuthServiceError.stateMismatch
        }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw AuthServiceError.invalidCallback
        }

        return AuthCode(
            code: code,
            codeVerifier: verifier,
            redirectURI: AppConfig.Auth.redirectURI
        )
    }

    // MARK: - ASWebAuthenticationSession

    private func presentSession(authURL: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthServiceError.cancelled)
                    } else {
                        continuation.resume(throwing: AuthServiceError.providerError(error.localizedDescription))
                    }
                    return
                }
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: AuthServiceError.invalidCallback)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            // Share the system session so an existing Vex login is reused (SSO).
            session.prefersEphemeralWebBrowserSession = false
            self.currentSession = session
            if !session.start() {
                continuation.resume(throwing: AuthServiceError.providerError("Couldn't open the sign-in browser."))
            }
        }
    }

    // MARK: - PKCE helpers

    /// RFC 7636 code verifier: 43–128 unreserved characters.
    private static func makeCodeVerifier() -> String {
        randomURLSafeString(count: 64)
    }

    /// S256 challenge = BASE64URL(SHA256(verifier)).
    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncode(Data(digest))
    }

    private static func randomURLSafeString(count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return base64URLEncode(Data(bytes))
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Presentation anchor

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the app's active foreground window as the presentation anchor.
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow }
            ?? windowScene?.windows.first
        return window ?? ASPresentationAnchor()
    }
}
