import Observation
import SwiftUI

@Observable
final class MovieDetailPresenter {
    /// The list item we navigated from; renders the header instantly while
    /// the full detail loads.
    let summary: MovieSummary
    private(set) var state: LoadState<MovieDetailViewModel> = .idle

    private let interactor: any MovieDetailInteracting
    private let router: any MovieDetailRouting

    init(summary: MovieSummary, interactor: any MovieDetailInteracting, router: any MovieDetailRouting) {
        self.summary = summary
        self.interactor = interactor
        self.router = router
    }

    var title: String { state.value?.title ?? summary.title }
    var posterURL: URL? { state.value?.posterURL ?? summary.posterURL }
    var backdropURL: URL? { state.value?.backdropURL ?? summary.backdropURL ?? summary.posterURL }
    var shareURL: URL? { URL(string: "https://www.themoviedb.org/movie/\(summary.id)") }

    // MARK: Intents

    func onAppear() async {
        guard state.isIdle else { return }
        await load()
    }

    func retry() async {
        await load()
    }

    func playTrailer(_ video: Video? = nil) {
        guard let viewModel = state.value,
              let selected = video ?? viewModel.trailers.first else { return }
        router.playTrailer(TrailerContext(movieTitle: viewModel.title, videos: viewModel.trailers, initialVideo: selected))
    }

    func showAllReviews() {
        router.showReviews(movieID: summary.id, title: title)
    }

    // MARK: Private

    private func load() async {
        state = .loading
        do {
            let detail = try await interactor.fetchDetail(movieID: summary.id)
            state = .loaded(MovieDetailViewModel(detail: detail))
        } catch {
            state = error == .cancelled ? .idle : .failed(error)
        }
    }
}

/// Display-ready movie detail produced by the presenter.
nonisolated struct MovieDetailViewModel: Equatable, Sendable {
    nonisolated struct Fact: Hashable, Sendable {
        let label: String
        let value: String
        let symbol: String
    }

    static let reviewPreviewCount = 2
    static let castLimit = 15

    let id: Int
    let title: String
    let tagline: String?
    let overview: String?
    let posterURL: URL?
    let backdropURL: URL?
    let metadata: [String]
    let ratingFraction: Double
    let ratingText: String
    let voteCountText: String
    let genres: [Genre]
    let cast: [CastMember]
    let trailers: [Video]
    let reviewPreviews: [ReviewViewModel]
    let totalReviews: Int
    let facts: [Fact]

    init(detail: MovieDetail) {
        id = detail.id
        title = detail.title
        tagline = detail.tagline
        overview = detail.overview
        posterURL = TMDBImage.url(path: detail.posterPath, size: .posterLarge)
        backdropURL = TMDBImage.url(path: detail.backdropPath, size: .backdrop)
        metadata = [
            Formatters.year(from: detail.releaseDate),
            Formatters.runtime(minutes: detail.runtime),
            detail.originalLanguage?.uppercased(),
        ].compactMap(\.self)
        ratingFraction = min(max(detail.voteAverage / 10, 0), 1)
        ratingText = detail.voteCount > 0 ? Formatters.rating(detail.voteAverage) : "NR"
        voteCountText = detail.voteCount > 0
            ? "\(Formatters.compact(detail.voteCount)) votes"
            : "No votes yet"
        genres = detail.genres
        cast = Array(detail.cast.prefix(Self.castLimit))
        trailers = detail.videos.playableTrailers
        reviewPreviews = (detail.reviews?.items ?? []).prefix(Self.reviewPreviewCount).map(ReviewViewModel.init(review:))
        totalReviews = detail.reviews?.totalResults ?? 0
        facts = Self.makeFacts(from: detail)
    }

    private static func makeFacts(from detail: MovieDetail) -> [Fact] {
        [
            detail.status.map { Fact(label: "Status", value: $0, symbol: "checkmark.seal.fill") },
            Formatters.longDate(from: detail.releaseDate).map { Fact(label: "Release", value: $0, symbol: "calendar") },
            Formatters.languageName(code: detail.originalLanguage).map {
                Fact(label: "Language", value: $0, symbol: "character.bubble.fill")
            },
            Formatters.runtime(minutes: detail.runtime).map { Fact(label: "Runtime", value: $0, symbol: "clock.fill") },
            Formatters.money(detail.budget).map { Fact(label: "Budget", value: $0, symbol: "banknote.fill") },
            Formatters.money(detail.revenue).map { Fact(label: "Revenue", value: $0, symbol: "chart.line.uptrend.xyaxis") },
        ].compactMap(\.self)
    }
}
