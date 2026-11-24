import Nuke
import SwiftUI

@main
struct TheMoviesApp: App {
    @State private var session: AppSession

    init() {
        // Disk-backed image cache so posters survive relaunches and scroll smoothly.
        ImagePipeline.shared = ImagePipeline(configuration: .withDataCache)
        _session = State(initialValue: AppSession(store: KeychainCredentialStore()))
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
        }
    }
}
