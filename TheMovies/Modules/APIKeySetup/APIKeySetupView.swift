import SwiftUI

struct APIKeySetupView: View {
    @State private var presenter: APIKeySetupPresenter
    @FocusState private var isFieldFocused: Bool

    private static let apiSettingsURL = URL(string: "https://www.themoviedb.org/settings/api")
    private static let maxWidth: CGFloat = 460

    init(presenter: APIKeySetupPresenter) {
        _presenter = State(initialValue: presenter)
    }

    var body: some View {
        ZStack {
            AmbientBackground()
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    PosterFanHero()
                        .padding(.top, Theme.Spacing.xl)
                    titleBlock
                    keyCard
                    demoButton
                }
                .frame(maxWidth: Self.maxWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sensoryFeedback(.error, trigger: presenter.failureCount)
        .sensoryFeedback(.success, trigger: presenter.phase) { _, new in new == .succeeded }
    }

    private var titleBlock: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("The Movies")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(Theme.accentGradient)
                .staggeredAppear(index: 1)
            Text("Discover films by genre, read reviews and watch trailers.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .staggeredAppear(index: 2)
        }
    }

    // MARK: Key entry

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("TMDB API key", systemImage: "key.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            keyField
                .keyframeAnimator(initialValue: 0.0, trigger: presenter.failureCount) { content, offset in
                    content.offset(x: offset)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(-14, duration: 0.07)
                        CubicKeyframe(12, duration: 0.07)
                        CubicKeyframe(-8, duration: 0.07)
                        CubicKeyframe(5, duration: 0.07)
                        SpringKeyframe(0, duration: 0.25)
                    }
                }

            if let message = presenter.errorMessage {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityIdentifier("api-key-error")
            }

            connectButton

            if let url = Self.apiSettingsURL {
                Link(destination: url) {
                    Label("Get a free API key from TMDB", systemImage: "arrow.up.right.square")
                        .font(.footnote.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.xxs)
            }
        }
        .padding(Theme.Spacing.l)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.l))
        .animation(Motion.bouncy, value: presenter.phase)
        .staggeredAppear(index: 3)
    }

    private var keyField: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Group {
                if presenter.isSecureEntry {
                    SecureField("Paste your key or token", text: $presenter.input)
                } else {
                    TextField("Paste your key or token", text: $presenter.input)
                }
            }
            .font(.body.monospaced())
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.password)
            .submitLabel(.go)
            .focused($isFieldFocused)
            .onSubmit { Task { await presenter.connect() } }
            .accessibilityIdentifier("api-key-field")

            Button {
                withAnimation(Motion.snappy) { presenter.toggleSecureEntry() }
            } label: {
                Image(systemName: presenter.isSecureEntry ? "eye" : "eye.slash")
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(Theme.textSecondary)
            }
            .accessibilityLabel(presenter.isSecureEntry ? "Show key" : "Hide key")

            PasteButton(payloadType: String.self) { strings in
                presenter.paste(strings.first ?? "")
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.capsule)
            .tint(Theme.accent)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.m, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                .strokeBorder(fieldBorderColor, lineWidth: isFieldFocused || presenter.errorMessage != nil ? 1.5 : 1)
        }
    }

    private var fieldBorderColor: Color {
        switch presenter.phase {
        case .failed: Theme.accent
        case .succeeded: Theme.ratingColor(1)
        default: isFieldFocused ? Theme.accent.opacity(0.6) : Theme.stroke
        }
    }

    private var connectButton: some View {
        Button {
            isFieldFocused = false
            Task { await presenter.connect() }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                switch presenter.phase {
                case .validating:
                    ProgressView().tint(.white)
                    Text("Verifying…")
                case .succeeded:
                    Image(systemName: "checkmark.circle.fill")
                        .symbolEffect(.bounce, options: .nonRepeating)
                        .transition(.scale.combined(with: .opacity))
                    Text("Connected!")
                case .idle, .failed:
                    Text("Connect")
                    Image(systemName: "arrow.right")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xxs)
            .contentTransition(.interpolate)
        }
        .buttonStyle(.glassProminent)
        .tint(presenter.phase == .succeeded ? Theme.ratingColor(1) : Theme.accent)
        .disabled(!presenter.canSubmit && presenter.phase != .succeeded)
        .accessibilityIdentifier("connect-button")
    }

    private var demoButton: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack {
                Rectangle().fill(Theme.stroke).frame(height: 1)
                Text("or").font(.footnote).foregroundStyle(Theme.textTertiary)
                Rectangle().fill(Theme.stroke).frame(height: 1)
            }
            Button(action: presenter.startDemo) {
                Label("Explore with demo data", systemImage: "sparkles.tv")
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, Theme.Spacing.xxs)
            }
            .buttonStyle(.glass)
            .accessibilityIdentifier("demo-button")
        }
        .staggeredAppear(index: 4)
    }
}

/// Three generated posters that fan out and gently float.
private struct PosterFanHero: View {
    @State private var isFanned = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let titles = ["Midnight Echo", "Neon Harbor", "Golden Atlas"]
    private let seeds = [3, 11, 7]
    private static let posterWidth: CGFloat = 96

    var body: some View {
        ZStack {
            ForEach(titles.indices, id: \.self) { index in
                let offset = Double(index - 1)
                PosterArtwork(url: nil, title: titles[index], seed: seeds[index], cornerRadius: 14)
                    .frame(width: Self.posterWidth)
                    .shadow(color: Theme.shadow, radius: 14, y: 8)
                    .rotationEffect(.degrees(isFanned ? offset * 12 : 0), anchor: .bottom)
                    .offset(x: isFanned ? offset * 64 : 0, y: isFanned ? abs(offset) * 14 : 0)
                    .zIndex(index == 1 ? 1 : 0)
                    .phaseAnimator([false, true], trigger: reduceMotion) { poster, isUp in
                        poster.offset(y: isUp && !reduceMotion ? -6 : 0)
                    } animation: { _ in
                        .easeInOut(duration: 2.2).delay(Double(index) * 0.3)
                    }
            }
        }
        .frame(height: 170)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.15)) { isFanned = true }
        }
        .accessibilityHidden(true)
    }
}
