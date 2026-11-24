import Foundation

/// TMDB accepts either a v3 API key (query parameter) or a v4 read access
/// token (bearer header). Both are supported transparently.
nonisolated enum APICredential: Hashable, Sendable {
    case apiKey(String)
    case accessToken(String)

    private static let apiKeyLength = 32
    private static let minimumTokenLength = 40

    /// Parses user input. Returns `nil` when the value is clearly malformed so
    /// we can reject it before making a network request.
    init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.isAccessToken(trimmed) {
            self = .accessToken(trimmed)
        } else if Self.isAPIKey(trimmed) {
            self = .apiKey(trimmed)
        } else {
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .apiKey(let value), .accessToken(let value): value
        }
    }

    private static func isAPIKey(_ value: String) -> Bool {
        value.count == apiKeyLength && value.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    /// JWT: three base64url segments separated by dots.
    private static func isAccessToken(_ value: String) -> Bool {
        let segments = value.split(separator: ".", omittingEmptySubsequences: false)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_="))
        return value.count >= minimumTokenLength
            && segments.count == 3
            && segments.allSatisfy { !$0.isEmpty && $0.unicodeScalars.allSatisfy(allowed.contains) }
    }
}
