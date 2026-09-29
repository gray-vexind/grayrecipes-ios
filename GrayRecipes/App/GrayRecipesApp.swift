import SwiftUI

@main
struct GrayRecipesApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(.brandPrimary)
        }
    }
}
