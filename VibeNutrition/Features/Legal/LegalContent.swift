import Foundation

/// Static, in-app legal copy. Reviewed against the iOS schema + edge functions actually shipped.
/// Replace `[COMPANY_NAME]` and `[CONTACT_EMAIL]` with the legal entity owning VibeCal before launch.
enum LegalContent {

    static let appName = "VibeCal"
    static let companyPlaceholder = "[COMPANY_NAME]"
    static let contactPlaceholder = "[CONTACT_EMAIL]"
    static let lastUpdated = "May 17, 2026"

    // MARK: - FAQ

    static let faq: [(question: String, answer: String)] = [
        (
            "How does VibeCal estimate calories from a photo?",
            "When you tap Scan, VibeCal uploads a single photo of your meal to our servers, " +
            "asks a vision AI model to identify the foods and estimate portion size in grams, " +
            "then returns calories and macros. Vision-based estimates are approximate — " +
            "you can always slide each item up or down before saving."
        ),
        (
            "How is my daily calorie target calculated?",
            "We use the Mifflin-St Jeor equation for your basal metabolic rate (BMR), then " +
            "multiply by an activity factor based on your weekly training days (and Apple Health " +
            "step data, if you connect it). Your goal and selected pace add or subtract a daily " +
            "calorie delta. All of this is capped at ±20% of your TDEE so the target stays sane."
        ),
        (
            "Why does my target change when I change my pace?",
            "Slow / Medium / Fast roughly correspond to 0.25 / 0.5 / 0.75 kg per week. " +
            "Because 1 kg of body mass ≈ 7,700 kcal, faster paces mean a larger daily surplus " +
            "(when gaining) or deficit (when losing)."
        ),
        (
            "Where does the Recommended Daily Intake (RDI) for vitamins and minerals come from?",
            "We use the U.S. NIH Office of Dietary Supplements RDAs for adults 19+, which " +
            "match the FDA Daily Values used on most nutrition labels. Values for vitamin C, " +
            "iron, magnesium, and zinc differ by sex."
        ),
        (
            "Are micronutrient numbers from the scan accurate?",
            "They are best-effort estimates from a vision AI model. Treat them as directional, " +
            "not lab-grade — they're useful for spotting weeks where you're consistently low in " +
            "something, not for medical diagnostics."
        ),
        (
            "What happens if I run out of free scans?",
            "Free accounts get 3 scans per day. You can still log meals manually as many times " +
            "as you like, or upgrade to Premium for unlimited scans."
        ),
        (
            "Will my data be used to train AI models?",
            "No. Your food photos are sent to OpenAI for the single purpose of analyzing the " +
            "meal you just photographed and are not used by us to train any model."
        ),
        (
            "How do I delete my account?",
            "Open the profile screen → Danger zone → Delete my account. This permanently removes " +
            "your profile, food logs, weight logs, scan photos, and subscription record. It can't be undone."
        ),
        (
            "Can I export my data?",
            "Yes. Profile → Your data → Export as JSON produces a single file with your profile, " +
            "goals, latest targets, food logs, and weight logs that you can share or archive."
        ),
        (
            "Is VibeCal medical advice?",
            "No. VibeCal is a general wellness app, not a medical device. If you have a medical " +
            "condition, are pregnant or breastfeeding, are under 18, or have a history of disordered " +
            "eating, please talk to a qualified clinician before changing your diet."
        ),
    ]

    // MARK: - Privacy Policy

    static let privacyPolicy: String = """
    \(appName) Privacy Policy

    Last updated: \(lastUpdated)

    \(companyPlaceholder) ("we", "us") operates \(appName) (the "App"). This policy explains
    what personal data the App collects, why, how we use it, and your rights under the EU
    General Data Protection Regulation (GDPR) and other applicable laws.

    1. Data we collect

    Account & auth
      • Email address (you provide this when you sign up, or it comes from Apple/Google when
        you use Sign in with Apple / Sign in with Google).
      • Authentication tokens issued by our backend provider (Supabase).

    Profile & goals
      • Age, biological sex, height, current weight, goal weight, selected pace, training days
        per week, dietary preference, meals per day, main focus, units preference.
      • These are required to compute a daily calorie & macro target. We store them in our
        Postgres database (Supabase), in your row only.

    Food logs
      • Each meal you log: items, grams, calories, macros, optional micronutrients, source
        (scan or manual), timestamp.
      • For scans, the photo you take is uploaded to encrypted storage and sent once to a
        vision AI model for analysis. Photos are scoped to your user folder; only you (and our
        servers) can access them.

    Weight logs
      • Each weight check-in (kg + timestamp).

    Health data (optional, requires explicit consent via iOS HealthKit)
      • Average daily steps (last 14 days) and active energy burned, used only to refine
        your activity multiplier. HealthKit data never leaves the device unless you explicitly
        sync it; raw samples are not uploaded.

    Subscription & purchase data
      • RevenueCat customer ID, current entitlement tier, expiry date, product identifier of
        the active purchase.

    Marketing email (only if you opt in)
      • If you check the marketing opt-in box in Settings, we store the email address you
        provided, the opt-in flag, and the timestamp of your consent so we can prove it.
      • You can withdraw consent at any time from the same screen; we will stop sending
        marketing email and update your record.

    Analytics & diagnostics
      • Standard, anonymous Apple App Store diagnostics. We do not run third-party analytics
        SDKs that track you across apps.

    2. How we use your data
      • Compute and display your daily targets and progress.
      • Save and replay your food and weight logs.
      • Analyze the photos you submit, only for the purpose of identifying that one meal.
      • Enforce the free-scan limit and unlock premium features after a valid purchase.
      • Send the notifications you've opted into.
      • Send marketing email only if you explicitly opted in.

    3. Legal bases (GDPR)
      • Performance of a contract: providing the app you signed up for.
      • Consent: HealthKit access, push notifications, marketing email. Each is opt-in and
        revocable from Settings or iOS Settings.
      • Legitimate interests: keeping the service running and secure, preventing abuse.

    4. Sharing
      • Supabase (database, auth, storage, edge functions) — our backend provider.
      • OpenAI — receives the single photo you submit and your prompt during food scanning;
        not used to train models for us.
      • RevenueCat — processes subscription state.
      • Apple — Sign in with Apple, App Store payments, HealthKit (on-device).
      • Google — only if you use Sign in with Google.
      We do not sell your personal data to anyone.

    5. International transfers
      Our backend may be hosted in regions outside your country. Where data leaves the
      EEA / UK, we rely on Standard Contractual Clauses or equivalent safeguards.

    6. Retention
      We keep your data until you delete your account. Deletion is immediate and irreversible
      via Profile → Delete my account, which also removes your storage objects and auth row.

    7. Your rights
      Under GDPR you have the right to access, correct, delete, restrict, or object to the
      processing of your personal data, and the right to data portability. You can:
        • Export your data: Profile → Your data → Export as JSON.
        • Delete your data: Profile → Danger zone → Delete my account.
        • Email us at \(contactPlaceholder) for anything else.

    8. Children
      \(appName) is not directed at children under 13. We will not knowingly create an account
      for a child under 13 (we ask for your age during onboarding and reject ages below 13).
      If you believe a child has signed up, contact \(contactPlaceholder).

    9. Security
      Data in transit is encrypted with TLS. Data at rest is encrypted by our cloud provider.
      Row-level security in Postgres restricts every table so users can only read or write
      their own rows. Scan photos sit in storage policies scoped to your user folder.

    10. Changes to this policy
      We'll update this page (and the "Last updated" date above) when material changes occur,
      and notify you in-app for significant changes.

    11. Contact
      Data controller: \(companyPlaceholder)
      Contact email:   \(contactPlaceholder)
    """

    // MARK: - Terms of Service

    static let termsOfService: String = """
    \(appName) Terms of Service

    Last updated: \(lastUpdated)

    These Terms govern your use of \(appName) (the "App") operated by \(companyPlaceholder).
    By using the App you agree to these Terms.

    1. Eligibility
      You must be at least 13 years old to use the App. By creating an account you confirm
      that you meet this requirement.

    2. Not medical advice
      \(appName) is a general wellness and education tool. It is NOT a medical device and
      does NOT provide medical, dietary, or clinical advice. Results vary widely from person
      to person. Calorie and macro estimates — including those produced by photo analysis —
      are approximate and may be wrong. Do not rely on the App to manage a medical condition.
      Consult a qualified clinician before making significant dietary changes, especially if
      you are pregnant or nursing, have a history of disordered eating, or have any chronic
      health condition.

    3. Your account
      You're responsible for the accuracy of the information you provide (age, sex, height,
      weight, etc.) and for keeping your sign-in credentials secure. You may not share your
      account or use it on behalf of someone else without authorization.

    4. Acceptable use
      Don't reverse-engineer, abuse, overload, or use the App for any unlawful purpose.
      Don't upload photos that aren't food or that contain other people's private information
      without their consent.

    5. Subscriptions
      Premium subscriptions are sold through the Apple App Store and managed by Apple.
      Pricing, renewal, and refund rules are handled by Apple under their standard terms.
      Cancel at any time in App Store → your Apple ID → Subscriptions.

    6. Intellectual property
      The App, its design, code, and content are owned by \(companyPlaceholder) or its
      licensors. You retain rights to the content you submit (e.g. food photos); by uploading
      it you grant us a non-exclusive license to process that content solely to provide the
      service to you.

    7. Disclaimers
      The App is provided "as is" and "as available." To the maximum extent permitted by
      Swedish law, we disclaim all warranties — express or implied — including merchantability,
      fitness for a particular purpose, and non-infringement.

    8. Limitation of liability
      To the maximum extent permitted by Swedish law, \(companyPlaceholder)'s total liability
      for any claim arising out of or related to these Terms or the App is limited to the
      amount you paid us for the App in the 12 months preceding the claim.
      Nothing in these Terms limits liability for gross negligence, willful misconduct, or
      any liability that cannot be limited under applicable law.

    9. Termination
      You may delete your account at any time from Profile → Danger zone. We may suspend or
      terminate accounts that violate these Terms or applicable law.

    10. Changes
      We may update these Terms. Material changes will be communicated in-app. Your continued
      use of the App after a change means you accept the new Terms.

    11. Governing law and venue
      These Terms are governed by the laws of Sweden, excluding its conflict-of-laws rules.
      The courts of Stockholm, Sweden have exclusive jurisdiction over any dispute, unless
      mandatory consumer protection law in your country of residence grants you additional
      rights or a different venue.

    12. Contact
      \(companyPlaceholder), \(contactPlaceholder)
    """
}
