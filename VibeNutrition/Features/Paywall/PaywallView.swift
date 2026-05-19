import SwiftUI
import RevenueCat

struct PaywallView: View {
    let onUnlocked: () -> Void
    let onSkip: () -> Void

    @State private var purchases = PurchaseService.shared
    @State private var selectedPackage: Package?
    @State private var processing = false

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.lg) {
                    hero
                    featuresList
                    if purchases.isLoadingOfferings {
                        ProgressView().tint(Theme.Palette.accent).padding(.top, Theme.Spacing.lg)
                    } else {
                        offeringsSection
                    }
                    finePrint
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.xl)
            }

            VStack {
                Spacer()
                actionsBar
            }
        }
        .task {
            await purchases.loginIfNeeded()
            await purchases.loadOfferings()
            selectedPackage = defaultPackage()
        }
        .preferredColorScheme(.dark)
    }

    private var hero: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 56, weight: .heavy))
                .foregroundStyle(Theme.Gradients.accent)
            Text("Unlock VibeCal Premium")
                .font(Theme.Typo.h1)
                .foregroundStyle(Theme.Palette.text)
                .multilineTextAlignment(.center)
            Text("Everything you need to actually hit your goal.")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    private var featuresList: some View {
        VStack(spacing: Theme.Spacing.sm) {
            featureRow("infinity", "Unlimited food scans")
            featureRow("sparkles", "AI meal suggestions after every scan")
            featureRow("slider.horizontal.3", "Adjust portions per meal")
            featureRow("chart.line.uptrend.xyaxis", "Weekly progress reports")
            featureRow("bell.badge.fill", "Smart adaptive reminders")
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: 24)
            Text(text)
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.text)
            Spacer()
        }
    }

    private var offeringsSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if let packages = purchases.offerings?.current?.availablePackages, !packages.isEmpty {
                ForEach(packages, id: \.identifier) { pkg in
                    packageRow(pkg)
                }
            } else {
                Text("No packages available. Configure offerings in RevenueCat.")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                    .padding(.vertical, Theme.Spacing.lg)
            }
        }
    }

    private func packageRow(_ pkg: Package) -> some View {
        let isSelected = pkg.identifier == selectedPackage?.identifier
        let isAnnual = pkg.packageType == .annual
        let title = pkg.storeProduct.localizedTitle.isEmpty ? defaultTitle(for: pkg) : pkg.storeProduct.localizedTitle
        let price = pkg.storeProduct.localizedPriceString
        return Button {
            Haptics.select()
            selectedPackage = pkg
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(Theme.Typo.bodyBold)
                            .foregroundStyle(Theme.Palette.text)
                        if isAnnual {
                            Text("Best value")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(Theme.Palette.bg)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.Palette.accentAlt, in: Capsule())
                        }
                    }
                    Text(price)
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Palette.textMuted)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.Palette.accent : Theme.Palette.border)
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radii.lg)
                    .fill(isSelected ? Theme.Palette.surfaceHi : Theme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radii.lg)
                    .stroke(isSelected ? Theme.Palette.accent : Theme.Palette.border,
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .accessibilityLabel("\(title), \(price)\(isAnnual ? ", best value" : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private func defaultTitle(for pkg: Package) -> String {
        switch pkg.packageType {
        case .annual: return "Yearly"
        case .monthly: return "Monthly"
        case .weekly: return "Weekly"
        case .lifetime: return "Lifetime"
        default: return pkg.identifier.capitalized
        }
    }

    private var finePrint: some View {
        Text("Subscription auto-renews unless cancelled at least 24 hours before the end of the period. Manage in App Store > Subscriptions.")
            .font(Theme.Typo.caption)
            .foregroundStyle(Theme.Palette.textDim)
            .multilineTextAlignment(.center)
    }

    private var actionsBar: some View {
        VStack(spacing: Theme.Spacing.sm) {
            PrimaryButton(
                title: processing ? "Processing…" : "Start premium",
                isEnabled: !processing && selectedPackage != nil
            ) {
                Task { await purchaseSelected() }
            }
            HStack {
                Button("Restore") { Task { await restore() } }
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Spacer()
                Button("Not now") { onSkip() }
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            .padding(.horizontal, Theme.Spacing.sm)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.lg)
        .background(
            LinearGradient(
                colors: [Theme.Palette.bg.opacity(0), Theme.Palette.bg],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false),
            alignment: .bottom
        )
    }

    private func defaultPackage() -> Package? {
        let packages = purchases.offerings?.current?.availablePackages ?? []
        return packages.first(where: { $0.packageType == .annual }) ?? packages.first
    }

    private func purchaseSelected() async {
        guard let pkg = selectedPackage else { return }
        processing = true
        defer { processing = false }
        let ok = await purchases.purchase(pkg)
        if ok {
            Haptics.success()
            onUnlocked()
        }
    }

    private func restore() async {
        processing = true
        defer { processing = false }
        let ok = await purchases.restore()
        if ok {
            Haptics.success()
            onUnlocked()
        }
    }
}

#Preview {
    // Offerings come from RevenueCat at runtime; the preview shows the
    // empty-offerings placeholder copy + the hero / features / action bar.
    PaywallView(onUnlocked: {}, onSkip: {})
        .preferredColorScheme(.dark)
}
