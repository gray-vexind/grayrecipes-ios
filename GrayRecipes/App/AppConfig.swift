import SwiftUI

/// Central app configuration. Change `baseURL` here to point at a different
/// environment (e.g. a local dev server).
enum AppConfig {
    /// Base URL of the Gray Recipes backend. All API paths are relative to this.
    static let baseURL = URL(string: "https://grayrecipes.com")!

    /// Request timeout for normal API calls.
    static let requestTimeout: TimeInterval = 30

    /// Longer timeout for the server-side extract (Textract) call, which can be slow.
    static let extractTimeout: TimeInterval = 90

    // MARK: - Vex Authentication (OAuth 2.0 authorization-code + PKCE)
    //
    // "Sign in with Vex" opens the Keycloak hosted login in an in-app browser
    // (ASWebAuthenticationSession), receives an authorization code on the custom
    // redirect scheme below, and hands it to the backend's
    // `/api/auth/mobile/exchange` endpoint for a server-side token exchange.
    //
    // These mirror the web values in grayrecipes `lib/auth.ts`
    // (KEYCLOAK_URL / KEYCLOAK_REALM / KEYCLOAK_CLIENT_ID). If the platform ever
    // moves realms or clients, change them here.
    enum Auth {
        /// Keycloak base URL (Vex Authentication).
        static let keycloakURL = URL(string: "https://auth.vex.industries")!

        /// Realm that holds customer identities (same as the website).
        static let realm = "customers"

        /// Public OAuth client shared with the web app.
        static let clientID = "vex-platform"

        /// Custom URL scheme + full redirect URI the app is registered to handle.
        /// This EXACT redirect URI must be whitelisted on the Keycloak client.
        static let redirectScheme = "grayrecipes"
        static let redirectURI = "grayrecipes://auth-callback"

        /// OIDC scopes requested during login.
        static let scopes = "openid email profile"

        /// Authorization endpoint for the configured realm.
        static var authorizationEndpoint: URL {
            keycloakURL.appendingPathComponent(
                "realms/\(realm)/protocol/openid-connect/auth"
            )
        }

        /// End-session (logout) endpoint for the configured realm.
        static var logoutEndpoint: URL {
            keycloakURL.appendingPathComponent(
                "realms/\(realm)/protocol/openid-connect/logout"
            )
        }
    }
}

extension Color {
    /// Gray Recipes brand accent. Adjust to match web branding if desired.
    static let brandPrimary = Color(red: 0.42, green: 0.35, blue: 0.80)
}
