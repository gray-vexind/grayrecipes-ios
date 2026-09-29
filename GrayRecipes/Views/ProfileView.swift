import SwiftUI

/// The rightmost "Profile" tab. When signed in it shows the Vex account +
/// sign-out; when signed out it shows the "Sign in with Vex account" CTA.
struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        NavigationStack {
            Group {
                if let user = session.currentUser {
                    signedInList(user: user)
                } else {
                    signedOut
                }
            }
            .navigationTitle("Profile")
        }
    }

    // MARK: Signed in

    private func signedInList(user: AuthUser) -> some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.brandPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name.isEmpty ? user.preferredUsername : user.name)
                            .font(.headline)
                        Text(user.email).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Button(role: .destructive) {
                    Task { await session.signOut() }
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            Section {
                LabeledContent("Server", value: AppConfig.baseURL.host ?? "—")
                LabeledContent("Version", value: appVersion)
            } footer: {
                Text("Gray Recipes for iOS")
            }
        }
    }

    // MARK: Signed out

    private var signedOut: some View {
        ScrollView {
            VexSignInView()
                .padding(.top, 40)
                .padding(.bottom, 24)

            VStack(spacing: 4) {
                Text("Server: \(AppConfig.baseURL.host ?? "—")")
                Text("Version \(appVersion)")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 24)
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

#Preview {
    ProfileView().environmentObject(SessionStore())
}
