import Foundation

nonisolated struct Review: Decodable, Hashable, Identifiable, Sendable {
    let id: String
    let author: String
    let authorDetails: AuthorDetails?
    let content: String
    let createdAt: String?
    let url: String?

    nonisolated struct AuthorDetails: Decodable, Hashable, Sendable {
        let name: String?
        let username: String?
        let avatarPath: String?
        let rating: Double?
    }

    init(
        id: String,
        author: String,
        authorDetails: AuthorDetails? = nil,
        content: String,
        createdAt: String? = nil,
        url: String? = nil
    ) {
        self.id = id
        self.author = author
        self.authorDetails = authorDetails
        self.content = content
        self.createdAt = createdAt
        self.url = url
    }

    /// TMDB historically stored Gravatar URLs as `"/https://..."`; handle both forms.
    var avatarURL: URL? {
        guard let path = authorDetails?.avatarPath?.nilIfBlank else { return nil }
        if path.hasPrefix("/http") {
            return URL(string: String(path.dropFirst()))
        }
        return TMDBImage.url(path: path, size: .profile)
    }
}
