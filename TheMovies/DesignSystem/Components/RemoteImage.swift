import NukeUI
import SwiftUI

/// Cached, cancellable remote image with a shimmer while loading, a custom
/// fallback on failure and a soft fade/zoom when the image arrives.
struct RemoteImage<Fallback: View>: View {
    let url: URL?
    @ViewBuilder var fallback: () -> Fallback

    var body: some View {
        LazyImage(url: url, transaction: Transaction(animation: Motion.smooth)) { state in
            if let image = state.image {
                image
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.combined(with: .scale(scale: 1.06)))
            } else if url == nil || state.error != nil {
                fallback()
            } else {
                Rectangle().fill(Theme.surface).shimmer()
            }
        }
        .onDisappear(.lowerPriority)
    }
}

/// 2:3 poster that falls back to generated artwork when no image exists.
struct PosterArtwork: View {
    let url: URL?
    let title: String
    let seed: Int
    var cornerRadius: CGFloat = Theme.Radius.m

    var body: some View {
        Color.clear
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay {
                RemoteImage(url: url) {
                    GeneratedArtwork(title: title, seed: seed, symbol: "film")
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 0.5)
            }
    }
}

/// Deterministic gradient artwork for missing posters, avatars and backdrops.
struct GeneratedArtwork: View {
    let title: String
    let seed: Int
    var symbol: String = "film"
    var showsTitle = true

    private static let hueStep = 37
    private static let hueRange = 360

    private var hue: Double { Double(abs(seed * Self.hueStep) % Self.hueRange) / Double(Self.hueRange) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: hue, saturation: 0.55, brightness: 0.45),
                    Color(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: symbol)
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(.white.opacity(0.12))
                .rotationEffect(.degrees(-12))
                .offset(x: 30, y: -30)
            if showsTitle {
                Text(title)
                    .font(.system(.headline, design: .serif).weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .minimumScaleFactor(0.7)
                    .padding(Theme.Spacing.s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Circular avatar with initials fallback.
struct AvatarView: View {
    let url: URL?
    let name: String
    var size: CGFloat = 44

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    var body: some View {
        RemoteImage(url: url) {
            ZStack {
                GeneratedArtwork(title: "", seed: name.unicodeScalars.reduce(0) { $0 + Int($1.value) }, symbol: "person", showsTitle: false)
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay { Circle().strokeBorder(Theme.stroke, lineWidth: 1) }
        .accessibilityHidden(true)
    }
}
