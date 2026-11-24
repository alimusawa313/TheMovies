import Observation
import SwiftUI

/// Push destinations in the main navigation stack.
nonisolated enum AppRoute: Hashable, Sendable {
    case movies(Genre)
    case movieDetail(MovieSummary)
    case reviews(movieID: Int, title: String)
}

/// Data needed to present the trailer player.
nonisolated struct TrailerContext: Hashable, Sendable {
    let movieTitle: String
    let videos: [Video]
    let initialVideo: Video
}

/// Modally presented destinations.
nonisolated enum SheetRoute: Identifiable, Hashable, Sendable {
    case trailer(TrailerContext)
    case settings

    var id: String {
        switch self {
        case .trailer(let context): "trailer-\(context.initialVideo.id)"
        case .settings: "settings"
        }
    }
}

/// Single source of truth for navigation state. VIPER routers mutate it;
/// `MainFlowView` renders it.
@Observable
final class Navigator {
    var path: [AppRoute] = []
    var sheet: SheetRoute?

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func present(_ sheet: SheetRoute) {
        self.sheet = sheet
    }

    func dismissSheet() {
        sheet = nil
    }
}

extension EnvironmentValues {
    /// Namespace shared by list cards and detail screens for zoom transitions.
    @Entry var zoomNamespace: Namespace.ID?
}

/// Applies the matched zoom source only when a namespace is available
/// (e.g. not in previews), so views stay usable in isolation.
private struct ZoomSourceModifier<ID: Hashable>: ViewModifier {
    let id: ID
    @Environment(\.zoomNamespace) private var namespace

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: id, in: namespace) { source in
                source.clipShape(.rect(cornerRadius: Theme.Radius.m, style: .continuous))
            }
        } else {
            content
        }
    }
}

private struct ZoomDestinationModifier<ID: Hashable>: ViewModifier {
    let id: ID
    @Environment(\.zoomNamespace) private var namespace

    func body(content: Content) -> some View {
        if let namespace {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

extension View {
    func zoomSource(id: some Hashable) -> some View {
        modifier(ZoomSourceModifier(id: id))
    }

    func zoomDestination(id: some Hashable) -> some View {
        modifier(ZoomDestinationModifier(id: id))
    }
}
