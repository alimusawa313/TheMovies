import SwiftUI

// MARK: - VIPER contract

protocol MovieListInteracting {
    func fetchMovies(genreID: Int, page: Int, sort: DiscoverSort) async throws(APIError) -> Page<MovieSummary>
}

protocol MovieListRouting {
    func showDetail(for movie: MovieSummary)
}

// MARK: - Interactor

struct MovieListInteractor: MovieListInteracting {
    let repository: any MovieRepository

    func fetchMovies(genreID: Int, page: Int, sort: DiscoverSort) async throws(APIError) -> Page<MovieSummary> {
        try await repository.discoverMovies(genreID: genreID, page: page, sort: sort)
    }
}

// MARK: - Router

struct MovieListRouter: MovieListRouting {
    let navigator: Navigator

    func showDetail(for movie: MovieSummary) {
        navigator.push(.movieDetail(movie))
    }
}

// MARK: - Builder

enum MovieListModule {
    static func build(genre: Genre, repository: any MovieRepository, navigator: Navigator) -> MovieListView {
        let presenter = MovieListPresenter(
            genre: genre,
            interactor: MovieListInteractor(repository: repository),
            router: MovieListRouter(navigator: navigator)
        )
        return MovieListView(presenter: presenter)
    }
}
