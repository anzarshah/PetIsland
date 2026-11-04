import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import UIKit

/// Owns auth state for the app. Sessions themselves live in the Supabase SDK (Keychain); this
/// object only observes them and runs the sign-in flows with friendly error handling.
@MainActor
@Observable
final class AuthService {
    static let shared = AuthService(client: SupabaseAuthClient())

    private(set) var state: AuthState = .unknown
    private(set) var isBusy = false
    /// Something to show the person. Nil after cancellations and successes.
    var errorMessage: String?

    private let client: AuthClient
    private var listener: Task<Void, Never>?
    private var pendingAppleNonce: String?

    init(client: AuthClient) {
        self.client = client
    }

    /// Restores the stored session and keeps `state` in sync with the SDK from then on.
    func start() {
        guard listener == nil else { return }
        listener = Task { [weak self, client] in
            let current = await client.currentAccount()
            self?.apply(current)
            for await account in client.accountChanges() {
                self?.apply(account)
            }
        }
    }

    // MARK: Google

    func signInWithGoogle(presenting: UIViewController) async {
        await run { [client] in
            try await client.signInWithGoogle(presenting: presenting)
        }
    }

    // MARK: Apple

    /// Configure the `SignInWithAppleButton` request: scopes plus a hashed nonce. The raw nonce
    /// is kept to hand to Supabase, which verifies the token was minted for this request.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        pendingAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func completeApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            fail(with: error)
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8),
                  let nonce = pendingAppleNonce else {
                fail(with: AuthFlowError.failed("Apple didn't return an identity token."))
                return
            }
            pendingAppleNonce = nil
            await signInWithApple(identityToken: identityToken, rawNonce: nonce, fullName: credential.fullName)
        }
    }

    func signInWithApple(identityToken: String, rawNonce: String, fullName: PersonNameComponents?) async {
        await run { [client] in
            try await client.signInWithApple(identityToken: identityToken, rawNonce: rawNonce, fullName: fullName)
        }
    }

    // MARK: Sign out and delete

    func signOut() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await client.signOut()
            state = .signedOut
            errorMessage = nil
        } catch {
            fail(with: error)
        }
    }

    /// Deletes the account on the server and signs out. Returns true when it worked.
    @discardableResult
    func deleteAccount() async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        do {
            try await client.deleteAccount()
            state = .signedOut
            errorMessage = nil
            return true
        } catch {
            fail(with: error)
            return false
        }
    }

    // MARK: Internals

    private func run(_ signIn: () async throws -> Account) async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let account = try await signIn()
            state = .signedIn(account)
        } catch {
            fail(with: error)
        }
    }

    private func fail(with error: Error) {
        let flow = AuthFlowError.from(error)
        errorMessage = flow.message
    }

    private func apply(_ account: Account?) {
        state = account.map(AuthState.signedIn) ?? .signedOut
    }

    static func randomNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "Unable to generate a nonce")
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
