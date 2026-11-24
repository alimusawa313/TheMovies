import SwiftUI
import YouTubePlayerKit

struct TrailerView: View {
    @State private var presenter: TrailerPresenter
    @Environment(\.openURL) private var openURL
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private static let landscapeListWidth: CGFloat = 300

    init(presenter: TrailerPresenter) {
        _presenter = State(initialValue: presenter)
    }

    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                // Landscape: player on the left, playlist on the right.
                HStack(alignment: .top, spacing: Theme.Spacing.l) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        header
                        player
                        infoRow
                    }
                    if presenter.videos.count > 1 {
                        moreVideos.frame(width: Self.landscapeListWidth)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    header
                    player
                    infoRow
                    if presenter.videos.count > 1 { moreVideos }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(Theme.Spacing.m)
        .animation(Motion.bouncy, value: presenter.selectedVideo)
        .sensoryFeedback(.selection, trigger: presenter.selectedVideo)
        .background { AmbientBackground() }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trailer-sheet")
    }

    private var player: some View {
        TrailerPlayer(video: presenter.selectedVideo) { url in openURL(url) }
            .id(presenter.selectedVideo.key)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(.rect(cornerRadius: Theme.Radius.l, style: .continuous))
            .shadow(color: Theme.shadow, radius: 20, y: 10)
            .transition(.blurReplace)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(presenter.movieTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .textCase(.uppercase)
                Text(presenter.selectedVideo.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .contentTransition(.opacity)
            }
            Spacer()
            Button(action: presenter.close) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Close")
            .accessibilityIdentifier("close-trailer")
        }
        .padding(.top, Theme.Spacing.xs)
    }

    private var infoRow: some View {
        HStack(spacing: Theme.Spacing.xs) {
            MetaPill(text: presenter.selectedVideo.type, symbol: "film")
            if let published = presenter.publishedText {
                MetaPill(text: published, symbol: "calendar")
            }
            Spacer()
            if let url = presenter.selectedVideo.youtubeURL {
                Button { openURL(url) } label: {
                    Label("YouTube", systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var moreVideos: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "More videos")
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.s) {
                    ForEach(presenter.videos) { video in
                        Button { presenter.select(video) } label: {
                            VideoRow(video: video, isSelected: presenter.isSelected(video))
                        }
                        .buttonStyle(.pressable(scale: 0.97))
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// Wraps the YouTube player with loading and error overlays.
private struct TrailerPlayer: View {
    let video: Video
    let openExternally: (URL) -> Void
    @StateObject private var player: YouTubePlayer

    init(video: Video, openExternally: @escaping (URL) -> Void) {
        self.video = video
        self.openExternally = openExternally
        _player = StateObject(wrappedValue: YouTubePlayer(
            source: .video(id: video.key),
            parameters: .init(autoPlay: true, showFullscreenButton: true)
        ))
    }

    var body: some View {
        YouTubePlayerView(player) { state in
            switch state {
            case .idle:
                loadingOverlay
            case .ready:
                EmptyView()
            case .error(let error):
                errorOverlay(message: Self.message(for: error))
            }
        }
        .background(Color.black)
    }

    private var loadingOverlay: some View {
        ZStack {
            RemoteImage(url: video.thumbnailURL) { Color.black }
            Color.black.opacity(0.45)
            VStack(spacing: Theme.Spacing.s) {
                BouncingDots()
                Text("Loading trailer…")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("trailer-loading")
    }

    private func errorOverlay(message: String) -> some View {
        ZStack {
            Color.black
            VStack(spacing: Theme.Spacing.s) {
                Image(systemName: "play.slash.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.accentGradient)
                    .symbolEffect(.bounce, options: .nonRepeating)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                if let url = video.youtubeURL {
                    Button("Watch on YouTube") { openExternally(url) }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.accent)
                }
            }
            .padding()
        }
        .accessibilityIdentifier("trailer-error")
    }

    static func message(for error: YouTubePlayer.Error) -> String {
        switch error {
        case .embeddedVideoPlayingNotAllowed:
            "The owner of this video doesn't allow playback inside other apps."
        case .notFound:
            "This video is no longer available."
        case .html5NotSupported, .iFrameApiFailedToLoad, .setupFailed:
            "The player couldn't start. Check your connection and try again."
        default:
            "Something went wrong while playing this video."
        }
    }
}

private struct VideoRow: View {
    let video: Video
    let isSelected: Bool
    private static let thumbnailWidth: CGFloat = 112

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(width: Self.thumbnailWidth)
                .overlay {
                    RemoteImage(url: video.thumbnailURL) {
                        GeneratedArtwork(title: "", seed: video.key.hashValue, symbol: "play.rectangle", showsTitle: false)
                    }
                }
                .overlay {
                    if isSelected {
                        Image(systemName: "waveform")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .symbolEffect(.variableColor.iterative, options: .repeat(.continuous))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.black.opacity(0.45))
                    }
                }
                .clipShape(.rect(cornerRadius: Theme.Radius.s, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(video.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Text(isSelected ? "Now playing" : video.type)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.xs)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                .fill(isSelected ? Theme.accent.opacity(0.14) : Theme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                .strokeBorder(isSelected ? Theme.accent.opacity(0.5) : .clear, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
