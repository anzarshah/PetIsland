import Supabase
import XCTest
@testable import IslandPet

/// How a Supabase session becomes the app's `Account` — in particular that an expired stored
/// session (what the SDK reports at launch with `emitLocalSessionAsInitialSession`) is signed out.
final class SessionMappingTests: XCTestCase {
    private func session(expiresIn seconds: TimeInterval) -> Session {
        let user = User(
            id: UUID(),
            appMetadata: ["provider": .string("apple")],
            userMetadata: ["full_name": .string("Mochi Tester")],
            aud: "authenticated",
            email: "mochi@example.com",
            createdAt: .now,
            updatedAt: .now
        )
        return Session(
            accessToken: "access",
            tokenType: "bearer",
            expiresIn: seconds,
            expiresAt: Date().addingTimeInterval(seconds).timeIntervalSince1970,
            refreshToken: "refresh",
            user: user
        )
    }

    @MainActor
    func testValidSessionMapsToAccount() {
        let account = SupabaseAuthClient.account(from: session(expiresIn: 3600))
        XCTAssertEqual(account?.email, "mochi@example.com")
        XCTAssertEqual(account?.fullName, "Mochi Tester")
        XCTAssertEqual(account?.provider, "apple")
    }

    @MainActor
    func testExpiredOrMissingSessionIsSignedOut() {
        XCTAssertNil(SupabaseAuthClient.account(from: session(expiresIn: -60)))
        XCTAssertNil(SupabaseAuthClient.account(from: session(expiresIn: 10)),
                     "the SDK counts a token that expires within 30 s as expired")
        XCTAssertNil(SupabaseAuthClient.account(from: nil))
    }
}
