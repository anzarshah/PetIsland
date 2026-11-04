import AuthenticationServices
import XCTest
@testable import IslandPet

@MainActor
final class MockAuthClient: AuthClient {
    var storedAccount: Account?
    var signInResult: Result<Account, Error> = .failure(AuthFlowError.failed("unset"))
    var signOutError: Error?
    var deleteError: Error?
    /// Simulated latency so overlapping calls can be observed.
    var delayMilliseconds = 0

    private(set) var googleCalls = 0
    private(set) var appleCalls: [(token: String, nonce: String, name: PersonNameComponents?)] = []
    private(set) var signOutCalls = 0
    private(set) var deleteCalls = 0
    private var continuation: AsyncStream<Account?>.Continuation?

    func currentAccount() async -> Account? { storedAccount }

    func accountChanges() -> AsyncStream<Account?> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    /// Simulates the SDK reporting a session change.
    func emit(_ account: Account?) {
        continuation?.yield(account)
    }

    func signInWithGoogle(presenting: UIViewController) async throws -> Account {
        googleCalls += 1
        try await simulateLatency()
        return try signInResult.get()
    }

    func signInWithApple(identityToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> Account {
        appleCalls.append((identityToken, rawNonce, fullName))
        try await simulateLatency()
        return try signInResult.get()
    }

    private func simulateLatency() async throws {
        guard delayMilliseconds > 0 else { return }
        try await Task.sleep(for: .milliseconds(delayMilliseconds))
    }

    func signOut() async throws {
        signOutCalls += 1
        if let signOutError { throw signOutError }
    }

    func deleteAccount() async throws {
        deleteCalls += 1
        if let deleteError { throw deleteError }
    }
}

final class AuthServiceTests: XCTestCase {
    private let account = Account(id: UUID(), email: "mochi@example.com", fullName: "Mochi Tester", provider: "google")

    @MainActor
    private func makeService(stored: Account? = nil) async -> (AuthService, MockAuthClient) {
        let client = MockAuthClient()
        client.storedAccount = stored
        let service = AuthService(client: client)
        service.start()
        await waitUntil { service.state != .unknown }
        return (service, client)
    }

    @MainActor
    private func waitUntil(timeout: TimeInterval = 2, _ condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @MainActor
    func testStartRestoresStoredSession() async {
        let (signedIn, _) = await makeService(stored: account)
        XCTAssertEqual(signedIn.state, .signedIn(account))

        let (signedOut, _) = await makeService(stored: nil)
        XCTAssertEqual(signedOut.state, .signedOut)
    }

    @MainActor
    func testGoogleSignInSuccess() async {
        let (service, client) = await makeService()
        client.signInResult = .success(account)

        await service.signInWithGoogle(presenting: UIViewController())

        XCTAssertEqual(service.state, .signedIn(account))
        XCTAssertNil(service.errorMessage)
        XCTAssertFalse(service.isBusy)
        XCTAssertEqual(client.googleCalls, 1)
    }

    @MainActor
    func testUserCancellationIsSilent() async {
        let (service, client) = await makeService()
        client.signInResult = .failure(NSError(domain: "com.google.GIDSignIn", code: -5))
        await service.signInWithGoogle(presenting: UIViewController())
        XCTAssertEqual(service.state, .signedOut)
        XCTAssertNil(service.errorMessage, "cancelling must not show an error")

        client.signInResult = .failure(ASAuthorizationError(.canceled))
        await service.signInWithApple(identityToken: "token", rawNonce: "nonce", fullName: nil)
        XCTAssertNil(service.errorMessage)
        XCTAssertEqual(service.state, .signedOut)
    }

    @MainActor
    func testNetworkFailureShowsFriendlyMessage() async {
        let (service, client) = await makeService()
        client.signInResult = .failure(URLError(.notConnectedToInternet))
        await service.signInWithGoogle(presenting: UIViewController())
        XCTAssertEqual(service.state, .signedOut)
        XCTAssertEqual(service.errorMessage, AuthFlowError.network.message)
        XCTAssertFalse(service.isBusy)
    }

    @MainActor
    func testAppleUnavailableGetsAnActionableMessage() async {
        let (service, client) = await makeService()
        // ASAuthorizationError.unknown (1000): what the simulator reports with no Apple Account signed in.
        client.signInResult = .failure(ASAuthorizationError(.unknown))
        await service.signInWithApple(identityToken: "token", rawNonce: "nonce", fullName: nil)
        XCTAssertEqual(service.errorMessage, AuthFlowError.appleUnavailable.message)
        XCTAssertEqual(service.state, .signedOut)
        XCTAssertEqual(AuthFlowError.from(ASAuthorizationError(.failed)), .appleUnavailable)
        XCTAssertEqual(AuthFlowError.from(ASAuthorizationError(.canceled)), .cancelled)
    }

    @MainActor
    func testAuthFailureShowsMessageAndStaysSignedOut() async {
        let (service, client) = await makeService()
        client.signInResult = .failure(NSError(domain: "supabase", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid token"]))
        await service.signInWithApple(identityToken: "token", rawNonce: "nonce", fullName: nil)
        XCTAssertEqual(service.state, .signedOut)
        XCTAssertEqual(service.errorMessage, "Sign-in didn't go through. Invalid token.")
    }

    @MainActor
    func testAppleSignInPassesTokenNonceAndName() async {
        let (service, client) = await makeService()
        client.signInResult = .success(Account(id: account.id, email: account.email, fullName: "Mochi Tester", provider: "apple"))
        var name = PersonNameComponents()
        name.givenName = "Mochi"
        name.familyName = "Tester"

        await service.signInWithApple(identityToken: "apple-token", rawNonce: "raw-nonce", fullName: name)

        XCTAssertEqual(client.appleCalls.count, 1)
        XCTAssertEqual(client.appleCalls.first?.token, "apple-token")
        XCTAssertEqual(client.appleCalls.first?.nonce, "raw-nonce")
        XCTAssertEqual(client.appleCalls.first?.name?.givenName, "Mochi")
        XCTAssertEqual(service.state.account?.provider, "apple")
    }

    @MainActor
    func testAppleRequestGetsScopesAndHashedNonce() async {
        let (service, _) = await makeService()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        service.prepareAppleRequest(request)
        XCTAssertEqual(request.requestedScopes, [.fullName, .email])
        XCTAssertEqual(request.nonce?.count, 64, "nonce is a hex SHA-256 digest")
        XCTAssertEqual(AuthService.sha256("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertNotEqual(AuthService.randomNonce(), AuthService.randomNonce())
    }

    @MainActor
    func testSignOut() async {
        let (service, client) = await makeService(stored: account)
        await service.signOut()
        XCTAssertEqual(client.signOutCalls, 1)
        XCTAssertEqual(service.state, .signedOut)
        XCTAssertNil(service.errorMessage)
    }

    @MainActor
    func testDeleteAccountSignsOutOnSuccessAndReportsFailure() async {
        let (service, client) = await makeService(stored: account)
        let deleted = await service.deleteAccount()
        XCTAssertTrue(deleted)
        XCTAssertEqual(client.deleteCalls, 1)
        XCTAssertEqual(service.state, .signedOut)

        let (failing, failingClient) = await makeService(stored: account)
        failingClient.deleteError = URLError(.timedOut)
        let result = await failing.deleteAccount()
        XCTAssertFalse(result)
        XCTAssertEqual(failing.state, .signedIn(account), "a failed deletion keeps the session")
        XCTAssertEqual(failing.errorMessage, AuthFlowError.network.message)
    }

    @MainActor
    func testSessionChangesFromTheSDKUpdateState() async {
        let (service, client) = await makeService()
        client.emit(account)
        await waitUntil { service.state == .signedIn(self.account) }
        XCTAssertEqual(service.state, .signedIn(account))

        client.emit(nil)
        await waitUntil { service.state == .signedOut }
        XCTAssertEqual(service.state, .signedOut)
    }

    @MainActor
    func testConcurrentSignInIsIgnoredWhileBusy() async {
        let (service, client) = await makeService()
        client.signInResult = .success(account)
        client.delayMilliseconds = 50
        async let first: Void = service.signInWithGoogle(presenting: UIViewController())
        async let second: Void = service.signInWithGoogle(presenting: UIViewController())
        _ = await (first, second)
        XCTAssertEqual(client.googleCalls, 1, "buttons are disabled while busy; a second tap is dropped")
    }
}
