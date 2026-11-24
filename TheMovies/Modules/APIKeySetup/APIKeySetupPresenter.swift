import Observation
import SwiftUI

@Observable
final class APIKeySetupPresenter {
    enum Phase: Equatable {
        case idle
        case validating
        case failed(String)
        case succeeded
    }

    var input = "" {
        didSet {
            if case .failed = phase { phase = .idle }
        }
    }
    var isSecureEntry = true
    private(set) var phase: Phase = .idle
    /// Incremented on each failure; drives the shake animation and haptic.
    private(set) var failureCount = 0

    private let interactor: any APIKeySetupInteracting
    private let router: any APIKeySetupRouting
    private let successDelay: Duration

    init(
        interactor: any APIKeySetupInteracting,
        router: any APIKeySetupRouting,
        successDelay: Duration = .milliseconds(750)
    ) {
        self.interactor = interactor
        self.router = router
        self.successDelay = successDelay
    }

    var canSubmit: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && phase != .validating
            && phase != .succeeded
    }

    var errorMessage: String? {
        if case .failed(let message) = phase { return message }
        return nil
    }

    // MARK: Intents

    func connect() async {
        guard canSubmit else { return }
        phase = .validating
        do {
            let credential = try await interactor.validate(input)
            phase = .succeeded
            // Let the success animation play before switching screens.
            try? await Task.sleep(for: successDelay)
            try router.complete(with: credential)
        } catch let error as APIError {
            handle(error)
        } catch {
            fail(with: "We couldn't save your key securely. Please try again.")
        }
    }

    func toggleSecureEntry() {
        isSecureEntry.toggle()
    }

    func paste(_ value: String) {
        input = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func startDemo() {
        router.startDemo()
    }

    // MARK: Private

    private func handle(_ error: APIError) {
        switch error {
        case .cancelled:
            phase = .idle
        case .unauthorized:
            fail(with: "TMDB rejected this key. Double-check it and try again.")
        default:
            fail(with: error.message)
        }
    }

    private func fail(with message: String) {
        phase = .failed(message)
        failureCount += 1
    }
}
