import SwiftUI

/// Animated circular score that fills and counts up on appear.
struct RatingRing: View {
    let fraction: Double
    var size: CGFloat = 64
    var lineWidth: CGFloat = 6

    @State private var progress: Double = 0
    private static let maxScore = 10.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [Theme.ratingColor(fraction).opacity(0.6), Theme.ratingColor(fraction)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.ratingColor(fraction).opacity(0.6), radius: 6)
            CountingText(value: progress * Self.maxScore)
                .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(width: size, height: size)
        .onAppear { animate(to: fraction) }
        .onChange(of: fraction) { _, newValue in animate(to: newValue) }
        .accessibilityElement()
        .accessibilityLabel("Rating \(Formatters.rating(fraction * Self.maxScore)) out of 10")
    }

    private func animate(to value: Double) {
        withAnimation(.spring(response: 1.2, dampingFraction: 0.82).delay(0.15)) {
            progress = min(max(value, 0), 1)
        }
    }
}

/// Text that interpolates its numeric value frame-by-frame.
struct CountingText: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(Formatters.rating(value))
            .monospacedDigit()
    }
}

/// Compact rating pill shown on posters.
struct RatingBadge: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.ratingColor(rating / 10))
            Text(rating > 0 ? Formatters.rating(rating) : "NR")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .capsule)
        .accessibilityLabel(rating > 0 ? "Rated \(Formatters.rating(rating))" : "Not rated")
    }
}
