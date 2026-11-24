import SwiftUI

/// Wrapping horizontal layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = Theme.Spacing.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, maxWidth: proposal.width ?? .infinity)
        let height = rows.last.map { $0.maxY } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, maxWidth: bounds.width)
        for row in rows {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private struct Row {
        var items: [(index: Int, x: CGFloat, size: CGSize)] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
        var maxY: CGFloat { y + height }
    }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let current = rows[rows.count - 1]
            let proposedX = current.items.isEmpty ? 0 : current.width + spacing
            if proposedX + size.width > maxWidth, !current.items.isEmpty {
                rows.append(Row(y: current.maxY + spacing))
            }
            let last = rows.count - 1
            let x = rows[last].items.isEmpty ? 0 : rows[last].width + spacing
            rows[last].items.append((index, x, size))
            rows[last].width = x + size.width
            rows[last].height = max(rows[last].height, size.height)
        }
        return rows
    }
}

/// Text that collapses to a few lines with an animated "Read more" toggle.
struct ExpandableText: View {
    let text: String
    var lineLimit = 4
    var font: Font = .body

    @State private var isExpanded = false
    @State private var fullHeight: CGFloat = 0
    @State private var truncatedHeight: CGFloat = 0

    private var isTruncatable: Bool { fullHeight > truncatedHeight + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(text)
                .font(font)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(isExpanded ? nil : lineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .background(alignment: .topLeading) { measurement }
                .contentTransition(.interpolate)

            if isTruncatable {
                Button {
                    withAnimation(Motion.bouncy) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show less" : "Read more")
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accentGradient)
                }
                .buttonStyle(.pressable)
                .sensoryFeedback(.selection, trigger: isExpanded)
            }
        }
    }

    /// Invisible copies used to detect whether the text is actually truncated.
    private var measurement: some View {
        ZStack {
            Text(text).font(font)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fullHeight = $0 }
            Text(text).font(font)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { truncatedHeight = $0 }
        }
        .hidden()
        .accessibilityHidden(true)
    }
}

/// Small rounded label used for metadata ("2h 10m", "2024").
struct MetaPill: View {
    let text: String
    var symbol: String?

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.caption2.weight(.bold)) }
            Text(text).font(.caption.weight(.semibold))
        }
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }
}

/// Section title with optional trailing accessory.
struct SectionHeader<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            accessory()
        }
    }
}

extension SectionHeader where Accessory == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}
