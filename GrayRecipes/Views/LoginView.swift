import SwiftUI

/// Reusable "Sign in with Vex" call-to-action. Shown in the Profile tab and
/// anywhere a signed-out user hits a gated action (e.g. Capture). Tapping the
/// button launches the in-app Safari browser to Vex Authentication.
struct VexSignInView: View {
    @EnvironmentObject private var session: SessionStore

    /// Optional context line explaining why sign-in is needed (e.g. from Capture).
    var prompt: String = "Sign in with your Vex account to save recipes and manage your groups."

    var body: some View {
        VStack(spacing: 24) {
            header

            Text(prompt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: { Task { await session.signInWithVex() } }) {
                HStack {
                    if session.isAuthenticating {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "lock.shield")
                    }
                    Text(session.isAuthenticating ? "Opening Vex…" : "Sign in with Vex account")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.brandPrimary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(session.isAuthenticating)
            .padding(.horizontal, 32)

            if let error = session.authErrorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Text("Uses the same secure Vex Authentication as grayrecipes.com. We never see your password.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.brandPrimary)
            Text("Gray Recipes")
                .font(.largeTitle.bold())
        }
    }
}

/// Full-screen login (used when a screen wants to present sign-in on its own).
struct LoginView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VexSignInView()
                    .padding(.top, 60)
                    .padding(.bottom, 40)
            }
            .navigationTitle("")
        }
    }
}

#Preview {
    LoginView().environmentObject(SessionStore())
}
