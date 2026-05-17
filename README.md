# VibeCal — iOS

An AI-powered calorie & macro coach for fitness-focused users. Native iOS in Swift + SwiftUI, backed by Supabase.

> Internal Xcode target name is `VibeNutrition` for backward compatibility with the existing
> bundle ID (`com.vibe.nutrition`) and CI pipeline. The user-facing display name is **VibeCal**.

> **Phase 1 status:** scaffold + onboarding flow ✅
> **Phase 2 status:** TDEE engine + plan generation + plan preview ✅
> **Phase 3 status:** food scan + OpenAI Vision edge function + meal suggestions ✅
> **Phase 4 status:** daily dashboard + manual entry + weight check-in + streak ✅
> **Phase 5 status:** RevenueCat paywall + entitlement sync webhook ✅
> **Phase 6 status:** profile + account deletion + data export + notifications + weekly progress + adaptive nudge ✅
>
> All six phases shipped. Remaining work to ship to TestFlight: real Supabase project + keys, App Store assets, EAS/Fastlane build pipeline.

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
    Plan/             # NutritionEngine, PlanGenerator, generation + preview screens
    Scan/             # camera, scan-flow coordinator, review, meal suggestions
    Dashboard/        # ring + macro bars, manual entry, weight check-in
    Paywall/          # RevenueCat-powered paywall
    Profile/          # profile, weekly progress, account deletion, data export
supabase/
  config.toml
  functions/
    analyze-food/         # OpenAI Vision -> validated JSON
    suggest-meals/        # remaining macros + diet pref -> 3 ideas
    revenuecat-webhook/   # syncs RC events into entitlements table
    delete-account/       # purges all user data + storage + auth row
    weekly-progress/      # last 7 days vs target + adaptive nudge flag
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

CI runs the same on every push via `.github/workflows/ios.yml` (macOS 14 runner, Xcode 15.4, code signing disabled).

`OnboardingStateTests` covers:
- initial step + advancement
- persist / restore roundtrip
- progress monotonicity
- back-button underflow guard

`NutritionEngineTests` covers:
- Mifflin-St Jeor BMR against known reference values (male/female/other)
- activity multiplier baselines + step bump cap
- ±20% goal-adjustment cap
- protein priority + fat floor in macro split
- non-negative macros at very low kcal targets
- end-to-end compute returns sensible numbers

## Phase 1 acceptance criteria

- [x] Project generates cleanly via XcodeGen
- [x] Supabase schema with RLS for all user-scoped tables
- [x] Email + Sign in with Apple wired through Supabase
- [x] 12-screen onboarding, one question per screen
- [x] Onboarding state persists locally (resumes mid-flow after kill)
- [x] Each answer syncs to Supabase on advance
- [x] Top progress bar, haptics, slide transitions
- [x] Dark-mode-only theme with neon accent gradient

## Deploying edge functions

```bash
supabase secrets set OPENAI_API_KEY=sk-...
supabase secrets set REVENUECAT_WEBHOOK_SECRET=<random-shared-secret>
supabase functions deploy analyze-food
supabase functions deploy suggest-meals
supabase functions deploy revenuecat-webhook --no-verify-jwt
supabase functions deploy delete-account
supabase functions deploy weekly-progress
```

- `analyze-food` and `suggest-meals` verify the user JWT and enforce that the uploaded image path begins with `<user_id>/`, so a logged-in user cannot trigger analysis against another user's storage object.
- `revenuecat-webhook` is JWT-less (RevenueCat doesn't send a Supabase token) and instead authenticates with a shared secret in the `Authorization: Bearer …` header. Set the same secret in RevenueCat's webhook config. Only events whose `app_user_id` is a valid UUID are accepted, matching the Supabase user ID we log in to RC with.

## Phase 2 acceptance criteria

- [x] Pure `NutritionEngine` functions (no IO, fully unit-testable)
- [x] Mifflin-St Jeor BMR, activity multiplier with step data bump (capped +0.10)
- [x] Goal-adjusted kcal capped at ±20% TDEE
- [x] Protein priority (1.6–2.2 g/kg by goal), fat floor ≥0.8 g/kg, carbs remainder
- [x] HealthKit reads 14-day avg steps when user opted in
- [x] `PlanGenerator` runs honest staged status messages (no fake counters)
- [x] `targets` row written to Supabase on completion
- [x] Plan preview shows kcal ring, macro split, weekly projection, computation breakdown
- [x] Plan preview shown **before** any paywall

## Phase 3 acceptance criteria

- [x] `analyze-food` edge function: JWT-verified, path-ownership-checked, Zod-validated, retries once on bad model output
- [x] `suggest-meals` edge function: returns exactly 3 ideas matched to remaining macros + diet pref
- [x] OpenAI key lives in Supabase secrets, never in app bundle
- [x] `CameraScreen` uses AVFoundation with PhotosPicker fallback when permission denied
- [x] `FoodScanService.analyze` uploads to per-user storage folder, invokes function, parses
- [x] `ScanReviewView` lets user adjust grams; macros recompute live and proportionally
- [x] Confirm writes to `food_logs` with `source = scan`
- [x] Free tier capped at 3 scans/day (counted from `food_logs` where `source = scan`)
- [x] `MealSuggestionsSheet` shown after save if user opted in

## Phase 4 acceptance criteria

- [x] `DashboardView` shows kcal-remaining ring + macro bars + today's log list + streak pill
- [x] `DashboardViewModel` loads target, today's logs, and current streak in parallel
- [x] Pull-to-refresh re-syncs the day
- [x] Manual food entry (name, grams, kcal, P/C/F)
- [x] Weight check-in with slider, pre-fills last logged weight
- [x] Swipe-to-delete on log rows
- [x] `StreakService` counts consecutive days with at least one log
- [x] Empty state when no logs today

## Phase 5 acceptance criteria

- [x] `PurchaseService` wraps RevenueCat (configure, login as Supabase user, offerings, purchase, restore)
- [x] `PaywallView` shows feature list, monthly + yearly packages (yearly highlighted as Best value), restore button, "Not now" escape hatch
- [x] Slots between plan preview and main — never before plan preview
- [x] `revenuecat-webhook` edge function upserts `entitlements` row, shared-secret authenticated, rejects non-UUID app_user_ids
- [x] `EntitlementService.refresh()` is called after each purchase/restore
- [x] Free-tier scan cap remains enforced via the entitlements row

## Phase 6 acceptance criteria

- [x] `ProfileView` with account, subscription, notifications, data, legal, danger sections
- [x] Delete account confirmation alert → `delete-account` edge function purges all rows + storage objects + auth user (App Store §5.1.1(v) compliance)
- [x] Data export builds a sorted, ISO-8601-dated JSON dump and presents `UIActivityViewController`
- [x] `NotificationService` schedules daily reminder + weekly summary based on user pref
- [x] Subscription management deep-links to App Store > Subscriptions
- [x] `WeeklyProgressView` shows adherence, weight delta vs expected, adaptive recalibrate nudge when deviation > 0.3 kg
- [x] Tapping streak pill opens weekly progress
- [x] No fake testimonials, no fabricated counters anywhere

## What's left before TestFlight

- Real Supabase project + keys (replace `Secrets.plist` placeholders)
- Apple Developer team ID in `project.yml` `DEVELOPMENT_TEAM`
- App Store Connect listing + screenshots + marketing copy
- RevenueCat dashboard: create offering with monthly + yearly packages, configure webhook URL + shared secret
- Privacy policy and terms hosted at the URLs referenced in `ProfileView`
- Real app icon PNGs in `Assets.xcassets/AppIcon.appiconset/` (scaffolding committed)
- Fastlane / EAS deploy pipeline beyond the GitHub Actions build+test workflow
