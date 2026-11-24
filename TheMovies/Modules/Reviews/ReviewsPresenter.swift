import Observation
import SwiftUI

@Observable
final class ReviewsPresenter {
    let movieID: Int
    let movieTitle: String
    private(set) var paginator = Paginator<ReviewViewModel>()
    private(set) var expandedReviewIDs: Set<String> = []
    var refreshError: APIError?

    private let interactor: any ReviewsInteracting
    private var generation = 0

    init(movieID: Int, movieTitle: String, interactor: any ReviewsInteracting) {
        self.movieID = movieID
        self.movieTitle = movieTitle
        self.interactor = interactor
    }

    var reviews: [ReviewViewModel] { paginator.items }

    /// Average of the ratings among the reviews loaded so far.
    var averageRating: Double? {
        let ratings = reviews.compactMap(\.rating)
        guard !ratings.isEmpty else { return nil }
        return ratings.reduce(0, +) / Double(ratings.count)
    }

    func isExpanded(_ review: ReviewViewModel) -> Bool {
        expandedReviewIDs.contains(review.id)
    }

    // MARK: Intents

    func onAppear() async {
        guard paginator.phase == .idle else { return }
        await loadFirstPage()
    }

    func retry() async {
        await loadFirstPage()
    }

    func refresh() async {
        generation += 1
        let token = generation
        let hadItems = !paginator.items.isEmpty
        paginator = paginator.startingRefresh()
        do {
            let page = try await interactor.fetchReviews(movieID: movieID, page: 1)
            guard token == generation else { return }
            paginator = paginator.receiving(page)
        } catch {
            guard token == generation else { return }
            if hadItems, error != .cancelled { refreshError = error }
            paginator = paginator.failing(with: error)
        }
    }

    func loadMoreIfNeeded(after review: ReviewViewModel) async {
        guard paginator.shouldLoadMore(after: review) else { return }
        await loadNextPage()
    }

    func retryNextPage() async {
        guard case .failedNextPage = paginator.phase else { return }
        await loadNextPage()
    }

    func toggleExpansion(of review: ReviewViewModel) {
        expandedReviewIDs = expandedReviewIDs.symmetricDifference([review.id])
    }

    // MARK: Private

    private func loadFirstPage() async {
        generation += 1
        paginator = paginator.startingFirstPage()
        await fetch(page: 1, token: generation)
    }

    private func loadNextPage() async {
        let page = paginator.nextPage
        paginator = paginator.startingNextPage()
        await fetch(page: page, token: generation)
    }

    private func fetch(page: Int, token: Int) async {
        do {
            let result = try await interactor.fetchReviews(movieID: movieID, page: page)
            guard token == generation else { return }
            paginator = paginator.receiving(result)
        } catch {
            guard token == generation else { return }
            paginator = paginator.failing(with: error)
        }
    }
}
