import SwiftUI

struct DashboardView: View {
    @State private var vm = DashboardViewModel()
    @State private var network = NetworkStatus.shared
    @State private var showingScan = false
    @State private var showingManualEntry = false
    @State private var showingWeightCheckIn = false
    @State private var showingProfile = false
    @State private var showingWeekly = false
    @State private var showingEditWeight = false
    @State private var showingEditGoalWeight = false
    @State private var nutrientPage: NutrientPage = .macros

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.lg) {
                    ringCard
                    nutrientPager
                    actionsRow
                    planSection
                    todaySection
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, Theme.Spacing.lg)
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
        .task { await vm.load() }
        .fullScreenCover(isPresented: $showingScan) {
            ScanFlowView { _ in
                showingScan = false
                Task { await vm.load() }
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntrySheet(onSaved: {
                showingManualEntry = false
                Task { await vm.load() }
            })
        }
        .sheet(isPresented: $showingWeightCheckIn) {
            WeightCheckInSheet { showingWeightCheckIn = false }
        }
        .sheet(isPresented: $showingProfile) { ProfileView() }
        .sheet(isPresented: $showingWeekly, onDismiss: { Task { await vm.load() } }) {
            WeeklyProgressView()
        }
        .sheet(isPresented: $showingEditWeight) {
            EditWeightSheet(
                title: "Update current weight",
                initialKg: vm.latestWeight?.weightKg ?? vm.latestGoal?.startWeightKg ?? 70
            ) { newKg in
                Task { await vm.saveCurrentWeight(newKg) }
            }
        }
        .sheet(isPresented: $showingEditGoalWeight) {
            EditWeightSheet(
                title: "Update goal weight",
                initialKg: vm.latestGoal?.goalWeightKg ?? 70
            ) { newKg in
                Task { await vm.saveGoalWeight(newKg) }
            }
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
        Button {
            Haptics.tapLight()
            showingWeekly = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.warning)
                Text("\(vm.streak)")
                    .font(Theme.Typo.bodyBold)
                    .foregroundStyle(Theme.Palette.text)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.Palette.surface, in: Capsule())
        }
        .accessibilityLabel("\(vm.streak) day streak. Tap to view weekly progress.")
    }

    private var ringCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(Theme.Palette.surface, lineWidth: 18)
                Circle()
                    .trim(from: 0, to: min(1, vm.kcalProgress))
                    .stroke(Theme.Gradients.accent, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(Theme.Motion.spring, value: vm.kcalProgress)
                VStack(spacing: 0) {
                    Text("\(vm.kcalRemaining)")
                        .font(Theme.Typo.numeralXL)
                        .foregroundStyle(Theme.Palette.text)
                        .contentTransition(.numericText(value: Double(vm.kcalRemaining)))
                    Text("kcal left")
                        .font(Theme.Typo.body)
                        .foregroundStyle(Theme.Palette.textMuted)
                    if let t = vm.target {
                        Text("of \(t.kcal)")
                            .font(Theme.Typo.caption)
                            .foregroundStyle(Theme.Palette.textDim)
                    }
                }
            }
            .frame(width: 240, height: 240)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Calories remaining")
            .accessibilityValue(ringAccessibilityValue)
        }
    }

    private var ringAccessibilityValue: String {
        guard let t = vm.target else { return "\(vm.kcalRemaining) kilocalories left" }
        return "\(vm.kcalRemaining) of \(t.kcal) kilocalories left"
    }

    /// Horizontal pager: Macros (default) → Vitamins → Minerals.
    /// Swipe right-to-left to advance to the next category.
    private var nutrientPager: some View {
        VStack(spacing: Theme.Spacing.xs) {
            TabView(selection: $nutrientPage) {
                macrosCard.tag(NutrientPage.macros)
                vitaminsCard.tag(NutrientPage.vitamins)
                mineralsCard.tag(NutrientPage.minerals)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 180)

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
        return nutrientCard(title: "Vitamins") {
            nutrientBar(label: "Vitamin D",
                        consumed: consumed.vitaminDMcg ?? 0, target: target.vitaminDMcg ?? 0,
                        unit: "μg", color: Theme.Palette.accent, fractionDigits: 1)
            nutrientBar(label: "Vitamin B12",
                        consumed: consumed.vitaminB12Mcg ?? 0, target: target.vitaminB12Mcg ?? 0,
                        unit: "μg", color: Theme.Palette.accentDeep, fractionDigits: 1)
            nutrientBar(label: "Vitamin C",
                        consumed: consumed.vitaminCMg ?? 0, target: target.vitaminCMg ?? 0,
                        unit: "mg", color: Theme.Palette.accentAlt)
        }
    }

    private var mineralsCard: some View {
        let consumed = vm.microsConsumed
        let target = vm.microsTarget
        return nutrientCard(title: "Minerals") {
            nutrientBar(label: "Magnesium",
                        consumed: consumed.magnesiumMg ?? 0, target: target.magnesiumMg ?? 0,
                        unit: "mg", color: Theme.Palette.accent)
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
        .padding(.horizontal, 2)
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
        digits <= 0
            ? "\(Int(value.rounded()))"
            : String(format: "%.\(digits)f", value)
    }

    private var actionsRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            actionTile(icon: "camera.fill", title: "Scan") {
                showingScan = true
            }
            actionTile(icon: "plus.circle.fill", title: "Manual") {
                showingManualEntry = true
            }
            actionTile(icon: "scalemass.fill", title: "Weight") {
                showingWeightCheckIn = true
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

    @ViewBuilder
    private var planSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Plan")
                .font(Theme.Typo.h3)
                .foregroundStyle(Theme.Palette.text)

            HStack(spacing: Theme.Spacing.sm) {
                weightTile(
                    icon: "scalemass",
                    label: "Current",
                    value: weightString(vm.latestWeight?.weightKg ?? vm.latestGoal?.startWeightKg)
                ) {
                    showingEditWeight = true
                }
                weightTile(
                    icon: "target",
                    label: "Goal",
                    value: weightString(vm.latestGoal?.goalWeightKg)
                ) {
                    showingEditGoalWeight = true
                }
            }

            paceSegmented

            if let current = vm.latestWeight?.weightKg ?? vm.latestGoal?.startWeightKg,
               let goal = vm.latestGoal?.goalWeightKg {
                WeightProjectionChart(
                    currentKg: current,
                    goalKg: goal,
                    pace: vm.pace,
                    heightCm: vm.profile?.heightCm
                )
            }
        }
    }

    private func weightTile(icon: String, label: String, value: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tapLight()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textMuted)
                    Text(label)
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Palette.textMuted)
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textDim)
                }
                Text(value)
                    .font(Theme.Typo.bodyBold)
                    .foregroundStyle(Theme.Palette.text)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
        }
        .accessibilityLabel("\(label) weight \(value). Tap to edit.")
    }

    private var paceSegmented: some View {
        HStack(spacing: 6) {
            ForEach(Pace.allCases) { p in
                paceChip(p)
            }
        }
        .padding(4)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private func paceChip(_ p: Pace) -> some View {
        let selected = vm.pace == p
        return Button {
            Haptics.select()
            Task { await vm.savePace(p) }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: paceIcon(p))
                    .font(.system(size: 14, weight: .semibold))
                Text(paceShortLabel(p))
                    .font(Theme.Typo.caption)
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
        .accessibilityLabel("\(p.label). \(p.subtitle).")
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private func paceIcon(_ pace: Pace) -> String {
        switch pace {
        case .slow:   return "tortoise.fill"
        case .medium: return "figure.walk"
        case .fast:   return "hare.fill"
        }
    }

    private func paceShortLabel(_ pace: Pace) -> String {
        switch pace {
        case .slow:   return "Slow"
        case .medium: return "Balanced"
        case .fast:   return "Faster"
        }
    }

    private func weightString(_ kg: Double?) -> String {
        guard let kg else { return "—" }
        return String(format: "%.1f kg", kg)
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
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "fork.knife")
                .font(.system(size: 36))
                .foregroundStyle(Theme.Palette.textDim)
            Text("Nothing logged yet.")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.textMuted)
            Text("Tap Scan or Manual to log your first meal.")
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Palette.textDim)
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
        case 17..<22: return "Good evening"
        default: return "Late night"
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
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
        .swipeActions {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
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
    DashboardView()
        .preferredColorScheme(.dark)
}
