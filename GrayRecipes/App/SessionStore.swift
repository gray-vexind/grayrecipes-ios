import SwiftUI

/// Observable auth/session state for the app. Drives whether we show the login
/// screen or the main tabs.
@MainActor
final class SessionStore: ObservableObject {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(AuthUser)
    }

    @Published private(set) var state: State = .loading
    @Published var authErrorMessage: String?

    /// True while an interactive "Sign in with Vex" flow is in progress.
    @Published private(set) var isAuthenticating = false

    private let authService = AuthService()

    init() {
        Task { await restore() }
        Task {
            await APIClient.shared.setAuthExpiredHandler { [weak self] in
                await self?.forceSignOut()
            }
        }
    }

    var currentUser: AuthUser? {
        if case .signedIn(let user) = state { return user }
        return nil
    }

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    /// On launch: if we hold a token, validate it (with refresh fallback).
    func restore() async {
        let hasToken = await APIClient.shared.accessToken != nil
        guard hasToken else {
            state = .signedOut
            return
        }
        do {
            let user = try await GrayRecipesAPI.me()
            state = .signedIn(user)
        } catch {
            // me() already attempts refresh internally; if it still fails, sign out.
            await APIClient.shared.clearTokens()
            state = .signedOut
        }
    }

    func signIn(email: String, password: String) async {
        authErrorMessage = nil
        do {
            let tokens = try await GrayRecipesAPI.login(email: email, password: password)
            await APIClient.shared.storeTokens(tokens)
            state = .signedIn(tokens.user)
        } catch {
            authErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Preferred sign-in: "Sign in with Vex" (OAuth auth-code + PKCE) presented
    /// in an in-app browser. Never sees the user's password; supports SSO/MFA.
    func signInWithVex() async {
        guard !isAuthenticating else { return }
        authErrorMessage = nil
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            let authCode = try await authService.authenticate()
            let tokens = try await GrayRecipesAPI.exchange(
                code: authCode.code,
                codeVerifier: authCode.codeVerifier,
                redirectUri: authCode.redirectURI
            )
            await APIClient.shared.storeTokens(tokens)
            state = .signedIn(tokens.user)
        } catch AuthService.AuthServiceError.cancelled {
            // User dismissed the browser — not an error worth surfacing.
        } catch {
            authErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func signOut() async {
        await APIClient.shared.clearTokens()
        state = .signedOut
    }

    private func forceSignOut() async {
        await APIClient.shared.clearTokens()
        state = .signedOut
        authErrorMessage = "Your session expired. Please sign in again."
    }
}
