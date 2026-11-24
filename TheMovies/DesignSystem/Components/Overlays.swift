import SwiftUI

// MARK: - Toast

/// Transient top banner for non-blocking errors (e.g. a failed refresh while
/// content is already on screen). Auto-dismisses and can be swiped away.
private struct ErrorToastModifier: ViewModifier {
    @Binding var error: APIError?
    private static let displayDuration: Duration = .seconds(3.5)
    private static let dismissDragThreshold: CGFloat = -20

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let error {
                    toast(for: error)
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.top, Theme.Spacing.xs)
                        .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                        .task(id: error) {
                            try? await Task.sleep(for: Self.displayDuration)
                            guard !Task.isCancelled else { return }
                            withAnimation(Motion.bouncy) { self.error = nil }
                        }
                        .gesture(
                            DragGesture().onEnded { value in
                                if value.translation.height < Self.dismissDragThreshold {
                                    withAnimation(Motion.bouncy) { self.error = nil }
                                }
                            }
                        )
                }
            }
            .animation(Motion.bouncy, value: error)
            .sensoryFeedback(.warning, trigger: error) { _, new in new != nil }
    }

    private func toast(for error: APIError) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: error.symbol)
                .foregroundStyle(Theme.accent)
                .symbolEffect(.bounce, value: error)
            VStack(alignment: .leading, spacing: 1) {
                Text(error.title).font(.subheadline.weight(.semibold))
                Text(error.message).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.m))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("error-toast")
    }
}

extension View {
    func errorToast(_ error: Binding<APIError?>) -> some View {
        modifier(ErrorToastModifier(error: error))
    }
}

// MARK: - Scroll to top

/// Floating glass button that springs in once the user has scrolled down.
struct ScrollToTopButton: View {
    let isVisible: Bool
    let action: () -> Void
    @State private var taps = 0

    var body: some View {
        if isVisible {
            Button {
                taps += 1
                action()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline.weight(.bold))
                    .frame(width: 48, height: 48)
                    .symbolEffect(.bounce.up, value: taps)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .sensoryFeedback(.impact(weight: .light), trigger: taps)
            .transition(.scale(scale: 0.3).combined(with: .opacity).combined(with: .offset(y: 40)))
            .accessibilityLabel("Scroll to top")
            .accessibilityIdentifier("scroll-to-top")
        }
    }
}

// MARK: - Ambient background

/// Slowly drifting mesh gradient behind main screens.
struct AmbientBackground: View {
    var tint: Color = Theme.accent
    var secondaryTint: Color = Theme.accentWarm

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShifted = false

    private var points: [SIMD2<Float>] {
        let drift: Float = isShifted ? 0.18 : 0
        return [
            [0, 0], [0.5 + drift, 0], [1, 0],
            [0, 0.45 - drift / 2], [0.55 - drift, 0.35 + drift / 2], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1],
        ]
    }

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: points,
            colors: [
                tint.opacity(0.55), Theme.background, secondaryTint.opacity(0.45),
                Theme.background, tint.opacity(0.18), Theme.background,
                Theme.background, Theme.background, Theme.background,
            ]
        )
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                isShifted = true
            }
        }
        .accessibilityHidden(true)
    }
}
