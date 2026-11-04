# Island Pet

A small pixel-art pet-care game for iPhone. You adopt one cat or dog, and it lives on at home with needs that change with real time, grows from baby to adult, and can visit your Dynamic Island as a Live Activity. Built with SwiftUI, ActivityKit, WidgetKit, App Intents and UserNotifications — no server, nothing leaves the device.

Requires iOS 17+. The island features need an iPhone with a Dynamic Island (iPhone 14 Pro / 15 / 16 / 17 families).

## Run it on your iPhone

1. Open `IslandPet.xcodeproj` in Xcode 16 or newer.
2. Set your signing in `Config/Signing.xcconfig`: `DEVELOPMENT_TEAM` (your Team ID) and `ISLANDPET_BUNDLE_PREFIX` (a reverse-DNS prefix you own). Picking the team under *Signing & Capabilities* for all three targets works too.
3. Run the `IslandPet` scheme on the phone. Adopt a pet, then tap **Send … to the island** when you want it in the Dynamic Island.

Island buttons (`LiveActivityIntent`) only fire on a real device; the Simulator renders the Live Activity but does not deliver its button intents to the app.

## How it works

- **One persistent pet** (`Shared/PetState.swift`, `Shared/PetStore.swift`): a versioned, Codable `PetState` with a stable ID, adoption date, species, coat, name, personality, accessory, four needs (fullness, energy, cleanliness, mood; 0–100), bond XP, care timestamps and a last-reconciled date. `PetStore` is the single serialized owner; the app, Live Activity intents and Shortcuts all change the pet through it. Older builds' species/coat/name profile is migrated on first launch.
- **Time-based rules** (`Shared/PetReducer.swift`, `Shared/GameBalance.swift`): pure functions. Needs decay per elapsed hour when the app opens or an action runs (never from a timer), naps restore energy over their duration, long gaps are capped and floored so a week away leaves a scruffy, hungry pet rather than a tragedy, and clocks that move backwards are tolerated. Actions have cooldowns with diminishing returns instead of hard locks. Every number lives in `GameBalance`.
- **Growth**: baby (< 2 days), young (< 7 days), adult — same animal, bigger body and longer tail, with markings, eye colour and accessory carried through.
- **Pixel art** (`Shared/PetRigs.swift`, `Shared/PetFrames.swift`, `Shared/PetSpriteComposer.swift`): 24×24 frames are composed from hand-drawn parts — a body per posture, a head per species and stage, tails, ears, eyes and mouths — placed at whole-pixel offsets listed in a frame table. Legs are drawn pixel by pixel from per-frame stride values so paws plant where the body moves. Six colour roles per coat, lit from the upper left. Separate hand-drawn 16×16 sprites (`Shared/CompactSprites.swift`) serve the Dynamic Island. Everything renders with nearest-neighbour scaling snapped to device pixels.
- **Behaviour** (`IslandPet/PetAnimator.swift`): idle, walk, run, turn, sit/stand, stretch/yawn, lie down, sleep, groom, eat, chase and pounce (sometimes a miss), happy hop, startled, look-at-user, on fixed per-animation frame rates. Weighted random behaviour choice tuned by personality (curious, cozy, bouncy); cats and dogs have different rhythms. Tap → look, then hop. Feed → bowl arrives, eating, happy. Play → chase and pounce. Inactivity → yawn, curl up, doze; waking startles and stretches. Reduce Motion removes translation and hops.
- **Home screen** (`IslandPet/HomeView.swift`): the pet on its stage, one "what your pet needs now" suggestion, need meters that say "Low" in words as well as colour, age and bond progress, Feed / Play / Groom / Nap, and the island visit card. Light and dark appearance, VoiceOver labels on the pet, needs and actions, 44 pt+ targets. Cosmetic edits (name, coat, accessory, personality) keep age, needs and bond; saying goodbye is a separate, confirmed step.
- **Reminders** (`Shared/ReminderPlanner.swift`, `IslandPet/ReminderScheduler.swift`): optional. Permission is requested only when you turn them on. The planner predicts when the first need will run low and schedules a single consolidated notification (interruption level *active*, never Time Sensitive), moved out of quiet hours and spaced by your frequency choice. Caring for the pet or changing settings cancels and reschedules it. Tapping it opens the care screen.
- **Island visits** (`Shared/IslandVisitManager.swift`, `IslandPetWidget/`): the pet lives in the app; the Live Activity is a user-started visit of up to eight hours that you renew explicitly. It shows a snapshot — pet sprite, caption, lowest need or current action with a system-driven progress ring, visit countdown, and the one most useful quick action. Without a fresh sync for three hours it shows a truthful resting state. A replacement visit is requested before the old one is ended, so a failure never empties the island. No background keep-alive, no audio session.

## Account (optional)

Settings → Account offers Sign in with Apple and Sign in with Google through Supabase Auth, shows the signed-in name/email, and has Sign out and Delete account. Sign-in is optional and the pet stays on-device. Service IDs live in `Config/AppConfig.xcconfig`; see `SETUP.md` for the Supabase dashboard checks, the `profiles` SQL, the `delete-account` Edge Function, and how to test.

## Tests

`IslandPetTests` covers time-based decay, long offline gaps, backward clock changes, action effects and cooldowns, growth milestones, bond levels, legacy-profile migration, store persistence and events, island snapshot identity, reminder planning (quiet hours, time zones, frequency spacing, rescheduling after care), and `AuthService` against a mocked auth client. Run with `xcodebuild test -scheme IslandPet -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.

## Project layout

```
project.yml              XcodeGen spec (regenerate with `xcodegen generate` after adding files)
Config/Signing.xcconfig  Team ID and bundle ID for all targets (includes AppConfig.xcconfig: Supabase + Google IDs)
IslandPet/               App: adoption, home, edit, settings (account + reminders), auth, animator, stage, services
supabase/                profiles migration and the delete-account Edge Function
IslandPetWidget/         Widget extension: Live Activity presentations
IslandPetTests/          Unit tests
Shared/                  Compiled into app and widget: model, state, balance, reducer, store, art, intents, island manager, reminder planner
```
