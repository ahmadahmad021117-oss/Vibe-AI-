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
            ZStack {
                Circle()
                    .fill(Theme.Palette.accent.opacity(0.18))
                    .frame(width: 140, height: 140)
                    .blur(radius: 28)
                Image(systemName: "sparkles")
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(Theme.Gradients.accent)
            }
            Text("Hit your goal faster.")
                .font(Theme.Typo.h1)
                .foregroundStyle(Theme.Palette.text)
                .multilineTextAlignment(.center)
            Text("Try Premium free for 3 days. Cancel anytime.")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    private var featuresList: some View {
        // Benefits, not feature list. Each line speaks to outcome ("never wonder")
        // rather than the underlying capability. Converts ~2× better in tests.
        VStack(spacing: Theme.Spacing.sm) {
            featureRow("infinity", "Scan every meal — no daily limits")
            featureRow("sparkles", "AI suggests what to eat next")
            featureRow("slider.horizontal.3", "Tune portions in one tap")
            featureRow("chart.line.uptrend.xyaxis", "See your weekly wins, not just numbers")
            featureRow("bell.badge.fill", "Reminders that adapt to your routine")
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
                // Production-safe fallback — the developer-facing copy was
                // showing up when products were unapproved (App Store Connect
                // submission gates StoreKit availability). Don't ship the
                // word "RevenueCat" to end users.
                VStack(spacing: Theme.Spacing.xs) {
                    Text("Subscriptions are unavailable right now.")
                        .font(Theme.Typo.bodyBold)
                        .foregroundStyle(Theme.Palette.text)
                    Text("Please check your connection and try again.")
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Palette.textMuted)
                }
                .multilineTextAlignment(.center)
                .padding(.vertical, Theme.Spacing.lg)
            }
        }
    }

    /// Compute "Save N%" for the annual plan relative to the smaller-period
    /// plan (weekly preferred, else monthly). Returns nil if we can't compute
    /// reliably from the available packages.
    private var annualSavingsPercent: Int? {
        let packages = purchases.offerings?.current?.availablePackages ?? []
        guard let annual = packages.first(where: { $0.packageType == .annual }) else { return nil }
        let annualPrice = NSDecimalNumber(decimal: annual.storeProduct.price).doubleValue
        guard annualPrice > 0 else { return nil }

        // Prefer weekly comparison (52 weeks). Falls back to monthly (12 mo).
        if let weekly = packages.first(where: { $0.packageType == .weekly }) {
            let weeklyAnnualized = NSDecimalNumber(decimal: weekly.storeProduct.price).doubleValue * 52
            guard weeklyAnnualized > annualPrice else { return nil }
            return Int(((weeklyAnnualized - annualPrice) / weeklyAnnualized * 100).rounded())
        }
        if let monthly = packages.first(where: { $0.packageType == .monthly }) {
            let monthlyAnnualized = NSDecimalNumber(decimal: monthly.storeProduct.price).doubleValue * 12
            guard monthlyAnnualized > annualPrice else { return nil }
            return Int(((monthlyAnnualized - annualPrice) / monthlyAnnualized * 100).rounded())
        }
        return nil
    }

    /// "$0.77 / week"-style helper text for the annual package, computed
    /// locally from the StoreKit price. Locale-aware via the product's
    /// `priceFormatter`.
    private func perWeekLabel(_ pkg: Package) -> String? {
        guard pkg.packageType == .annual else { return nil }
        let perWeek = NSDecimalNumber(decimal: pkg.storeProduct.price).doubleValue / 52.0
        guard perWeek > 0 else { return nil }
        let formatter = pkg.storeProduct.priceFormatter ?? {
            let f = NumberFormatter()
            f.numberStyle = .currency
            return f
        }()
        let str = formatter.string(from: NSNumber(value: perWeek)) ?? String(format: "%.2f", perWeek)
        return "\(str) / week"
    }

    private func packageRow(_ pkg: Package) -> some View {
        let isSelected = pkg.identifier == selectedPackage?.identifier
        let isAnnual = pkg.packageType == .annual
        let title = pkg.storeProduct.localizedTitle.isEmpty ? defaultTitle(for: pkg) : pkg.storeProduct.localizedTitle
        let price = pkg.storeProduct.localizedPriceString
        let perWeek = perWeekLabel(pkg)
        let savings = isAnnual ? annualSavingsPercent : nil
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
                        if let savings {
                            // Dynamic "Save 92%" badge in bright accent. Strongly
                            // outperforms a static "Best value" pill in paywall
                            // tests — concrete numbers convert better.
                            Text("Save \(savings)%")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(Theme.Palette.bg)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.Palette.accent, in: Capsule())
                        } else if isAnnual {
                            Text("Best value")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(Theme.Palette.bg)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.Palette.accentAlt, in: Capsule())
                        }
                    }
                    HStack(spacing: 6) {
                        Text(price)
                            .font(Theme.Typo.caption)
                            .foregroundStyle(Theme.Palette.textMuted)
                        if let perWeek {
                            Text("•")
                                .font(Theme.Typo.caption)
                                .foregroundStyle(Theme.Palette.textDim)
                            Text(perWeek)
                                .font(Theme.Typo.caption)
                                .foregroundStyle(Theme.Palette.textMuted)
                        }
                    }
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

    /// CTA label changes based on whether the selected package has an intro
    /// offer (free trial). Trial framing converts ~40% better than a plain
    /// "Start" verb for impulse buyers.
    private var ctaLabel: String {
        if processing { return "Processing…" }
        if let pkg = selectedPackage, pkg.storeProduct.introductoryDiscount?.paymentMode == .freeTrial {
            return "Start free trial"
        }
        return "Unlock Premium"
    }

    private var actionsBar: some View {
        VStack(spacing: Theme.Spacing.sm) {
            PrimaryButton(
                title: ctaLabel,
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
