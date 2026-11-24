import SwiftUI

/// Movie search results, embedded under the genre screen's search bar.
struct MovieSearchResultsView: View {
    let presenter: MovieSearchPresenter
    @State private var selectedMovie: MovieSummary?

    private static let skeletonCount = 5

    var body: some View {
        Group {
            switch presenter.paginator.phase {
            case .idle:
                skeleton
            case .loadingFirstPage where presenter.results.isEmpty:
                skeleton
            case .failedFirstPage(let error):
                ErrorStateView(error: error) { Task { await presenter.retry() } }
            case _ where presenter.paginator.isEmpty:
                EmptyStateView(
                    symbol: "magnifyingglass",
                    title: "No movies found",
                    message: "We couldn't find a movie called “\(presenter.query)”. Check the spelling or try another title."
                )
            default:
                results
            }
        }
        .animation(Motion.smooth, value: presenter.paginator.phase)
        .sensoryFeedback(.selection, trigger: selectedMovie)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search-results")
    }

    private var results: some View {
        LazyVStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Movies") {
                Text("\(presenter.paginator.totalResults.formatted()) results")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .contentTransition(.numericText(value: Double(presenter.paginator.totalResults)))
            }
            ForEach(Array(presenter.results.enumerated()), id: \.element.id) { index, movie in
                Button {
                    selectedMovie = movie
                    presenter.didSelect(movie)
                } label: {
                    SearchResultRow(movie: movie, query: presenter.query)
                }
                .buttonStyle(.pressable(scale: 0.97))
                .staggeredAppear(index: index)
                .onAppear {
                    Task { await presenter.loadMoreIfNeeded(after: movie) }
                }
                .accessibilityIdentifier("search-result-\(movie.id)")
            }
            LoadMoreFooter(
                status: LoadMoreFooter.Status(
                    paginator: presenter.paginator,
                    endMessage: "That's everything for “\(presenter.query)”"
                )
            ) {
                Task { await presenter.retryNextPage() }
            }
        }
        .transition(.opacity)
    }

    private var skeleton: some View {
        VStack(spacing: Theme.Spacing.s) {
            ForEach(0..<Self.skeletonCount, id: \.self) { _ in
                HStack(spacing: Theme.Spacing.s) {
                    SkeletonBlock().frame(width: 64, height: 96)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock().frame(width: 180, height: 16)
                        SkeletonBlock().frame(width: 90, height: 12)
                        SkeletonBlock().frame(height: 12)
                    }
                }
                .padding(Theme.Spacing.xs)
            }
        }
        .accessibilityLabel("Searching")
        .accessibilityIdentifier("search-skeleton")
        .transition(.opacity)
    }
}

/// One search result: poster, highlighted title, year, rating and overview.
struct SearchResultRow: View {
    let movie: MovieSummary
    let query: String

    private static let posterWidth: CGFloat = 64

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            PosterArtwork(url: movie.posterURL, title: movie.title, seed: movie.id, cornerRadius: Theme.Radius.s)
                .frame(width: Self.posterWidth)
                .zoomSource(id: movie.id)
            VStack(alignment: .leading, spacing: 6) {
                Text(highlightedTitle)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: Theme.Spacing.xs) {
                    Text(movie.releaseYear ?? "TBA")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    RatingBadge(rating: movie.voteAverage)
                }
                if !movie.overview.isEmpty {
                    Text(movie.overview)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, Theme.Spacing.xs)
        }
        .padding(Theme.Spacing.xs)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.m, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Title with the matched part of the query emphasised in the accent colour.
    private var highlightedTitle: AttributedString {
        var title = AttributedString(movie.title)
        if !query.isEmpty, let range = title.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            title[range].foregroundColor = Theme.accent
        }
        return title
    }
}
