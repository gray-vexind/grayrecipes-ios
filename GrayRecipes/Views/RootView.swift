import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        switch session.state {
        case .loading:
            LoadingView()
        case .signedOut, .signedIn:
            // The app is usable while signed out (public browsing, website
            // parity). Gated actions (Capture) and the Profile tab prompt for
            // "Sign in with Vex" as needed.
            MainTabView()
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.brandPrimary)
            ProgressView()
        }
    }
}

#Preview {
    RootView().environmentObject(SessionStore())
}
