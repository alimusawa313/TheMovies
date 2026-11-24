import Testing
@testable import TheMovies

final class MockAPIKeySetupInteractor: APIKeySetupInteracting {
    var result: Result<APICredential, APIError>
    private(set) var received: [String] = []

    init(_ result: Result<APICredential, APIError>) { self.result = result }

    func validate(_ rawKey: String) async throws(APIError) -> APICredential {
        received.append(rawKey)
        return try result.get()
    }
}

final class SpyAPIKeySetupRouter: APIKeySetupRouting {
    var saveFailure: CredentialStoreError?
    private(set) var completed: [APICredential] = []
    private(set) var demoStarted = 0

    func complete(with credential: APICredential) throws(CredentialStoreError) {
        if let saveFailure { throw saveFailure }
        completed.append(credential)
    }

    func startDemo() { demoStarted += 1 }
}

@Suite("API key setup presenter")
struct APIKeySetupPresenterTests {
    private func makeSUT(
        _ result: Result<APICredential, APIError>,
        router: SpyAPIKeySetupRouter = SpyAPIKeySetupRouter()
    ) -> (APIKeySetupPresenter, MockAPIKeySetupInteractor, SpyAPIKeySetupRouter) {
        let interactor = MockAPIKeySetupInteractor(result)
        return (APIKeySetupPresenter(interactor: interactor, router: router, successDelay: .zero), interactor, router)
    }

    @Test("A valid key signs the user in")
    func success() async {
        let credential = APICredential.apiKey(Fixtures.validAPIKey)
        let (presenter, _, router) = makeSUT(.success(credential))
        presenter.input = Fixtures.validAPIKey
        await presenter.connect()
        #expect(presenter.phase == .succeeded)
        #expect(router.completed == [credential])
    }

    @Test("Blank input cannot be submitted")
    func blankInput() async {
        let (presenter, interactor, _) = makeSUT(.success(.apiKey(Fixtures.validAPIKey)))
        presenter.input = "   "
        #expect(!presenter.canSubmit)
        await presenter.connect()
        #expect(interactor.received.isEmpty)
    }

    @Test("A rejected key shows a friendly message and shakes")
    func rejected() async {
        let (presenter, _, router) = makeSUT(.failure(.unauthorized))
        presenter.input = Fixtures.validAPIKey
        await presenter.connect()
        #expect(presenter.errorMessage?.contains("rejected") == true)
        #expect(presenter.failureCount == 1)
        #expect(router.completed.isEmpty)
    }

    @Test("Editing the key clears a previous error")
    func editingClearsError() async {
        let (presenter, _, _) = makeSUT(.failure(.offline))
        presenter.input = Fixtures.validAPIKey
        await presenter.connect()
        #expect(presenter.errorMessage != nil)
        presenter.input += "x"
        #expect(presenter.phase == .idle)
    }

    @Test("A Keychain failure is reported instead of silently continuing")
    func keychainFailure() async {
        let router = SpyAPIKeySetupRouter()
        router.saveFailure = .unexpectedStatus(-1)
        let (presenter, _, _) = makeSUT(.success(.apiKey(Fixtures.validAPIKey)), router: router)
        presenter.input = Fixtures.validAPIKey
        await presenter.connect()
        #expect(presenter.errorMessage?.contains("save") == true)
    }

    @Test("Demo mode routes through the router")
    func demo() {
        let (presenter, _, router) = makeSUT(.failure(.offline))
        presenter.startDemo()
        #expect(router.demoStarted == 1)
    }

    @Test("Interactor rejects malformed keys without calling the network")
    func interactorRejectsMalformed() async {
        let interactor = APIKeySetupInteractor { _ in
            Issue.record("Network should not be called for malformed keys")
            return FakeMovieRepository()
        }
        await #expect(throws: APIError.invalidCredential) {
            try await interactor.validate("abc")
        }
    }

    @Test("Interactor surfaces TMDB rejection")
    func interactorPropagatesRejection() async {
        let interactor = APIKeySetupInteractor { _ in FakeMovieRepository(validationResult: .failure(.unauthorized)) }
        await #expect(throws: APIError.unauthorized) {
            try await interactor.validate(Fixtures.validAPIKey)
        }
    }
}

@Suite("App session")
struct AppSessionTests {
    private let noLaunchOverrides = LaunchConfiguration(arguments: [], environment: [:])

    @Test("Starts in onboarding without a stored key")
    func onboarding() {
        let session = AppSession(store: InMemoryCredentialStore(), launch: noLaunchOverrides)
        #expect(session.mode == .onboarding)
        #expect(session.makeRepository() == nil)
    }

    @Test("Restores a stored key")
    func restores() {
        let credential = APICredential.apiKey(Fixtures.validAPIKey)
        let session = AppSession(store: InMemoryCredentialStore(credential: credential), launch: noLaunchOverrides)
        #expect(session.mode == .live(credential))
    }

    @Test("Sign in persists, sign out clears")
    func signInAndOut() throws {
        let store = InMemoryCredentialStore()
        let session = AppSession(store: store, launch: noLaunchOverrides)
        let credential = APICredential.apiKey(Fixtures.validAPIKey)
        try session.signIn(with: credential)
        #expect(store.current == credential)
        try session.signOut()
        #expect(store.current == nil)
        #expect(session.mode == .onboarding)
    }

    @Test("A Keychain failure on sign out keeps the session")
    func signOutFailure() {
        let credential = APICredential.apiKey(Fixtures.validAPIKey)
        let store = InMemoryCredentialStore(credential: credential, failure: .unexpectedStatus(-25300))
        let session = AppSession(store: store, launch: noLaunchOverrides)
        #expect(throws: CredentialStoreError.unexpectedStatus(-25300)) { try session.signOut() }
        #expect(session.mode == .live(credential))
    }

    @Test("UI-testing launch uses stub data and never a live key")
    func uiTestingLaunch() {
        let launch = LaunchConfiguration(
            arguments: [LaunchConfiguration.uiTestingArgument],
            environment: [LaunchConfiguration.scenarioKey: "failure", LaunchConfiguration.apiKeyKey: Fixtures.validAPIKey]
        )
        let session = AppSession(store: InMemoryCredentialStore(credential: .apiKey(Fixtures.validAPIKey)), launch: launch)
        #expect(session.mode == .demo(.failure))
        #expect(launch.environmentCredential == nil)
    }

    @Test("The onboarding UI-test scenario starts on the key screen")
    func onboardingScenario() {
        let launch = LaunchConfiguration(
            arguments: [LaunchConfiguration.uiTestingArgument],
            environment: [LaunchConfiguration.scenarioKey: LaunchConfiguration.onboardingScenario]
        )
        #expect(AppSession(store: InMemoryCredentialStore(), launch: launch).mode == .onboarding)
    }
}

@Suite("Stub repository")
struct StubMovieRepositoryTests {
    @Test("Flaky pagination fails page 2 once, then succeeds")
    func flaky() async throws {
        let repository = StubMovieRepository(scenario: .flakyPagination, latency: .zero)
        await #expect(throws: APIError.timedOut) {
            try await repository.discoverMovies(genreID: 28, page: 2, sort: .popular)
        }
        let page = try await repository.discoverMovies(genreID: 28, page: 2, sort: .popular)
        #expect(page.items.count == StubMovieRepository.moviesPerPage)
    }

    @Test("Failure scenario fails every call as offline")
    func failure() async {
        let repository = StubMovieRepository(scenario: .failure, latency: .zero)
        await #expect(throws: APIError.offline) { try await repository.genres() }
    }
}
