import SwiftUI

/// Everything below the title once details have loaded.
struct MovieDetailSections: View {
    let viewModel: MovieDetailViewModel
    let presenter: MovieDetailPresenter

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            ratingAndTrailerRow.staggeredAppear(index: 0)
            if !viewModel.genres.isEmpty { genreChips.staggeredAppear(index: 1) }
            overview.staggeredAppear(index: 2)
            if !viewModel.cast.isEmpty { castSection.staggeredAppear(index: 3) }
            if !viewModel.trailers.isEmpty { videosSection.staggeredAppear(index: 4) }
            reviewsSection.staggeredAppear(index: 5)
            if !viewModel.facts.isEmpty { factsSection.staggeredAppear(index: 6) }
            Text("Data provided by TMDB. This product uses the TMDB API but is not endorsed or certified by TMDB.")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: Rating + trailer

    private var ratingAndTrailerRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.m) {
                ratingSummary
                Spacer(minLength: Theme.Spacing.s)
                PlayTrailerButton(isAvailable: !viewModel.trailers.isEmpty) { presenter.playTrailer() }
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                ratingSummary
                PlayTrailerButton(isAvailable: !viewModel.trailers.isEmpty) { presenter.playTrailer() }
            }
        }
    }

    private var ratingSummary: some View {
        HStack(spacing: Theme.Spacing.s) {
            RatingRing(fraction: viewModel.ratingFraction)
            VStack(alignment: .leading, spacing: 2) {
                Text("User score")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .textCase(.uppercase)
                Text("\(viewModel.ratingText) / 10")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(viewModel.voteCountText)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: Genres

    private var genreChips: some View {
        FlowLayout(spacing: Theme.Spacing.xs) {
            ForEach(viewModel.genres) { genre in
                Label(genre.name, systemImage: GenreAppearance.symbol(for: genre.id))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(GenreAppearance.gradient(for: genre.id), in: .capsule)
            }
        }
    }

    // MARK: Overview

    private var overview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Overview")
            if let overview = viewModel.overview {
                ExpandableText(text: overview, lineLimit: 4)
            } else {
                Text("No overview available yet.")
                    .font(.body.italic())
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    // MARK: Cast

    private var castSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Top Cast")
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: Theme.Spacing.m) {
                    ForEach(viewModel.cast) { member in
                        CastCard(member: member).carouselEffect()
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, Theme.Spacing.xxs)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    // MARK: Videos

    private var videosSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Trailers & Clips") {
                Text("\(viewModel.trailers.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            ScrollView(.horizontal) {
                LazyHStack(spacing: Theme.Spacing.m) {
                    ForEach(viewModel.trailers) { video in
                        Button { presenter.playTrailer(video) } label: {
                            VideoThumbnailCard(video: video)
                        }
                        .buttonStyle(.pressable(scale: 0.95))
                        .carouselEffect()
                        .accessibilityIdentifier("video-\(video.id)")
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, Theme.Spacing.xxs)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    // MARK: Reviews

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Reviews") {
                if viewModel.totalReviews > 0 {
                    Button {
                        presenter.showAllReviews()
                    } label: {
                        HStack(spacing: 4) {
                            Text("See all \(viewModel.totalReviews)")
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accentGradient)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("see-all-reviews")
                }
            }
            if viewModel.reviewPreviews.isEmpty {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "text.bubble")
                        .font(.title2)
                        .foregroundStyle(Theme.accentGradient)
                        .symbolEffect(.breathe, options: .repeat(.continuous))
                    Text("No reviews yet. Be the first to share your thoughts on TMDB.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(Theme.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.l, style: .continuous))
                .accessibilityIdentifier("no-reviews")
            } else {
                ForEach(viewModel.reviewPreviews) { review in
                    Button { presenter.showAllReviews() } label: {
                        ReviewCard(review: review, collapsedLineLimit: 4)
                    }
                    .buttonStyle(.pressable(scale: 0.97))
                }
            }
        }
    }

    // MARK: Facts

    private var factsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Details")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Theme.Spacing.s)], spacing: Theme.Spacing.s) {
                ForEach(viewModel.facts, id: \.self) { fact in
                    FactTile(fact: fact)
                }
            }
        }
    }
}

// MARK: - Subviews

/// Prominent glass "Play Trailer" button with a pulsing halo.
struct PlayTrailerButton: View {
    let isAvailable: Bool
    let action: () -> Void

    @State private var taps = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isAvailable {
            Button {
                taps += 1
                action()
            } label: {
                Label("Play Trailer", systemImage: "play.fill")
                    .font(.headline)
                    .symbolEffect(.bounce, value: taps)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, Theme.Spacing.xxs)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.accent)
            .background {
                Capsule()
                    .fill(Theme.accent.opacity(0.45))
                    .blur(radius: 12)
                    .phaseAnimator([false, true], trigger: reduceMotion) { halo, isExpanded in
                        halo
                            .scaleEffect(isExpanded && !reduceMotion ? 1.15 : 0.9)
                            .opacity(isExpanded ? 0.9 : 0.4)
                    } animation: { _ in .easeInOut(duration: 1.4) }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: taps)
            .accessibilityIdentifier("play-trailer-button")
        } else {
            Label("No trailer", systemImage: "play.slash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .capsule)
                .accessibilityIdentifier("no-trailer")
        }
    }
}

private struct CastCard: View {
    let member: CastMember
    private static let width: CGFloat = 86

    var body: some View {
        VStack(spacing: 6) {
            AvatarView(url: member.profileURL, name: member.name, size: 74)
                .shadow(color: Theme.shadow, radius: 8, y: 4)
            Text(member.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
            if let character = member.character?.nilIfBlank {
                Text(character)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(2)
            }
        }
        .multilineTextAlignment(.center)
        .frame(width: Self.width)
        .accessibilityElement(children: .combine)
    }
}

private struct VideoThumbnailCard: View {
    let video: Video
    private static let width: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay {
                    RemoteImage(url: video.thumbnailURL) {
                        GeneratedArtwork(title: "", seed: video.key.hashValue, symbol: "play.rectangle", showsTitle: false)
                    }
                }
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .clipShape(.rect(cornerRadius: Theme.Radius.m, style: .continuous))
            Text(video.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Text(video.type)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(width: Self.width)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Play \(video.name)")
    }
}

private struct FactTile: View {
    let fact: MovieDetailViewModel.Fact

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: fact.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accentGradient)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(fact.label)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                Text(fact.value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.s)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.m, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
