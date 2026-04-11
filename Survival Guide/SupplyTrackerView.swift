import SwiftUI
import Combine

// MARK: - Models

enum SupplyCategory: String, Codable, CaseIterable, Identifiable {
    case water         = "Water"
    case food          = "Food"
    case medical       = "Medical"
    case fuel          = "Fuel"
    case power         = "Power"
    case communication = "Communication"
    case other         = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .water:         return "drop.fill"
        case .food:          return "fork.knife"
        case .medical:       return "cross.case.fill"
        case .fuel:          return "flame.fill"
        case .power:         return "bolt.fill"
        case .communication: return "antenna.radiowaves.left.and.right"
        case .other:         return "archivebox.fill"
        }
    }

    var color: Color {
        switch self {
        case .water:         return .blue
        case .food:          return .orange
        case .medical:       return .red
        case .fuel:          return Color(red: 0.6, green: 0.3, blue: 0.0)
        case .power:         return .yellow
        case .communication: return .green
        case .other:         return .gray
        }
    }
}

struct SupplyItem: Codable, Identifiable {
    var id = UUID()
    var name: String
    var category: SupplyCategory
    var quantity: Double
    var unit: String
    var dailyUseRate: Double?   // units consumed per day (nil = not time-based)
    var expiryDate: Date?
    var notes: String

    var daysRemaining: Double? {
        guard let rate = dailyUseRate, rate > 0 else { return nil }
        return quantity / rate
    }

    var statusColor: Color {
        guard let days = daysRemaining else { return .secondary }
        if days >= 14 { return .green }
        if days >= 7  { return Color(red: 0.6, green: 0.8, blue: 0.0) }
        if days >= 3  { return .orange }
        return .red
    }

    var statusLabel: String {
        guard let days = daysRemaining else { return "" }
        if days >= 1 { return "\(Int(days)) days" }
        return "< 1 day"
    }
}

struct HouseholdConfig: Codable {
    var adults: Int        = 2
    var children: Int      = 0
    var dogs: Int          = 0
    var cats: Int          = 0
    var smallAnimals: Int  = 0   // rodents, birds, chickens, etc.

    var waterNeededPerDay: Double {
        Double(adults)       * 1.0  +
        Double(children)     * 0.75 +
        Double(dogs)         * 0.5  +
        Double(cats)         * 0.25 +
        Double(smallAnimals) * 0.1
    }

    var totalPeople: Int { adults + children }
    var totalPets: Int   { dogs + cats + smallAnimals }
    var description: String {
        var parts: [String] = []
        if adults       > 0 { parts.append("\(adults) adult\(adults == 1 ? "" : "s")") }
        if children     > 0 { parts.append("\(children) child\(children == 1 ? "" : "ren")") }
        if dogs         > 0 { parts.append("\(dogs) dog\(dogs == 1 ? "" : "s")") }
        if cats         > 0 { parts.append("\(cats) cat\(cats == 1 ? "" : "s")") }
        if smallAnimals > 0 { parts.append("\(smallAnimals) small animal\(smallAnimals == 1 ? "" : "s")") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Supply Engine

@MainActor
class SupplyEngine: ObservableObject {
    @Published var items: [SupplyItem] = []
    @Published var household = HouseholdConfig()

    private let itemsKey     = "supply_items_v1"
    private let householdKey = "supply_household_v1"

    init() {
        load()
        if items.isEmpty { seedDefaults() }
    }

    // MARK: Persistence

    func save() {
        if let d = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(d, forKey: itemsKey)
        }
        if let d = try? JSONEncoder().encode(household) {
            UserDefaults.standard.set(d, forKey: householdKey)
        }
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([SupplyItem].self, from: d) {
            items = decoded
        }
        if let d = UserDefaults.standard.data(forKey: householdKey),
           let decoded = try? JSONDecoder().decode(HouseholdConfig.self, from: d) {
            household = decoded
        }
    }

    func add(_ item: SupplyItem) {
        items.append(item)
        save()
    }

    func update(_ item: SupplyItem) {
        if let i = items.firstIndex(where: { $0.id == item.id }) {
            items[i] = item
            save()
        }
    }

    func delete(_ item: SupplyItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func updateHousehold(_ h: HouseholdConfig) {
        household = h
        // Update water daily use rate to match new household
        for i in items.indices where items[i].category == .water {
            if items[i].dailyUseRate != nil {
                items[i].dailyUseRate = h.waterNeededPerDay
            }
        }
        save()
    }

    // MARK: Computed

    func items(in category: SupplyCategory) -> [SupplyItem] {
        items.filter { $0.category == category }
    }

    func totalDaysWater() -> Double? {
        let gallons = items.filter { $0.category == .water }
            .reduce(0) { $0 + $1.quantity }
        let need = household.waterNeededPerDay
        guard need > 0 else { return nil }
        return gallons / need
    }

    // MARK: Seed

    private func seedDefaults() {
        let h = household
        items = [
            SupplyItem(name: "Stored Water", category: .water,
                       quantity: 0, unit: "gallons",
                       dailyUseRate: h.waterNeededPerDay,
                       notes: "Food-grade containers. Rotate every 6 months."),
            SupplyItem(name: "Emergency Food Supply", category: .food,
                       quantity: 0, unit: "days",
                       dailyUseRate: 1.0,
                       notes: "Shelf-stable meals, canned goods, freeze-dried."),
            SupplyItem(name: "Prescription Medications", category: .medical,
                       quantity: 0, unit: "days supply",
                       dailyUseRate: 1.0,
                       notes: "All household members combined."),
            SupplyItem(name: "Generator Fuel (Gasoline)", category: .fuel,
                       quantity: 0, unit: "gallons",
                       dailyUseRate: nil,
                       notes: "Add daily use rate based on your generator's consumption."),
            SupplyItem(name: "Vehicle Fuel", category: .fuel,
                       quantity: 0, unit: "gallons",
                       dailyUseRate: nil,
                       notes: "Keep tank at least half full at all times."),
            SupplyItem(name: "Cash", category: .other,
                       quantity: 0, unit: "dollars",
                       dailyUseRate: nil,
                       notes: "Small bills. ATMs and card readers won't work in grid-down."),
            SupplyItem(name: "AA Batteries", category: .power,
                       quantity: 0, unit: "count",
                       dailyUseRate: nil,
                       notes: ""),
            SupplyItem(name: "AAA Batteries", category: .power,
                       quantity: 0, unit: "count",
                       dailyUseRate: nil,
                       notes: ""),
            SupplyItem(name: "N95 Masks", category: .medical,
                       quantity: 0, unit: "count",
                       dailyUseRate: nil,
                       notes: ""),
            SupplyItem(name: "Potassium Iodide (KI) Tablets", category: .medical,
                       quantity: 0, unit: "doses",
                       dailyUseRate: nil,
                       notes: "One dose per person per nuclear event — take only when directed."),
            SupplyItem(name: "NOAA/Ham Radio Batteries", category: .communication,
                       quantity: 0, unit: "sets",
                       dailyUseRate: nil,
                       notes: ""),
        ]
        save()
    }
}

// MARK: - Main View

struct SupplyTrackerView: View {
    @StateObject private var engine = SupplyEngine()
    @State private var showHouseholdEditor = false
    @State private var showAddItem = false
    @State private var editingItem: SupplyItem? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // ── Header ────────────────────────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Supply Inventory")
                            .font(.title2.bold())
                        Text("Track what you have on hand")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showHouseholdEditor = true
                    } label: {
                        Label(engine.household.description, systemImage: "person.2.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showAddItem = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                // ── Water summary (special — calculated from household) ────────
                WaterSummaryCard(engine: engine)

                // ── Category cards ────────────────────────────────────────────
                ForEach(SupplyCategory.allCases) { category in
                    let catItems = engine.items(in: category)
                    if !catItems.isEmpty {
                        SupplyCategoryCard(
                            category: category,
                            items: catItems,
                            onEdit: { editingItem = $0 },
                            onDelete: { engine.delete($0) }
                        )
                    }
                }

                // ── Empty state ───────────────────────────────────────────────
                if engine.items.isEmpty {
                    ContentUnavailableView(
                        "No supplies logged",
                        systemImage: "archivebox",
                        description: Text("Tap Add Item to start tracking your emergency supplies.")
                    )
                }

                // ── Status legend ─────────────────────────────────────────────
                HStack(spacing: 20) {
                    Label("14+ days",  systemImage: "circle.fill").foregroundStyle(.green)
                    Label("7–14 days", systemImage: "circle.fill").foregroundStyle(Color(red: 0.6, green: 0.8, blue: 0.0))
                    Label("3–7 days",  systemImage: "circle.fill").foregroundStyle(.orange)
                    Label("< 3 days",  systemImage: "circle.fill").foregroundStyle(.red)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .sheet(isPresented: $showHouseholdEditor) {
            HouseholdEditorSheet(config: engine.household) { updated in
                engine.updateHousehold(updated)
            }
        }
        .sheet(isPresented: $showAddItem) {
            SupplyItemSheet(item: nil) { newItem in
                engine.add(newItem)
            }
        }
        .sheet(item: $editingItem) { item in
            SupplyItemSheet(item: item) { updated in
                engine.update(updated)
            }
        }
    }
}

// MARK: - Water Summary Card

struct WaterSummaryCard: View {
    @ObservedObject var engine: SupplyEngine

    private var totalGallons: Double {
        engine.items(in: .water).reduce(0) { $0 + $1.quantity }
    }

    private var daysOfWater: Double {
        let need = engine.household.waterNeededPerDay
        guard need > 0 else { return 0 }
        return totalGallons / need
    }

    private var statusColor: Color {
        if daysOfWater >= 14 { return .green }
        if daysOfWater >= 7  { return Color(red: 0.6, green: 0.8, blue: 0.0) }
        if daysOfWater >= 3  { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "drop.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Water Supply")
                    .font(.system(size: 14, weight: .semibold))
                HStack(spacing: 6) {
                    Text(String(format: "%.1f gallons", totalGallons))
                        .font(.system(size: 13))
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f days for household", daysOfWater))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
                Text("Based on \(String(format: "%.1f", engine.household.waterNeededPerDay)) gal/day · \(engine.household.description)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Goal indicator
            VStack(spacing: 2) {
                Text("Goal")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("14 days")
                    .font(.system(size: 12, weight: .semibold))
                ProgressView(value: min(1.0, daysOfWater / 14.0))
                    .tint(statusColor)
                    .frame(width: 80)
            }
        }
        .padding(16)
        .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Category Card

struct SupplyCategoryCard: View {
    let category: SupplyCategory
    let items: [SupplyItem]
    let onEdit: (SupplyItem) -> Void
    let onDelete: (SupplyItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: category.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(category.color)
                Text(category.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            VStack(spacing: 0) {
                ForEach(items) { item in
                    SupplyItemRow(item: item, category: category,
                                  onEdit: { onEdit(item) },
                                  onDelete: { onDelete(item) })
                    if item.id != items.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(category.color.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Supply Item Row

struct SupplyItemRow: View {
    let item: SupplyItem
    let category: SupplyCategory
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                HStack(spacing: 6) {
                    Text(quantityText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    if !item.notes.isEmpty {
                        let notes = item.notes
                        Text("·")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 12))
                        Text(notes)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                if let exp = item.expiryDate {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text("Expires \(exp, style: .date)")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(exp < Date() ? .red : .secondary)
                }
            }

            Spacer()

            if let days = item.daysRemaining {
                VStack(spacing: 2) {
                    Text(item.statusLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(item.statusColor)
                    if item.dailyUseRate != nil {
                        Text("remaining")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 4) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private var quantityText: String {
        let qty = item.quantity
        let formatted = qty == qty.rounded() ? String(format: "%.0f", qty) : String(format: "%.1f", qty)
        return "\(formatted) \(item.unit)"
    }
}

// MARK: - Household Editor Sheet

struct HouseholdEditorSheet: View {
    @State private var config: HouseholdConfig
    let onSave: (HouseholdConfig) -> Void
    @Environment(\.dismiss) private var dismiss

    init(config: HouseholdConfig, onSave: @escaping (HouseholdConfig) -> Void) {
        self._config = State(initialValue: config)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Household Size")
                .font(.title2.bold())
            Text("Used to calculate water and food requirements.")
                .font(.body).foregroundStyle(.secondary)

            Divider()

            Group {
                HouseholdStepper(label: "Adults",                     value: $config.adults,       min: 1)
                HouseholdStepper(label: "Children",                   value: $config.children,     min: 0)
                HouseholdStepper(label: "Dogs",                       value: $config.dogs,         min: 0)
                HouseholdStepper(label: "Cats",                       value: $config.cats,         min: 0)
                HouseholdStepper(label: "Small Animals (birds, etc.)",value: $config.smallAnimals, min: 0)
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "drop.fill").foregroundStyle(.blue)
                Text("Daily water need: \(String(format: "%.2f", config.waterNeededPerDay)) gallons")
                    .font(.system(size: 13, weight: .medium))
            }
            Text("Adults: 1 gal · Children: 0.75 gal · Dogs: 0.5 gal · Cats: 0.25 gal · Small animals: 0.1 gal")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") {
                    onSave(config)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

struct HouseholdStepper: View {
    let label: String
    @Binding var value: Int
    let min: Int

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
            Spacer()
            Stepper("\(value)", value: $value, in: min...20)
                .labelsHidden()
            Text("\(value)")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 24, alignment: .trailing)
        }
    }
}

// MARK: - Add/Edit Item Sheet

struct SupplyItemSheet: View {
    let existingItem: SupplyItem?
    let onSave: (SupplyItem) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var category: SupplyCategory
    @State private var quantityStr: String
    @State private var unit: String
    @State private var hasDailyRate: Bool
    @State private var dailyRateStr: String
    @State private var hasExpiry: Bool
    @State private var expiryDate: Date
    @State private var notes: String

    init(item: SupplyItem?, onSave: @escaping (SupplyItem) -> Void) {
        self.existingItem = item
        self.onSave = onSave
        _name         = State(initialValue: item?.name ?? "")
        _category     = State(initialValue: item?.category ?? .other)
        _quantityStr  = State(initialValue: item.map { String(format: "%.1f", $0.quantity) } ?? "0")
        _unit         = State(initialValue: item?.unit ?? "units")
        _hasDailyRate = State(initialValue: item?.dailyUseRate != nil)
        _dailyRateStr = State(initialValue: item?.dailyUseRate.map { String(format: "%.2f", $0) } ?? "1.0")
        _hasExpiry    = State(initialValue: item?.expiryDate != nil)
        _expiryDate   = State(initialValue: item?.expiryDate ?? Date())
        _notes        = State(initialValue: item?.notes ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existingItem == nil ? "Add Supply Item" : "Edit Supply Item")
                .font(.title2.bold())
            Divider()

            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Name").font(.caption).foregroundStyle(.secondary)
                TextField("e.g. Stored Water", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // Category
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $category) {
                        ForEach(SupplyCategory.allCases) { c in
                            Label(c.rawValue, systemImage: c.symbol).tag(c)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                Spacer()

                // Quantity + unit
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quantity").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        TextField("0", text: $quantityStr)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                        TextField("unit", text: $unit)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
            }

            // Daily use rate
            Toggle("Track days remaining", isOn: $hasDailyRate)
            if hasDailyRate {
                HStack(spacing: 8) {
                    Text("Daily use:")
                        .font(.system(size: 13))
                    TextField("1.0", text: $dailyRateStr)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                    Text(unit + " per day")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 20)
            }

            // Expiry
            Toggle("Has expiry date", isOn: $hasExpiry)
            if hasExpiry {
                DatePicker("Expires:", selection: $expiryDate, displayedComponents: .date)
                    .padding(.leading, 20)
            }

            // Notes
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes (optional)").font(.caption).foregroundStyle(.secondary)
                TextField("Storage location, rotation date, etc.", text: $notes)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") {
                    var item = existingItem ?? SupplyItem(
                        name: name, category: category,
                        quantity: 0, unit: unit,
                        notes: notes
                    )
                    item.name        = name
                    item.category    = category
                    item.quantity    = Double(quantityStr) ?? 0
                    item.unit        = unit
                    item.dailyUseRate = hasDailyRate ? Double(dailyRateStr) : nil
                    item.expiryDate  = hasExpiry ? expiryDate : nil
                    item.notes       = notes
                    onSave(item)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
