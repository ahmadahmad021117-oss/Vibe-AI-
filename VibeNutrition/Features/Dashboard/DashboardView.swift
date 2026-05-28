import SwiftUI

struct DashboardView: View {
    /// Injected so MainTabView can share state with ProgressTabView.
    @Bindable var vm: DashboardViewModel

    @State private var network = NetworkStatus.shared
    @State private var entitlements = EntitlementService.shared
    @State private var showingScan = false
    @State private var showingPaywall = false
    @State private var showingManualEntry = false
    @State private var showingProfile = false
    @State private var showingWeekly = false
    @State private var nutrientPage: NutrientPage = .macros

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.lg) {
                    ringCard
                        .padding(.horizontal, Theme.Spacing.lg)
                    nutrientPager
                    actionsRow
                        .padding(.horizontal, Theme.Spacing.lg)
                    if vm.profile?.mealSuggestionsEnabled ?? true {
                        mealIdeasSection
                            .padding(.horizontal, Theme.Spacing.lg)
                    }
                    todaySection
                        .padding(.horizontal, Theme.Spacing.lg)
                    // Tab bar is ~83pt + safe-area inset. 80pt left part of the
                    // empty-state card clipped behind it; 140 keeps content fully
                    // visible above the bar.
                    Spacer(minLength: 140)
                }
                .padding(.top, Theme.Spacing.sm)
            }
            .refreshable { await vm.load() }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.sm)
                    if !network.isOnline {
                        offlineBanner
                    }
                }
                .background(Theme.Palette.bg)
            }
        }
        .task { if vm.target == nil { await vm.load() } }
        .fullScreenCover(isPresented: $showingScan) {
            ScanFlowView { _ in
                showingScan = false
                Task { await vm.load() }
            }
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallView(
                onUnlocked: {
                    showingPaywall = false
                    // Fall through to the camera on a successful purchase —
                    // matches the "tap once, get scanning" intent.
                    showingScan = true
                },
                onSkip: { showingPaywall = false }
            )
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntrySheet(onSaved: {
                showingManualEntry = false
                Task { await vm.load() }
            })
        }
        .sheet(isPresented: $showingProfile) { ProfileView() }
        .sheet(isPresented: $showingWeekly, onDismiss: { Task { await vm.load() } }) {
            WeeklyProgressView()
        }
        .preferredColorScheme(.dark)
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 13, weight: .semibold))
            Text("Offline — changes will sync when you reconnect.")
                .font(Theme.Typo.caption)
        }
        .foregroundStyle(Theme.Palette.warning)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, Theme.Spacing.lg)
        .background(Theme.Palette.surface)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Offline. Changes will sync when you reconnect.")
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Text(dateString)
                    .font(Theme.Typo.h2)
                    .foregroundStyle(Theme.Palette.text)
            }
            Spacer()
            if vm.streak > 0 {
                streakPill
            }
            Button {
                Haptics.tapLight()
                showingProfile = true
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.Palette.textMuted)
            }
        }
    }

    private var streakPill: some View {
        // Streak ≥ 7: pill switches to a bright accent fill with white text
        // so the "I'm doing it" feeling actually lands. The original muted
        // pill made a 14-day streak look identical to day 1 — zero reward
        // signal for the user's behaviour, which is the whole point of a
        // streak.
        let hot = vm.streak >= 7
        return Button {
            Haptics.tapLight()
            showingWeekly = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(hot ? .white : Theme.Palette.warning)
                Text("\(vm.streak)")
                    .font(Theme.Typo.bodyBold)
                    .foregroundStyle(hot ? .white : Theme.Palette.text)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if hot {
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                } else {
                    Capsule().fill(Theme.Palette.surface)
                }
            }
            .shadow(color: hot ? Color.orange.opacity(0.45) : .clear, radius: hot ? 10 : 0)
        }
        .accessibilityLabel("\(vm.streak) day streak. Tap to view weekly progress.")
    }

    private var ringCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(Theme.Palette.surface, lineWidth: 18)
                // Base ring (0 → 1.0). When over target this is the warning
                // band — the *excess* is then drawn on top in a brighter
                // danger stroke so the overflow is unmistakable instead of
                // collapsing into a fully-wrapped accent ring.
                Circle()
                    .trim(from: 0, to: min(1, vm.kcalProgress))
                    .stroke(ringBaseStroke, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(Theme.Motion.spring, value: vm.kcalProgress)
                if vm.isOverTarget {
                    Circle()
                        .trim(from: 0, to: min(0.5, max(0, vm.kcalProgress - 1)))
                        .stroke(Theme.Palette.danger,
                                style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(Theme.Motion.spring, value: vm.kcalProgress)
                }
                ringCenterLabel
            }
            .frame(width: 240, height: 240)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(vm.isOverTarget ? "Calories over target" : "Calories remaining")
            .accessibilityValue(ringAccessibilityValue)
        }
    }

    /// Either an accent gradient (under target) or a flat warning fill (over).
    /// We use a flat color in the over state so the excess danger stroke
    /// drawn on top is visually distinct.
    private var ringBaseStroke: AnyShapeStyle {
        vm.isOverTarget
            ? AnyShapeStyle(Theme.Palette.warning)
            : AnyShapeStyle(Theme.Gradients.accent)
    }

    @ViewBuilder
    private var ringCenterLabel: some View {
        if vm.isOverTarget {
            VStack(spacing: 0) {
                Text(vm.kcalOver.grouped)
                    .font(Theme.Typo.numeralXL)
                    .foregroundStyle(Theme.Palette.danger)
                    .contentTransition(.numericText(value: Double(vm.kcalOver)))
                Text("kcal over")
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.danger)
                if let t = vm.target {
                    Text("\(vm.kcalConsumed.grouped) of \(t.kcal.grouped)")
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Palette.textDim)
                }
            }
        } else {
            VStack(spacing: 0) {
                Text(vm.kcalRemaining.grouped)
                    .font(Theme.Typo.numeralXL)
                    .foregroundStyle(Theme.Palette.text)
                    .contentTransition(.numericText(value: Double(vm.kcalRemaining)))
                Text("kcal left")
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Palette.textMuted)
                if let t = vm.target {
                    Text("of \(t.kcal.grouped)")
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Palette.textDim)
                }
            }
        }
    }

    private var ringAccessibilityValue: String {
        if vm.isOverTarget {
            guard let t = vm.target else { return "\(vm.kcalOver) kilocalories over" }
            return "\(vm.kcalOver) kilocalories over your \(t.kcal) target"
        }
        guard let t = vm.target else { return "\(vm.kcalRemaining) kilocalories left" }
        return "\(vm.kcalRemaining) of \(t.kcal) kilocalories left"
    }

    /// Horizontal pager: Macros (default) → Vitamins → Minerals.
    /// Edge-to-edge so swipe transitions don't show black side gutters; cards have
    /// their own horizontal padding to align with the rest of the page.
    private var nutrientPager: some View {
        VStack(spacing: Theme.Spacing.xs) {
            TabView(selection: $nutrientPage) {
                macrosCard.tag(NutrientPage.macros)
                vitaminsCard.tag(NutrientPage.vitamins)
                mineralsCard.tag(NutrientPage.minerals)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 200)

            pageIndicator
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(NutrientPage.allCases) { page in
                Capsule()
                    .fill(nutrientPage == page ? Theme.Palette.accent : Theme.Palette.border)
                    .frame(width: nutrientPage == page ? 20 : 8, height: 6)
                    .animation(Theme.Motion.spring, value: nutrientPage)
            }
        }
        .padding(.top, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(pageIndicatorAccessibilityLabel)
    }

    private var pageIndicatorAccessibilityLabel: String {
        let position = (NutrientPage.allCases.firstIndex(of: nutrientPage) ?? 0) + 1
        return "\(nutrientPage.title) tab \(position) of \(NutrientPage.allCases.count)"
    }

    private var macrosCard: some View {
        nutrientCard(title: "Macros") {
            nutrientBar(label: "Protein",
                        consumed: vm.proteinConsumed, target: Double(vm.target?.proteinG ?? 0),
                        unit: "g", color: Theme.Palette.accent)
            nutrientBar(label: "Carbs",
                        consumed: vm.carbsConsumed, target: Double(vm.target?.carbsG ?? 0),
                        unit: "g", color: Theme.Palette.accentDeep)
            nutrientBar(label: "Fat",
                        consumed: vm.fatConsumed, target: Double(vm.target?.fatG ?? 0),
                        unit: "g", color: Theme.Palette.accentAlt)
        }
    }

    private var vitaminsCard: some View {
        let consumed = vm.microsConsumed
        let target = vm.microsTarget
        // Every row on the card uses the same digit count — Vitamin C used to
        // render "0 / 90 mg" next to "0.0 / 15.0 μg", which looked like a bug.
        return nutrientCard(title: "Vitamins") {
            nutrientBar(label: "Vitamin D",
                        consumed: consumed.vitaminDMcg ?? 0, target: target.vitaminDMcg ?? 0,
                        unit: "μg", color: Theme.Palette.accent, fractionDigits: 1)
            nutrientBar(label: "Vitamin B12",
                        consumed: consumed.vitaminB12Mcg ?? 0, target: target.vitaminB12Mcg ?? 0,
                        unit: "μg", color: Theme.Palette.accentDeep, fractionDigits: 1)
            nutrientBar(label: "Vitamin C",
                        consumed: consumed.vitaminCMg ?? 0, target: target.vitaminCMg ?? 0,
                        unit: "mg", color: Theme.Palette.accentAlt, fractionDigits: 1)
        }
    }

    private var mineralsCard: some View {
        let consumed = vm.microsConsumed
        let target = vm.microsTarget
        // Same consistency rule as Vitamins: Magnesium previously skipped the
        // decimal while Iron/Zinc kept it — visually jarring inside one card.
        return nutrientCard(title: "Minerals") {
            nutrientBar(label: "Magnesium",
                        consumed: consumed.magnesiumMg ?? 0, target: target.magnesiumMg ?? 0,
                        unit: "mg", color: Theme.Palette.accent, fractionDigits: 1)
            nutrientBar(label: "Iron",
                        consumed: consumed.ironMg ?? 0, target: target.ironMg ?? 0,
                        unit: "mg", color: Theme.Palette.accentDeep, fractionDigits: 1)
            nutrientBar(label: "Zinc",
                        consumed: consumed.zincMg ?? 0, target: target.zincMg ?? 0,
                        unit: "mg", color: Theme.Palette.accentAlt, fractionDigits: 1)
        }
    }

    @ViewBuilder
    private func nutrientCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(title)
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Spacer()
            }
            content()
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
        // Page lives inside an edge-to-edge TabView so each card supplies its own
        // horizontal inset; matches the .lg padding used by other home-page sections.
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private func nutrientBar(label: String, consumed: Double, target: Double,
                             unit: String, color: Color,
                             fractionDigits: Int = 0) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Spacer()
                Text("\(format(consumed, digits: fractionDigits)) / \(format(target, digits: fractionDigits)) \(unit)")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.text)
            }
            GeometryReader { proxy in
                let progress = target > 0 ? min(1, consumed / target) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.bg)
                    Capsule().fill(color).frame(width: progress * proxy.size.width)
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(format(consumed, digits: fractionDigits)) of \(format(target, digits: fractionDigits)) \(unit)")
    }

    private func format(_ value: Double, digits: Int) -> String {
        // Per-card consistency: if any row on a card needs a decimal (e.g. Iron
        // at "8.0 mg"), every row on the same card should match. We pick the
        // digit count at the call-site, but route through `Double.grouped` so
        // the thousands separator is always a comma (en_US), never a thin space.
        value.grouped(max(0, digits))
    }

    private var actionsRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            actionTile(icon: "camera.fill", title: "Scan") {
                // Cal-AI-style hard paywall: scanning requires active premium
                // (which the 3-day intro-offer trial counts as). Non-premium
                // users see the paywall before the camera, not after.
                if entitlements.isPremium {
                    showingScan = true
                } else {
                    showingPaywall = true
                }
            }
            actionTile(icon: "plus.circle.fill", title: "Manual") {
                showingManualEntry = true
            }
        }
    }

    private func actionTile(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tapMedium()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.Palette.text)
                Text(title)
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
        }
        .accessibilityLabel(title)
    }

    /// Inline meal-ideas row — fetched once when Home appears, with a refresh button.
    /// Suggestions stay until the user taps refresh; we don't re-hit the function on
    /// every log change because the daily quota for `suggest-meals` is not free.
    @ViewBuilder
    private var mealIdeasSection: some View {
        if vm.target != nil {
            MealIdeasCard(
                remainingKcal: vm.kcalRemaining,
                remainingProtein: vm.proteinRemaining,
                remainingCarbs: vm.carbsRemaining,
                remainingFat: vm.fatRemaining,
                dietaryPref: vm.profile?.dietaryPref ?? .normal,
                goalType: vm.latestGoal?.type
            )
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Today")
                    .font(Theme.Typo.h3)
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                Text("\(vm.todayLogs.count) entr\(vm.todayLogs.count == 1 ? "y" : "ies")")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            if vm.todayLogs.isEmpty {
                emptyState
            } else {
                ForEach(vm.todayLogs) { log in
                    LogRow(log: log) {
                        Task { await vm.delete(log: log) }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        // The original empty state — a grey fork-and-knife with "Nothing
        // logged yet" — felt like a death notice. New version uses a soft
        // accent glow + action-first copy to encourage the very first log.
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Theme.Palette.accent.opacity(0.18))
                    .frame(width: 88, height: 88)
                    .blur(radius: 18)
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(Theme.Gradients.accent)
            }
            Text("Let's get you started")
                .font(Theme.Typo.bodyBold)
                .foregroundStyle(Theme.Palette.text)
            Text("Snap a meal or add it manually — takes 5 seconds.")
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        // 17:00–05:00 stays a neutral "Good evening." The previous "Late night"
        // label fired for ~7 hours and read as a soft judgment for users who
        // legitimately eat dinner past 22:00 — exactly the audience a gain plan
        // needs to keep logging.
        default: return "Good evening"
        }
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }
}

/// Pages in the home-screen nutrient pager. Swipe right-to-left walks `macros → vitamins → minerals`.
enum NutrientPage: Int, CaseIterable, Identifiable {
    case macros
    case vitamins
    case minerals
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .macros:   return "Macros"
        case .vitamins: return "Vitamins"
        case .minerals: return "Minerals"
        }
    }
}

private struct LogRow: View {
    let log: FoodLog
    let onDelete: () -> Void

    /// Drives the confirmation dialog. The row was previously using
    /// `.swipeActions`, which is silently inert outside of a `List` — so until
    /// now there was no working way for the user to delete a wrongly-scanned
    /// meal. Confirm-before-delete because the action hits Supabase and isn't
    /// undoable from the UI.
    @State private var confirming = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: log.source == .scan ? "camera.fill" : "pencil")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: 36, height: 36)
                .background(Theme.Palette.surfaceHi, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typo.bodyBold)
                    .foregroundStyle(Theme.Palette.text)
                Text(timeString)
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            Spacer()
            Text("\(log.kcal) kcal")
                .font(Theme.Typo.bodyBold)
                .foregroundStyle(Theme.Palette.text)
            deleteButton
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
        .confirmationDialog(
            "Delete this meal?",
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button("Delete \(title)", role: .destructive) {
                Haptics.tapMedium()
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(log.kcal) kcal from today. You can't undo this.")
        }
    }

    private var deleteButton: some View {
        Button {
            Haptics.tapLight()
            confirming = true
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Palette.danger)
                .frame(width: 32, height: 32)
                .background(Theme.Palette.surfaceHi, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete \(title)")
    }

    private var title: String {
        if log.items.count == 1 { return log.items[0].name.capitalized }
        return log.items.first?.name.capitalized ?? "Meal"
    }

    private var timeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: log.loggedAt)
    }
}

#Preview {
    // Loads from Supabase on appear; preview shows the empty/loading layout.
    DashboardView(vm: DashboardViewModel())
        .preferredColorScheme(.dark)
}
