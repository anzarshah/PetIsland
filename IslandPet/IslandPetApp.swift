import GoogleSignIn
import SwiftUI

@main
struct IslandPetApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Also runs when iOS launches the app in the background to perform a Live Activity intent.
        AppServices.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    // Session restore is off the launch path: it starts once the first frame is up.
                    AuthService.shared.start()
                }
                .onOpenURL { url in
                    // Google Sign-In's redirect comes back through the reversed-client-ID scheme.
                    if GIDSignIn.sharedInstance.handle(url) { return }
                    AppServices.shared.handle(url)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                AppServices.shared.didBecomeActive()
            }
        }
    }
}
