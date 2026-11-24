import Testing
@testable import TheMovies

@Suite("Paginator")
struct PaginatorTests {
    private typealias MoviePaginator = Paginator<MovieSummary>

    @Test("First page loads items and keeps more pages available")
    func firstPage() {
        let paginator = MoviePaginator().startingFirstPage().receiving(Fixtures.moviePage(1, ids: 0..<20))
        #expect(paginator.items.count == 20)
        #expect(paginator.phase == .loaded)
        #expect(paginator.canLoadNextPage)
        #expect(paginator.nextPage == 2)
    }

    @Test("Next pages append and drop duplicates returned by the API")
    func appendsAndDeduplicates() {
        let paginator = MoviePaginator()
            .startingFirstPage().receiving(Fixtures.moviePage(1, ids: 0..<20))
            .startingNextPage().receiving(Fixtures.moviePage(2, ids: 15..<35))
        #expect(paginator.items.map(\.id) == Array(0..<35))
        #expect(paginator.currentPage == 2)
    }

    @Test("The last page marks the end of the list")
    func reachesEnd() {
        let paginator = MoviePaginator()
            .startingFirstPage().receiving(Fixtures.moviePage(1, ids: 0..<20, totalPages: 1))
        #expect(!paginator.canLoadNextPage)
        #expect(paginator.hasReachedEnd)
    }

    @Test("An empty first page is an empty state, not an error")
    func emptyFirstPage() {
        let paginator = MoviePaginator().startingFirstPage().receiving(Page(page: 1, items: [], totalPages: 0, totalResults: 0))
        #expect(paginator.isEmpty)
        #expect(!paginator.hasReachedEnd)
    }

    @Test("Prefetch triggers only near the end of the list")
    func threshold() {
        let paginator = MoviePaginator().startingFirstPage().receiving(Fixtures.moviePage(1, ids: 0..<20))
        let nearEnd = paginator.items[20 - MoviePaginator.prefetchThreshold]
        #expect(paginator.shouldLoadMore(after: nearEnd))
        #expect(!paginator.shouldLoadMore(after: paginator.items[0]))
    }

    @Test("No scroll-triggered loads while a page is already loading")
    func noDoubleLoad() {
        let paginator = MoviePaginator()
            .startingFirstPage().receiving(Fixtures.moviePage(1, ids: 0..<20))
            .startingNextPage()
        #expect(!paginator.shouldLoadMore(after: paginator.items[19]))
    }

    @Test("A failing first page with no content shows a full-screen error")
    func firstPageFailure() {
        let paginator = MoviePaginator().startingFirstPage().failing(with: .offline)
        #expect(paginator.phase == .failedFirstPage(.offline))
    }

    @Test("A failing next page keeps items and blocks auto-retry")
    func nextPageFailure() {
        let paginator = MoviePaginator()
            .startingFirstPage().receiving(Fixtures.moviePage(1, ids: 0..<20))
            .startingNextPage().failing(with: .timedOut)
        #expect(paginator.phase == .failedNextPage(.timedOut))
        #expect(paginator.items.count == 20)
        #expect(!paginator.shouldLoadMore(after: paginator.items[19]))
    }

    @Test("A failing refresh keeps the existing content")
    func refreshFailure() {
        let paginator = MoviePaginator()
            .startingFirstPage().receiving(Fixtures.moviePage(1, ids: 0..<20))
            .startingRefresh().failing(with: .server(statusCode: 500))
        #expect(paginator.phase == .loaded)
        #expect(paginator.items.count == 20)
    }

    @Test("Cancellation resets to idle so the next appearance reloads")
    func cancellation() {
        #expect(MoviePaginator().startingFirstPage().failing(with: .cancelled).phase == .idle)
    }
}
