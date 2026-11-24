import SwiftUI

// MARK: - VIPER contract

protocol ReviewsInteracting {
    func fetchReviews(movieID: Int, page: Int) async throws(APIError) -> Page<ReviewViewModel>
}

// MARK: - Interactor

struct ReviewsInteractor: ReviewsInteracting {
    let repository: any MovieRepository

    func fetchReviews(movieID: Int, page: Int) async throws(APIError) -> Page<ReviewViewModel> {
        try await repository.reviews(movieID: movieID, page: page).map(ReviewViewModel.init(review:))
    }
}

// MARK: - Builder

/// The reviews screen is a leaf: it has no outgoing navigation, so it needs no router.
enum ReviewsModule {
    static func build(movieID: Int, title: String, repository: any MovieRepository) -> ReviewsView {
        let presenter = ReviewsPresenter(
            movieID: movieID,
            movieTitle: title,
            interactor: ReviewsInteractor(repository: repository)
        )
        return ReviewsView(presenter: presenter)
    }
}

// MARK: - View model

/// Display-ready review shared by the reviews screen and the detail preview.
nonisolated struct ReviewViewModel: Identifiable, Hashable, Sendable {
    /// Reviews longer than this collapse behind "Read more".
    static let collapsibleLength = 280

    let id: String
    let author: String
    let handle: String?
    let avatarURL: URL?
    let rating: Double?
    let dateText: String?
    let content: String
    let url: URL?

    init(review: Review) {
        let details = review.authorDetails
        id = review.id
        author = details?.name?.nilIfBlank ?? review.author.nilIfBlank ?? "Anonymous"
        handle = details?.username?.nilIfBlank.map { "@\($0)" }
        avatarURL = review.avatarURL
        rating = details?.rating
        dateText = Formatters.timestamp(from: review.createdAt).map { Formatters.relative($0) }
        content = Self.clean(review.content)
        url = review.url.flatMap(URL.init(string:))
    }

    var isCollapsible: Bool { content.count > Self.collapsibleLength }

    var ratingText: String? { rating.map { Formatters.rating($0) } }

    /// Strips HTML tags and normalises whitespace from user-generated content.
    static func clean(_ raw: String) -> String {
        let withoutTags = raw.replacing(/<[^>]+>/, with: "")
        let normalized = withoutTags
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacing(/\n{3,}/, with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "This review has no text." : normalized
    }
}
