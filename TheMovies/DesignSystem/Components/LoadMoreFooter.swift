import SwiftUI

/// Footer shown under endlessly scrolling lists.
struct LoadMoreFooter: View {
    enum Status: Equatable {
        case hidden
        case loading
        case failed(APIError)
        case end(String)
    }

    let status: Status
    let retry: () -> Void

    var body: some View {
        Group {
            switch status {
            case .hidden:
                Color.clear.frame(height: 1)
            case .loading:
                BouncingDots()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.l)
                    .accessibilityLabel("Loading more")
                    .accessibilityIdentifier("load-more-indicator")
            case .failed(let error):
                InlineErrorCard(error: error, retry: retry)
                    .padding(.vertical, Theme.Spacing.s)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("load-more-error")
            case .end(let message):
                Label(message, systemImage: "sparkles")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.l)
                    .accessibilityIdentifier("end-of-list")
            }
        }
        .animation(Motion.bouncy, value: status)
    }
}

extension LoadMoreFooter.Status {
    init<Item>(paginator: Paginator<Item>, endMessage: String) {
        switch paginator.phase {
        case .loadingNextPage:
            self = .loading
        case .failedNextPage(let error):
            self = .failed(error)
        case .loaded where paginator.hasReachedEnd:
            self = .end(endMessage)
        case .loaded where paginator.hasMore && !paginator.items.isEmpty:
            // Keep a spinner visible so the user sees more content is coming.
            self = .loading
        default:
            self = .hidden
        }
    }
}

/// Three dots that hop in sequence.
struct BouncingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let dotCount = 3

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(Theme.accentGradient)
                    .frame(width: 9, height: 9)
                    .phaseAnimator([false, true], trigger: reduceMotion) { dot, isUp in
                        dot
                            .offset(y: isUp && !reduceMotion ? -8 : 0)
                            .scaleEffect(isUp ? 1.15 : 0.85)
                            .opacity(isUp ? 1 : 0.5)
                    } animation: { isUp in
                        isUp ? .spring(response: 0.3, dampingFraction: 0.5).delay(Double(index) * 0.12)
                            : .easeIn(duration: 0.25)
                    }
            }
        }
    }
}
