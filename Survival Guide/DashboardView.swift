import SwiftUI
import Combine

// MARK: - Dashboard View

struct DashboardView: View {
    @StateObject private var foodEngine    = FoodRotationEngine.shared
    @StateObject private var powerEngine   = PowerOutageEngine.shared
    @StateObject private var supplyStore   = SupplyEngine()          // local read-only snapshot
    @StateObject private var skillStore    = SkillTreeStore.shared
    @StateObject private var drillEngine   = DrillEngine.shared
    @StateObject private var seedEngine    = SeedBankEngine.shared
    @StateObject private var medEngine     = MedicationEngine.shared
    @StateObject private var settingsStore = AppSettingsStore.shared

    @EnvironmentObject private var locationStore: LocationStore
    @EnvironmentObject private var supplyEngine : SupplyEngine

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                locationHeader
                statusRow
                alertsSection
                statsGrid
                bottomRow
            }
            .padding(20)
        }
    }

    // MARK: - Location Header

    private var locationHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(locationStore.config.displayName.isEmpty
                     ? "Survival Guide" : locationStore.config.displayName)
                    .font(.system(size: 24, weight: .bold))
                HStack(spacing: 6) {
                    ForEach(locationStore.config.regionTypes, id: \.self) { r in
                        Label(r.rawValue, systemImage: r.symbol)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            // Hazard badges
            HStack(spacing: 4) {
                ForEach(locationStore.config.hazards.prefix(5), id: \.self) { h in
                    Image(systemName: h.symbol)
                        .font(.system(size: 13))
                        .foregroundStyle(h.color)
                        .padding(6)
                        .background(h.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Status Row

    private var statusRow: some View {
        HStack(spacing: 12) {
            // Power
            StatusCard(
                symbol: powerEngine.currentOutage != nil ? "bolt.slash.fill" : "bolt.fill",
                title: powerEngine.currentOutage != nil ? "OUTAGE" : "Power Normal",
                subtitle: powerEngine.currentOutage.map { outageElapsed($0.startDate) } ?? "\(powerEngine.outagesThisYear.count) outages this year",
                color: powerEngine.currentOutage != nil ? .red : .green,
                pulse: powerEngine.currentOutage != nil
            )

            // Food supply
            let dailyCal = dailyCalories
            let days = dailyCal > 0 ? foodEngine.totalCalories / dailyCal : 0
            StatusCard(
                symbol: "cart.fill",
                title: days >= 30 ? "Food Supply OK" : days >= 7 ? "Low Food Supply" : "Critical: Food",
                subtitle: String(format: "%.0f days · %.0f cal total", days, foodEngine.totalCalories),
                color: days >= 30 ? .green : days >= 7 ? .yellow : .red,
                pulse: days < 7
            )

            // Skills
            let skillPct = allSkills.isEmpty ? 0.0 : Double(skillStore.completed.count) / Double(allSkills.count)
            StatusCard(
                symbol: "brain.fill",
                title: "Skills",
                subtitle: String(format: "%d/%d learned (%.0f%%)", skillStore.completed.count, allSkills.count, skillPct * 100),
                color: skillPct >= 0.5 ? .green : skillPct >= 0.25 ? .yellow : .orange,
                pulse: false
            )

            // Drills
            let overdue = drillEngine.overdue.count
            StatusCard(
                symbol: "checklist",
                title: overdue == 0 ? "Drills Current" : "\(overdue) Overdue",
                subtitle: drillEngine.upcoming.first.flatMap { s in
                    s.nextScheduled.map { "Next: \($0.formatted(date: .abbreviated, time: .omitted))" }
                } ?? "\(drillEngine.sessionsThisYear.count) drills this year",
                color: overdue == 0 ? .green : .orange,
                pulse: overdue > 0
            )
        }
    }

    // MARK: - Alerts Section

    @ViewBuilder
    private var alertsSection: some View {
        let expiring = foodEngine.expiringSoon
        let lowSupply = supplyEngine.items.filter { $0.daysRemaining != nil && $0.daysRemaining! < 7 }
        let overdueD  = drillEngine.overdue

        let hasAlerts = !expiring.isEmpty || !lowSupply.isEmpty || !overdueD.isEmpty

        if hasAlerts {
            VStack(alignment: .leading, spacing: 8) {
                Label("Attention Needed", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)

                VStack(spacing: 6) {
                    if !expiring.isEmpty {
                        AlertRow(
                            symbol: "cart.badge.minus",
                            color: .red,
                            text: "\(expiring.count) food item\(expiring.count == 1 ? "" : "s") expiring within 30 days",
                            detail: expiring.prefix(3).map(\.name).joined(separator: ", ")
                        )
                    }
                    if !lowSupply.isEmpty {
                        AlertRow(
                            symbol: "drop.triangle.fill",
                            color: .orange,
                            text: "\(lowSupply.count) supply item\(lowSupply.count == 1 ? "" : "s") running low",
                            detail: lowSupply.prefix(3).map(\.name).joined(separator: ", ")
                        )
                    }
                    if !overdueD.isEmpty {
                        AlertRow(
                            symbol: "exclamationmark.circle.fill",
                            color: .yellow,
                            text: "\(overdueD.count) drill type\(overdueD.count == 1 ? "" : "s") overdue",
                            detail: overdueD.prefix(3).map(\.0.rawValue).joined(separator: ", ")
                        )
                    }
                }
            }
            .padding(16)
            .background(Color.orange.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.2)))
        }
    }

    // MARK: - Stats Grid

    private var waterDays: Double {
        guard supplyEngine.household.waterNeededPerDay > 0 else { return 0 }
        let gallons = supplyEngine.items
            .filter { $0.category == .water }
            .reduce(0.0) { $0 + $1.quantity }
        return gallons / supplyEngine.household.waterNeededPerDay
    }

    private var statsGrid: some View {
        let wd = waterDays
        return LazyVGrid(columns: columns, spacing: 12) {
            StatGridCard(
                symbol: "drop.fill", color: .blue, title: "Water Supply",
                value: String(format: "%.0f", wd), unit: "days",
                status: wd >= 14 ? .good : wd >= 3 ? .warn : .bad
            )

            // Medications
            StatGridCard(
                symbol: "pills.fill", color: .red, title: "Medications",
                value: "\(medEngine.medications.count)", unit: "tracked",
                status: .neutral
            )

            // Seed varieties
            StatGridCard(
                symbol: "leaf.fill", color: .green, title: "Seed Bank",
                value: "\(seedEngine.seeds.count)", unit: "varieties",
                status: .neutral
            )

            // Water sources
            let wsEngine = WaterSourceEngine.shared
            StatGridCard(
                symbol: "map.fill", color: .cyan, title: "Water Sources",
                value: "\(wsEngine.sources.count)", unit: "mapped",
                status: wsEngine.sources.isEmpty ? .warn : .good
            )

            // Total fuel logged
            StatGridCard(
                symbol: "fuelpump.fill", color: .yellow, title: "Fuel Logged",
                value: String(format: "%.0f", powerEngine.totalFuelGallons), unit: "gallons",
                status: .neutral
            )

            // Garden beds
            StatGridCard(
                symbol: "square.grid.2x2.fill", color: .teal, title: "Garden Beds",
                value: "\(seedEngine.beds.count)", unit: "beds",
                status: .neutral
            )
        }
    }

    // MARK: - Bottom Row

    private var bottomRow: some View {
        HStack(alignment: .top, spacing: 12) {
            // Seeds this month
            thisMonthSeeds

            // Upcoming drills
            upcomingDrillsCard
        }
    }

    private var thisMonthSeeds: some View {
        let month = Calendar.current.component(.month, from: Date())
        let tasks = seedEngine.seedsForMonth(month)
        let monthName = Calendar.current.monthSymbols[month - 1]

        return VStack(alignment: .leading, spacing: 8) {
            Label("Plant in \(monthName)", systemImage: "calendar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)

            if tasks.indoor.isEmpty && tasks.direct.isEmpty {
                Text("No planting tasks for this month.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                if !tasks.indoor.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Start Indoors").font(.system(size: 11, weight: .semibold)).foregroundStyle(.yellow)
                        ForEach(tasks.indoor.prefix(4)) { s in
                            Text("• \(s.commonName)\(s.variety.isEmpty ? "" : " (\(s.variety))")")
                                .font(.system(size: 11))
                        }
                    }
                }
                if !tasks.direct.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Direct Sow").font(.system(size: 11, weight: .semibold)).foregroundStyle(.green)
                        ForEach(tasks.direct.prefix(4)) { s in
                            Text("• \(s.commonName)\(s.variety.isEmpty ? "" : " (\(s.variety))")")
                                .font(.system(size: 11))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private var upcomingDrillsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Upcoming Drills", systemImage: "calendar.badge.clock")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue)

            if drillEngine.upcoming.isEmpty {
                Text("No drills scheduled.\nVisit Drills & Practice to plan your next drill.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                ForEach(drillEngine.upcoming.prefix(4)) { s in
                    HStack {
                        Image(systemName: s.type.symbol)
                            .font(.system(size: 11))
                            .foregroundStyle(s.type.color)
                        Text(s.type.rawValue)
                            .font(.system(size: 12)).lineLimit(1)
                        Spacer()
                        if let next = s.nextScheduled {
                            Text(next, style: .date)
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private var dailyCalories: Double {
        let hh = supplyEngine.household
        return Double(hh.adults) * settingsStore.settings.dailyCaloriesAdult
             + Double(hh.children) * settingsStore.settings.dailyCaloriesChild
    }

    private func outageElapsed(_ start: Date) -> String {
        let mins = Int(Date().timeIntervalSince(start) / 60)
        let h = mins / 60, m = mins % 60
        return h == 0 ? "\(m)m elapsed" : "\(h)h \(m)m elapsed"
    }
}

// MARK: - Sub-components

private struct StatusCard: View {
    let symbol  : String
    let title   : String
    let subtitle: String
    let color   : Color
    let pulse   : Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                    .symbolEffect(.pulse, isActive: pulse)
                Spacer()
                Circle().fill(color).frame(width: 8, height: 8)
                    .opacity(pulse ? 1 : 0.4)
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2)))
    }
}

private enum StatStatus { case good, warn, bad, neutral }

private struct StatGridCard: View {
    let symbol: String
    let color : Color
    let title : String
    let value : String
    let unit  : String
    let status: StatStatus

    private var dotColor: Color {
        switch status {
        case .good:    return .green
        case .warn:    return .yellow
        case .bad:     return .red
        case .neutral: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value).font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(unit).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Circle().fill(dotColor).frame(width: 7, height: 7)
        }
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct AlertRow: View {
    let symbol: String
    let color : Color
    let text  : String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(text).font(.system(size: 12, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
