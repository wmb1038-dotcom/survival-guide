import SwiftUI
import Combine

// MARK: - Models

enum SunNeeds: String, Codable, CaseIterable, Identifiable {
    case fullSun    = "Full Sun"
    case partialSun = "Partial Sun"
    case shade      = "Shade"
    var id: String { rawValue }
}

enum SeedUnit: String, Codable, CaseIterable, Identifiable {
    case packets = "packets"
    case ounces  = "oz"
    case seeds   = "seeds"
    case pounds  = "lbs"
    var id: String { rawValue }
}

struct SeedEntry: Codable, Identifiable {
    var id                   = UUID()
    var commonName           : String       = ""
    var variety              : String       = ""
    var quantity             : Double       = 1
    var unit                 : SeedUnit     = .packets
    var yearHarvested        : Int?         = nil
    var daysToMaturity       : Int          = 70
    var sunNeeds             : SunNeeds     = .fullSun
    var indoorStartWeeksBefore: Int         = 0    // 0 = direct sow
    var plantingMonths       : [Int]        = []   // 1–12
    var notes                : String       = ""

    var isLowStock: Bool { quantity <= 1 }

    var plantingMonthsDisplay: String {
        guard !plantingMonths.isEmpty else { return "Unset" }
        return plantingMonths.sorted().map { Calendar.current.shortMonthSymbols[$0 - 1] }.joined(separator: ", ")
    }
}

struct GardenBed: Codable, Identifiable {
    var id               = UUID()
    var name             : String  = ""
    var widthFt          : Double  = 4
    var lengthFt         : Double  = 8
    var currentCrop      : String  = ""
    var plantedDate      : Date?   = nil
    var expectedHarvest  : Date?   = nil
    var notes            : String  = ""

    var squareFeet: Double { widthFt * lengthFt }

    var daysToHarvest: Int? {
        guard let exp = expectedHarvest else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: exp).day ?? 0)
    }
}

// MARK: - Engine

@MainActor
class SeedBankEngine: ObservableObject {
    static let shared = SeedBankEngine()
    private let seedKey = "seeds_v1"
    private let bedKey  = "garden_beds_v1"

    @Published var seeds : [SeedEntry]  = []
    @Published var beds  : [GardenBed]  = []

    init() { load() }

    func save() {
        if let d = try? JSONEncoder().encode(seeds) { UserDefaults.standard.set(d, forKey: seedKey) }
        if let d = try? JSONEncoder().encode(beds)  { UserDefaults.standard.set(d, forKey: bedKey) }
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: seedKey),
           let v = try? JSONDecoder().decode([SeedEntry].self, from: d) { seeds = v }
        if let d = UserDefaults.standard.data(forKey: bedKey),
           let v = try? JSONDecoder().decode([GardenBed].self, from: d) { beds = v }
    }

    func upsertSeed(_ s: SeedEntry) {
        if let i = seeds.firstIndex(where: { $0.id == s.id }) { seeds[i] = s } else { seeds.append(s) }
        save()
    }
    func deleteSeed(_ s: SeedEntry) { seeds.removeAll { $0.id == s.id }; save() }

    func upsertBed(_ b: GardenBed) {
        if let i = beds.firstIndex(where: { $0.id == b.id }) { beds[i] = b } else { beds.append(b) }
        save()
    }
    func deleteBed(_ b: GardenBed) { beds.removeAll { $0.id == b.id }; save() }

    /// Seeds that should be started indoors or direct-sown this month
    func seedsForMonth(_ month: Int) -> (indoor: [SeedEntry], direct: [SeedEntry]) {
        let indoor = seeds.filter { s in
            guard s.indoorStartWeeksBefore > 0 else { return false }
            return s.plantingMonths.contains { targetMonth in
                let startMonth = targetMonth - Int(ceil(Double(s.indoorStartWeeksBefore) / 4.0))
                return ((startMonth - 1 + 12) % 12 + 1) == month
            }
        }
        let direct = seeds.filter { s in
            s.indoorStartWeeksBefore == 0 && s.plantingMonths.contains(month)
        }
        return (indoor, direct)
    }

    /// Frost months derived from ClimateDatabase temperature data
    func frostMonths(nearestClimateCity: String) -> Set<Int> {
        guard !nearestClimateCity.isEmpty,
              let cityData = climateDatabase.first(where: { $0.city == nearestClimateCity })
        else { return [] }
        return Set(cityData.months.filter { $0.lowF < 32 }.map { $0.month })
    }
}

// MARK: - Main View

struct SeedBankView: View {
    @StateObject private var engine = SeedBankEngine.shared
    @EnvironmentObject var locationStore: LocationStore
    @State private var tab = 0
    @State private var showAddSeed = false
    @State private var showAddBed  = false
    @State private var editSeed: SeedEntry?  = nil
    @State private var editBed:  GardenBed?  = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                StatBadge(value: "\(engine.seeds.count)", label: "Varieties", color: .green)
                StatBadge(value: "\(engine.beds.count)", label: "Garden Beds", color: .teal)
                let low = engine.seeds.filter { $0.isLowStock }.count
                if low > 0 {
                    StatBadge(value: "\(low)", label: "Low Stock", color: .yellow)
                }
                Spacer()
                Button { showAddSeed = true } label: {
                    Label("Add Seed", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent).tint(.green)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(Color.white.opacity(0.04))

            Picker("", selection: $tab) {
                Text("Seed Inventory").tag(0)
                Text("Garden Beds").tag(1)
                Text("Planting Calendar").tag(2)
            }
            .pickerStyle(.segmented).padding(.horizontal, 20).padding(.vertical, 10)
            Divider().opacity(0.3)

            switch tab {
            case 0: seedInventoryTab
            case 1: gardenBedsTab
            case 2: plantingCalendarTab
            default: EmptyView()
            }
        }
        .sheet(isPresented: $showAddSeed) { SeedEntrySheet(seed: SeedEntry()) { engine.upsertSeed($0) } }
        .sheet(item: $editSeed)           { s in SeedEntrySheet(seed: s) { engine.upsertSeed($0) } }
        .sheet(isPresented: $showAddBed)  { GardenBedSheet(bed: GardenBed()) { engine.upsertBed($0) } }
        .sheet(item: $editBed)            { b in GardenBedSheet(bed: b) { engine.upsertBed($0) } }
    }

    // MARK: Seed Inventory

    private var seedInventoryTab: some View {
        Group {
            if engine.seeds.isEmpty {
                ContentUnavailableView("No Seeds",
                    systemImage: "leaf.fill",
                    description: Text("Add seeds to track your inventory and planting schedule."))
            } else {
                List {
                    ForEach(engine.seeds) { seed in
                        SeedRow(seed: seed)
                            .contentShape(Rectangle())
                            .onTapGesture { editSeed = seed }
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { idx in idx.forEach { engine.deleteSeed(engine.seeds[$0]) } }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: Garden Beds

    private var gardenBedsTab: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { showAddBed = true } label: {
                    Label("Add Bed", systemImage: "plus").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent).tint(.teal)
            }
            .padding(.horizontal, 20).padding(.vertical, 8)
            Divider().opacity(0.3)

            if engine.beds.isEmpty {
                ContentUnavailableView("No Garden Beds", systemImage: "square.3.layers.3d")
            } else {
                List {
                    ForEach(engine.beds) { bed in
                        BedRow(bed: bed)
                            .contentShape(Rectangle())
                            .onTapGesture { editBed = bed }
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { idx in idx.forEach { engine.deleteBed(engine.beds[$0]) } }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: Planting Calendar

    private var plantingCalendarTab: some View {
        let city = locationStore.config.nearestClimateCity
        let frostMonths = engine.frostMonths(nearestClimateCity: city)
        let monthSymbols = Calendar.current.shortMonthSymbols
        let currentMonth = Calendar.current.component(.month, from: Date())

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !city.isEmpty && !frostMonths.isEmpty {
                    Text("❄️ Frost months for \(city): \(frostMonths.sorted().map { monthSymbols[$0-1] }.joined(separator: ", "))")
                        .font(.system(size: 12))
                        .foregroundStyle(.cyan.opacity(0.8))
                        .padding(.horizontal, 20)
                }

                ForEach(1...12, id: \.self) { month in
                    let tasks = engine.seedsForMonth(month)
                    if !tasks.indoor.isEmpty || !tasks.direct.isEmpty {
                        CalendarMonthBlock(
                            month: monthSymbols[month - 1],
                            isCurrent: month == currentMonth,
                            isFrost: frostMonths.contains(month),
                            indoorSeeds: tasks.indoor,
                            directSeeds: tasks.direct
                        )
                        .padding(.horizontal, 20)
                    }
                }

                if engine.seeds.isEmpty {
                    Text("Add seeds and set their planting months to see the calendar.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(20)
                } else if (1...12).allSatisfy({ engine.seedsForMonth($0).indoor.isEmpty && engine.seedsForMonth($0).direct.isEmpty }) {
                    Text("Set planting months on your seeds to populate the calendar.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(20)
                }
            }
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Calendar Month Block

private struct CalendarMonthBlock: View {
    let month: String
    let isCurrent: Bool
    let isFrost: Bool
    let indoorSeeds: [SeedEntry]
    let directSeeds: [SeedEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(month.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(isCurrent ? .orange : .primary)
                if isCurrent {
                    Text("← NOW")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.orange)
                }
                if isFrost {
                    Label("Frost Risk", systemImage: "snowflake")
                        .font(.system(size: 10))
                        .foregroundStyle(.cyan)
                }
            }
            if !indoorSeeds.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "house.fill").font(.system(size: 9)).foregroundStyle(.yellow)
                    Text("Start Indoors: ") .font(.system(size: 11, weight: .medium)).foregroundStyle(.yellow)
                    + Text(indoorSeeds.map { "\($0.commonName)\($0.variety.isEmpty ? "" : " (\($0.variety))")" }.joined(separator: ", "))
                        .font(.system(size: 11)).foregroundStyle(.primary)
                }
            }
            if !directSeeds.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "sun.max.fill").font(.system(size: 9)).foregroundStyle(.green)
                    Text("Direct Sow: ").font(.system(size: 11, weight: .medium)).foregroundStyle(.green)
                    + Text(directSeeds.map { "\($0.commonName)\($0.variety.isEmpty ? "" : " (\($0.variety))")" }.joined(separator: ", "))
                        .font(.system(size: 11)).foregroundStyle(.primary)
                }
            }
        }
        .padding(10)
        .background(
            isCurrent
                ? Color.orange.opacity(0.08)
                : Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrent ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Rows

private struct SeedRow: View {
    let seed: SeedEntry
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(seed.isLowStock ? .yellow : .green)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(seed.commonName.isEmpty ? "Unnamed" : seed.commonName)
                        .font(.system(size: 13, weight: .medium))
                    if !seed.variety.isEmpty {
                        Text("(\(seed.variety))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(seed.quantity, specifier: "%.4g") \(seed.unit.rawValue)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(seed.isLowStock ? .yellow : .secondary)
                }
                HStack(spacing: 8) {
                    Text("\(seed.daysToMaturity)d · \(seed.sunNeeds.rawValue)")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    if !seed.plantingMonths.isEmpty {
                        Text(seed.plantingMonthsDisplay)
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 3)
    }
}

private struct BedRow: View {
    let bed: GardenBed
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.grid.2x2.fill")
                .foregroundStyle(.teal).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(bed.name.isEmpty ? "Unnamed Bed" : bed.name)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(String(format: "%.0f sq ft", bed.squareFeet))
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    if !bed.currentCrop.isEmpty {
                        Text(bed.currentCrop).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    if let days = bed.daysToHarvest {
                        Text("Harvest in \(days)d")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(days < 14 ? .green : .secondary)
                    }
                }
            }
        }
        .padding(.vertical, 3)
    }
}

private struct StatBadge: View {
    let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Seed Entry Sheet

struct SeedEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var seed: SeedEntry
    @State private var hasYear = false
    private let onSave: (SeedEntry) -> Void

    init(seed: SeedEntry, onSave: @escaping (SeedEntry) -> Void) {
        _seed    = State(initialValue: seed)
        _hasYear = State(initialValue: seed.yearHarvested != nil)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(seed.commonName.isEmpty ? "New Seed" : seed.commonName)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(seed); dismiss() }
                    .buttonStyle(.borderedProminent).tint(.green)
                    .disabled(seed.commonName.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding()
            Divider()
            Form {
                Section("Identity") {
                    TextField("Common Name (e.g. Tomato)", text: $seed.commonName)
                    TextField("Variety (e.g. Cherokee Purple)", text: $seed.variety)
                }
                Section("Quantity") {
                    HStack {
                        Text("Quantity"); Spacer()
                        TextField("Qty", value: $seed.quantity, format: .number)
                            .multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    Picker("Unit", selection: $seed.unit) {
                        ForEach(SeedUnit.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("Has harvest year", isOn: $hasYear)
                        .onChange(of: hasYear) { _, on in
                            seed.yearHarvested = on ? (seed.yearHarvested ?? Calendar.current.component(.year, from: Date())) : nil
                        }
                    if hasYear {
                        HStack {
                            Text("Year Harvested"); Spacer()
                            TextField("Year", value: Binding(
                                get: { seed.yearHarvested ?? 2024 },
                                set: { seed.yearHarvested = $0 }
                            ), format: .number).multilineTextAlignment(.trailing).frame(width: 80)
                        }
                    }
                }
                Section("Growing") {
                    HStack {
                        Text("Days to Maturity"); Spacer()
                        TextField("Days", value: $seed.daysToMaturity, format: .number)
                            .multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    Picker("Sun", selection: $seed.sunNeeds) {
                        ForEach(SunNeeds.allCases) { Text($0.rawValue).tag($0) }
                    }
                    HStack {
                        Text("Wks to start indoors (0 = direct)")
                        Spacer()
                        TextField("Wks", value: $seed.indoorStartWeeksBefore, format: .number)
                            .multilineTextAlignment(.trailing).frame(width: 60)
                    }
                }
                Section("Planting Months") {
                    let symbols = Calendar.current.shortMonthSymbols
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 6) {
                        ForEach(1...12, id: \.self) { m in
                            let selected = seed.plantingMonths.contains(m)
                            Button {
                                if selected { seed.plantingMonths.removeAll { $0 == m } }
                                else        { seed.plantingMonths.append(m) }
                            } label: {
                                Text(symbols[m - 1])
                                    .font(.system(size: 11, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(selected ? Color.green.opacity(0.3) : Color.white.opacity(0.06),
                                                in: RoundedRectangle(cornerRadius: 5))
                                    .foregroundStyle(selected ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section { TextField("Notes", text: $seed.notes, axis: .vertical).lineLimit(3...6) }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 440, minHeight: 580)
    }
}

// MARK: - Garden Bed Sheet

struct GardenBedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bed: GardenBed
    @State private var hasPlanted = false
    @State private var hasHarvest = false
    private let onSave: (GardenBed) -> Void

    init(bed: GardenBed, onSave: @escaping (GardenBed) -> Void) {
        _bed        = State(initialValue: bed)
        _hasPlanted = State(initialValue: bed.plantedDate != nil)
        _hasHarvest = State(initialValue: bed.expectedHarvest != nil)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(bed.name.isEmpty ? "New Garden Bed" : bed.name)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(bed); dismiss() }
                    .buttonStyle(.borderedProminent).tint(.teal)
                    .disabled(bed.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding()
            Divider()
            Form {
                Section {
                    TextField("Bed Name", text: $bed.name)
                    HStack {
                        Text("Width (ft)"); Spacer()
                        TextField("4", value: $bed.widthFt, format: .number)
                            .multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    HStack {
                        Text("Length (ft)"); Spacer()
                        TextField("8", value: $bed.lengthFt, format: .number)
                            .multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    Text(String(format: "Area: %.0f sq ft", bed.squareFeet))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Current Crop") {
                    TextField("Crop name", text: $bed.currentCrop)
                    Toggle("Has planted date", isOn: $hasPlanted)
                        .onChange(of: hasPlanted) { _, on in
                            bed.plantedDate = on ? (bed.plantedDate ?? Date()) : nil
                        }
                    if hasPlanted {
                        DatePicker("Planted", selection: Binding(
                            get: { bed.plantedDate ?? Date() },
                            set: { bed.plantedDate = $0 }), displayedComponents: .date)
                    }
                    Toggle("Has expected harvest", isOn: $hasHarvest)
                        .onChange(of: hasHarvest) { _, on in
                            bed.expectedHarvest = on ? (bed.expectedHarvest ?? Date()) : nil
                        }
                    if hasHarvest {
                        DatePicker("Expected harvest", selection: Binding(
                            get: { bed.expectedHarvest ?? Date() },
                            set: { bed.expectedHarvest = $0 }), displayedComponents: .date)
                    }
                }
                Section { TextField("Notes", text: $bed.notes, axis: .vertical).lineLimit(3...6) }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 420, minHeight: 500)
    }
}
