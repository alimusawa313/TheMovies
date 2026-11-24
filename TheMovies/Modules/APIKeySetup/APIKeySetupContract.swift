import SwiftUI

// MARK: - VIPER contract

protocol APIKeySetupInteracting {
    /// Parses and verifies the key against TMDB, returning a usable credential.
    func validate(_ rawKey: String) async throws(APIError) -> APICredential
}

protocol APIKeySetupRouting {
    func complete(with credential: APICredential) throws(CredentialStoreError)
    func startDemo()
}

// MARK: - Interactor

struct APIKeySetupInteractor: APIKeySetupInteracting {
    let makeRepository: (APICredential) -> any MovieRepository

    func validate(_ rawKey: String) async throws(APIError) -> APICredential {
        guard let credential = APICredential(rawValue: rawKey) else { throw .invalidCredential }
        try await makeRepository(credential).validateCredential()
        return credential
    }
}

// MARK: - Router

struct APIKeySetupRouter: APIKeySetupRouting {
    let session: AppSession

    func complete(with credential: APICredential) throws(CredentialStoreError) {
        try session.signIn(with: credential)
    }

    func startDemo() {
        session.startDemo()
    }
}

// MARK: - Builder

enum APIKeySetupModule {
    static func build(session: AppSession) -> APIKeySetupView {
        let presenter = APIKeySetupPresenter(
            interactor: APIKeySetupInteractor(makeRepository: AppSession.liveRepository(for:)),
            router: APIKeySetupRouter(session: session)
        )
        return APIKeySetupView(presenter: presenter)
    }
}
