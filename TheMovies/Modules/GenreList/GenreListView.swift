import SwiftUI

struct GenreListView: View {
    @State private var presenter: GenreListPresenter
    @State private var searchPresenter: MovieSearchPresenter
    @State private var settingsTaps = 0
    @State private var selectedGenre: Genre?

    private let columns = [GridItem(.adaptive(minimum: 158, maximum: 280), spacing: Theme.Spacing.m)]
    private static let cardHeight: CGFloat = 136
    private static let skeletonCount = 10

    init(presenter: GenreListPresenter, searchPresenter: MovieSearchPresenter) {
        _presenter = State(initialValue: presenter)
        _searchPresenter = State(initialValue: searchPresenter)
    }

    private var isSearching: Bool {
        !presenter.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            AmbientBackground()
            content
        }
        .navigationTitle("Genres")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    settingsTaps += 1
                    presenter.didTapSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .symbolEffect(.rotate.byLayer, value: settingsTaps)
                }
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("settings-button")
            }
        }
        .searchable(text: $presenter.searchText, prompt: "Search movies or genres")
        .sensoryFeedback(.selection, trigger: selectedGenre)
        .task { await presenter.onAppear() }
        // Restarted (and the previous search cancelled) on every keystroke.
        .task(id: presenter.searchText) { await searchPresenter.updateQuery(presenter.searchText) }
        .animation(Motion.smooth, value: isSearching)
        .errorToast($presenter.refreshError)
    }

    @ViewBuilder
    private var content: some View {
        if isSearching {
            searchContent
        } else {
            genreContent
        }
    }

    @ViewBuilder
    private var genreContent: some View {
        switch presenter.state {
        case .idle, .loading:
            skeleton
        case .failed(let error):
            ErrorStateView(error: error) { Task { await presenter.retry() } }
        case .empty:
            EmptyStateView(
                symbol: "film.stack",
                title: "No genres yet",
                message: "TMDB didn't return any genres. Pull to try again later.",
                actionTitle: "Reload"
            ) { Task { await presenter.retry() } }
        case .loaded:
            loadedContent
        }
    }

    private var loadedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                header
                grid
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await presenter.refresh() }
        .animation(Motion.bouncy, value: presenter.filteredGenres)
        .transition(.opacity)
    }

    private var searchContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                if !presenter.filteredGenres.isEmpty {
                    matchingGenres
                }
                MovieSearchResultsView(presenter: searchPresenter)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .scrollDismissesKeyboard(.immediately)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// Genres whose name matches the query, as tappable chips.
    private var matchingGenres: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Genres")
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(presenter.filteredGenres) { genre in
                        Button {
                            selectedGenre = genre
                            presenter.didSelect(genre)
                        } label: {
                            Label(genre.name, systemImage: GenreAppearance.symbol(for: genre.id))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(GenreAppearance.gradient(for: genre.id), in: .capsule)
                        }
                        .buttonStyle(.pressable)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
        .transition(.opacity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text("What are you in the mood for?")
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.accentGradient)
            Text("\(presenter.filteredGenres.count) genres to explore")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .contentTransition(.numericText(value: Double(presenter.filteredGenres.count)))
        }
        .padding(.top, Theme.Spacing.xs)
        .staggeredAppear(index: 0)
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.m) {
            ForEach(Array(presenter.filteredGenres.enumerated()), id: \.element.id) { index, genre in
                Button {
                    selectedGenre = genre
                    presenter.didSelect(genre)
                } label: {
                    GenreCard(genre: genre)
                        .frame(height: Self.cardHeight)
                }
                .buttonStyle(.pressable(scale: 0.94, tilt: 8))
                .staggeredAppear(index: index + 1)
                .scrollDepthEffect()
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .accessibilityIdentifier("genre-card-\(genre.id)")
            }
        }
        .accessibilityIdentifier("genre-grid")
    }

    private var skeleton: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    SkeletonBlock().frame(width: 260, height: 26)
                    SkeletonBlock().frame(width: 140, height: 14)
                }
                LazyVGrid(columns: columns, spacing: Theme.Spacing.m) {
                    ForEach(0..<Self.skeletonCount, id: \.self) { _ in
                        SkeletonBlock(cornerRadius: Theme.Radius.l).frame(height: Self.cardHeight)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
        }
        .scrollDisabled(true)
        .accessibilityLabel("Loading genres")
        .accessibilityIdentifier("genre-skeleton")
        .transition(.opacity)
    }
}

/// Colourful genre tile with a large rotated glyph.
struct GenreCard: View {
    let genre: Genre
    @State private var bounce = 0

    private var colors: [Color] { GenreAppearance.colors(for: genre.id) }
    private var symbol: String { GenreAppearance.symbol(for: genre.id) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GenreAppearance.gradient(for: genre.id)

            Image(systemName: symbol)
                .font(.system(size: 76, weight: .bold))
                .foregroundStyle(.white.opacity(0.2))
                .rotationEffect(.degrees(-14))
                .offset(x: 18, y: -6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .symbolEffect(.bounce.up, value: bounce)
                Text(genre.name)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 4) {
                    Text("Explore")
                    Image(systemName: "arrow.right")
                }
                .font(.caption.weight(.semibold))
                .opacity(0.85)
            }
            .foregroundStyle(.white)
            .padding(14)
        }
        .clipShape(.rect(cornerRadius: Theme.Radius.l, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: colors[0].opacity(0.35), radius: 14, y: 8)
        .onAppear { bounce += 1 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(genre.name)
        .accessibilityHint("Shows movies in this genre")
        .accessibilityAddTraits(.isButton)
    }
}
