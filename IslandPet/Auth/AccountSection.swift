import AuthenticationServices
import GoogleSignInSwift
import SwiftUI

/// Sign in with Apple / Google, the signed-in profile, sign out, and account deletion.
struct AccountSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var confirmDelete = false

    private var auth: AuthService { .shared }

    var body: some View {
        Section {
            switch auth.state {
            case .unknown:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Checking sign-in…")
                        .foregroundStyle(.secondary)
                }
            case .signedOut:
                signedOut
            case .signedIn(let account):
                signedIn(account)
            }
            if let message = auth.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Error: \(message)")
            }
        } header: {
            Text("Account")
        } footer: {
            Text(auth.state.account == nil
                 ? "Optional. Your pet and its progress stay on this device either way."
                 : "Deleting your account removes it from Island Pet's servers. Your pet stays on this device.")
        }
        .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                Task { await auth.deleteAccount() }
            }
            Button("Keep account", role: .cancel) {}
        } message: {
            Text("This permanently removes your account and profile from Island Pet's servers. It can't be undone.")
        }
    }

    // MARK: Signed out

    private var signedOut: some View {
        VStack(spacing: 12) {
            Text("Sign in to attach an account to Island Pet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            SignInWithAppleButton(.signIn) { request in
                auth.prepareAppleRequest(request)
            } onCompletion: { result in
                Task { await auth.completeApple(result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 48)
            .accessibilityLabel("Sign in with Apple")

            GoogleSignInButton(scheme: colorScheme == .dark ? .dark : .light, style: .wide, state: auth.isBusy ? .disabled : .normal) {
                Task { await signInWithGoogle() }
            }
            .frame(height: 48)
            .accessibilityLabel("Sign in with Google")
        }
        .padding(.vertical, 6)
        .disabled(auth.isBusy)
        .opacity(auth.isBusy ? 0.6 : 1)
        .overlay {
            if auth.isBusy {
                ProgressView()
                    .controlSize(.large)
                    .accessibilityLabel("Signing in")
            }
        }
    }

    private func signInWithGoogle() async {
        guard let presenter = UIApplication.shared.topViewController else {
            auth.errorMessage = AuthFlowError.failed("Couldn't find a screen to present Google Sign-In.").message
            return
        }
        await auth.signInWithGoogle(presenting: presenter)
    }

    // MARK: Signed in

    private func signedIn(_ account: Account) -> some View {
        Group {
            HStack(spacing: 12) {
                Text(account.initial)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Pastel.coral, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName)
                        .font(.headline)
                    if let email = account.email, email != account.displayName {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let provider = account.provider {
                        Text("Signed in with \(provider.capitalized)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            Button("Sign out") {
                Task { await auth.signOut() }
            }
            .disabled(auth.isBusy)

            Button("Delete account…", role: .destructive) {
                confirmDelete = true
            }
            .disabled(auth.isBusy)
        }
    }
}

extension UIApplication {
    /// The view controller to present system sign-in sheets from (the top of the active scene).
    var topViewController: UIViewController? {
        let scenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
