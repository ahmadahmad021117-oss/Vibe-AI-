import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var profile: Profile?
    @State private var notificationPref: NotificationPref = .important

    @State private var showingDeleteConfirm = false
    @State private var deleting = false
    @State private var error: String?
    @State private var exportURL: URL?

    @State private var showingFAQ = false
    @State private var showingPrivacy = false
    @State private var showingTerms = false
    @State private var showingEmailSheet = false
    @State private var showingPaceSheet = false
    @State private var showingPaywall = false

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    accountSection
                    subscriptionSection
                    planSection
                    notificationsSection
                    dataSection
                    legalSection
                    dangerSection
                    Spacer(minLength: Theme.Spacing.xl)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                header
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Palette.bg)
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
        .sheet(isPresented: $showingEmailSheet) {
            MarketingEmailSheet(
                initialEmail: profile?.marketingEmail ?? AuthService.shared.session?.user.email ?? "",
                initialOptIn: profile?.marketingEmailOptIn ?? false
            ) { email, optIn in
                Task { await saveMarketingConsent(email: email, optIn: optIn) }
            }
        }
        .sheet(isPresented: $showingPaceSheet, onDismiss: { Task { await load() } }) {
            PaceSheet()
        }
        .sheet(isPresented: $showingPaywall, onDismiss: { Task { await load() } }) {
            PaywallView(
                onUnlocked: { showingPaywall = false },
                onSkip:     { showingPaywall = false }
            )
        }
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .font(Theme.Typo.h2)
                .foregroundStyle(Theme.Palette.text)
            Spacer()
            Button {
                Haptics.tapLight()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textMuted)
                    .frame(width: 30, height: 30)
                    .background(Theme.Palette.surface, in: Circle())
            }
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        section("Account") {
            valueRow(
                icon: "envelope.fill",
                tint: .blue,
                label: "Email",
                value: AuthService.shared.session?.user.email ?? "—"
            )
            divider
            tappableRow(
                icon: "megaphone.fill",
                tint: .orange,
                label: "Marketing email",
                value: profile?.marketingEmailOptIn == true ? "On" : "Off"
            ) {
                showingEmailSheet = true
            }
            divider
            tappableRow(
                icon: "rectangle.portrait.and.arrow.right",
                tint: .red,
                label: "Sign out"
            ) {
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

    private var planSection: some View {
        section("Plan") {
            tappableRow(
                icon: "speedometer",
                tint: .indigo,
                label: "Pace",
                value: paceShortLabel(profile?.pace)
            ) {
                showingPaceSheet = true
            }
        }
    }

    private func paceShortLabel(_ pace: Pace?) -> String {
        guard let pace else { return "—" }
        switch pace {
        case .slow:   return "Slow"
        case .medium: return "Balanced"
        case .fast:   return "Faster"
        }
    }

    private var subscriptionSection: some View {
        section("Subscription") {
            valueRow(
                icon: "crown.fill",
                tint: .yellow,
                label: "Status",
                value: EntitlementService.shared.isPremium ? "Premium" : "Free",
                valueColor: EntitlementService.shared.isPremium ? Theme.Palette.accent : Theme.Palette.textMuted
            )

            // Free users get an in-line gradient CTA that opens the paywall as a
            // sheet. Without this, free users have no path to upgrade after
            // onboarding — they're permanently stuck on the free tier and we
            // never collect revenue.
            if !EntitlementService.shared.isPremium {
                divider
                upgradeCTA
            }

            divider
            tappableRow(
                icon: "gear",
                tint: .gray,
                label: "Manage in App Store"
            ) {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    /// Big gradient "Upgrade" pill that opens the paywall. Designed to be the
    /// most eye-catching control in Settings for free users.
    private var upgradeCTA: some View {
        Button {
            Haptics.tapMedium()
            showingPaywall = true
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.Palette.bg)
                Text("Unlock Premium")
                    .font(Theme.Typo.bodyBold)
                    .foregroundStyle(Theme.Palette.bg)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Palette.bg)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 12)
            .background(
                Theme.Gradients.accent,
                in: RoundedRectangle(cornerRadius: Theme.Radii.md, style: .continuous)
            )
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upgrade to Premium")
    }

    private var notificationsSection: some View {
        section("Notifications") {
            ForEach(Array(NotificationPref.allCases.enumerated()), id: \.element.id) { idx, pref in
                Button {
                    Haptics.select()
                    notificationPref = pref
                    Task {
                        try? await ProfileService.shared.upsert(ProfilePatch(notificationPref: pref))
                        await NotificationService.shared.apply(pref: pref)
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        iconBadge(systemName: iconFor(pref), tint: tintFor(pref))
                        Text(pref.label)
                            .font(Theme.Typo.body)
                            .foregroundStyle(Theme.Palette.text)
                        Spacer()
                        if notificationPref == pref {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.Palette.accent)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(pref.label)
                .accessibilityAddTraits(notificationPref == pref ? [.isSelected, .isButton] : .isButton)
                if idx < NotificationPref.allCases.count - 1 {
                    divider
                }
            }
        }
    }

    private var dataSection: some View {
        section("Your data") {
            tappableRow(
                icon: "square.and.arrow.up.fill",
                tint: .blue,
                label: "Export as JSON"
            ) {
                Task { await exportData() }
            }
        }
    }

    private var legalSection: some View {
        section("Help & Legal") {
            tappableRow(icon: "questionmark", tint: .gray, label: "FAQ") { showingFAQ = true }
            divider
            tappableRow(icon: "hand.raised.fill", tint: .indigo, label: "Privacy policy") { showingPrivacy = true }
            divider
            tappableRow(icon: "doc.text.fill", tint: .gray, label: "Terms of service") { showingTerms = true }
        }
    }

    private var dangerSection: some View {
        section("Danger zone") {
            Button {
                Haptics.warn()
                showingDeleteConfirm = true
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    iconBadge(systemName: "trash.fill", tint: .red)
                    Text(deleting ? "Deleting…" : "Delete my account")
                        .font(Theme.Typo.body)
                        .foregroundStyle(Theme.Palette.danger)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(deleting)
        }
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Palette.textMuted)
                .padding(.leading, Theme.Spacing.md)
            VStack(spacing: 0) {
                content()
            }
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radii.lg, style: .continuous)
                    .stroke(Theme.Palette.border.opacity(0.7), lineWidth: 0.5)
            )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.Palette.border.opacity(0.6))
            .frame(height: 0.5)
            .padding(.leading, Theme.Spacing.md + 28 + Theme.Spacing.sm)
    }

    /// Colored squircle icon badge (iOS Settings-style).
    private func iconBadge(systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    /// Non-interactive row showing a label and a trailing value.
    private func valueRow(icon: String, tint: Color, label: String, value: String, valueColor: Color = Theme.Palette.textMuted) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            iconBadge(systemName: icon, tint: tint)
            Text(label)
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.text)
            Spacer()
            Text(value)
                .font(Theme.Typo.caption)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
    }

    private func tappableRow(
        icon: String,
        tint: Color,
        label: String,
        value: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tapLight()
            action()
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                iconBadge(systemName: icon, tint: tint)
                Text(label)
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                if let value {
                    Text(value)
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Palette.textMuted)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textDim)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Helpers

    private func iconFor(_ pref: NotificationPref) -> String {
        switch pref {
        case .full: return "bell.badge.fill"
        case .important: return "bell.fill"
        case .off: return "bell.slash.fill"
        }
    }

    private func tintFor(_ pref: NotificationPref) -> Color {
        switch pref {
        case .full: return .red
        case .important: return .orange
        case .off: return .gray
        }
    }

    // MARK: - Data ops

    private func load() async {
        let profile = try? await ProfileService.shared.fetchCurrent()
        self.profile = profile
        self.notificationPref = profile?.notificationPref ?? .important
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
