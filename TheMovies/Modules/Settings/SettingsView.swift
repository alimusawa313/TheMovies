import SwiftUI

/// Appearance and data-source settings.
struct SettingsView: View {
    let session: AppSession
    let onClose: () -> Void

    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                dataSourceSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                        .accessibilityIdentifier("settings-done")
                }
            }
            .alert("Couldn't sign out", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: appearance)
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(AppearancePreference.allCases) { option in
                    AppearanceOption(option: option, isSelected: appearance == option) {
                        withAnimation(Motion.bouncy) { appearance = option }
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.xxs)
        }
    }

    private var dataSourceSection: some View {
        Section("Data source") {
            switch session.mode {
            case .live(let credential):
                Label("Connected to TMDB", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.ratingColor(1))
                LabeledContent("Key", value: Self.masked(credential.rawValue))
                Button("Change API key", role: .destructive, action: signOut)
            case .demo:
                Label("Demo mode — offline sample data", systemImage: "sparkles.tv")
                Button("Connect a TMDB key", action: signOut)
            case .onboarding:
                EmptyView()
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func signOut() {
        do {
            try session.signOut()
            onClose()
        } catch {
            errorMessage = "Your key could not be removed from the Keychain. Please try again."
        }
    }

    private static func masked(_ value: String) -> String {
        let visibleCount = 4
        return "••••••••" + value.suffix(visibleCount)
    }
}

private struct AppearanceOption: View {
    let option: AppearancePreference
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: option.symbol)
                    .font(.title2)
                    .symbolEffect(.bounce, value: isSelected)
                Text(option.title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.s)
            .foregroundStyle(isSelected ? .white : Theme.textSecondary)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.surface))
            }
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("appearance-\(option.rawValue)")
    }
}
