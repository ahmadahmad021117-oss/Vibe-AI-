import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile: Profile?
    @State private var notificationPref: NotificationPref = .important
    @State private var showingDeleteConfirm = false
    @State private var deleting = false
    @State private var error: String?
    @State private var exportURL: URL?

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
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
               message: { Text("This permanently removes your profile, logs, weights, scans, and subscription record. It cannot be undone.") })
        .alert("Error", isPresented: .constant(error != nil), actions: {
            Button("OK") { error = nil }
        }, message: { Text(error ?? "") })
        .sheet(item: $exportURL) { url in
            ShareSheet(activityItems: [url])
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

    private var accountSection: some View {
        section("Account") {
            row(icon: "envelope", label: "Email") {
                Text(AuthService.shared.session?.user.email ?? "—")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            row(icon: "arrow.right.square", label: "Sign out") {}
                .onTapGesture {
                    Haptics.tapLight()
                    Task { try? await AuthService.shared.signOut() }
                }
        }
    }

    private var subscriptionSection: some View {
        section("Subscription") {
            row(icon: "crown", label: "Status") {
                Text(EntitlementService.shared.isPremium ? "Premium" : "Free")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(EntitlementService.shared.isPremium ? Theme.Palette.accent : Theme.Palette.textMuted)
            }
            row(icon: "gear", label: "Manage in App Store") {}
                .onTapGesture {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        Haptics.tapLight()
                        UIApplication.shared.open(url)
                    }
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

    private func iconFor(_ pref: NotificationPref) -> String {
        switch pref {
        case .full: return "bell.badge.fill"
        case .important: return "bell.fill"
        case .off: return "bell.slash.fill"
        }
    }

    private var dataSection: some View {
        section("Your data") {
            row(icon: "square.and.arrow.up", label: "Export as JSON") {}
                .onTapGesture { Task { await exportData() } }
        }
    }

    private var legalSection: some View {
        section("Help & Legal") {
            row(icon: "questionmark.circle", label: "FAQ") {}
                .onTapGesture {
                    open("https://vibe-nutrition.example.com/faq")
                }
            row(icon: "doc.text", label: "Privacy policy") {}
                .onTapGesture {
                    open("https://vibe-nutrition.example.com/privacy")
                }
            row(icon: "doc.plaintext", label: "Terms of service") {}
                .onTapGesture {
                    open("https://vibe-nutrition.example.com/terms")
                }
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

    private func load() async {
        profile = try? await ProfileService.shared.fetchCurrent()
        notificationPref = profile?.notificationPref ?? .important
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

    private func open(_ string: String) {
        if let url = URL(string: string) {
            Haptics.tapLight()
            UIApplication.shared.open(url)
        }
    }
}

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
