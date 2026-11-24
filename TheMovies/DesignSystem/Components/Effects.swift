import SwiftUI

// MARK: - Pressable button style

/// Bouncy press feedback with an optional 3D tilt.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    var tilt: Double = 0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .rotation3DEffect(
                .degrees(configuration.isPressed ? tilt : 0),
                axis: (x: 1, y: -1, z: 0),
                perspective: 0.6
            )
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(configuration.isPressed ? .snappy(duration: 0.14) : Motion.bouncy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }

    static func pressable(scale: CGFloat = 0.95, tilt: Double = 0) -> PressableButtonStyle {
        PressableButtonStyle(scale: scale, tilt: tilt)
    }
}

// MARK: - Shimmer

/// Sweeping highlight used by skeleton placeholders. Falls back to a gentle
/// pulse when Reduce Motion is enabled.
private struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [.clear, Theme.shimmerHighlight, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width)
                    .offset(x: phase * proxy.size.width)
                }
                .mask(content)
                .opacity(reduceMotion ? 0 : 1)
                .allowsHitTesting(false)
            }
            .opacity(reduceMotion && phase > 0 ? 0.6 : 1)
            .onAppear {
                withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: reduceMotion)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

/// Rounded placeholder block for skeleton screens.
struct SkeletonBlock: View {
    var cornerRadius: CGFloat = Theme.Radius.s

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Theme.surface)
            .shimmer()
            .accessibilityHidden(true)
    }
}

// MARK: - Staggered entrance

private struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 28)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.94)
            .blur(radius: isVisible || reduceMotion ? 0 : 6)
            .onAppear {
                guard !isVisible else { return }
                withAnimation(Motion.bouncy.delay(Motion.staggerDelay(for: index))) {
                    isVisible = true
                }
            }
    }
}

extension View {
    /// Springs the view in with a small per-index delay.
    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppearModifier(index: index))
    }

    /// Subtle depth effect as compact cards scroll in and out of the viewport.
    /// Only for views shorter than the screen: tall views never become fully
    /// visible, so they would stay scaled down. No blur, to keep text crisp.
    func scrollDepthEffect() -> some View {
        scrollTransition(.interactive.threshold(.visible(0.4)), axis: .vertical) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.94)
                .opacity(phase.isIdentity ? 1 : 0.6)
        }
    }

    /// Carousel effect for horizontal lists.
    func carouselEffect() -> some View {
        scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.86)
                .opacity(phase.isIdentity ? 1 : 0.6)
                .rotation3DEffect(.degrees(phase.value * -12), axis: (x: 0, y: 1, z: 0))
        }
    }
}
