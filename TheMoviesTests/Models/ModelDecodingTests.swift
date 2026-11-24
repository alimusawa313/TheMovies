import Foundation
import Testing
@testable import TheMovies

@Suite("Model decoding")
struct ModelDecodingTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try TMDBAPIClient.makeDecoder().decode(type, from: Data(json.utf8))
    }

    @Test("Discover page tolerates nulls, empty dates and missing fields")
    func discoverPage() throws {
        let json = """
        {"page":1,"total_pages":42,"total_results":830,"results":[
          {"id":1,"title":"Complete","overview":"Text","poster_path":"/p.jpg","backdrop_path":"/b.jpg",
           "vote_average":7.8,"vote_count":1200,"release_date":"2014-11-05"},
          {"id":2,"title":"Sparse","poster_path":null,"release_date":""}
        ]}
        """
        let page = try decode(Page<MovieSummary>.self, json)
        #expect(page.items.count == 2)
        #expect(page.totalPages == 42)
        #expect(page.hasMore)
        #expect(page.items[0].posterURL?.absoluteString == "https://image.tmdb.org/t/p/w342/p.jpg")
        #expect(page.items[0].releaseYear == "2014")
        #expect(page.items[1].posterURL == nil)
        #expect(page.items[1].releaseYear == nil)
        #expect(page.items[1].voteAverage == 0)
    }

    @Test("A malformed item is skipped instead of failing the page")
    func lossyResults() throws {
        let json = #"{"page":1,"total_pages":1,"total_results":2,"results":[{"id":1,"title":"Good"},{"title":"No id"}]}"#
        let page = try decode(Page<MovieSummary>.self, json)
        #expect(page.items.map(\.id) == [1])
    }

    @Test("Pages beyond TMDB's 500-page cap are not requested")
    func pageCap() {
        let page = Page<Int>(page: 500, items: [1], totalPages: 900, totalResults: 18_000)
        #expect(!page.hasMore)
    }

    @Test("Movie detail decodes appended videos, reviews and credits")
    func movieDetail() throws {
        let json = """
        {"id":550,"title":"Fight Club","tagline":"","overview":"Overview","runtime":139,"release_date":"1999-10-15",
         "genres":[{"id":18,"name":"Drama"}],"vote_average":8.4,"vote_count":30000,"budget":63000000,"revenue":0,
         "videos":{"results":[{"id":"v1","key":"abc","name":"Trailer","site":"YouTube","type":"Trailer","official":true}]},
         "reviews":{"page":1,"total_pages":2,"total_results":7,"results":[{"id":"r1","author":"A","content":"Wow"}]},
         "credits":{"cast":[{"id":1,"name":"Edward Norton","character":"Narrator","profile_path":null}]}}
        """
        let detail = try decode(MovieDetail.self, json)
        #expect(detail.tagline == nil)
        #expect(detail.videos.first?.key == "abc")
        #expect(detail.reviews?.totalResults == 7)
        #expect(detail.cast.first?.name == "Edward Norton")
        #expect(detail.revenue == 0)
    }

    @Test("Movie detail survives missing appended sections")
    func movieDetailWithoutAppends() throws {
        let detail = try decode(MovieDetail.self, #"{"id":1,"title":"Bare"}"#)
        #expect(detail.videos.isEmpty)
        #expect(detail.reviews == nil)
        #expect(detail.cast.isEmpty)
        #expect(detail.genres.isEmpty)
    }

    @Test("Review avatars handle both TMDB paths and legacy Gravatar URLs")
    func reviewAvatars() throws {
        let json = """
        {"page":1,"total_pages":1,"total_results":2,"results":[
          {"id":"1","author":"a","content":"x","author_details":{"avatar_path":"/https://secure.gravatar.com/avatar/abc.jpg"}},
          {"id":"2","author":"b","content":"y","author_details":{"avatar_path":"/local.jpg","rating":null}}
        ]}
        """
        let page = try decode(Page<Review>.self, json)
        #expect(page.items[0].avatarURL?.absoluteString == "https://secure.gravatar.com/avatar/abc.jpg")
        #expect(page.items[1].avatarURL?.absoluteString == "https://image.tmdb.org/t/p/w185/local.jpg")
    }

    @Test("Trailer ranking prefers official YouTube trailers and drops other sites")
    func trailerRanking() {
        let videos = [
            Fixtures.video(id: "clip", type: "Clip"),
            Fixtures.video(id: "vimeo", type: "Trailer", site: "Vimeo"),
            Fixtures.video(id: "fan", type: "Trailer", official: false),
            Fixtures.video(id: "teaser", type: "Teaser"),
            Fixtures.video(id: "official", type: "Trailer"),
        ]
        #expect(videos.playableTrailers.map(\.id) == ["official", "fan", "teaser", "clip"])
    }
}

@Suite("Formatters")
struct FormattersTests {
    @Test("Runtime formatting", arguments: [(169, "2h 49m"), (45, "45m"), (120, "2h")])
    func runtime(minutes: Int, expected: String) {
        #expect(Formatters.runtime(minutes: minutes) == expected)
    }

    @Test("Missing runtimes produce nil")
    func missingRuntime() {
        #expect(Formatters.runtime(minutes: nil) == nil)
        #expect(Formatters.runtime(minutes: 0) == nil)
    }

    @Test("Year parsing rejects malformed dates")
    func year() {
        #expect(Formatters.year(from: "2014-11-05") == "2014")
        #expect(Formatters.year(from: "") == nil)
        #expect(Formatters.year(from: "soon") == nil)
    }

    @Test("Money hides unknown values")
    func money() {
        #expect(Formatters.money(165_000_000) == "$165M")
        #expect(Formatters.money(0) == nil)
    }

    @Test("Timestamps parse with and without fractional seconds")
    func timestamps() {
        #expect(Formatters.timestamp(from: "2025-03-14T10:15:00.000Z") != nil)
        #expect(Formatters.timestamp(from: "2025-03-14T10:15:00Z") != nil)
        #expect(Formatters.timestamp(from: "yesterday") == nil)
    }
}
