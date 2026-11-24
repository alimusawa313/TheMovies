import SwiftUI

struct ReviewsView: View {
    @State private var presenter: ReviewsPresenter
    @State private var showsScrollToTop = false
    @State private var scrollPosition = ScrollPosition(edge: .top)

    private static let scrollToTopThreshold: CGFloat = 900
    private static let skeletonCount = 4
    private static let readableWidth: CGFloat = 720

    init(presenter: ReviewsPresenter) {
        _presenter = State(initialValue: presenter)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AmbientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    header
                    content
                }
                .frame(maxWidth: Self.readableWidth)
                .frame(maxWidth: .infinity)
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
            .accessibilityIdentifier("reviews-list")

            ScrollToTopButton(isVisible: showsScrollToTop) {
                withAnimation(Motion.smooth) { scrollPosition.scrollTo(edge: .top) }
            }
            .padding(Theme.Spacing.l)
        }
        .navigationTitle("Reviews")
        .navigationBarTitleDisplayMode(.inline)
        .task { await presenter.onAppear() }
        .errorToast($presenter.refreshError)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(presenter.movieTitle)
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
            HStack(spacing: Theme.Spacing.s) {
                Label {
                    Text("\(presenter.paginator.totalResults) reviews")
                        .contentTransition(.numericText(value: Double(presenter.paginator.totalResults)))
                } icon: {
                    Image(systemName: "text.bubble.fill")
                }
                if let average = presenter.averageRating {
                    Label("\(Formatters.rating(average)) avg", systemImage: "star.fill")
                        .foregroundStyle(Theme.ratingColor(average / 10))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .animation(Motion.bouncy, value: presenter.paginator.totalResults)
        }
        .padding(.top, Theme.Spacing.xs)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch presenter.paginator.phase {
            case .idle:
                skeleton
            case .loadingFirstPage where presenter.reviews.isEmpty:
                skeleton
            case .failedFirstPage(let error):
                ErrorStateView(error: error) { Task { await presenter.retry() } }
                    .padding(.top, Theme.Spacing.xl)
            case _ where presenter.paginator.isEmpty:
                EmptyStateView(
                    symbol: "text.bubble",
                    title: "No reviews yet",
                    message: "Nobody has reviewed \(presenter.movieTitle) on TMDB yet. Check back soon."
                )
                .padding(.top, Theme.Spacing.xl)
            default:
                list
            }
        }
        .animation(Motion.smooth, value: presenter.paginator.phase)
    }

    private var list: some View {
        LazyVStack(spacing: Theme.Spacing.m) {
            ForEach(Array(presenter.reviews.enumerated()), id: \.element.id) { index, review in
                ReviewCard(review: review, isExpanded: presenter.isExpanded(review)) {
                    withAnimation(Motion.bouncy) { presenter.toggleExpansion(of: review) }
                }
                .staggeredAppear(index: index)
                .onAppear {
                    Task { await presenter.loadMoreIfNeeded(after: review) }
                }
                .accessibilityIdentifier("review-card-\(index)")
            }
            LoadMoreFooter(
                status: LoadMoreFooter.Status(paginator: presenter.paginator, endMessage: "You've read every review")
            ) {
                Task { await presenter.retryNextPage() }
            }
        }
        .transition(.opacity)
    }

    private var skeleton: some View {
        VStack(spacing: Theme.Spacing.m) {
            ForEach(0..<Self.skeletonCount, id: \.self) { _ in
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    HStack(spacing: Theme.Spacing.s) {
                        SkeletonBlock(cornerRadius: 22).frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonBlock().frame(width: 140, height: 14)
                            SkeletonBlock().frame(width: 90, height: 10)
                        }
                    }
                    SkeletonBlock().frame(height: 12)
                    SkeletonBlock().frame(height: 12)
                    SkeletonBlock().frame(width: 200, height: 12)
                }
                .padding(Theme.Spacing.m)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.l, style: .continuous))
            }
        }
        .accessibilityLabel("Loading reviews")
        .accessibilityIdentifier("review-skeleton")
        .transition(.opacity)
    }
}

/// A single review. Tapping toggles the expanded state for long reviews.
struct ReviewCard: View {
    let review: ReviewViewModel
    var isExpanded = false
    var collapsedLineLimit = 6
    var onToggle: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            authorRow
            Text(review.content)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(isExpanded ? nil : collapsedLineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
            if review.isCollapsible, onToggle != nil {
                HStack(spacing: 4) {
                    Text(isExpanded ? "Show less" : "Read more")
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accentGradient)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.l, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: Theme.Radius.l))
        .onTapGesture {
            guard review.isCollapsible else { return }
            onToggle?()
        }
        .sensoryFeedback(.selection, trigger: isExpanded)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: isExpanded ? "Show less" : "Read more") { onToggle?() }
    }

    private var authorRow: some View {
        HStack(spacing: Theme.Spacing.s) {
            AvatarView(url: review.avatarURL, name: review.author)
            VStack(alignment: .leading, spacing: 2) {
                Text(review.author)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text([review.handle, review.dateText].compactMap(\.self).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: Theme.Spacing.xs)
            if let rating = review.rating, let text = review.ratingText {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.caption2)
                    Text(text).font(.caption.weight(.bold)).monospacedDigit()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Theme.ratingColor(rating / 10), in: .capsule)
            }
        }
    }
}
