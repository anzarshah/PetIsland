import Foundation
import GoogleSignIn
import Supabase
import UIKit

/// The auth operations the app needs, abstracted so `AuthService` can be tested with a mock.
@MainActor
protocol AuthClient {
    /// The account whose session is stored on this device, if any.
    func currentAccount() async -> Account?
    /// Emits whenever the session changes (sign-in, sign-out, refresh, deletion).
    func accountChanges() -> AsyncStream<Account?>
    func signInWithGoogle(presenting: UIViewController) async throws -> Account
    func signInWithApple(identityToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> Account
    func signOut() async throws
    /// Deletes the account on the server, then clears the local session.
    func deleteAccount() async throws
}

extension SupabaseClient {
    /// The one client the app talks to. Sessions are persisted and refreshed by the SDK (Keychain).
    /// The stored session is reported immediately at launch; the SDK refreshes it in the
    /// background rather than making the UI wait on the network.
    static let shared = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabasePublishableKey,
        options: SupabaseClientOptions(auth: SupabaseClientOptions.AuthOptions(emitLocalSessionAsInitialSession: true))
    )
}

/// Production implementation: Google Sign-In and Sign in with Apple exchange their ID tokens
/// with Supabase Auth (`signInWithIdToken`); no custom backend, no custom token storage.
@MainActor
final class SupabaseAuthClient: AuthClient {
    private let client: SupabaseClient

    init(client: SupabaseClient = .shared) {
        self.client = client
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: AppConfig.googleClientID, serverClientID: AppConfig.googleServerClientID)
    }

    func currentAccount() async -> Account? {
        // The locally stored session, without waiting for a refresh.
        Self.account(from: client.auth.currentSession)
    }

    func accountChanges() -> AsyncStream<Account?> {
        let auth = client.auth
        return AsyncStream { continuation in
            let task = Task {
                for await (_, session) in auth.authStateChanges {
                    continuation.yield(Self.account(from: session))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func signInWithGoogle(presenting: UIViewController) async throws -> Account {
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthFlowError.failed("Google didn't return an identity token.")
        }
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .google, idToken: idToken, accessToken: result.user.accessToken.tokenString)
        )
        return Self.account(from: session.user)
    }

    func signInWithApple(identityToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> Account {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: identityToken, nonce: rawNonce)
        )
        var user = session.user
        // Apple sends the name only on the very first authorization; keep it before it is gone.
        if let name = fullName.flatMap(Self.formatted), user.userMetadata["full_name"]?.stringValue == nil {
            if let updated = try? await client.auth.update(user: UserAttributes(data: ["full_name": .string(name)])) {
                user = updated
            }
        }
        return Self.account(from: user)
    }

    func signOut() async throws {
        GIDSignIn.sharedInstance.signOut()
        try await client.auth.signOut()
    }

    func deleteAccount() async throws {
        try await client.functions.invoke("delete-account")
        GIDSignIn.sharedInstance.signOut()
        // The server-side user is gone; only the local session needs clearing.
        try? await client.auth.signOut(scope: .local)
    }

    // MARK: Helpers

    /// A session only counts while its access token is valid. With
    /// `emitLocalSessionAsInitialSession` the SDK reports the stored session at launch even when
    /// it has expired, so an expired one is treated as signed out here. The SDK then refreshes it
    /// in the background and `accountChanges()` delivers the outcome: `tokenRefreshed` (signed
    /// in again) or `signedOut` (refresh token revoked, user deleted).
    static func account(from session: Session?) -> Account? {
        guard let session, !session.isExpired else { return nil }
        return account(from: session.user)
    }

    static func account(from user: User) -> Account {
        Account(
            id: user.id,
            email: user.email,
            fullName: user.userMetadata["full_name"]?.stringValue ?? user.userMetadata["name"]?.stringValue,
            provider: user.appMetadata["provider"]?.stringValue
        )
    }

    private static func formatted(_ name: PersonNameComponents) -> String? {
        let text = PersonNameComponentsFormatter.localizedString(from: name, style: .default).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }
}
