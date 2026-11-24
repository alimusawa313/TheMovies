import Foundation

/// Every failure the data layer can surface, normalised so the UI can render
/// a meaningful message and decide whether a retry makes sense.
nonisolated enum APIError: Error, Equatable, Sendable {
    case invalidCredential
    case unauthorized
    case notFound
    case rateLimited(retryAfter: TimeInterval?)
    case server(statusCode: Int)
    case unexpectedStatus(Int)
    case offline
    case timedOut
    case decoding(String)
    case invalidRequest
    case cancelled
    case transport(String)
}

nonisolated extension APIError {
    /// Maps any thrown error (URLError, CancellationError, ...) into an `APIError`.
    static func map(_ error: any Error) -> APIError {
        if let apiError = error as? APIError { return apiError }
        if error is CancellationError { return .cancelled }
        if let urlError = error as? URLError { return map(urlError) }
        if error is DecodingError { return .decoding(String(describing: error)) }
        return .transport(error.localizedDescription)
    }

    static func map(_ urlError: URLError) -> APIError {
        switch urlError.code {
        case .cancelled:
            return .cancelled
        case .timedOut:
            return .timedOut
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
             .internationalRoamingOff, .cannotFindHost, .cannotConnectToHost,
             .dnsLookupFailed:
            return .offline
        default:
            return .transport(urlError.localizedDescription)
        }
    }

    /// Maps a non-2xx HTTP status code into an error.
    static func from(statusCode: Int, retryAfterHeader: String?) -> APIError {
        switch statusCode {
        case 401, 403: return .unauthorized
        case 404: return .notFound
        case 429: return .rateLimited(retryAfter: retryAfterHeader.flatMap(TimeInterval.init))
        case 500...599: return .server(statusCode: statusCode)
        default: return .unexpectedStatus(statusCode)
        }
    }

    var isRetryable: Bool {
        switch self {
        case .invalidCredential, .unauthorized, .notFound, .invalidRequest, .cancelled:
            return false
        default:
            return true
        }
    }

    var title: String {
        switch self {
        case .invalidCredential: "That key doesn't look right"
        case .unauthorized: "Access denied"
        case .notFound: "Nothing here"
        case .rateLimited: "Slow down a little"
        case .server: "TMDB is having a moment"
        case .unexpectedStatus: "Unexpected response"
        case .offline: "You're offline"
        case .timedOut: "This is taking too long"
        case .decoding: "We couldn't read the data"
        case .invalidRequest: "Invalid request"
        case .cancelled: "Cancelled"
        case .transport: "Something went wrong"
        }
    }

    var message: String {
        switch self {
        case .invalidCredential:
            "Paste a TMDB v3 API key (32 characters) or a v4 read access token."
        case .unauthorized:
            "Your TMDB API key was rejected. Check it in Settings and try again."
        case .notFound:
            "TMDB couldn't find what you were looking for."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                "Too many requests. Try again in \(Int(retryAfter.rounded(.up))) seconds."
            } else {
                "Too many requests. Wait a moment and try again."
            }
        case .server(let statusCode):
            "The server responded with an error (\(statusCode)). Please try again shortly."
        case .unexpectedStatus(let statusCode):
            "The server returned status \(statusCode)."
        case .offline:
            "Check your internet connection and try again."
        case .timedOut:
            "The request timed out. Check your connection and retry."
        case .decoding:
            "TMDB sent something we didn't expect. Please try again later."
        case .invalidRequest:
            "The request could not be built."
        case .cancelled:
            "The request was cancelled."
        case .transport(let description):
            description
        }
    }

    var symbol: String {
        switch self {
        case .offline: "wifi.slash"
        case .timedOut: "hourglass"
        case .unauthorized, .invalidCredential: "key.slash"
        case .notFound: "questionmark.folder"
        case .rateLimited: "tortoise"
        case .server, .unexpectedStatus: "server.rack"
        case .decoding: "doc.questionmark"
        default: "exclamationmark.triangle"
        }
    }
}
