import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var profile: Profile?
    @State private var latestGoal: Goal?
    @State private var latestWeight: WeightLog?
    @State private var notificationPref: NotificationPref = .important
    @State private var pace: Pace = .medium

    // Edit sheets / inline pickers
    @State private var showingDeleteConfirm = false
    @State private var deleting = false
    @State private var error: String?
    @State private var exportURL: URL?

    @State private var showingEditWeight = false
    @State private var showingEditGoalWeight = false
    @State private var showingFAQ = false
    @State private var showingPrivacy = false
    @State private var showingTerms = false
    @State private var showingEmailSheet = false

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header
                    accountSection
                    subscriptionSection
                    goalSection
                    paceSection
                    projectionSection
                    notificationsSection
                    dataSection
                    legalSection
                    dangerSection
                    Spacer(minLength: Theme.Spacing.xl)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
        }
        .task { await load() }
        .preferredColorScheme(.dark)
        .alert("Delete your account?",
               isPresented: $showingDeleteConfirm,
               actions: {
                   Button("Cancel", role: .cancel) {}
                   Button("Delete", role: .destructive) {
                       Task { await deleteAccount() }
                   }
               },
               message: {
                   Text("This permanently removes your profile, logs, weights, scans, and subscription record. It cannot be undone.")
               })
        .alert("Error", isPresented: .constant(error != nil), actions: {
            Button("OK") { error = nil }
        }, message: { Text(error ?? "") })
        .sheet(item: $exportURL) { url in
            ShareSheet(activityItems: [url])
        }
        .sheet(isPresented: $showingFAQ) { FAQView() }
        .sheet(isPresented: $showingPrivacy) { PrivacyPolicyView() }
        .sheet(isPresented: $showingTerms) { TermsOfServiceView() }
        .sheet(isPresented: $showingEditWeight) {
            EditWeightSheet(
                title: "Update current weight",
                initialKg: latestWeight?.weightKg ?? latestGoal?.startWeightKg ?? 70
            ) { newKg in
                Task { await saveCurrentWeight(newKg) }
            }
        }
        .sheet(isPresented: $showingEditGoalWeight) {
            EditWeightSheet(
                title: "Update goal weight",
                initialKg: latestGoal?.goalWeightKg ?? 70
            ) { newKg in
                Task { await saveGoalWeight(newKg) }
            }
        }
        .sheet(isPresented: $showingEmailSheet) {
            MarketingEmailSheet(
                initialEmail: profile?.marketingEmail ?? AuthService.shared.session?.user.email ?? "",
                initialOptIn: profile?.marketingEmailOptIn ?? false
            ) { email, optIn in
                Task { await saveMarketingConsent(email: email, optIn: optIn) }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Profile")
                .font(Theme.Typo.h1)
                .foregroundStyle(Theme.Palette.text)
            Spacer()
            Button {
                Haptics.tapLight()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textMuted)
                    .frame(width: 36, height: 36)
                    .background(Theme.Palette.surface, in: Circle())
            }
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        section("Account") {
            row(icon: "envelope", label: "Account email") {
                Text(AuthService.shared.session?.user.email ?? "—")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            tappableRow(icon: "megaphone", label: marketingRowLabel) {
                showingEmailSheet = true
            }
            tappableRow(icon: "arrow.right.square", label: "Sign out") {
                Task {
                    do {
                        try await AuthService.shared.signOut()
                        dismiss()
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
        }
    }

    private var marketingRowLabel: String {
        if profile?.marketingEmailOptIn == true {
            return "Marketing email · On"
        }
        return "Marketing email · Off"
    }

    private var subscriptionSection: some View {
        section("Subscription") {
            row(icon: "crown", label: "Status") {
                Text(EntitlementService.shared.isPremium ? "Premium" : "Free")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(EntitlementService.shared.isPremium ? Theme.Palette.accent : Theme.Palette.textMuted)
            }
            tappableRow(icon: "gear", label: "Manage in App Store") {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private var goalSection: some View {
        section("Weight") {
            tappableRow(icon: "scalemass", label: "Current weight") {
                showingEditWeight = true
            } trailing: {
                Text(weightString(latestWeight?.weightKg ?? latestGoal?.startWeightKg))
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            tappableRow(icon: "target", label: "Goal weight") {
                showingEditGoalWeight = true
            } trailing: {
                Text(weightString(latestGoal?.goalWeightKg))
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
        }
    }

    private var paceSection: some View {
        section("Pace") {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(Pace.allCases) { p in
                    OptionCard(
                        title: p.label,
                        subtitle: p.subtitle,
                        systemImage: paceIcon(p),
                        isSelected: pace == p
                    ) {
                        pace = p
                        Task { await savePace(p) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var projectionSection: some View {
        if let current = latestWeight?.weightKg ?? latestGoal?.startWeightKg,
           let goal = latestGoal?.goalWeightKg {
            section("Projection") {
                WeightProjectionChart(
                    currentKg: current,
                    goalKg: goal,
                    pace: pace,
                    heightCm: profile?.heightCm
                )
            }
        }
    }

    private var notificationsSection: some View {
        section("Notifications") {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(NotificationPref.allCases) { pref in
                    OptionCard(
                        title: pref.label,
                        systemImage: iconFor(pref),
                        isSelected: notificationPref == pref
                    ) {
                        notificationPref = pref
                        Task {
                            try? await ProfileService.shared.upsert(ProfilePatch(notificationPref: pref))
                            await NotificationService.shared.apply(pref: pref)
                        }
                    }
                }
            }
        }
    }

    private var dataSection: some View {
        section("Your data") {
            tappableRow(icon: "square.and.arrow.up", label: "Export as JSON") {
                Task { await exportData() }
            }
        }
    }

    private var legalSection: some View {
        section("Help & Legal") {
            tappableRow(icon: "questionmark.circle", label: "FAQ") { showingFAQ = true }
            tappableRow(icon: "doc.text", label: "Privacy policy") { showingPrivacy = true }
            tappableRow(icon: "doc.plaintext", label: "Terms of service") { showingTerms = true }
        }
    }

    private var dangerSection: some View {
        section("Danger zone") {
            Button {
                Haptics.warn()
                showingDeleteConfirm = true
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(Theme.Palette.danger)
                    Text(deleting ? "Deleting…" : "Delete my account")
                        .font(Theme.Typo.bodyBold)
                        .foregroundStyle(Theme.Palette.danger)
                    Spacer()
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
            }
            .disabled(deleting)
        }
    }

    // MARK: - Helpers

    private func iconFor(_ pref: NotificationPref) -> String {
        switch pref {
        case .full: return "bell.badge.fill"
        case .important: return "bell.fill"
        case .off: return "bell.slash.fill"
        }
    }

    private func paceIcon(_ pace: Pace) -> String {
        switch pace {
        case .slow:   return "tortoise.fill"
        case .medium: return "figure.walk"
        case .fast:   return "hare.fill"
        }
    }

    private func weightString(_ kg: Double?) -> String {
        guard let kg else { return "—" }
        return String(format: "%.1f kg", kg)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title.uppercased())
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textMuted)
                .padding(.leading, 4)
            content()
        }
    }

    @ViewBuilder
    private func row<Trailing: View>(icon: String, label: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.Palette.textMuted)
                .frame(width: 24)
            Text(label)
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.text)
            Spacer()
            trailing()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    /// Real button-driven row so VoiceOver and tap targets actually work.
    /// Overload without a trailing view (the chevron is shown either way).
    private func tappableRow(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        tappableRow(icon: icon, label: label, action: action) { EmptyView() }
    }

    @ViewBuilder
    private func tappableRow<Trailing: View>(
        icon: String,
        label: String,
        action: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        Button {
            Haptics.tapLight()
            action()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textMuted)
                    .frame(width: 24)
                Text(label)
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                trailing()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textDim)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
        }
        .accessibilityLabel(label)
    }

    // MARK: - Data ops

    private func load() async {
        async let profileT = ProfileService.shared.fetchCurrent()
        async let goalT    = GoalService.shared.fetchLatest()
        async let weightT  = WeightLogService.shared.fetchLatest()
        let profile  = try? await profileT
        let goal     = try? await goalT
        let weight   = try? await weightT
        self.profile = profile
        self.latestGoal = goal
        self.latestWeight = weight
        self.notificationPref = profile?.notificationPref ?? .important
        self.pace = profile?.pace ?? .medium
        await EntitlementService.shared.refresh()
    }

    private func deleteAccount() async {
        deleting = true
        defer { deleting = false }
        do {
            try await AccountService.shared.deleteAccount()
            dismiss()
        } catch {
            self.error = error.friendlyMessage
        }
    }

    private func exportData() async {
        do {
            let url = try await AccountService.shared.exportData()
            exportURL = url
        } catch {
            self.error = error.friendlyMessage
        }
    }

    private func saveCurrentWeight(_ kg: Double) async {
        do {
            try await WeightLogService.shared.write(weightKg: kg)
            latestWeight = try await WeightLogService.shared.fetchLatest()
            // Recompute kcal target: weight changed → BMR/TDEE change.
            await recomputePlan()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func saveGoalWeight(_ kg: Double) async {
        do {
            try await GoalService.shared.updateGoalWeight(kg)
            latestGoal = try await GoalService.shared.fetchLatest()
            await recomputePlan()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func savePace(_ newPace: Pace) async {
        do {
            try await ProfileService.shared.upsert(ProfilePatch(pace: newPace))
            profile?.pace = newPace
            await recomputePlan()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func saveMarketingConsent(email: String, optIn: Bool) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let nowISO = ISO8601DateFormatter().string(from: Date())
        let patch = ProfilePatch(
            marketingEmail: trimmed.isEmpty ? nil : trimmed,
            marketingEmailOptIn: optIn,
            marketingConsentAt: nowISO
        )
        do {
            try await ProfileService.shared.upsert(patch)
            profile?.marketingEmail = trimmed.isEmpty ? nil : trimmed
            profile?.marketingEmailOptIn = optIn
            profile?.marketingConsentAt = Date()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func recomputePlan() async {
        let gen = PlanGenerator()
        await gen.run(using: nil)   // hydrates from Supabase, picks up new weight/pace/goal
    }
}

// MARK: - URL identifiable + share sheet

// URL is Identifiable so we can drive sheet(item:).
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

#Preview {
    ProfileView()
        .preferredColorScheme(.dark)
}
