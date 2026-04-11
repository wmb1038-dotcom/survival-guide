import SwiftUI
import Combine

// MARK: - Models

enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    case canned       = "Canned"
    case dryGoods     = "Dry Goods"
    case freezeDried  = "Freeze-Dried"
    case frozen       = "Frozen"
    case fresh        = "Fresh"
    case beverages    = "Beverages"
    case other        = "Other"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .canned:      return "cylinder.fill"
        case .dryGoods:    return "bag.fill"
        case .freezeDried: return "snowflake"
        case .frozen:      return "thermometer.snowflake"
        case .fresh:       return "leaf.fill"
        case .beverages:   return "drop.fill"
        case .other:       return "shippingbox.fill"
        }
    }
    var color: Color {
        switch self {
        case .canned:      return Color(red: 0.7, green: 0.5, blue: 0.2)
        case .dryGoods:    return Color(red: 0.8, green: 0.7, blue: 0.3)
        case .freezeDried: return .cyan
        case .frozen:      return Color(red: 0.5, green: 0.7, blue: 1.0)
        case .fresh:       return .green
        case .beverages:   return .blue
        case .other:       return .gray
        }
    }
}

struct FoodItem: Codable, Identifiable {
    var id            = UUID()
    var name          : String         = ""
    var category      : FoodCategory   = .canned
    var quantity      : Double         = 1
    var unit          : String         = "cans"
    var caloriesPerUnit: Double        = 250
    var expirationDate: Date?          = nil
    var dateAdded     : Date           = Date()
    var notes         : String         = ""

    var totalCalories: Double { quantity * caloriesPerUnit }

    var daysUntilExpiration: Int? {
        guard let exp = expirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: exp).day
    }

    enum Urgency { case fine, soon, urgent, expired, noDate }
    var urgency: Urgency {
        guard let days = daysUntilExpiration else { return .noDate }
        if days < 0  { return .expired }
        if days < 30 { return .urgent }
        if days < 90 { return .soon }
        return .fine
    }
    var urgencyColor: Color {
        switch urgency {
        case .fine:   return .green
        case .soon:   return .yellow
        case .urgent: return .orange
        case .expired:return .red
        case .noDate: return .secondary
        }
    }
}

// MARK: - Engine

@MainActor
class FoodRotationEngine: ObservableObject {
    static let shared = FoodRotationEngine()
    private let key = "food_rotation_v1"

    @Published var items: [FoodItem] = []

    init() { load() }

    func save() {
        if let d = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(d, forKey: key)
        }
        scheduleAllNotifications()
    }

    private func load() {
        guard let d = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([FoodItem].self, from: d) else { return }
        items = decoded
    }

    func upsert(_ item: FoodItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
        } else {
            items.append(item)
        }
        save()
    }

    func delete(_ item: FoodItem) {
        NotificationManager.shared.cancelFoodAlerts(itemID: item.id.uuidString)
        items.removeAll { $0.id == item.id }
        save()
    }

    // MARK: Computed

    var totalCalories: Double { items.reduce(0) { $0 + $1.totalCalories } }

    func daysOfSupply(dailyCalories: Double) -> Double? {
        guard dailyCalories > 0 else { return nil }
        return totalCalories / dailyCalories
    }

    var expiringSoon: [FoodItem] {
        items.filter { $0.urgency == .urgent || $0.urgency == .expired }
             .sorted { ($0.daysUntilExpiration ?? 9999) < ($1.daysUntilExpiration ?? 9999) }
    }

    var itemsByCategory: [(FoodCategory, [FoodItem])] {
        FoodCategory.allCases.compactMap { cat in
            let list = items.filter { $0.category == cat }
            return list.isEmpty ? nil : (cat, list)
        }
    }

    private func scheduleAllNotifications() {
        for item in items {
            if let exp = item.expirationDate {
                NotificationManager.shared.scheduleFoodAlerts(
                    itemID: item.id.uuidString, name: item.name, expirationDate: exp)
            }
        }
    }
}

// MARK: - Main View

struct FoodRotationView: View {
    @StateObject private var engine = FoodRotationEngine.shared
    @EnvironmentObject var supplyEngine: SupplyEngine
    @State private var tab: Int = 0
    @State private var showAdd = false
    @State private var editing: FoodItem? = nil

    private var dailyCalories: Double {
        let hh = supplyEngine.household
        return Double(hh.adults) * 2000 + Double(hh.children) * 1500
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header stats
            HStack(spacing: 16) {
                StatPill(label: "Total Calories",
                         value: engine.totalCalories >= 1000
                            ? String(format: "%.0fk", engine.totalCalories / 1000)
                            : String(format: "%.0f", engine.totalCalories),
                         color: .orange)
                if let days = engine.daysOfSupply(dailyCalories: dailyCalories) {
                    StatPill(label: "Days of Supply",
                             value: String(format: "%.0f", days),
                             color: days >= 30 ? .green : days >= 7 ? .yellow : .red)
                }
                if !engine.expiringSoon.isEmpty {
                    StatPill(label: "Expiring Soon",
                             value: "\(engine.expiringSoon.count)",
                             color: .red)
                }
                Spacer()
                Button { showAdd = true } label: {
                    Label("Add Item", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.04))

            Picker("", selection: $tab) {
                Text("All Items").tag(0)
                Text("Expiring Soon").tag(1)
                Text("By Category").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider().opacity(0.3)

            switch tab {
            case 0: itemList(items: engine.items.sorted { ($0.daysUntilExpiration ?? 99999) < ($1.daysUntilExpiration ?? 99999) })
            case 1: itemList(items: engine.expiringSoon)
            case 2: categoryView
            default: EmptyView()
            }
        }
        .sheet(isPresented: $showAdd) {
            FoodItemSheet(item: FoodItem()) { engine.upsert($0) }
        }
        .sheet(item: $editing) { item in
            FoodItemSheet(item: item) { engine.upsert($0) }
        }
    }

    private func itemList(items: [FoodItem]) -> some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView("No Items",
                    systemImage: "cart",
                    description: Text("Add food items to track expiration and calories."))
            } else {
                List {
                    ForEach(items) { item in
                        FoodItemRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = item }
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { idx in
                        idx.forEach { engine.delete(items[$0]) }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var categoryView: some View {
        List {
            ForEach(engine.itemsByCategory, id: \.0) { cat, catItems in
                Section {
                    ForEach(catItems) { item in
                        FoodItemRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = item }
                    }
                    .onDelete { idx in idx.forEach { engine.delete(catItems[$0]) } }
                } header: {
                    Label(cat.rawValue, systemImage: cat.symbol)
                        .foregroundStyle(cat.color)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Row

private struct FoodItemRow: View {
    let item: FoodItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.category.symbol)
                .font(.system(size: 14))
                .foregroundStyle(item.category.color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.name.isEmpty ? "Unnamed Item" : item.name)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(String(format: "%.0f cal", item.totalCalories))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text("\(item.quantity, specifier: "%.4g") \(item.unit)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    if let days = item.daysUntilExpiration {
                        Text(days < 0 ? "EXPIRED" : days == 0 ? "Expires today" : "Exp. \(days)d")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(item.urgencyColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(item.urgencyColor.opacity(0.15),
                                        in: RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Add / Edit Sheet

struct FoodItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: FoodItem
    @State private var hasExpiry = false
    private let onSave: (FoodItem) -> Void

    init(item: FoodItem, onSave: @escaping (FoodItem) -> Void) {
        _item = State(initialValue: item)
        _hasExpiry = State(initialValue: item.expirationDate != nil)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(item.name.isEmpty ? "New Food Item" : item.name)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(item); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(item.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            Divider()

            Form {
                Section("Item") {
                    TextField("Name", text: $item.name)
                    Picker("Category", selection: $item.category) {
                        ForEach(FoodCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.symbol).tag(cat)
                        }
                    }
                }
                Section("Quantity") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("Qty", value: $item.quantity, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Unit")
                        Spacer()
                        TextField("cans, lbs, oz…", text: $item.unit)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Calories per unit")
                        Spacer()
                        TextField("Cal", value: $item.caloriesPerUnit, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                Section("Expiration") {
                    Toggle("Has expiration date", isOn: $hasExpiry)
                        .onChange(of: hasExpiry) { _, on in
                            item.expirationDate = on ? (item.expirationDate ?? Date()) : nil
                        }
                    if hasExpiry {
                        DatePicker("Expires", selection: Binding(
                            get: { item.expirationDate ?? Date() },
                            set: { item.expirationDate = $0 }
                        ), displayedComponents: .date)
                    }
                }
                Section("Notes") {
                    TextField("Optional notes", text: $item.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 420, minHeight: 500)
    }
}
