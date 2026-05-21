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

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    header
                    accountSection
                    subscriptionSection
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
            Text("Settings")
                .font(Theme.Typo.h1)
                .foregroundStyle(Theme.Palette.text)
            Spacer()
            Button {
                Haptics.tapLight()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textMuted)
                    .frame(width: 32, height: 32)
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
                    .lineLimit(1)
                    .truncationMode(.middle)
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

    private var notificationsSection: some View {
        section("Notifications") {
            HStack(spacing: 6) {
                ForEach(NotificationPref.allCases) { pref in
                    notificationChip(pref)
                }
            }
            .padding(4)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
        }
    }

    private func notificationChip(_ pref: NotificationPref) -> some View {
        let selected = notificationPref == pref
        return Button {
            Haptics.select()
            notificationPref = pref
            Task {
                try? await ProfileService.shared.upsert(ProfilePatch(notificationPref: pref))
                await NotificationService.shared.apply(pref: pref)
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: iconFor(pref))
                    .font(.system(size: 14, weight: .semibold))
                Text(shortLabel(pref))
                    .font(Theme.Typo.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? Theme.Palette.text : Theme.Palette.textMuted)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radii.md, style: .continuous)
                    .fill(selected ? Theme.Palette.surfaceHi : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radii.md, style: .continuous)
                    .stroke(selected ? Theme.Palette.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .accessibilityLabel(pref.label)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
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
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.danger)
                        .frame(width: 20)
                    Text(deleting ? "Deleting…" : "Delete my account")
                        .font(Theme.Typo.bodyBold)
                        .foregroundStyle(Theme.Palette.danger)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 10)
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

    private func shortLabel(_ pref: NotificationPref) -> String {
        switch pref {
        case .full: return "All"
        case .important: return "Important"
        case .off: return "Off"
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Palette.textMuted)
                .padding(.leading, 4)
            content()
        }
    }

    @ViewBuilder
    private func row<Trailing: View>(icon: String, label: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Palette.textMuted)
                .frame(width: 20)
            Text(label)
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.text)
            Spacer()
            trailing()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

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
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textMuted)
                    .frame(width: 20)
                Text(label)
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                trailing()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textDim)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 10)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
        }
        .accessibilityLabel(label)
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
