import Nuke
import SwiftUI

struct MovieListView: View {
    @State private var presenter: MovieListPresenter
    @State private var showsScrollToTop = false
    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var selectedMovie: MovieSummary?
    @State private var prefetcher = ImagePrefetcher()
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: Theme.Spacing.m)]
    private static let scrollToTopThreshold: CGFloat = 700
    private static let skeletonCount = 8

    init(presenter: MovieListPresenter) {
        _presenter = State(initialValue: presenter)
    }

    private var genreColors: [Color] { GenreAppearance.colors(for: presenter.genre.id) }
    /// iPhone landscape switches to the poster flow.
    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AmbientBackground(tint: genreColors[0], secondaryTint: genreColors[1])
            if isLandscape {
                landscapeContent
            } else {
                scrollContent
                ScrollToTopButton(isVisible: showsScrollToTop) {
                    withAnimation(Motion.smooth) { scrollPosition.scrollTo(edge: .top) }
                }
                .padding(Theme.Spacing.l)
            }
        }
        .animation(Motion.gentle, value: isLandscape)
        .navigationTitle(presenter.genre.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if isLandscape {
                // Landscape: the genre moves beside the back button and the sort
                // control takes the centre of the bar, freeing vertical space.
                ToolbarItem(placement: .topBarLeading) {
                    Label(presenter.genre.name, systemImage: GenreAppearance.symbol(for: presenter.genre.id))
                        .labelStyle(.titleAndIcon)
                        .font(.headline)
                        .fixedSize()
                        .accessibilityIdentifier("landscape-genre-title")
                }
                ToolbarItem(placement: .principal) {
                    SortBar(selection: presenter.sort, isCompact: true) { sort in
                        Task { await presenter.select(sort: sort) }
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .sensoryFeedback(.selection, trigger: selectedMovie)
        .task { await presenter.onAppear() }
        .onChange(of: presenter.movies.count) { oldCount, newCount in
            prefetchPosters(from: oldCount, to: newCount)
        }
        .onDisappear { prefetcher.stopPrefetching() }
        .errorToast($presenter.refreshError)
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                header
                SortBar(selection: presenter.sort) { sort in
                    Task { await presenter.select(sort: sort) }
                }
                content
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y > Self.scrollToTopThreshold
        } action: { _, isPastThreshold in
            withAnimation(Motion.bouncy) { showsScrollToTop = isPastThreshold }
        }
        .refreshable { await presenter.refresh() }
        .accessibilityIdentifier("movie-list")
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: GenreAppearance.symbol(for: presenter.genre.id))
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(GenreAppearance.gradient(for: presenter.genre.id), in: .rect(cornerRadius: 12))
                .symbolEffect(.bounce, value: presenter.sort)
            VStack(alignment: .leading, spacing: 2) {
                Text("Discover")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .textCase(.uppercase)
                Text(resultCountText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.numericText(value: Double(presenter.paginator.totalResults)))
                    .animation(Motion.smooth, value: presenter.paginator.totalResults)
            }
        }
    }

    private var resultCountText: String {
        let total = presenter.paginator.totalResults
        return total > 0 ? "\(total.formatted()) movies" : "Finding movies…"
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch presenter.paginator.phase {
            case .idle:
                skeleton
            case .loadingFirstPage where presenter.movies.isEmpty:
                skeleton
            case .failedFirstPage(let error):
                errorView(error).padding(.top, Theme.Spacing.xl)
            case _ where presenter.paginator.isEmpty:
                emptyView.padding(.top, Theme.Spacing.xl)
            default:
                grid
            }
        }
        .animation(Motion.smooth, value: presenter.paginator.phase)
    }

    private func errorView(_ error: APIError) -> some View {
        ErrorStateView(error: error) { Task { await presenter.retry() } }
    }

    private var emptyView: some View {
        EmptyStateView(
            symbol: "popcorn",
            title: "No movies found",
            message: "Nothing matches “\(presenter.sort.title)” in \(presenter.genre.name). Try another sort.",
            actionTitle: "Show Popular"
        ) { Task { await presenter.select(sort: .popular) } }
    }

    // MARK: Landscape

    private var landscapeContent: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Group {
                switch presenter.paginator.phase {
                case .idle:
                    flowSkeleton
                case .loadingFirstPage where presenter.movies.isEmpty:
                    flowSkeleton
                case .failedFirstPage(let error):
                    ScrollView { errorView(error) }
                case _ where presenter.paginator.isEmpty:
                    ScrollView { emptyView }
                default:
                    MoviePosterFlowView(presenter: presenter)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(Motion.smooth, value: presenter.paginator.phase)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    /// Tilted placeholder posters while the first page loads in landscape.
    private var flowSkeleton: some View {
        HStack(spacing: -40) {
            ForEach(-2...2, id: \.self) { offset in
                SkeletonBlock(cornerRadius: Theme.Radius.s)
                    .frame(width: 130, height: 195)
                    .rotation3DEffect(.degrees(Double(-offset) * 55), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                    .scaleEffect(offset == 0 ? 1 : 0.88)
                    .zIndex(-Double(abs(offset)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Loading movies")
        .accessibilityIdentifier("flow-skeleton")
        .transition(.opacity)
    }

    private var grid: some View {
        VStack(spacing: Theme.Spacing.s) {
            LazyVGrid(columns: columns, spacing: Theme.Spacing.l) {
                ForEach(Array(presenter.movies.enumerated()), id: \.element.id) { index, movie in
                    Button {
                        selectedMovie = movie
                        presenter.didSelect(movie)
                    } label: {
                        MovieCard(movie: movie)
                    }
                    .buttonStyle(.pressable(scale: 0.94, tilt: 6))
                    .staggeredAppear(index: index)
                    .scrollDepthEffect()
                    .onAppear {
                        Task { await presenter.loadMoreIfNeeded(after: movie) }
                    }
                    .accessibilityIdentifier("movie-card-\(movie.id)")
                }
            }
            LoadMoreFooter(
                status: LoadMoreFooter.Status(
                    paginator: presenter.paginator,
                    endMessage: "That's every \(presenter.genre.name.lowercased()) movie we've got"
                )
            ) {
                Task { await presenter.retryNextPage() }
            }
        }
        .transition(.opacity)
    }

    private var skeleton: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.l) {
            ForEach(0..<Self.skeletonCount, id: \.self) { _ in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    SkeletonBlock(cornerRadius: Theme.Radius.m).aspectRatio(2.0 / 3.0, contentMode: .fit)
                    SkeletonBlock().frame(height: 14)
                    SkeletonBlock().frame(width: 60, height: 10)
                }
            }
        }
        .accessibilityLabel("Loading movies")
        .accessibilityIdentifier("movie-skeleton")
        .transition(.opacity)
    }

    private func prefetchPosters(from oldCount: Int, to newCount: Int) {
        guard newCount > oldCount, oldCount < presenter.movies.count else { return }
        let urls = presenter.movies[oldCount..<newCount].compactMap(\.posterURL)
        prefetcher.startPrefetching(with: urls)
    }
}

/// Horizontal sort chips with a sliding, matched-geometry selection pill.
struct SortBar: View {
    let selection: DiscoverSort
    /// Compact chips sized for the navigation bar (landscape).
    var isCompact = false
    let onSelect: (DiscoverSort) -> Void
    @Namespace private var namespace

    var body: some View {
        Group {
            if isCompact {
                // Fits the bar without scrolling; a ScrollView in a toolbar collapses to zero width.
                chips
            } else {
                ScrollView(.horizontal) {
                    chips.padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .animation(Motion.bouncy, value: selection)
        .accessibilityIdentifier("sort-bar")
    }

    private var chips: some View {
        HStack(spacing: isCompact ? Theme.Spacing.xxs : Theme.Spacing.xs) {
            ForEach(DiscoverSort.allCases) { sort in
                chip(for: sort)
            }
        }
    }

    private func chip(for sort: DiscoverSort) -> some View {
        let isSelected = sort == selection
        // In the compact (toolbar) variant only the selected chip reveals its
        // title; the rest stay as icons so the bar remains uncluttered.
        let showsTitle = !isCompact || isSelected
        return Button { onSelect(sort) } label: {
            HStack(spacing: 6) {
                Image(systemName: sort.symbol)
                if showsTitle {
                    Text(sort.title)
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.6, anchor: .leading)))
                }
            }
                .font(isCompact ? .footnote.weight(.semibold) : .subheadline.weight(.semibold))
                .symbolEffect(.bounce, value: isSelected)
                .padding(.horizontal, isCompact ? 11 : 14)
                .padding(.vertical, isCompact ? 6 : 9)
                .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Theme.accentGradient)
                            .matchedGeometryEffect(id: "sort-selection", in: namespace)
                            .shadow(color: Theme.accent.opacity(0.4), radius: 8, y: 4)
                    } else {
                        Capsule().fill(Theme.surface)
                    }
                }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(sort.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("sort-\(sort.id)")
    }
}

/// Poster card used in the discover grid.
struct MovieCard: View {
    let movie: MovieSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Zoom source wraps only the poster: it clips to a rounded rect,
            // which would otherwise shave the corners of the text below.
            PosterArtwork(url: movie.posterURL, title: movie.title, seed: movie.id)
                .overlay(alignment: .topTrailing) {
                    RatingBadge(rating: movie.voteAverage).padding(Theme.Spacing.xs)
                }
                .zoomSource(id: movie.id)
                .shadow(color: Theme.shadow, radius: 10, y: 6)
            Text(movie.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
            Text(movie.releaseYear ?? "Release date TBA")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}
