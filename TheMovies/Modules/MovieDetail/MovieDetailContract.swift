import SwiftUI

// MARK: - VIPER contract

protocol MovieDetailInteracting {
    func fetchDetail(movieID: Int) async throws(APIError) -> MovieDetail
}

protocol MovieDetailRouting {
    func showReviews(movieID: Int, title: String)
    func playTrailer(_ context: TrailerContext)
}

// MARK: - Interactor

struct MovieDetailInteractor: MovieDetailInteracting {
    let repository: any MovieRepository

    func fetchDetail(movieID: Int) async throws(APIError) -> MovieDetail {
        try await repository.movieDetail(id: movieID)
    }
}

// MARK: - Router

struct MovieDetailRouter: MovieDetailRouting {
    let navigator: Navigator

    func showReviews(movieID: Int, title: String) {
        navigator.push(.reviews(movieID: movieID, title: title))
    }

    func playTrailer(_ context: TrailerContext) {
        navigator.present(.trailer(context))
    }
}

// MARK: - Builder

enum MovieDetailModule {
    static func build(movie: MovieSummary, repository: any MovieRepository, navigator: Navigator) -> MovieDetailView {
        let presenter = MovieDetailPresenter(
            summary: movie,
            interactor: MovieDetailInteractor(repository: repository),
            router: MovieDetailRouter(navigator: navigator)
        )
        return MovieDetailView(presenter: presenter)
    }
}
