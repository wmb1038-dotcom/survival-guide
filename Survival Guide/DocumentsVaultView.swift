import SwiftUI
import Combine
import Security

// MARK: - Keychain helper (replaces UserDefaults for sensitive vault data)

private enum VaultKeychain {
    private static let service = "com.woodrowbell.Survival-Guide.vault"
    private static let account = "documents_vault_v1"

    static func load() -> Data? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData:  kCFBooleanTrue as Any,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func save(_ data: Data) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attrs: [CFString: Any] = [kSecValueData: data]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func delete() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Models

enum VaultCategory: String, Codable, CaseIterable, Identifiable {
    case identity   = "Identity"
    case insurance  = "Insurance"
    case financial  = "Financial"
    case vehicle    = "Vehicle"
    case property   = "Property"
    case medical    = "Medical"
    case contacts   = "Key Contacts"
    case other      = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .identity:  return "person.crop.rectangle.fill"
        case .insurance: return "shield.fill"
        case .financial: return "banknote.fill"
        case .vehicle:   return "car.fill"
        case .property:  return "house.fill"
        case .medical:   return "cross.case.fill"
        case .contacts:  return "phone.fill"
        case .other:     return "doc.fill"
        }
    }

    var color: Color {
        switch self {
        case .identity:  return .blue
        case .insurance: return .green
        case .financial: return Color(red: 0.1, green: 0.6, blue: 0.3)
        case .vehicle:   return .orange
        case .property:  return .brown
        case .medical:   return .red
        case .contacts:  return .purple
        case .other:     return .gray
        }
    }
}

struct VaultEntry: Codable, Identifiable {
    var id = UUID()
    var category: VaultCategory = .other
    var label: String = ""
    var value: String = ""
    var notes: String = ""
}

// MARK: - Engine

@MainActor
class VaultEngine: ObservableObject {
    @Published var entries: [VaultEntry] = []

    init() { load() }

    func add(_ e: VaultEntry) { entries.append(e); save() }

    func update(_ e: VaultEntry) {
        if let i = entries.firstIndex(where: { $0.id == e.id }) {
            entries[i] = e; save()
        }
    }

    func delete(_ e: VaultEntry) {
        entries.removeAll { $0.id == e.id }; save()
    }

    /// Persists vault entries in the macOS Keychain (encrypted at rest).
    func save() {
        guard let d = try? JSONEncoder().encode(entries) else { return }
        VaultKeychain.save(d)
    }

    /// Wipes all vault data from the Keychain.
    func deleteAll() {
        entries = []
        VaultKeychain.delete()
    }

    private func load() {
        // Migrate from legacy UserDefaults store on first launch after update
        let legacyKey = "documents_vault_v1"
        if let legacyData = UserDefaults.standard.data(forKey: legacyKey),
           let decoded = try? JSONDecoder().decode([VaultEntry].self, from: legacyData) {
            entries = decoded
            save()                                           // write to Keychain
            UserDefaults.standard.removeObject(forKey: legacyKey) // remove plaintext copy
            return
        }
        guard let d = VaultKeychain.load(),
              let decoded = try? JSONDecoder().decode([VaultEntry].self, from: d) else { return }
        entries = decoded
    }

    func entries(for category: VaultCategory) -> [VaultEntry] {
        entries.filter { $0.category == category }
    }
}

// MARK: - Main View

struct DocumentsVaultView: View {
    @StateObject private var engine = VaultEngine()
    @State private var showAdd = false
    @State private var editItem: VaultEntry?
    @State private var selectedCategory: VaultCategory? = nil

    private var categoriesInUse: [VaultCategory] {
        let used = Set(engine.entries.map { $0.category })
        return VaultCategory.allCases.filter { used.contains($0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Documents Vault")
                            .font(.title2.bold())
                        Text("Record critical numbers offline — no photos, just numbers")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { showAdd = true } label: {
                        Label("Add Entry", systemImage: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                }

                // Privacy banner
                VaultPrivacyBanner()

                if engine.entries.isEmpty {
                    EmptyVaultState { showAdd = true }
                } else {
                    // Category filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: "All", isSelected: selectedCategory == nil) {
                                selectedCategory = nil
                            }
                            ForEach(categoriesInUse) { cat in
                                FilterChip(
                                    label: cat.rawValue,
                                    isSelected: selectedCategory == cat,
                                    color: cat.color
                                ) {
                                    selectedCategory = selectedCategory == cat ? nil : cat
                                }
                            }
                        }
                    }

                    // Entries by category
                    let displayCats = selectedCategory.map { [$0] } ?? categoriesInUse
                    ForEach(displayCats) { cat in
                        let catEntries = engine.entries(for: cat)
                        if !catEntries.isEmpty {
                            VaultCategorySection(
                                category: cat,
                                entries: catEntries,
                                onEdit: { editItem = $0 },
                                onDelete: { engine.delete($0) }
                            )
                        }
                    }
                }

                // Suggested entries card
                VaultSuggestionsCard { template in
                    var e = VaultEntry()
                    e.category = template.0
                    e.label = template.1
                    showAdd = true
                    // Pre-populate via editItem hack isn't needed — we just open the sheet
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showAdd) {
            VaultEntrySheet(entry: VaultEntry()) { engine.add($0) }
        }
        .sheet(item: $editItem) { entry in
            VaultEntrySheet(entry: entry) { engine.update($0) }
        }
    }
}

// MARK: - Components

private struct VaultPrivacyBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 3) {
                Text("Stored locally on this device only.")
                    .font(.system(size: 12, weight: .semibold))
                Text("Record account/policy numbers and key contacts — not passwords or full card numbers. Also keep a handwritten copy in a waterproof bag with your important documents.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.15), lineWidth: 1))
    }
}

private struct VaultCategorySection: View {
    let category: VaultCategory
    let entries: [VaultEntry]
    let onEdit: (VaultEntry) -> Void
    let onDelete: (VaultEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: category.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(category.color)
                Text(category.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                Text("(\(entries.count))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                ForEach(entries) { entry in
                    VaultRow(entry: entry, color: category.color,
                             onEdit: { onEdit(entry) }, onDelete: { onDelete(entry) })
                }
            }
        }
    }
}

private struct VaultRow: View {
    let entry: VaultEntry
    let color: Color
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var revealed = false
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.label.isEmpty ? "Untitled" : entry.label)
                    .font(.system(size: 12, weight: .semibold))
                if revealed {
                    Text(entry.value.isEmpty ? "—" : entry.value)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(color)
                    if !entry.notes.isEmpty {
                        Text(entry.notes).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                } else {
                    Text(entry.value.isEmpty ? "—" : String(repeating: "•", count: min(entry.value.count, 12)))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { revealed.toggle() }
            } label: {
                Image(systemName: revealed ? "eye.slash" : "eye")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button(action: onEdit) {
                Image(systemName: "pencil").font(.system(size: 12))
            }.buttonStyle(.plain).foregroundStyle(.secondary)

            Button { showDeleteConfirm = true } label: {
                Image(systemName: "trash").font(.system(size: 12))
            }
            .buttonStyle(.plain).foregroundStyle(.red.opacity(0.7))
            .confirmationDialog("Delete \"\(entry.label)\"?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { onDelete() }
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1))
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var color: Color = .blue
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(isSelected ? color : Color.primary.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyVaultState: View {
    let onAdd: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.doc.fill")
                .font(.system(size: 36))
                .foregroundStyle(.blue.opacity(0.5))
            Text("No entries yet").font(.headline)
            Text("Store critical document numbers — passport, insurance policy, vehicle VIN, bank account numbers — for access after a disaster.")
                .font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 360)
            Button("Add Entry", action: onAdd).buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity).padding(40)
    }
}

private let suggestedEntries: [(VaultCategory, String)] = [
    (.identity,  "Passport Number"),
    (.identity,  "Driver's License Number"),
    (.identity,  "Social Security Number (last 4)"),
    (.identity,  "Birth Certificate Location"),
    (.insurance, "Homeowner/Renter Policy Number"),
    (.insurance, "Health Insurance ID / Group Number"),
    (.insurance, "Auto Insurance Policy Number"),
    (.insurance, "Life Insurance Policy Number"),
    (.financial, "Bank Account (last 4 digits)"),
    (.financial, "Safe Deposit Box Location + Key Location"),
    (.vehicle,   "Vehicle VIN"),
    (.vehicle,   "License Plate Number"),
    (.vehicle,   "Title Location"),
    (.property,  "Deed / Lease Location"),
    (.property,  "Utility Account Numbers"),
    (.property,  "Water Shutoff Location"),
    (.property,  "Gas Shutoff Location"),
    (.property,  "Main Breaker Location"),
    (.medical,   "Blood Type"),
    (.medical,   "Allergies"),
    (.medical,   "Primary Doctor + Phone"),
    (.contacts,  "Landlord / Property Manager"),
    (.contacts,  "Attorney Contact"),
    (.contacts,  "Accountant Contact"),
]

private struct VaultSuggestionsCard: View {
    let onAdd: ((VaultCategory, String)) -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.clipboard.fill")
                        .font(.system(size: 13)).foregroundStyle(.purple)
                    Text("Suggested Entries to Add")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                    ForEach(Array(suggestedEntries.enumerated()), id: \.offset) { _, entry in
                        HStack(spacing: 6) {
                            Image(systemName: entry.0.symbol)
                                .font(.system(size: 10))
                                .foregroundStyle(entry.0.color)
                            Text(entry.1)
                                .font(.system(size: 11))
                            Spacer()
                        }
                        .padding(5)
                        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 5))
                    }
                }
                Text("Tap Add Entry above to add any of these.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Entry Sheet

struct VaultEntrySheet: View {
    @State var entry: VaultEntry
    let onSave: (VaultEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry.label.isEmpty ? "Add Entry" : "Edit Entry")
                .font(.headline).padding(.horizontal)

            Form {
                Section("Category") {
                    Picker("Category", selection: $entry.category) {
                        ForEach(VaultCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.symbol).tag(cat)
                        }
                    }
                }
                Section("Entry") {
                    TextField("Label (e.g. Passport Number)", text: $entry.label)
                    TextField("Value", text: $entry.value)
                    TextField("Notes (optional)", text: $entry.notes)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(entry); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .disabled(entry.label.isEmpty || entry.value.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .frame(width: 420)
    }
}
