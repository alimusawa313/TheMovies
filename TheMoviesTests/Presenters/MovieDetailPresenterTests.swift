import Testing
@testable import TheMovies

final class MockMovieDetailInteractor: MovieDetailInteracting {
    var results: [Result<MovieDetail, APIError>]
    init(_ results: [Result<MovieDetail, APIError>]) { self.results = results }

    func fetchDetail(movieID: Int) async throws(APIError) -> MovieDetail {
        try results.removeFirst().get()
    }
}

final class SpyMovieDetailRouter: MovieDetailRouting {
    private(set) var reviewRequests: [(Int, String)] = []
    private(set) var trailers: [TrailerContext] = []

    func showReviews(movieID: Int, title: String) { reviewRequests.append((movieID, title)) }
    func playTrailer(_ context: TrailerContext) { trailers.append(context) }
}

@Suite("Movie detail presenter")
struct MovieDetailPresenterTests {
    private let summary = MovieSummary(id: 550, title: "Fight Club", posterPath: "/p.jpg", releaseDate: "1999-10-15")

    private func detail(videos: [Video] = [], reviews: [Review] = [], totalReviews: Int = 0) -> MovieDetail {
        MovieDetail(
            id: 550,
            title: "Fight Club",
            tagline: "Mischief. Mayhem. Soap.",
            overview: "An insomniac office worker…",
            runtime: 139,
            releaseDate: "1999-10-15",
            genres: [Genre(id: 18, name: "Drama")],
            voteAverage: 8.43,
            voteCount: 30_123,
            originalLanguage: "en",
            budget: 63_000_000,
            revenue: 0,
            videos: videos,
            reviews: Page(page: 1, items: reviews, totalPages: 1, totalResults: totalReviews)
        )
    }

    private func makeSUT(_ results: [Result<MovieDetail, APIError>]) -> (MovieDetailPresenter, SpyMovieDetailRouter) {
        let router = SpyMovieDetailRouter()
        return (MovieDetailPresenter(summary: summary, interactor: MockMovieDetailInteractor(results), router: router), router)
    }

    @Test("Header data is available immediately from the list summary")
    func headerBeforeLoad() {
        let (presenter, _) = makeSUT([])
        #expect(presenter.title == "Fight Club")
        #expect(presenter.posterURL != nil)
        #expect(presenter.state == .idle)
    }

    @Test("Formats primary information for display")
    func viewModel() async throws {
        let (presenter, _) = makeSUT([.success(detail())])
        await presenter.onAppear()
        let viewModel = try #require(presenter.state.value)
        #expect(viewModel.metadata == ["1999", "2h 19m", "EN"])
        #expect(viewModel.ratingText == "8.4")
        #expect(viewModel.voteCountText == "30K votes")
        #expect(viewModel.facts.map(\.label) == ["Release", "Language", "Runtime", "Budget"])
    }

    @Test("Play trailer opens the best trailer with all playable videos")
    func playsBestTrailer() async {
        let videos = [Fixtures.video(id: "teaser", type: "Teaser"), Fixtures.video(id: "trailer")]
        let (presenter, router) = makeSUT([.success(detail(videos: videos))])
        await presenter.onAppear()
        presenter.playTrailer()
        #expect(router.trailers.first?.initialVideo.id == "trailer")
        #expect(router.trailers.first?.videos.count == 2)
    }

    @Test("No trailer means nothing is presented")
    func noTrailer() async {
        let (presenter, router) = makeSUT([.success(detail(videos: [Fixtures.video(id: "v", site: "Vimeo")]))])
        await presenter.onAppear()
        presenter.playTrailer()
        #expect(presenter.state.value?.trailers.isEmpty == true)
        #expect(router.trailers.isEmpty)
    }

    @Test("Shows a review preview and routes to all reviews")
    func reviewsPreview() async {
        let reviews = (0..<5).map { Fixtures.review(id: "\($0)") }
        let (presenter, router) = makeSUT([.success(detail(reviews: reviews, totalReviews: 12))])
        await presenter.onAppear()
        #expect(presenter.state.value?.reviewPreviews.count == MovieDetailViewModel.reviewPreviewCount)
        #expect(presenter.state.value?.totalReviews == 12)
        presenter.showAllReviews()
        #expect(router.reviewRequests.first?.0 == 550)
    }

    @Test("Not found is a non-retryable error; offline is retryable and recovers")
    func errors() async {
        let (notFound, _) = makeSUT([.failure(.notFound)])
        await notFound.onAppear()
        #expect(notFound.state == .failed(.notFound))
        #expect(notFound.state.error?.isRetryable == false)

        let (offline, _) = makeSUT([.failure(.offline), .success(detail())])
        await offline.onAppear()
        #expect(offline.state.error == .offline)
        await offline.retry()
        #expect(offline.state.value?.title == "Fight Club")
    }
}
