import SwiftUI
import Combine

// MARK: - Models

enum FuelType: String, Codable, CaseIterable, Identifiable {
    case gasoline    = "Gasoline"
    case diesel      = "Diesel"
    case propane     = "Propane"
    case naturalGas  = "Natural Gas"
    case other       = "Other"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .gasoline:   return "fuelpump.fill"
        case .diesel:     return "fuelpump.fill"
        case .propane:    return "flame.fill"
        case .naturalGas: return "flame.fill"
        case .other:      return "bolt.fill"
        }
    }
}

struct OutageEvent: Codable, Identifiable {
    var id          = UUID()
    var startDate   : Date    = Date()
    var endDate     : Date?   = nil
    var cause       : String  = ""
    var notes       : String  = ""

    var isOngoing: Bool { endDate == nil }

    var durationMinutes: Int? {
        guard let end = endDate else { return nil }
        return Int(end.timeIntervalSince(startDate) / 60)
    }

    var durationString: String {
        guard let mins = durationMinutes else { return "Ongoing" }
        let h = mins / 60, m = mins % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}

struct FuelEntry: Codable, Identifiable {
    var id              = UUID()
    var date            : Date     = Date()
    var fuelType        : FuelType = .gasoline
    var gallons         : Double   = 0
    var costPerGallon   : Double   = 0
    var generatorHours  : Double   = 0
    var notes           : String   = ""

    var totalCost: Double { gallons * costPerGallon }
}

struct BatterySnapshot: Codable, Identifiable {
    var id      = UUID()
    var date    : Date   = Date()
    var source  : String = "Powerwall"
    var levelPct: Int    = 100
    var notes   : String = ""
}

// MARK: - Engine

@MainActor
class PowerOutageEngine: ObservableObject {
    static let shared = PowerOutageEngine()

    private let outageKey  = "outage_events_v1"
    private let fuelKey    = "fuel_log_v1"
    private let battKey    = "battery_log_v1"

    @Published var outages    : [OutageEvent]      = []
    @Published var fuelLog    : [FuelEntry]        = []
    @Published var batteryLog : [BatterySnapshot]  = []

    init() { load() }

    // MARK: Persistence
    func save() {
        if let d = try? JSONEncoder().encode(outages)    { UserDefaults.standard.set(d, forKey: outageKey) }
        if let d = try? JSONEncoder().encode(fuelLog)    { UserDefaults.standard.set(d, forKey: fuelKey) }
        if let d = try? JSONEncoder().encode(batteryLog) { UserDefaults.standard.set(d, forKey: battKey) }
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: outageKey),
           let v = try? JSONDecoder().decode([OutageEvent].self, from: d) { outages = v }
        if let d = UserDefaults.standard.data(forKey: fuelKey),
           let v = try? JSONDecoder().decode([FuelEntry].self, from: d) { fuelLog = v }
        if let d = UserDefaults.standard.data(forKey: battKey),
           let v = try? JSONDecoder().decode([BatterySnapshot].self, from: d) { batteryLog = v }
    }

    // MARK: Actions
    func startOutage(cause: String = "") {
        // Close any open outage first
        if let idx = outages.firstIndex(where: { $0.isOngoing }) {
            outages[idx].endDate = Date()
        }
        var e = OutageEvent(); e.cause = cause
        outages.insert(e, at: 0)
        save()
    }

    func endOutage() {
        if let idx = outages.firstIndex(where: { $0.isOngoing }) {
            outages[idx].endDate = Date()
            save()
        }
    }

    func upsertOutage(_ event: OutageEvent) {
        if let idx = outages.firstIndex(where: { $0.id == event.id }) {
            outages[idx] = event
        } else {
            outages.insert(event, at: 0)
        }
        save()
    }

    func deleteOutage(_ event: OutageEvent) {
        outages.removeAll { $0.id == event.id }; save()
    }

    func addFuel(_ entry: FuelEntry) { fuelLog.insert(entry, at: 0); save() }
    func deleteFuel(_ entry: FuelEntry) { fuelLog.removeAll { $0.id == entry.id }; save() }

    func addSnapshot(_ snap: BatterySnapshot) { batteryLog.insert(snap, at: 0); save() }
    func deleteSnapshot(_ snap: BatterySnapshot) { batteryLog.removeAll { $0.id == snap.id }; save() }

    // MARK: Stats
    var currentOutage: OutageEvent? { outages.first(where: { $0.isOngoing }) }

    var outagesThisYear: [OutageEvent] {
        let start = Calendar.current.startOfYear
        return outages.filter { $0.startDate >= start }
    }

    var avgDurationHours: Double? {
        let completed = outagesThisYear.compactMap { $0.durationMinutes }
        guard !completed.isEmpty else { return nil }
        return Double(completed.reduce(0, +)) / Double(completed.count) / 60.0
    }

    var totalFuelGallons: Double { fuelLog.reduce(0) { $0 + $1.gallons } }
    var totalFuelCost: Double    { fuelLog.reduce(0) { $0 + $1.totalCost } }
}

private extension Calendar {
    var startOfYear: Date {
        let comps = DateComponents(year: dateComponents([.year], from: Date()).year)
        return date(from: comps) ?? Date()
    }
}

// MARK: - Main View

struct PowerOutageView: View {
    @StateObject private var engine = PowerOutageEngine.shared
    @State private var tab: Int = 0
    @State private var showOutageSheet = false
    @State private var showFuelSheet   = false
    @State private var showBattSheet   = false
    @State private var editingOutage: OutageEvent? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Status card
            statusCard
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.04))

            Picker("", selection: $tab) {
                Text("Outage History").tag(0)
                Text("Fuel Log").tag(1)
                Text("Battery Log").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            Divider().opacity(0.3)

            switch tab {
            case 0: outageHistoryTab
            case 1: fuelTab
            case 2: batteryTab
            default: EmptyView()
            }
        }
        .sheet(isPresented: $showOutageSheet) {
            OutageEventSheet(event: OutageEvent()) { engine.upsertOutage($0) }
        }
        .sheet(item: $editingOutage) { ev in
            OutageEventSheet(event: ev) { engine.upsertOutage($0) }
        }
        .sheet(isPresented: $showFuelSheet) {
            FuelEntrySheet { engine.addFuel($0) }
        }
        .sheet(isPresented: $showBattSheet) {
            BatterySnapshotSheet { engine.addSnapshot($0) }
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        HStack(spacing: 20) {
            // Power status
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(engine.currentOutage != nil
                              ? Color.red.opacity(0.18) : Color.green.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: engine.currentOutage != nil ? "bolt.slash.fill" : "bolt.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(engine.currentOutage != nil ? .red : .green)
                        .symbolEffect(.pulse, isActive: engine.currentOutage != nil)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.currentOutage != nil ? "OUTAGE IN PROGRESS" : "Power Normal")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(engine.currentOutage != nil ? .red : .green)
                    if let ev = engine.currentOutage {
                        Text(relativeDuration(from: ev.startDate))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider().frame(height: 36)

            // Stats
            Group {
                MiniStat(label: "This Year", value: "\(engine.outagesThisYear.count)", unit: "outages")
                if let avg = engine.avgDurationHours {
                    MiniStat(label: "Avg Duration", value: String(format: "%.1f", avg), unit: "hrs")
                }
                MiniStat(label: "Total Fuel", value: String(format: "%.1f", engine.totalFuelGallons), unit: "gal")
            }

            Spacer()

            // Quick actions
            VStack(spacing: 6) {
                if engine.currentOutage != nil {
                    Button("End Outage") { engine.endOutage() }
                        .buttonStyle(.borderedProminent).tint(.green)
                        .font(.system(size: 12, weight: .semibold))
                } else {
                    Button("Log Outage Start") { engine.startOutage() }
                        .buttonStyle(.borderedProminent).tint(.red)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
        }
    }

    // MARK: - Outage History

    private var outageHistoryTab: some View {
        Group {
            if engine.outages.isEmpty {
                ContentUnavailableView("No Outages Logged",
                    systemImage: "bolt.fill",
                    description: Text("Use \"Log Outage Start\" when power goes out."))
            } else {
                List {
                    ForEach(engine.outages) { ev in
                        OutageRow(event: ev)
                            .contentShape(Rectangle())
                            .onTapGesture { editingOutage = ev }
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { idx in idx.forEach { engine.deleteOutage(engine.outages[$0]) } }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Fuel

    private var fuelTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(format: "Total: %.1f gal · $%.2f", engine.totalFuelGallons, engine.totalFuelCost))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button { showFuelSheet = true } label: {
                    Label("Add Entry", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent).tint(.orange)
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            Divider().opacity(0.3)

            if engine.fuelLog.isEmpty {
                ContentUnavailableView("No Fuel Entries", systemImage: "fuelpump.fill")
            } else {
                List {
                    ForEach(engine.fuelLog) { entry in
                        FuelRow(entry: entry)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { idx in idx.forEach { engine.deleteFuel(engine.fuelLog[$0]) } }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Battery

    private var batteryTab: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { showBattSheet = true } label: {
                    Label("Log Reading", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent).tint(.orange)
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            Divider().opacity(0.3)

            if engine.batteryLog.isEmpty {
                ContentUnavailableView("No Battery Readings", systemImage: "battery.100")
            } else {
                List {
                    ForEach(engine.batteryLog) { snap in
                        BatteryRow(snapshot: snap)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { idx in idx.forEach { engine.deleteSnapshot(engine.batteryLog[$0]) } }
                }
                .listStyle(.plain)
            }
        }
    }

    private func relativeDuration(from date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 60 { return "\(mins)m elapsed" }
        let h = mins / 60, m = mins % 60
        return m == 0 ? "\(h)h elapsed" : "\(h)h \(m)m elapsed"
    }
}

// MARK: - Rows

private struct OutageRow: View {
    let event: OutageEvent
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.isOngoing ? "bolt.slash.fill" : "bolt.fill")
                .foregroundStyle(event.isOngoing ? .red : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.startDate, style: .date)
                        .font(.system(size: 13, weight: .medium))
                    if event.isOngoing {
                        Text("ONGOING")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                    }
                    Spacer()
                    Text(event.durationString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if !event.cause.isEmpty {
                    Text(event.cause).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FuelRow: View {
    let entry: FuelEntry
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.fuelType.symbol)
                .foregroundStyle(.orange).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(entry.gallons, specifier: "%.1f") gal \(entry.fuelType.rawValue)")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(entry.totalCost > 0 ? String(format: "$%.2f", entry.totalCost) : "")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
                Text(entry.date, style: .date)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct BatteryRow: View {
    let snapshot: BatterySnapshot
    var color: Color { snapshot.levelPct > 60 ? .green : snapshot.levelPct > 20 ? .yellow : .red }
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "battery.75percent")
                .foregroundStyle(color).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(snapshot.source) — \(snapshot.levelPct)%")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(snapshot.date, style: .date)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 3).fill(color)
                            .frame(width: geo.size.width * CGFloat(snapshot.levelPct) / 100)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MiniStat: View {
    let label: String; let value: String; let unit: String
    var body: some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded))
            Text("\(unit)\n\(label)").font(.system(size: 9)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Sheets

struct OutageEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var event: OutageEvent
    @State private var hasEnd: Bool
    private let onSave: (OutageEvent) -> Void

    init(event: OutageEvent, onSave: @escaping (OutageEvent) -> Void) {
        _event  = State(initialValue: event)
        _hasEnd = State(initialValue: event.endDate != nil)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Outage Event").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(event); dismiss() }.buttonStyle(.borderedProminent).tint(.orange)
            }.padding()
            Divider()
            Form {
                Section {
                    DatePicker("Start", selection: $event.startDate)
                    Toggle("Outage Ended", isOn: $hasEnd)
                        .onChange(of: hasEnd) { _, on in
                            event.endDate = on ? (event.endDate ?? Date()) : nil
                        }
                    if hasEnd {
                        DatePicker("End", selection: Binding(
                            get: { event.endDate ?? Date() },
                            set: { event.endDate = $0 }))
                    }
                }
                Section {
                    TextField("Cause (utility outage, storm…)", text: $event.cause)
                    TextField("Notes", text: $event.notes, axis: .vertical).lineLimit(3...5)
                }
            }.formStyle(.grouped)
        }.frame(minWidth: 400, minHeight: 380)
    }
}

struct FuelEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entry = FuelEntry()
    private let onSave: (FuelEntry) -> Void
    init(onSave: @escaping (FuelEntry) -> Void) { self.onSave = onSave }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Fuel Entry").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(entry); dismiss() }.buttonStyle(.borderedProminent).tint(.orange)
            }.padding()
            Divider()
            Form {
                DatePicker("Date", selection: $entry.date, displayedComponents: .date)
                Picker("Fuel Type", selection: $entry.fuelType) {
                    ForEach(FuelType.allCases) { Text($0.rawValue).tag($0) }
                }
                HStack { Text("Gallons"); Spacer()
                    TextField("0.0", value: $entry.gallons, format: .number)
                        .multilineTextAlignment(.trailing).frame(width: 80) }
                HStack { Text("Cost / gallon ($)"); Spacer()
                    TextField("0.00", value: $entry.costPerGallon, format: .number)
                        .multilineTextAlignment(.trailing).frame(width: 80) }
                HStack { Text("Generator hours run"); Spacer()
                    TextField("0.0", value: $entry.generatorHours, format: .number)
                        .multilineTextAlignment(.trailing).frame(width: 80) }
                TextField("Notes", text: $entry.notes, axis: .vertical).lineLimit(3...5)
            }.formStyle(.grouped)
        }.frame(minWidth: 380, minHeight: 420)
    }
}

struct BatterySnapshotSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var snap = BatterySnapshot()
    private let onSave: (BatterySnapshot) -> Void
    init(onSave: @escaping (BatterySnapshot) -> Void) { self.onSave = onSave }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Battery Reading").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(snap); dismiss() }.buttonStyle(.borderedProminent).tint(.orange)
            }.padding()
            Divider()
            Form {
                DatePicker("Date / Time", selection: $snap.date)
                TextField("Source (Powerwall, Generator…)", text: $snap.source)
                HStack {
                    Text("Battery Level")
                    Spacer()
                    Slider(value: Binding(
                        get: { Double(snap.levelPct) },
                        set: { snap.levelPct = Int($0) }
                    ), in: 0...100, step: 1)
                    .frame(width: 140)
                    Text("\(snap.levelPct)%").frame(width: 36)
                }
                TextField("Notes", text: $snap.notes, axis: .vertical).lineLimit(3...5)
            }.formStyle(.grouped)
        }.frame(minWidth: 380, minHeight: 340)
    }
}
