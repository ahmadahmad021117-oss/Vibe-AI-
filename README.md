# Vibe Nutrition — iOS

An AI-powered calorie & macro coach for fitness-focused users (16–25). Native iOS in Swift + SwiftUI, backed by Supabase.

> **Phase 1 status:** scaffold + onboarding flow.
> Plan generation, food scan, paywall, dashboard, and compliance polish land in Phases 2–6.

---

## Stack

- **Language:** Swift 5.9
- **UI:** SwiftUI (iOS 17+, `@Observable`)
- **Backend:** Supabase (Postgres + Auth + Storage + Edge Functions)
- **Auth:** Email/password, Sign in with Apple, Google Sign-In
- **Subscriptions:** RevenueCat (wired in Phase 5)
- **Project generation:** XcodeGen (`project.yml`)

## Folder layout

```
VibeNutrition/
  App/                # entry point, root coordinator, splash
  Components/         # reusable UI primitives
  Features/
    Auth/             # sign-in gate
    Onboarding/       # state, card, 12 screens, coordinator
    # Plan/, Scan/, Paywall/, Dashboard/, Profile/ land later
  Models/             # Codable types mirroring the Postgres schema
  Resources/          # Secrets.plist, asset catalogs
  Services/           # Supabase, Auth, Profile, Goal
  Theme/              # design tokens + haptics
db/migrations/        # SQL applied to Supabase
VibeNutritionTests/   # XCTest target
project.yml           # XcodeGen spec
```

## First-time setup

### 1. Tooling

```bash
brew install xcodegen supabase/tap/supabase
```

### 2. Generate the Xcode project

```bash
xcodegen generate
open VibeNutrition.xcodeproj
```

XcodeGen will read `project.yml` and produce a clean `.xcodeproj` with all source files, Swift Package dependencies, capabilities, and the test target.

### 3. Configure secrets

Fill in `VibeNutrition/Resources/Secrets.plist` (already in `.gitignore` patterns — **do not commit real keys**):

```xml
<key>SUPABASE_URL</key>          <string>https://YOUR.supabase.co</string>
<key>SUPABASE_ANON_KEY</key>     <string>eyJ...</string>
<key>GOOGLE_CLIENT_ID</key>      <string>...apps.googleusercontent.com</string>
<key>REVENUECAT_API_KEY</key>    <string>appl_...</string>
```

### 4. Apply Supabase migrations

```bash
supabase link --project-ref YOUR_REF
supabase db push   # applies db/migrations/*.sql
```

The migrations create 7 tables (`profiles`, `goals`, `weight_logs`, `targets`, `food_logs`, `activity_syncs`, `entitlements`) with row-level security enforcing `auth.uid() = user_id`, plus the `food-scans` storage bucket.

### 5. Configure auth providers in Supabase Studio

- **Apple:** Authentication → Providers → Apple → enable. No client secret needed (Supabase verifies the ID token).
- **Google:** Authentication → Providers → Google → enable. Add the iOS client ID. Add `vibenutrition://` as a redirect URL.

### 6. Run

Hit ⌘R in Xcode. The app shows splash → auth → onboarding → placeholder main view.

## Tests

```bash
xcodebuild test -scheme VibeNutrition -destination 'platform=iOS Simulator,name=iPhone 15'
```

`OnboardingStateTests` covers:
- initial step + advancement
- persist / restore roundtrip
- progress monotonicity
- back-button underflow guard

## Phase 1 acceptance criteria

- [x] Project generates cleanly via XcodeGen
- [x] Supabase schema with RLS for all user-scoped tables
- [x] Email + Sign in with Apple wired through Supabase
- [x] 12-screen onboarding, one question per screen
- [x] Onboarding state persists locally (resumes mid-flow after kill)
- [x] Each answer syncs to Supabase on advance
- [x] Top progress bar, haptics, slide transitions
- [x] Dark-mode-only theme with neon accent gradient

## Coming next

- **Phase 2:** TDEE/macro engine (Mifflin-St Jeor) + plan preview screen
- **Phase 3:** Food scan via OpenAI Vision edge function
- **Phase 4:** Daily dashboard (kcal ring, macro bars, streak)
- **Phase 5:** RevenueCat paywall
- **Phase 6:** Profile, compliance (delete account, data export), notifications, weekly reports
