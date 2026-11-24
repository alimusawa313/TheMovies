import SwiftUI

/// Landscape browsing: a modern take on Cover Flow. The focused poster sits
/// flat in the centre under a pulsing spotlight, neighbours tilt back in 3D
/// and stack behind it with soft reflections. Posters are dealt in like cards,
/// a glare sweeps across each newly focused poster and a glass capsule bounces
/// to show what's in focus.
struct MoviePosterFlowView: View {
    let presenter: MovieListPresenter
    @State private var focusedID: MovieSummary.ID?
    @State private var containerSize: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let minimumContainerHeight: CGFloat = 160
    private static let posterHeightRatio: CGFloat = 0.5
    private static let maxPosterHeight: CGFloat = 300
    private static let reflectionRatio: CGFloat = 0.22
    /// Negative spacing so neighbours overlap like a stack.
    private static let overlap: CGFloat = 0.5

    private var focusedMovie: MovieSummary? {
        presenter.movies.first { $0.id == focusedID } ?? presenter.movies.first
    }

    private var focusedIndex: Int {
        presenter.movies.firstIndex { $0.id == focusedMovie?.id } ?? 0
    }

    var body: some View {
        ZStack {
            // Only lay the flow out once we have a real size; laying it out at a
            // transient size (mid-rotation, first frame) leaves it off-centre.
            if containerSize.height >= Self.minimumContainerHeight {
                layout(for: containerSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { containerSize = $0 }
        .background { focusedBackdrop }
        .sensoryFeedback(.selection, trigger: focusedID)
        .onChange(of: focusedID) { _, newValue in
            guard let movie = presenter.movies.first(where: { $0.id == newValue }) else { return }
            Task { await presenter.loadMoreIfNeeded(after: movie) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("poster-flow")
    }

    // MARK: Layout

    private func layout(for size: CGSize) -> some View {
        let posterHeight = min(size.height * Self.posterHeightRatio, Self.maxPosterHeight)
        let posterWidth = (posterHeight * 2 / 3).rounded()
        return VStack(spacing: Theme.Spacing.s) {
            ScrollViewReader { reader in
                flow(posterWidth: posterWidth, viewportWidth: size.width)
                    .onAppear { recenter(using: reader) }
                    // Content margins depend on the size; re-centre whenever it changes.
                    .onChange(of: posterWidth) { recenter(using: reader) }
                    .onChange(of: size.width) { recenter(using: reader) }
            }
            .frame(height: posterHeight * (1 + Self.reflectionRatio) + Theme.Spacing.xs)
            .background { Spotlight(size: posterHeight * 1.4) }
            infoCapsule
        }
        .padding(.bottom, Theme.Spacing.s)
    }

    /// Snaps the focused poster back to the centre after a layout change.
    private func recenter(using reader: ScrollViewProxy) {
        guard let id = focusedMovie?.id else { return }
        Task { @MainActor in
            // Let the new content margins apply before scrolling.
            await Task.yield()
            reader.scrollTo(id, anchor: .center)
        }
    }

    // MARK: Flow

    private func flow(posterWidth: CGFloat, viewportWidth: CGFloat) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: -posterWidth * Self.overlap) {
                ForEach(Array(presenter.movies.enumerated()), id: \.element.id) { index, movie in
                    Button {
                        select(movie)
                    } label: {
                        FlowPoster(
                            movie: movie,
                            width: posterWidth,
                            reflectionRatio: Self.reflectionRatio,
                            isFocused: movie.id == focusedMovie?.id,
                            dealIndex: index
                        )
                    }
                    .buttonStyle(.pressable(scale: 0.97))
                    .coverFlowEffect(posterWidth: posterWidth, isEnabled: !reduceMotion)
                    .zIndex(-Double(abs(index - focusedIndex)))
                    .accessibilityLabel(movie.title)
                    .accessibilityHint(movie.id == focusedMovie?.id ? "Opens details" : "Brings this poster into focus")
                    .accessibilityIdentifier("flow-poster-\(movie.id)")
                }
                footer(width: posterWidth)
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $focusedID, anchor: .center)
        .contentMargins(.horizontal, max((viewportWidth - posterWidth) / 2, 0), for: .scrollContent)
        .scrollClipDisabled()
    }

    private func select(_ movie: MovieSummary) {
        if movie.id == focusedMovie?.id {
            presenter.didSelect(movie)
        } else {
            withAnimation(Motion.smooth) { focusedID = movie.id }
        }
    }

    @ViewBuilder
    private func footer(width: CGFloat) -> some View {
        let status = LoadMoreFooter.Status(paginator: presenter.paginator, endMessage: "")
        Group {
            switch status {
            case .loading:
                BouncingDots()
            case .failed(let error):
                Button {
                    Task { await presenter.retryNextPage() }
                } label: {
                    VStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: error.symbol).font(.title2)
                        Text("Retry").font(.subheadline.weight(.semibold))
                    }
                    .padding(Theme.Spacing.m)
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("flow-retry")
            case .hidden, .end:
                EmptyView()
            }
        }
        .frame(width: width)
        .padding(.leading, width * (Self.overlap + 0.2))
    }

    // MARK: Info + backdrop

    @ViewBuilder
    private var infoCapsule: some View {
        if let movie = focusedMovie {
            let bounces = !reduceMotion
            HStack(spacing: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(movie.releaseYear ?? "TBA")
                        RatingBadge(rating: movie.voteAverage)
                        Text("\(focusedIndex + 1) of \(presenter.paginator.totalResults.formatted())")
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(focusedIndex)))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                }
                .id(movie.id)
                .transition(.blurReplace)

                Button {
                    presenter.didSelect(movie)
                } label: {
                    Label("Details", systemImage: "info.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .symbolEffect(.bounce, value: movie.id)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
                .accessibilityIdentifier("flow-details")
            }
            .padding(.leading, Theme.Spacing.l)
            .padding(.trailing, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xs)
            .clipShape(.capsule)
            .glassEffect(.regular, in: .capsule)
            .keyframeAnimator(initialValue: 1.0, trigger: movie.id) { content, scale in
                content.scaleEffect(bounces ? scale : 1)
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(1.07, duration: 0.14, spring: .snappy)
                    SpringKeyframe(0.98, duration: 0.16, spring: .bouncy)
                    SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
                }
            }
            .animation(Motion.bouncy, value: movie.id)
        }
    }

    private var focusedBackdrop: some View {
        ZStack {
            if let movie = focusedMovie {
                RemoteImage(url: movie.posterURL) {
                    GeneratedArtwork(title: "", seed: movie.id, symbol: "film", showsTitle: false)
                }
                .blur(radius: 60)
                .opacity(0.5)
                .id(movie.id)
                .transition(.opacity)
            }
        }
        .animation(Motion.smooth, value: focusedMovie?.id)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Soft accent glow behind the centre poster that slowly breathes.
private struct Spotlight: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let pulses = !reduceMotion
        return Circle()
            .fill(RadialGradient(
                colors: [Theme.accent.opacity(0.45), Theme.accentWarm.opacity(0.15), .clear],
                center: .center,
                startRadius: 0,
                endRadius: size / 2
            ))
            .frame(width: size, height: size)
            .blur(radius: 30)
            .phaseAnimator([false, true], trigger: reduceMotion) { glow, isBright in
                glow
                    .scaleEffect(isBright && pulses ? 1.12 : 0.92)
                    .opacity(isBright ? 1 : 0.65)
            } animation: { _ in .easeInOut(duration: 2.4) }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Poster with a fading mirror reflection, a deal-in entrance, an idle float
/// while focused and a glare sweep whenever it becomes focused.
private struct FlowPoster: View {
    let movie: MovieSummary
    let width: CGFloat
    let reflectionRatio: CGFloat
    let isFocused: Bool
    let dealIndex: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDealt = false
    @State private var glarePhase: CGFloat = -1.2

    private static let cornerRadius: CGFloat = 10
    private static let dealtCardCount = 8
    private static let dealStagger = 0.07
    private static let floatDistance: CGFloat = -7

    var body: some View {
        let height = width * 1.5
        VStack(spacing: 4) {
            artwork
                .frame(width: width, height: height)
                .overlay { glare }
                .zoomSource(id: movie.id)
                .shadow(color: .black.opacity(isFocused ? 0.5 : 0.3), radius: isFocused ? 22 : 12, y: isFocused ? 14 : 8)
            artwork
                .frame(width: width, height: height)
                .scaleEffect(x: 1, y: -1)
                .frame(height: height * reflectionRatio, alignment: .top)
                .clipped()
                .mask {
                    LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        // Idle float only while focused.
        .phaseAnimator(isFocused && !reduceMotion ? [false, true] : [false]) { poster, isUp in
            poster.offset(y: isUp ? Self.floatDistance : 0)
        } animation: { _ in .easeInOut(duration: 1.8) }
        // Deal-in entrance for the first screenful.
        .offset(x: isDealt ? 0 : width * 3, y: isDealt ? 0 : -width * 0.3)
        .rotationEffect(.degrees(isDealt ? 0 : 18))
        .opacity(isDealt ? 1 : 0)
        .onAppear(perform: deal)
        .onChange(of: isFocused) { _, focused in
            if focused { sweepGlare() }
        }
    }

    private var artwork: some View {
        PosterArtwork(url: movie.posterURL, title: movie.title, seed: movie.id, cornerRadius: Self.cornerRadius)
    }

    /// Diagonal highlight band swept across the poster.
    private var glare: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [.clear, .white.opacity(0.45), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: proxy.size.width * 0.7)
            .offset(x: glarePhase * proxy.size.width)
            .blendMode(.plusLighter)
        }
        .clipShape(.rect(cornerRadius: Self.cornerRadius, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func deal() {
        guard !isDealt else { return }
        guard !reduceMotion, dealIndex < Self.dealtCardCount else {
            isDealt = true
            return
        }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.72).delay(Double(dealIndex) * Self.dealStagger)) {
            isDealt = true
        }
        if isFocused { sweepGlare() }
    }

    private func sweepGlare() {
        guard !reduceMotion else { return }
        glarePhase = -1.2
        withAnimation(.easeOut(duration: 0.9).delay(0.15)) { glarePhase = 1.6 }
    }
}

extension View {
    /// Tilts, pushes apart and dims items by their distance from the centre of
    /// the horizontal scroll view.
    func coverFlowEffect(posterWidth: CGFloat, isEnabled: Bool) -> some View {
        visualEffect { content, proxy in
            let frame = proxy.frame(in: .scrollView(axis: .horizontal))
            let viewport = proxy.bounds(of: .scrollView(axis: .horizontal))?.width ?? frame.width
            // Distance from centre in poster widths (items are 0.5 apart).
            let distance = (frame.midX - viewport / 2) / max(posterWidth, 1)
            let progress = min(max(distance * 2, -1), 1)
            let tilt: Double = isEnabled ? 62 : 0
            // Give the focused poster breathing room, then stack the rest tightly.
            let magnitude = abs(distance)
            let target = magnitude <= 0.5
                ? magnitude * 1.9
                : 0.95 + (magnitude - 0.5) * 0.64
            let shift = isEnabled ? (target - magnitude) * (distance < 0 ? -1 : 1) * posterWidth : 0
            return content
                .offset(x: shift)
                .rotation3DEffect(.degrees(-progress * tilt), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                // Focused poster pops forward; neighbours recede.
                .scaleEffect(isEnabled ? 1.12 - abs(progress) * 0.24 : 1)
                .brightness(-abs(progress) * 0.15)
        }
    }
}
