import SwiftUI

struct MovieDetailView: View {
    @State private var presenter: MovieDetailPresenter
    @State private var showsNavigationTitle = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private static let regularHeaderHeight: CGFloat = 360
    private static let compactHeaderHeight: CGFloat = 240
    private static let posterWidth: CGFloat = 118
    private static let titleRevealOffset: CGFloat = 300
    private static let readableWidth: CGFloat = 760

    init(presenter: MovieDetailPresenter) {
        _presenter = State(initialValue: presenter)
    }

    /// Landscape iPhones get a shorter hero so content stays in view.
    private var headerHeight: CGFloat {
        verticalSizeClass == .compact ? Self.compactHeaderHeight : Self.regularHeaderHeight
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StretchyBackdrop(url: presenter.backdropURL, seed: presenter.summary.id, height: headerHeight)
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    titleBlock
                    detailContent
                }
                .frame(maxWidth: Self.readableWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.top, -headerHeight * 0.38)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.background)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > Self.titleRevealOffset
        } action: { _, isPastHeader in
            withAnimation(Motion.snappy) { showsNavigationTitle = isPastHeader }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(presenter.title)
                    .font(.headline)
                    .lineLimit(1)
                    .opacity(showsNavigationTitle ? 1 : 0)
                    .offset(y: showsNavigationTitle ? 0 : 10)
            }
            if let shareURL = presenter.shareURL {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareURL, subject: Text(presenter.title)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("share-button")
                }
            }
        }
        .zoomDestination(id: presenter.summary.id)
        .task { await presenter.onAppear() }
        .accessibilityIdentifier("movie-detail")
    }

    // MARK: Title block (renders immediately from the list summary)

    private var titleBlock: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.m) {
            PosterArtwork(url: presenter.posterURL, title: presenter.title, seed: presenter.summary.id)
                .frame(width: Self.posterWidth)
                .shadow(color: Theme.shadow, radius: 18, y: 10)
                .staggeredAppear(index: 0)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(presenter.title)
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("detail-title")
                if let tagline = presenter.state.value?.tagline {
                    Text(tagline)
                        .font(.subheadline.italic())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                metadataRow
            }
            .staggeredAppear(index: 1)
        }
        .animation(Motion.bouncy, value: presenter.state.value)
    }

    @ViewBuilder
    private var metadataRow: some View {
        if let metadata = presenter.state.value?.metadata, !metadata.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(metadata.enumerated()), id: \.offset) { index, item in
                    MetaPill(text: item)
                        .staggeredAppear(index: index)
                }
            }
        } else if presenter.state.isLoading {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in SkeletonBlock(cornerRadius: 14).frame(width: 54, height: 26) }
            }
        } else if let year = presenter.summary.releaseYear {
            MetaPill(text: year)
        }
    }

    // MARK: Body content

    @ViewBuilder
    private var detailContent: some View {
        Group {
            switch presenter.state {
            case .idle, .loading:
                DetailSkeleton()
            case .failed(let error):
                ErrorStateView(error: error) { Task { await presenter.retry() } }
            case .empty:
                EmptyStateView(symbol: "film", title: "No details", message: "TMDB has no details for this movie yet.")
            case .loaded(let viewModel):
                MovieDetailSections(viewModel: viewModel, presenter: presenter)
                    .transition(.opacity.combined(with: .offset(y: 20)))
            }
        }
        .animation(Motion.smooth, value: presenter.state.isLoading)
    }
}

/// Backdrop that stretches on overscroll and parallaxes on scroll.
struct StretchyBackdrop: View {
    let url: URL?
    let seed: Int
    let height: CGFloat

    private static let parallaxFactor: CGFloat = 0.4

    var body: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .scrollView).minY
            let isPulling = minY > 0
            RemoteImage(url: url) {
                GeneratedArtwork(title: "", seed: seed, symbol: "film", showsTitle: false)
            }
            .frame(width: proxy.size.width, height: height + (isPulling ? minY : 0))
            .clipped()
            .overlay { Theme.scrim }
            .offset(y: isPulling ? -minY : -minY * Self.parallaxFactor)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Placeholder shown below the title while details load.
private struct DetailSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack(spacing: Theme.Spacing.m) {
                SkeletonBlock(cornerRadius: 32).frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonBlock().frame(width: 90, height: 16)
                    SkeletonBlock().frame(width: 70, height: 12)
                }
                Spacer()
                SkeletonBlock(cornerRadius: 22).frame(width: 150, height: 44)
            }
            HStack {
                ForEach(0..<3, id: \.self) { _ in SkeletonBlock(cornerRadius: 14).frame(width: 80, height: 28) }
            }
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock().frame(width: 120, height: 20)
                ForEach(0..<4, id: \.self) { _ in SkeletonBlock().frame(height: 12) }
            }
        }
        .accessibilityLabel("Loading movie details")
        .accessibilityIdentifier("detail-skeleton")
        .transition(.opacity)
    }
}
