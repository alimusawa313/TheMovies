import Testing
@testable import TheMovies

final class MockReviewsInteractor: ReviewsInteracting {
    var results: [Result<Page<ReviewViewModel>, APIError>]
    private(set) var requestedPages: [Int] = []

    init(_ results: [Result<Page<ReviewViewModel>, APIError>]) { self.results = results }

    func fetchReviews(movieID: Int, page: Int) async throws(APIError) -> Page<ReviewViewModel> {
        requestedPages.append(page)
        return try results.removeFirst().get()
    }
}

@Suite("Reviews presenter")
struct ReviewsPresenterTests {
    private func page(_ number: Int, ids: Range<Int>, totalPages: Int, ratings: Double? = 8) -> Page<ReviewViewModel> {
        Page(
            page: number,
            items: ids.map { ReviewViewModel(review: Fixtures.review(id: "\($0)", rating: ratings)) },
            totalPages: totalPages,
            totalResults: totalPages * ids.count
        )
    }

    private func makeSUT(_ results: [Result<Page<ReviewViewModel>, APIError>]) -> (ReviewsPresenter, MockReviewsInteractor) {
        let interactor = MockReviewsInteractor(results)
        return (ReviewsPresenter(movieID: 1, movieTitle: "Title", interactor: interactor), interactor)
    }

    @Test("Loads reviews and paginates to the end")
    func paginates() async {
        let (presenter, interactor) = makeSUT([
            .success(page(1, ids: 0..<5, totalPages: 2)),
            .success(page(2, ids: 5..<10, totalPages: 2)),
        ])
        await presenter.onAppear()
        await presenter.loadMoreIfNeeded(after: presenter.reviews[4])
        #expect(presenter.reviews.count == 10)
        #expect(interactor.requestedPages == [1, 2])
        #expect(presenter.paginator.hasReachedEnd)
    }

    @Test("No reviews shows the empty state")
    func empty() async {
        let (presenter, _) = makeSUT([.success(Page(page: 1, items: [], totalPages: 0, totalResults: 0))])
        await presenter.onAppear()
        #expect(presenter.paginator.isEmpty)
        #expect(presenter.averageRating == nil)
    }

    @Test("Load-more failure keeps reviews and can be retried")
    func loadMoreFailure() async {
        let (presenter, _) = makeSUT([
            .success(page(1, ids: 0..<5, totalPages: 3)),
            .failure(.rateLimited(retryAfter: 2)),
            .success(page(2, ids: 5..<10, totalPages: 3)),
        ])
        await presenter.onAppear()
        await presenter.loadMoreIfNeeded(after: presenter.reviews[4])
        #expect(presenter.paginator.phase == .failedNextPage(.rateLimited(retryAfter: 2)))
        await presenter.retryNextPage()
        #expect(presenter.reviews.count == 10)
    }

    @Test("Average rating ignores unrated reviews")
    func averageRating() async {
        let rated = page(1, ids: 0..<2, totalPages: 1, ratings: 6)
        let unrated = ReviewViewModel(review: Fixtures.review(id: "x", rating: nil))
        let combined = Page(page: 1, items: rated.items + [unrated], totalPages: 1, totalResults: 3)
        let (presenter, _) = makeSUT([.success(combined)])
        await presenter.onAppear()
        #expect(presenter.averageRating == 6)
    }

    @Test("Toggling expansion is per review")
    func expansion() async {
        let (presenter, _) = makeSUT([.success(page(1, ids: 0..<2, totalPages: 1))])
        await presenter.onAppear()
        presenter.toggleExpansion(of: presenter.reviews[0])
        #expect(presenter.isExpanded(presenter.reviews[0]))
        #expect(!presenter.isExpanded(presenter.reviews[1]))
        presenter.toggleExpansion(of: presenter.reviews[0])
        #expect(!presenter.isExpanded(presenter.reviews[0]))
    }

    @Test("Review content is cleaned of HTML and excess whitespace")
    func cleaning() {
        #expect(ReviewViewModel.clean("<p>Great</p>\r\n\r\n\r\n\r\n<b>film</b> ") == "Great\n\nfilm")
        #expect(ReviewViewModel.clean("   ") == "This review has no text.")
    }

    @Test("Author falls back to the account name, then Anonymous")
    func authorFallback() {
        let review = Review(id: "1", author: "", authorDetails: .init(name: "", username: "", avatarPath: nil, rating: nil), content: "x")
        let viewModel = ReviewViewModel(review: review)
        #expect(viewModel.author == "Anonymous")
        #expect(viewModel.handle == nil)
    }
}

final class SpyTrailerRouter: TrailerRouting {
    private(set) var closeCount = 0
    func close() { closeCount += 1 }
}

@Suite("Trailer presenter")
struct TrailerPresenterTests {
    @Test("Starts with the chosen video and switches selection")
    func selection() {
        let videos = [Fixtures.video(id: "a"), Fixtures.video(id: "b")]
        let presenter = TrailerPresenter(
            context: TrailerContext(movieTitle: "M", videos: videos, initialVideo: videos[1]),
            router: SpyTrailerRouter()
        )
        #expect(presenter.isSelected(videos[1]))
        presenter.select(videos[0])
        #expect(presenter.selectedVideo == videos[0])
    }

    @Test("Falls back to the initial video when the list is empty, and closes via router")
    func emptyListAndClose() {
        let router = SpyTrailerRouter()
        let video = Fixtures.video(id: "only")
        let presenter = TrailerPresenter(context: TrailerContext(movieTitle: "M", videos: [], initialVideo: video), router: router)
        #expect(presenter.videos == [video])
        presenter.close()
        #expect(router.closeCount == 1)
    }
}
