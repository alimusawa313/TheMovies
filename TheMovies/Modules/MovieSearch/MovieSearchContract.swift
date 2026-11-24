import SwiftUI

// MARK: - VIPER contract

protocol MovieSearchInteracting {
    func search(query: String, page: Int) async throws(APIError) -> Page<MovieSummary>
}

// Routing reuses `MovieListRouting`: a search result opens the same detail screen.

// MARK: - Interactor

struct MovieSearchInteractor: MovieSearchInteracting {
    let repository: any MovieRepository

    func search(query: String, page: Int) async throws(APIError) -> Page<MovieSummary> {
        try await repository.searchMovies(query: query, page: page)
    }
}

// MARK: - Builder

enum MovieSearchModule {
    static func makePresenter(repository: any MovieRepository, navigator: Navigator) -> MovieSearchPresenter {
        MovieSearchPresenter(
            interactor: MovieSearchInteractor(repository: repository),
            router: MovieListRouter(navigator: navigator)
        )
    }
}
