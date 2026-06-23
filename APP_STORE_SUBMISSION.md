# VibeCal — App Store Submission Guide

Everything you need to submit VibeCal to the App Store. Work top to bottom.
App display name: **VibeCal**. Today: 2026-05-31.

---

## 3. Screenshots

Apple strictly requires only the **6.9" iPhone** set: **1320 × 2868 px** (e.g. iPhone 16 Pro Max).
Design 6–8 there; Apple scales them down for smaller phones. iPad set only needed if you ship iPad.

Capture from the Xcode Simulator (`Cmd + S` saves at exact resolution). Use realistic demo
data — full logs, an active streak, a believable weight trend. Empty states look bad.

Suggested order (first 2–3 show in search results — lead with your strongest):

| # | Screen | Caption |
|---|--------|---------|
| 1 | Scan result (food items + macros) | Snap a photo. Get calories instantly. |
| 2 | Dashboard (calorie ring + macros) | Your day at a glance |
| 3 | Plan / target screen | A calorie target built for your goal |
| 4 | Progress (weight chart + measurements) | Watch the trend, not the daily noise |
| 5 | Progress photos (before/after) | See your transformation |
| 6 | Meal ideas | Meal ideas that fit your macros |
| 7 | Home + lock-screen widgets | Log without opening the app |
| 8 | Water / streak / micronutrients | Track water, streaks, and micros too |

Notes:
- Consistent caption font/color matched to your accent color.
- Do NOT screenshot the paywall — Apple dislikes price-forward marketing shots.
- App preview video is optional (15–30s, same size).

---

## 4. Metadata (drafts — edit freely)

**App Name** (≤30): `VibeCal: AI Calorie Tracker`

**Subtitle** (≤30): `Snap meals, hit your macros`

**Keywords** (≤100, comma-separated, NO spaces):
`calorie,counter,macro,tracker,food,diet,nutrition,weight,loss,AI,scan,fasting,protein,meal,health`

**Promotional text** (≤170, editable anytime without review):
`Now with home & lock-screen widgets — log meals without opening the app. Snap a photo, get instant calories and macros powered by AI.`

**Description:**
```
VibeCal turns calorie tracking into something you'll actually stick with.
Just snap a photo of your meal — our AI identifies the food, estimates the
portion, and logs calories and macros in seconds. No more digging through
giant food databases.

WHAT YOU GET
• AI Food Scan — photograph any meal for instant calories, protein, carbs,
  fat, and key micronutrients.
• A Target Built For You — we calculate your daily calories and macros from
  your age, height, weight, goal, and activity using the proven Mifflin-St
  Jeor method.
• Track Your Progress — weight trends, body measurements, and before/after
  progress photos in one place.
• Stay On Track — water logging, daily streaks, and home & lock-screen
  widgets so logging takes one tap.
• Meal Ideas — get meal suggestions that fit your remaining macros and budget.
• Apple Health — optionally sync steps and energy to sharpen your target.

PREMIUM
Free accounts get 3 AI scans per day plus unlimited manual logging. Upgrade
to Premium for unlimited scans.

VibeCal is a general wellness app, not medical advice. Calorie estimates are
approximate. If you have a medical condition, are pregnant, under 18, or have
a history of disordered eating, talk to a clinician before changing your diet.
```

**URLs you must provide** (GitHub Pages is live: main branch /docs):
- Privacy Policy URL: `https://ahmadahmad021117-oss.github.io/Vibe-AI-/privacy.html`
- Support URL: `https://ahmadahmad021117-oss.github.io/Vibe-AI-/support.html`
- (Marketing URL, optional: `https://ahmadahmad021117-oss.github.io/Vibe-AI-/`)

Note: the support page (`docs/support.html`) must be committed & pushed to `main` before
the Support URL goes live — GitHub Pages serves from the pushed /docs folder.

---

## 5. App Privacy questionnaire (App Store Connect → App Privacy)

Declare these data types. ALL are "Linked to you", NONE "Used to track you".
("Used to track" = No everywhere — you run no ad/analytics SDKs.)

| Apple data type | Collect? | Linked | Purpose |
|---|---|---|---|
| Email Address | Yes | Yes | App Functionality |
| Name (optional via Apple) | Yes | Yes | App Functionality |
| Health (weight, body measurements, nutrition, micros, goals, water) | Yes | Yes | App Functionality |
| Fitness (steps, active energy) | Yes | Yes | App Functionality |
| Photos or Videos (meal + progress photos) | Yes | Yes | App Functionality |
| User ID (Supabase + RevenueCat) | Yes | Yes | App Functionality |
| Purchase History (subscription tier) | Yes | Yes | App Functionality |
| Crash Data | Yes | No | App Functionality |

**Answer "No" / not collected:** Location, Contacts, Browsing/Search history,
Sensitive info, Financial info, Advertising data / IDFA, Audio.

Third parties that receive data (already documented in your privacy policy):
Supabase (backend), Anthropic (single food photo per scan, not used for training),
RevenueCat (subscription state), Apple (Sign in with Apple, payments, HealthKit on-device).

---

## 6. Age Rating

Fill the content questionnaire in App Store Connect. VibeCal has no objectionable
content, so it rates **4+**. Answer "None" to all categories
(violence, sexual content, profanity, gambling, etc.).

Note: it's a diet/weight-loss app. Apple occasionally scrutinizes weight-management
content — keep all copy framed as general wellness (your Terms/Privacy already do this).
Your onboarding rejects ages below 13, which is consistent with a 4+ rating.

---

## 7. Subscription / In-App Purchase — RevenueCat DONE, App Store Connect pending

Verified in the dashboards 2026-05-31. **RevenueCat is fully configured:**
- Project "VibeCal", app "VibeCal iOS" connected
- Entitlement `premium` (matches the app code) with 2 products attached
- Offering `default` (active) with 2 packages — matches the app's `offerings()` call
- Products:
  - `com.vibecal.premium.yearly` (Premium Yearly)
  - `com.vibecal.premium.weekly` (Premium Weekly)

**The gap:** both products show **"Could not check"** in RevenueCat because the matching
subscriptions do NOT exist in App Store Connect yet (its Subscriptions page is empty —
no subscription group). Purchases won't work until the App Store side is created.

What YOU need to do (these require agreements / pricing / credentials — can't be automated):
1. **Business → Agreements**: sign the Paid Apps agreement (banking + tax forms).
   Subscriptions can't be created or sold until this is active.
2. **App Store Connect → VibeCal AI → Subscriptions**: create a subscription group, then
   two auto-renewable subscriptions with these EXACT product IDs (must match RevenueCat):
   - `com.vibecal.premium.yearly`
   - `com.vibecal.premium.weekly`
   Set price, localized name/description, and a review screenshot for each.
3. Once they're "Ready to Submit", RevenueCat's "Could not check" resolves automatically.
   If it doesn't, add an App Store Connect **In-App Purchase API key** under
   RevenueCat → Apps → VibeCal iOS so RevenueCat can verify product status.
4. Confirm the RevenueCat **public SDK key** is in your app's `REVENUECAT_API_KEY` config.
5. Test a sandbox purchase end-to-end before submitting.

---

## 8. Demo / review account (what it means)

Your app requires sign-in before anyone can use it. The Apple reviewer who tests your
app needs to get past that login — they can't create their own account. **If you don't
give them a working login, they auto-reject the app.**

What to do:
1. Create one real account in your app (e.g. `review@vibecal.app` / a password).
2. Log some meals, a weight or two, maybe a progress photo, so the reviewer sees a
   populated app, not empty screens.
3. In App Store Connect → your app version → **App Review Information**, type that
   email + password into the "Sign-In Required" demo account fields.
4. In the Notes box, add: "Delete account: Profile → Danger zone → Delete my account."

---

## Remaining checklist

Code / config — DONE:
- [x] Privacy manifest cleaned (Analytics purpose removed, GoogleSignIn comment removed)
- [x] FAQ AI-provider fixed (now Anthropic, matches the edge functions)
- [x] Encryption exemption set (ITSAppUsesNonExemptEncryption = NO)
- [x] HealthKit / camera / photo usage strings present
- [x] GoogleSignIn confirmed removed from Xcode dependencies (only Supabase + RevenueCat)
- [x] Account deletion + Sign in with Apple in place

You still need to:
- [ ] Apple Developer Program enrolled & paid ($99/yr)
- [ ] App icon 1024×1024 PNG (no alpha, no rounded corners)
- [ ] Screenshots — section 3
- [ ] Metadata entered — section 4
- [ ] App Privacy questionnaire — section 5
- [ ] Age rating — section 6
- [x] RevenueCat fully configured (entitlement, products, offering) — section 7
- [ ] **App Store Connect: sign Paid Apps agreement + create the 2 subscriptions — section 7 (BLOCKER)**
- [ ] Demo account for reviewer — section 8
- [ ] Publish privacy.html + create support page (live URLs)
- [ ] Archive in Xcode → upload → attach metadata → submit
