import Observation
import SwiftUI

// MARK: - VIPER contract

/// The trailer sheet receives its videos from the detail module, so it has no
/// data-loading interactor; the presenter owns selection, the router dismissal.
protocol TrailerRouting {
    func close()
}

struct TrailerRouter: TrailerRouting {
    let navigator: Navigator

    func close() {
        navigator.dismissSheet()
    }
}

// MARK: - Presenter

@Observable
final class TrailerPresenter {
    let movieTitle: String
    let videos: [Video]
    private(set) var selectedVideo: Video

    private let router: any TrailerRouting

    init(context: TrailerContext, router: any TrailerRouting) {
        self.movieTitle = context.movieTitle
        self.videos = context.videos.isEmpty ? [context.initialVideo] : context.videos
        self.selectedVideo = context.initialVideo
        self.router = router
    }

    var publishedText: String? {
        Formatters.timestamp(from: selectedVideo.publishedAt)
            .map { $0.formatted(.dateTime.month(.abbreviated).day().year()) }
    }

    func select(_ video: Video) {
        guard video != selectedVideo else { return }
        selectedVideo = video
    }

    func isSelected(_ video: Video) -> Bool {
        video == selectedVideo
    }

    func close() {
        router.close()
    }
}

// MARK: - Builder

enum TrailerModule {
    static func build(context: TrailerContext, navigator: Navigator) -> TrailerView {
        TrailerView(presenter: TrailerPresenter(context: context, router: TrailerRouter(navigator: navigator)))
    }
}
