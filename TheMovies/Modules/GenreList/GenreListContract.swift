import SwiftUI

// MARK: - VIPER contract

/// Interactor: business logic / data access for the genre list.
protocol GenreListInteracting {
    func fetchGenres() async throws(APIError) -> [Genre]
}

/// Router: navigation out of the genre list.
protocol GenreListRouting {
    func showMovies(for genre: Genre)
    func showSettings()
}

// MARK: - Interactor

struct GenreListInteractor: GenreListInteracting {
    let repository: any MovieRepository

    func fetchGenres() async throws(APIError) -> [Genre] {
        try await repository.genres()
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Router

struct GenreListRouter: GenreListRouting {
    let navigator: Navigator

    func showMovies(for genre: Genre) {
        navigator.push(.movies(genre))
    }

    func showSettings() {
        navigator.present(.settings)
    }
}

// MARK: - Builder

enum GenreListModule {
    static func build(repository: any MovieRepository, navigator: Navigator) -> GenreListView {
        let presenter = GenreListPresenter(
            interactor: GenreListInteractor(repository: repository),
            router: GenreListRouter(navigator: navigator)
        )
        let searchPresenter = MovieSearchModule.makePresenter(repository: repository, navigator: navigator)
        return GenreListView(presenter: presenter, searchPresenter: searchPresenter)
    }
}
