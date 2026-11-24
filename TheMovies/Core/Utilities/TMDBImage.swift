import Foundation

/// Builds TMDB image CDN URLs. The image CDN does not require an API key.
nonisolated enum TMDBImage {
    enum Size: String {
        case poster = "w342"
        case posterLarge = "w500"
        case backdrop = "w780"
        case profile = "w185"
    }

    private static let baseURL = "https://image.tmdb.org/t/p/"

    static func url(path: String?, size: Size) -> URL? {
        guard let path = path?.nilIfBlank, path.hasPrefix("/") else { return nil }
        return URL(string: baseURL + size.rawValue + path)
    }
}
