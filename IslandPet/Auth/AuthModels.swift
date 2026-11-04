import Foundation

/// The signed-in person, as much as we show in the app.
struct Account: Equatable, Sendable {
    var id: UUID
    var email: String?
    var fullName: String?
    /// "google" or "apple".
    var provider: String?

    var displayName: String {
        if let fullName, !fullName.isEmpty { return fullName }
        if let email, !email.isEmpty { return email }
        return "Signed in"
    }

    var initial: String {
        String(displayName.prefix(1)).uppercased()
    }
}

/// Auth state the whole app can observe. `RootView` can later gate on this if cloud backup arrives.
enum AuthState: Equatable, Sendable {
    /// Still restoring the session from the Keychain.
    case unknown
    case signedOut
    case signedIn(Account)

    var account: Account? {
        if case .signedIn(let account) = self { return account }
        return nil
    }
}

/// Errors as the person sees them. Cancelling is not an error worth mentioning.
enum AuthFlowError: Error, Equatable {
    case cancelled
    case network
    /// Sign in with Apple couldn't start: typically no Apple Account on the device (or simulator).
    case appleUnavailable
    case failed(String)

    /// Nil means nothing to show.
    var message: String? {
        switch self {
        case .cancelled: nil
        case .network: "Couldn't reach the sign-in service. Check your connection and try again."
        case .appleUnavailable: "Sign in with Apple isn't available right now. Make sure this device is signed in to an Apple Account with two-factor authentication, then try again."
        case .failed(let detail): "Sign-in didn't go through. \(detail)"
        }
    }

    private static let appleDomain = "com.apple.AuthenticationServices.AuthorizationError"

    /// Folds Google, Apple, URL-loading and Supabase errors into the cases above.
    static func from(_ error: Error) -> AuthFlowError {
        if let flow = error as? AuthFlowError { return flow }
        if error is CancellationError { return .cancelled }
        let nsError = error as NSError
        if nsError.domain == "com.google.GIDSignIn", nsError.code == -5 { return .cancelled }
        if nsError.domain == appleDomain {
            switch nsError.code {
            case 1001: return .cancelled                    // ASAuthorizationError.canceled
            case 1000, 1002, 1003, 1004, 1005: return .appleUnavailable  // unknown, invalidResponse, notHandled, failed, notInteractive
            default: break
            }
        }
        if error is URLError || nsError.domain == NSURLErrorDomain { return .network }
        return .failed(Self.friendlyDetail(for: error))
    }

    private static func friendlyDetail(for error: Error) -> String {
        let text = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count < 140 else { return "Please try again." }
        return text.hasSuffix(".") ? text : text + "."
    }
}
