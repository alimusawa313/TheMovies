import SwiftUI

/// Switches between onboarding and the main flow with an animated cross-fade.
struct RootView: View {
    let session: AppSession
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch session.mode {
            case .onboarding:
                APIKeySetupModule.build(session: session)
                    .transition(AnyTransition.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity.combined(with: .scale(scale: 1.08))
                    ))
            case .live, .demo:
                MainFlowView(session: session)
                    .id(session.mode)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .animation(Motion.gentle, value: session.mode)
        .preferredColorScheme(appearance.colorScheme)
        .tint(Theme.accent)
    }
}

/// Hosts the navigation stack for an authenticated (or demo) session.
struct MainFlowView: View {
    let session: AppSession
    @State private var navigator = Navigator()
    @State private var repository: (any MovieRepository)?
    @Namespace private var zoomNamespace

    var body: some View {
        Group {
            if let repository {
                let factory = ModuleFactory(repository: repository, navigator: navigator, session: session)
                NavigationStack(path: $navigator.path) {
                    factory.makeRoot()
                        .navigationDestination(for: AppRoute.self) { route in
                            factory.destination(for: route)
                        }
                }
                .sheet(item: $navigator.sheet) { route in
                    factory.sheet(for: route)
                }
                .environment(\.zoomNamespace, zoomNamespace)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if repository == nil {
                repository = session.makeRepository()
            }
        }
    }
}
