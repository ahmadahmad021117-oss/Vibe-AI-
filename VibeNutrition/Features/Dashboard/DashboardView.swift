import SwiftUI

struct DashboardView: View {
    @State private var vm = DashboardViewModel()
    @State private var network = NetworkStatus.shared
    @State private var showingScan = false
    @State private var showingManualEntry = false
    @State private var showingWeightCheckIn = false
    @State private var showingProfile = false
    @State private var showingWeekly = false

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                if !network.isOnline {
                    offlineBanner
                }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.lg) {
                        header
                        ringCard
                        macroBars
                        actionsRow
                        todaySection
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)
                }
                .refreshable { await vm.load() }
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
        .preferredColorScheme(.dark)
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 13, weight: .semibold))
            Text("Offline — changes will sync when you reconnect.")
                .font(Theme.Type.caption)
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
                    .font(Theme.Type.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Text(dateString)
                    .font(Theme.Type.h2)
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
                    .font(Theme.Type.bodyBold)
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
                        .font(Theme.Type.numeralXL)
                        .foregroundStyle(Theme.Palette.text)
                        .contentTransition(.numericText(value: Double(vm.kcalRemaining)))
                    Text("kcal left")
                        .font(Theme.Type.body)
                        .foregroundStyle(Theme.Palette.textMuted)
                    if let t = vm.target {
                        Text("of \(t.kcal)")
                            .font(Theme.Type.caption)
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

    private var macroBars: some View {
        VStack(spacing: Theme.Spacing.sm) {
            macroBar(label: "Protein",
                     consumed: vm.proteinConsumed, target: Double(vm.target?.proteinG ?? 0),
                     color: Theme.Palette.accent)
            macroBar(label: "Carbs",
                     consumed: vm.carbsConsumed, target: Double(vm.target?.carbsG ?? 0),
                     color: Theme.Palette.accentDeep)
            macroBar(label: "Fat",
                     consumed: vm.fatConsumed, target: Double(vm.target?.fatG ?? 0),
                     color: Theme.Palette.accentAlt)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
    }

    private func macroBar(label: String, consumed: Double, target: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(Theme.Type.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
                Spacer()
                Text("\(Int(consumed.rounded())) / \(Int(target.rounded())) g")
                    .font(Theme.Type.caption)
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
        .accessibilityValue("\(Int(consumed.rounded())) of \(Int(target.rounded())) grams")
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
                    .font(Theme.Type.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
        }
        .accessibilityLabel(title)
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Today")
                    .font(Theme.Type.h3)
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                Text("\(vm.todayLogs.count) entr\(vm.todayLogs.count == 1 ? "y" : "ies")")
                    .font(Theme.Type.caption)
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
                .font(Theme.Type.body)
                .foregroundStyle(Theme.Palette.textMuted)
            Text("Tap Scan or Manual to log your first meal.")
                .font(Theme.Type.caption)
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
                    .font(Theme.Type.bodyBold)
                    .foregroundStyle(Theme.Palette.text)
                Text(timeString)
                    .font(Theme.Type.caption)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            Spacer()
            Text("\(log.kcal) kcal")
                .font(Theme.Type.bodyBold)
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

