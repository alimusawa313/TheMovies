import Foundation

nonisolated protocol TMDBRequesting: Sendable {
    func send<Response: Decodable & Sendable>(
        _ endpoint: TMDBEndpoint,
        as type: Response.Type
    ) async throws(APIError) -> Response
}

/// Executes TMDB requests. Runs on the cooperative pool (`@concurrent`) so
/// networking and JSON decoding never block the main thread.
nonisolated struct TMDBAPIClient: TMDBRequesting {
    static let defaultBaseURL = URL(string: "https://api.themoviedb.org")!

    private let baseURL: URL
    private let credential: APICredential
    private let language: String
    private let http: any HTTPClient

    init(
        credential: APICredential,
        http: any HTTPClient = URLSessionHTTPClient(),
        baseURL: URL = TMDBAPIClient.defaultBaseURL,
        language: String = "en-US"
    ) {
        self.credential = credential
        self.http = http
        self.baseURL = baseURL
        self.language = language
    }

    @concurrent
    func send<Response: Decodable & Sendable>(
        _ endpoint: TMDBEndpoint,
        as type: Response.Type
    ) async throws(APIError) -> Response {
        let request = try endpoint.urlRequest(baseURL: baseURL, credential: credential, language: language)
        let (data, response) = try await perform(request)
        try Self.validate(response)
        return try Self.decode(type, from: data)
    }

    private func perform(_ request: URLRequest) async throws(APIError) -> (Data, HTTPURLResponse) {
        do {
            try Task.checkCancellation()
            let (data, response) = try await http.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.transport("The server returned an invalid response.")
            }
            return (data, httpResponse)
        } catch {
            throw APIError.map(error)
        }
    }

    private static func validate(_ response: HTTPURLResponse) throws(APIError) {
        guard (200..<300).contains(response.statusCode) else {
            throw APIError.from(
                statusCode: response.statusCode,
                retryAfterHeader: response.value(forHTTPHeaderField: "Retry-After")
            )
        }
    }

    private static func decode<Response: Decodable>(
        _ type: Response.Type,
        from data: Data
    ) throws(APIError) -> Response {
        do {
            return try makeDecoder().decode(type, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
