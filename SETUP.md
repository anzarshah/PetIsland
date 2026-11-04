# Island Pet — Sign in with Google / Apple (Supabase Auth) setup

Everything the app needs is wired; this is the checklist for the services around it. There is no
custom backend: Google and Apple issue ID tokens, the app hands them to Supabase Auth
(`signInWithIdToken`), and the Supabase Swift SDK stores and refreshes the session in the Keychain.

## 1. Project configuration (already in the repo)

| What | Where |
| --- | --- |
| Supabase URL + publishable key, Google iOS / Web client IDs, reversed client ID | `Config/AppConfig.xcconfig` (the only place; flows into `Info.plist`, read by `AppConfig.swift`) |
| Team ID `RVG4LJ7DUF`, bundle IDs `com.anzarshah.petisland` (+ `.widget`, `.tests`) | `Config/Signing.xcconfig`, `project.yml` |
| Sign in with Apple entitlement | `project.yml → entitlements` → generated `IslandPet/IslandPet.entitlements` (survives `xcodegen generate`) |
| Packages | `supabase-swift` (product **Supabase**), `GoogleSignIn-iOS` (**GoogleSignIn**, **GoogleSignInSwift**) |

Never add the Supabase `service_role` key or a Google client secret to the app or the repo. The
service_role key is only ever used by the Edge Function, where Supabase injects it as a secret.

After changing `project.yml` run `xcodegen generate`; the first build resolves the packages.

## 2. Supabase dashboard — double-check

**Authentication → Providers → Google**
- Enabled.
- Client IDs: both the **iOS** client ID (`384864931586-tit673b2vi8n25kgcphqpq9i85tqpdl0.apps.googleusercontent.com`) and the **Web** client ID (`384864931586-d84h0ksotdfrs79hqb45hftt7blnpt5b.apps.googleusercontent.com`), comma-separated. Google ID tokens from iOS carry the iOS client ID as audience; Supabase must trust it.
- **Skip nonce check: ON.** Google Sign-In for iOS does not let the app set a nonce, so Supabase can't verify one.

**Authentication → Providers → Apple**
- Enabled.
- Client IDs contains the app's bundle ID **`com.anzarshah.petisland`** (native Sign in with Apple uses the bundle ID as the audience; a Services ID is only needed for web sign-in).
- Nonce check stays ON (the app sends a hashed nonce to Apple and the raw nonce to Supabase).

**Authentication → URL Configuration** — nothing required for these native flows (no redirect URL).

**Apple Developer portal** — the App ID `com.anzarshah.petisland` needs the *Sign in with Apple* capability. With automatic signing and the entitlement present, Xcode enables it when you first build for a device while signed into your Apple account in Xcode → Settings → Accounts.

## 3. Google Cloud — reminders

- The OAuth consent screen is in **Testing**: only listed test users can sign in. Your Gmail is added; add anyone else who tests.
- Before launch, **Publish** the consent screen to Production (and complete verification if Google asks), otherwise real users get "access blocked".
- The iOS OAuth client must list bundle ID `com.anzarshah.petisland`. If you ever change the bundle ID, create a new iOS client and update `Config/AppConfig.xcconfig` (both the client ID and the reversed client ID).

## 4. Database — run this SQL

Supabase dashboard → SQL editor → paste the contents of
[`supabase/migrations/20261030220000_profiles.sql`](supabase/migrations/20261030220000_profiles.sql) → Run.

It creates `public.profiles` (id → `auth.users` on delete cascade, `full_name`, `avatar_url`,
`created_at`), enables RLS with "owner can select / update" policies, and adds triggers that
create a profile for each new user from Google/Apple metadata and fill in the name Apple delivers
on the first sign-in.

Alternatively, with the CLI linked to the project: `supabase db push`.

## 5. Edge Function — `delete-account`

Source: [`supabase/functions/delete-account/index.ts`](supabase/functions/delete-account/index.ts).
It verifies the caller's JWT with `auth.getUser`, then deletes that user through the Admin API
using `SUPABASE_SERVICE_ROLE_KEY`, which Supabase provides to functions automatically.

Deploy with the CLI:

```bash
brew install supabase/tap/supabase          # once
supabase login                               # once
cd ~/RSH/Projects/IslandPet
supabase link --project-ref vzokhzbrhqpokvjvfvvp
supabase functions deploy delete-account --no-verify-jwt
```

`--no-verify-jwt` turns off the gateway's own JWT check because the function performs the
verification itself (this also keeps it working with Supabase's newer asymmetric JWT signing
keys). No secrets need to be set: `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
`SUPABASE_SERVICE_ROLE_KEY` are injected by the platform.

Dashboard alternative: Edge Functions → Deploy a new function → name `delete-account` → paste
`index.ts` → Deploy, then in the function's settings turn **Verify JWT** off.

Check it: Edge Functions → delete-account → Logs after tapping *Delete account* in the app.

## 6. Testing

### Simulator
1. Run the `IslandPet` scheme on an iPhone 17 Pro simulator (any Dynamic Island model).
2. Home → gear (Settings) → **Account**.
3. **Sign in with Google**: a web sheet opens; sign in with your test-user Gmail. The sheet closes
   and the Account section shows your name and email. Supabase → Authentication → Users shows the
   user; Table editor → `profiles` has a row with `full_name`/`avatar_url`.
4. **Sign in with Apple**: works in the simulator when the simulator is signed into an Apple
   account (Settings → Sign in to your iPhone). The first authorization shows the name/email
   sheet; choose "Share My Email" or "Hide My Email". The user appears in Supabase with the
   provider `apple`, and `profiles.full_name` is filled.
5. Quit and relaunch the app: the Account section is still signed in (session restored from the
   Keychain by the SDK).
6. **Sign out** → the sign-in buttons return.
7. **Delete account…** → confirm → the user disappears from Authentication → Users and the
   `profiles` row is gone; the Account section is signed out.

If Apple sign-in fails in the simulator, test it on a device — simulator support depends on the
account being fully signed in with two-factor authentication.

### Real iPhone
1. In Xcode select your iPhone; the first build registers the App ID capability. If signing fails,
   open the app target → Signing & Capabilities and confirm the team and the *Sign in with Apple*
   capability are present.
2. Repeat the steps above. On a device Apple sign-in uses Face ID/passcode.
3. To test "Apple sends the name only once": Settings → [your name] → Sign in with Apple →
   Island Pet → *Stop Using Apple ID*, then sign in again in the app; you get a fresh first
   sign-in with the name sheet.

### Unit tests
`xcodebuild test -scheme IslandPet -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
runs 50 tests, including `AuthServiceTests` (mocked auth client: success, cancellation, failures,
sign-out, deletion, session changes) and `SessionMappingTests` (expired sessions count as signed out).

## 7. Assumptions, TODOs, limitations

- Sign-in is **optional** and lives in Settings → Account; the pet stays on-device. `AuthService.state`
  (`unknown / signedOut / signedIn`) is ready for `RootView` to gate on if cloud backup is added.
- Session restore: the SDK is configured with `emitLocalSessionAsInitialSession: true`, so the
  stored session is reported immediately at launch instead of after a network round trip. An
  **expired** stored session counts as signed out (`SupabaseAuthClient.account(from:)`); the SDK
  refreshes it in the background and the Account section flips to signed in on `tokenRefreshed`,
  or stays signed out if the refresh token was revoked (for example after the account was deleted
  on another device).
- `profiles.avatar_url` is filled from Google's `picture`; Apple provides no avatar. The app does
  not read or edit the profiles table yet (no network features besides auth).
- Account deletion deletes the Supabase user and, via cascade, the profile. It does not clear the
  local pet; use *Edit → Say goodbye* for that.
- Apple requires the Sign in with Apple capability on the App ID; I did not touch Xcode's signing
  UI — the entitlement is declared in `project.yml` and automatic signing handles the rest.
- Google Sign-In in the simulator uses the test-user allow list while the consent screen is in
  Testing mode.
- Localized strings are plain English literals, consistent with the rest of the app.
