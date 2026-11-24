import SwiftUI

/// Assembles VIPER modules for navigation destinations. Routers only describe
/// *where* to go (by mutating `Navigator`); the factory decides *what* to build.
struct ModuleFactory {
    let repository: any MovieRepository
    let navigator: Navigator
    let session: AppSession

    func makeRoot() -> some View {
        GenreListModule.build(repository: repository, navigator: navigator)
    }

    @ViewBuilder
    func destination(for route: AppRoute) -> some View {
        switch route {
        case .movies(let genre):
            MovieListModule.build(genre: genre, repository: repository, navigator: navigator)
        case .movieDetail(let movie):
            MovieDetailModule.build(movie: movie, repository: repository, navigator: navigator)
        case .reviews(let movieID, let title):
            ReviewsModule.build(movieID: movieID, title: title, repository: repository)
        }
    }

    @ViewBuilder
    func sheet(for route: SheetRoute) -> some View {
        switch route {
        case .trailer(let context):
            TrailerModule.build(context: context, navigator: navigator)
        case .settings:
            SettingsView(session: session, onClose: navigator.dismissSheet)
        }
    }
}
