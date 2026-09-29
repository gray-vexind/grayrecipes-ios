import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            RecipeListView()
                .tabItem { Label("Recipes", systemImage: "book") }

            CaptureFlowView()
                .tabItem { Label("Capture", systemImage: "camera.viewfinder") }

            // Rightmost tab: Profile. Shows the account when signed in, or a
            // "Sign in with Vex account" call-to-action when signed out.
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

#Preview {
    MainTabView().environmentObject(SessionStore())
}
