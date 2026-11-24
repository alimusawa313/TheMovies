import Foundation
import Observation
import os

/// Parses launch arguments / environment (used by the scheme, CI and UI tests).
nonisolated struct LaunchConfiguration: Sendable {
    static let uiTestingArgument = "-uiTesting"
    static let demoArgument = "-demo"
    static let scenarioKey = "STUB_SCENARIO"
    static let apiKeyKey = "TMDB_API_KEY"
    /// `STUB_SCENARIO=onboarding` starts UI tests on the API key screen.
    static let onboardingScenario = "onboarding"

    let stubScenario: StubMovieRepository.Scenario?
    let environmentCredential: APICredential?
    let resetsStoredCredential: Bool
    let stubLatency: Duration

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let isUITesting = arguments.contains(Self.uiTestingArgument)
        let isDemo = arguments.contains(Self.demoArgument)
        let rawScenario = environment[Self.scenarioKey]
        let scenario = rawScenario.flatMap(StubMovieRepository.Scenario.init(rawValue:))
        let wantsOnboarding = rawScenario == Self.onboardingScenario

        stubScenario = (isUITesting || isDemo) && !wantsOnboarding ? (scenario ?? .standard) : nil
        // UI tests must never hit the live API, even if a key is in the environment.
        environmentCredential = isUITesting
            ? nil
            : environment[Self.apiKeyKey].flatMap(APICredential.init(rawValue:))
        resetsStoredCredential = isUITesting
        stubLatency = isUITesting ? .milliseconds(250) : .milliseconds(650)
    }
}

/// Owns the authentication mode of the app (onboarding, live API, demo).
@Observable
final class AppSession {
    enum Mode: Hashable {
        case onboarding
        case live(APICredential)
        case demo(StubMovieRepository.Scenario)
    }

    private(set) var mode: Mode
    private let store: any CredentialStoring
    private let stubLatency: Duration
    private let logger = Logger(subsystem: "com.alihaidar.TheMovies", category: "Session")

    init(store: any CredentialStoring, launch: LaunchConfiguration = LaunchConfiguration()) {
        self.store = store
        self.stubLatency = launch.stubLatency
        if launch.resetsStoredCredential {
            try? store.delete()
        }
        if let scenario = launch.stubScenario {
            mode = .demo(scenario)
        } else if let credential = launch.environmentCredential ?? store.load() {
            mode = .live(credential)
        } else {
            mode = .onboarding
        }
    }

    var isDemo: Bool {
        if case .demo = mode { return true }
        return false
    }

    func signIn(with credential: APICredential) throws(CredentialStoreError) {
        try store.save(credential)
        mode = .live(credential)
    }

    func startDemo() {
        mode = .demo(.standard)
    }

    /// Clears the stored key and returns to onboarding.
    func signOut() throws(CredentialStoreError) {
        do {
            try store.delete()
        } catch {
            logger.error("Failed to delete credential: \(String(describing: error), privacy: .public)")
            throw error
        }
        mode = .onboarding
    }

    /// Builds a repository for the current mode, or `nil` while onboarding.
    func makeRepository() -> (any MovieRepository)? {
        switch mode {
        case .onboarding:
            nil
        case .live(let credential):
            Self.liveRepository(for: credential)
        case .demo(let scenario):
            StubMovieRepository(scenario: scenario, latency: stubLatency)
        }
    }

    nonisolated static func liveRepository(for credential: APICredential) -> any MovieRepository {
        TMDBMovieRepository(client: TMDBAPIClient(credential: credential))
    }
}
