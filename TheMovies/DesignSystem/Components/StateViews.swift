import SwiftUI

/// Full-screen error with an animated symbol, haptic and retry action.
struct ErrorStateView: View {
    let error: APIError
    var retry: (() -> Void)?
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    @State private var bounce = 0
    @State private var didAppear = false

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: error.symbol)
                .font(.system(size: 54, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accentGradient)
                .symbolEffect(.bounce.up.byLayer, value: bounce)
                .padding(.bottom, Theme.Spacing.xs)

            Text(error.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)

            Text(error.message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            actions.padding(.top, Theme.Spacing.xs)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .transition(.blurReplace.combined(with: .scale(0.94)))
        .sensoryFeedback(.error, trigger: didAppear) { _, new in new }
        .onAppear {
            didAppear = true
            bounce += 1
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("error-state")
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: Theme.Spacing.s) {
            if error.isRetryable, let retry {
                Button {
                    bounce += 1
                    retry()
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .padding(.horizontal, Theme.Spacing.s)
                        .padding(.vertical, Theme.Spacing.xxs)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
                .accessibilityIdentifier("retry-button")
            }
            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(.glass)
            }
        }
    }
}

/// Friendly empty state with a breathing symbol.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 52, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accentGradient)
                .symbolEffect(.breathe.pulse.byLayer, options: .repeat(.continuous))
                .padding(.bottom, Theme.Spacing.xs)

            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.glass)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .transition(.blurReplace.combined(with: .scale(0.94)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("empty-state")
    }
}

/// Compact horizontal error card used inline (sections, list footers).
struct InlineErrorCard: View {
    let error: APIError
    var retry: (() -> Void)?

    @State private var shake = 0

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: error.symbol)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .symbolEffect(.wiggle, value: shake)
            VStack(alignment: .leading, spacing: 2) {
                Text(error.title).font(.subheadline.weight(.semibold))
                Text(error.message)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: Theme.Spacing.xs)
            if error.isRetryable, let retry {
                Button {
                    shake += 1
                    retry()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.bold))
                        .padding(Theme.Spacing.xs)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Retry")
                .accessibilityIdentifier("inline-retry-button")
            }
        }
        .padding(Theme.Spacing.s)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.m, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1)
        }
        .onAppear { shake += 1 }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
