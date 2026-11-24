import Foundation
import Testing
@testable import TheMovies

@Suite("TMDB API client")
struct TMDBAPIClientTests {
    private func makeClient(_ http: StubHTTPClient, credential: APICredential = .apiKey(Fixtures.validAPIKey)) -> TMDBAPIClient {
        TMDBAPIClient(credential: credential, http: http)
    }

    @Test("Decodes a successful response")
    func decodesSuccess() async throws {
        let http = StubHTTPClient(status: 200, body: #"{"genres":[{"id":28,"name":"Action"}]}"#)
        let response = try await makeClient(http).send(.genres(), as: GenreListResponse.self)
        #expect(response.genres == [Genre(id: 28, name: "Action")])
    }

    @Test("Sends v3 API keys as a query parameter")
    func apiKeyGoesInQuery() async throws {
        let http = StubHTTPClient(status: 200, body: #"{"genres":[]}"#)
        _ = try await makeClient(http).send(.genres(), as: GenreListResponse.self)
        let request = try #require(http.requests.first)
        let items = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "api_key", value: Fixtures.validAPIKey)))
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("Sends v4 access tokens as a bearer header")
    func tokenGoesInHeader() async throws {
        let token = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature_part_123"
        let http = StubHTTPClient(status: 200, body: #"{"genres":[]}"#)
        _ = try await makeClient(http, credential: .accessToken(token)).send(.genres(), as: GenreListResponse.self)
        let request = try #require(http.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)")
        #expect(request.url?.query?.contains("api_key") == false)
    }

    @Test(
        "Maps HTTP error statuses",
        arguments: [
            (401, APIError.unauthorized),
            (404, APIError.notFound),
            (500, APIError.server(statusCode: 500)),
            (503, APIError.server(statusCode: 503)),
            (418, APIError.unexpectedStatus(418)),
        ]
    )
    func mapsStatusCodes(status: Int, expected: APIError) async {
        let http = StubHTTPClient(status: status, body: #"{"status_message":"nope"}"#)
        await #expect(throws: expected) {
            try await makeClient(http).send(.genres(), as: GenreListResponse.self)
        }
    }

    @Test("Reads Retry-After when rate limited")
    func rateLimited() async {
        let http = StubHTTPClient(status: 429, body: "{}", headers: ["Retry-After": "7"])
        await #expect(throws: APIError.rateLimited(retryAfter: 7)) {
            try await makeClient(http).send(.genres(), as: GenreListResponse.self)
        }
    }

    @Test(
        "Maps transport failures",
        arguments: [
            (URLError(.notConnectedToInternet), APIError.offline),
            (URLError(.timedOut), APIError.timedOut),
            (URLError(.cancelled), APIError.cancelled),
        ]
    )
    func mapsTransportErrors(error: URLError, expected: APIError) async {
        let http = StubHTTPClient(error: error)
        await #expect(throws: expected) {
            try await makeClient(http).send(.genres(), as: GenreListResponse.self)
        }
    }

    @Test("Reports malformed JSON as a decoding error")
    func malformedJSON() async {
        let http = StubHTTPClient(status: 200, body: "<html>not json</html>")
        do {
            _ = try await makeClient(http).send(.genres(), as: GenreListResponse.self)
            Issue.record("Expected a decoding error")
        } catch {
            guard case .decoding = error else {
                Issue.record("Expected .decoding, got \(error)")
                return
            }
        }
    }
}
