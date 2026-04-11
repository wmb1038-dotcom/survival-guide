import SwiftUI
import Combine

// MARK: - Data Models

struct ChecklistItem: Identifiable {
    let id: String      // stable — used for persistence
    let label: String
    let detail: String?
}

struct ChecklistCategory: Identifiable {
    let id: String
    let name: String
    let items: [ChecklistItem]
}

struct Checklist: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let color: Color
    let description: String
    let categories: [ChecklistCategory]

    var allItems: [ChecklistItem] { categories.flatMap { $0.items } }
}

// MARK: - Static Checklist Data

let allChecklists: [Checklist] = [

    Checklist(id: "kit72", name: "72-Hour Emergency Kit", symbol: "bag.fill", color: .orange,
              description: "Minimum supplies to survive 3 days without outside help.",
              categories: [
        ChecklistCategory(id: "water", name: "Water", items: [
            ChecklistItem(id: "kit72_w1", label: "3 gallons per person (1 gal/day × 3 days)", detail: "Store in food-grade sealed containers"),
            ChecklistItem(id: "kit72_w2", label: "Water purification tablets", detail: "Backup if stored water runs out"),
            ChecklistItem(id: "kit72_w3", label: "Portable water filter (LifeStraw or similar)", detail: nil),
        ]),
        ChecklistCategory(id: "food", name: "Food", items: [
            ChecklistItem(id: "kit72_f1", label: "9 ready-to-eat meals per person", detail: "No cooking required"),
            ChecklistItem(id: "kit72_f2", label: "Manual can opener", detail: nil),
            ChecklistItem(id: "kit72_f3", label: "Eating utensils and plates", detail: nil),
            ChecklistItem(id: "kit72_f4", label: "High-calorie snacks (nuts, bars)", detail: nil),
        ]),
        ChecklistCategory(id: "medical", name: "Medical", items: [
            ChecklistItem(id: "kit72_m1", label: "First aid kit (bandages, gauze, antiseptic)", detail: nil),
            ChecklistItem(id: "kit72_m2", label: "7-day supply of all prescription medications", detail: "Rotate regularly to keep current"),
            ChecklistItem(id: "kit72_m3", label: "OTC medications (pain reliever, antidiarrheal, antacid)", detail: nil),
            ChecklistItem(id: "kit72_m4", label: "Spare glasses or contact lens supplies", detail: nil),
        ]),
        ChecklistCategory(id: "docs", name: "Documents", items: [
            ChecklistItem(id: "kit72_d1", label: "Copies of IDs and passports (waterproof bag)", detail: nil),
            ChecklistItem(id: "kit72_d2", label: "Insurance documents", detail: nil),
            ChecklistItem(id: "kit72_d3", label: "Emergency contact list (printed)", detail: "Don't rely on phone memory"),
            ChecklistItem(id: "kit72_d4", label: "Cash — small bills ($100+ total)", detail: "ATMs and card readers won't work"),
        ]),
        ChecklistCategory(id: "tools", name: "Tools & Power", items: [
            ChecklistItem(id: "kit72_t1", label: "Flashlight + extra batteries", detail: nil),
            ChecklistItem(id: "kit72_t2", label: "Battery-powered or hand-crank NOAA radio", detail: "Tune to 162.550 MHz"),
            ChecklistItem(id: "kit72_t3", label: "Cell phone charger + backup battery bank (charged)", detail: nil),
            ChecklistItem(id: "kit72_t4", label: "Emergency whistle", detail: nil),
            ChecklistItem(id: "kit72_t5", label: "Duct tape", detail: nil),
        ]),
        ChecklistCategory(id: "sanitation", name: "Sanitation", items: [
            ChecklistItem(id: "kit72_s1", label: "Hand sanitizer (2 bottles)", detail: nil),
            ChecklistItem(id: "kit72_s2", label: "Toilet paper and wet wipes", detail: nil),
            ChecklistItem(id: "kit72_s3", label: "Heavy-duty garbage bags", detail: nil),
            ChecklistItem(id: "kit72_s4", label: "N95 masks (10+)", detail: nil),
        ]),
    ]),

    Checklist(id: "bob", name: "Bug-Out Bag", symbol: "figure.walk", color: .brown,
              description: "72-hour go-bag for rapid evacuation on foot or by vehicle.",
              categories: [
        ChecklistCategory(id: "water", name: "Water", items: [
            ChecklistItem(id: "bob_w1", label: "2 liters water per person (carried)", detail: nil),
            ChecklistItem(id: "bob_w2", label: "Portable water filter", detail: nil),
            ChecklistItem(id: "bob_w3", label: "Collapsible water container (2L)", detail: nil),
        ]),
        ChecklistCategory(id: "food", name: "Food", items: [
            ChecklistItem(id: "bob_f1", label: "3 days high-calorie food bars (2400 cal/day)", detail: nil),
            ChecklistItem(id: "bob_f2", label: "Compact utensil set", detail: nil),
        ]),
        ChecklistCategory(id: "shelter", name: "Shelter", items: [
            ChecklistItem(id: "bob_sh1", label: "Emergency bivy or compact sleeping bag", detail: nil),
            ChecklistItem(id: "bob_sh2", label: "Emergency mylar blanket (2)", detail: nil),
            ChecklistItem(id: "bob_sh3", label: "Tarp (8×10 minimum) + cordage", detail: nil),
            ChecklistItem(id: "bob_sh4", label: "550 paracord (50 ft)", detail: nil),
        ]),
        ChecklistCategory(id: "fire", name: "Fire & Light", items: [
            ChecklistItem(id: "bob_fi1", label: "Waterproof matches in waterproof case", detail: nil),
            ChecklistItem(id: "bob_fi2", label: "Lighter (2)", detail: nil),
            ChecklistItem(id: "bob_fi3", label: "Ferrocerium fire starter rod", detail: nil),
            ChecklistItem(id: "bob_fi4", label: "Headlamp + extra batteries", detail: nil),
        ]),
        ChecklistCategory(id: "nav", name: "Navigation", items: [
            ChecklistItem(id: "bob_n1", label: "Paper maps of Oahu (waterproofed or laminated)", detail: nil),
            ChecklistItem(id: "bob_n2", label: "Compass", detail: nil),
        ]),
        ChecklistCategory(id: "medical", name: "Medical", items: [
            ChecklistItem(id: "bob_m1", label: "Trauma first aid kit (tourniquet, hemostatic gauze)", detail: nil),
            ChecklistItem(id: "bob_m2", label: "3-day supply of all medications", detail: nil),
            ChecklistItem(id: "bob_m3", label: "Nitrile gloves (10 pairs)", detail: nil),
        ]),
        ChecklistCategory(id: "comm", name: "Communication", items: [
            ChecklistItem(id: "bob_c1", label: "Handheld ham or GMRS radio", detail: nil),
            ChecklistItem(id: "bob_c2", label: "Emergency whistle", detail: nil),
            ChecklistItem(id: "bob_c3", label: "Signal mirror", detail: nil),
        ]),
        ChecklistCategory(id: "docs", name: "Documents & Money", items: [
            ChecklistItem(id: "bob_d1", label: "Laminated ID and passport copies", detail: nil),
            ChecklistItem(id: "bob_d2", label: "Cash ($200+ in small bills)", detail: nil),
            ChecklistItem(id: "bob_d3", label: "USB drive with digital document copies", detail: nil),
        ]),
    ]),

    Checklist(id: "sip", name: "Shelter-in-Place", symbol: "house.and.flag.fill", color: .blue,
              description: "2-week supplies and materials to survive at home with no outside resources.",
              categories: [
        ChecklistCategory(id: "water", name: "Water (2 Weeks)", items: [
            ChecklistItem(id: "sip_w1", label: "14 gallons per person", detail: "Store in 55-gal drums or 5-gal food-grade jugs"),
            ChecklistItem(id: "sip_w2", label: "Water storage containers (55-gal drum or jugs)", detail: nil),
            ChecklistItem(id: "sip_w3", label: "Water purification tablets (backup)", detail: nil),
            ChecklistItem(id: "sip_w4", label: "Gravity filter (Berkey or similar)", detail: nil),
        ]),
        ChecklistCategory(id: "food", name: "Food (2 Weeks)", items: [
            ChecklistItem(id: "sip_f1", label: "42 shelf-stable meals per person", detail: "Canned goods, rice, beans, freeze-dried"),
            ChecklistItem(id: "sip_f2", label: "Manual can opener (2)", detail: nil),
            ChecklistItem(id: "sip_f3", label: "Camp stove + fuel canisters (propane or butane)", detail: "For cooking without power"),
            ChecklistItem(id: "sip_f4", label: "14-day supply of pet food", detail: nil),
        ]),
        ChecklistCategory(id: "sealing", name: "NBC Sealing", items: [
            ChecklistItem(id: "sip_se1", label: "6-mil plastic sheeting (enough to cover all windows/doors)", detail: "Pre-cut and label each piece"),
            ChecklistItem(id: "sip_se2", label: "Duct tape (10+ rolls)", detail: nil),
            ChecklistItem(id: "sip_se3", label: "N95/N100 respirators for each person", detail: nil),
        ]),
        ChecklistCategory(id: "power", name: "Power", items: [
            ChecklistItem(id: "sip_p1", label: "Generator (gasoline or propane)", detail: "NEVER run indoors"),
            ChecklistItem(id: "sip_p2", label: "7-day fuel supply for generator", detail: nil),
            ChecklistItem(id: "sip_p3", label: "Solar charger + battery bank", detail: nil),
            ChecklistItem(id: "sip_p4", label: "Flashlights + 30-day battery supply", detail: nil),
            ChecklistItem(id: "sip_p5", label: "Battery-powered or hand-crank NOAA radio", detail: nil),
        ]),
        ChecklistCategory(id: "sanitation", name: "Sanitation", items: [
            ChecklistItem(id: "sip_s1", label: "5-gallon bucket + toilet seat lid", detail: "Backup toilet if water is out"),
            ChecklistItem(id: "sip_s2", label: "Heavy-duty trash bags (box)", detail: nil),
            ChecklistItem(id: "sip_s3", label: "Cat litter (for waste management)", detail: nil),
            ChecklistItem(id: "sip_s4", label: "Hand sanitizer (gallon jug)", detail: nil),
        ]),
        ChecklistCategory(id: "medical", name: "Medical", items: [
            ChecklistItem(id: "sip_m1", label: "2-week supply of all medications", detail: nil),
            ChecklistItem(id: "sip_m2", label: "Comprehensive first aid kit", detail: nil),
            ChecklistItem(id: "sip_m3", label: "Potassium iodide (KI) tablets", detail: "For nuclear/radiation events — take only if directed"),
        ]),
    ]),

    Checklist(id: "nuclear", name: "Nuclear/Radiation Kit", symbol: "atom", color: .orange,
              description: "Specialized supplies for nuclear detonation or radiological event.",
              categories: [
        ChecklistCategory(id: "protection", name: "Protection", items: [
            ChecklistItem(id: "nuc_p1", label: "Potassium iodide (KI) tablets for each person", detail: "FDA-approved — protects thyroid from radioactive iodine"),
            ChecklistItem(id: "nuc_p2", label: "N100 respirators for each person (10+ each)", detail: "Filters radioactive particles — N95 is minimum"),
            ChecklistItem(id: "nuc_p3", label: "Disposable Tyvek coveralls", detail: nil),
            ChecklistItem(id: "nuc_p4", label: "Nitrile gloves (box)", detail: nil),
            ChecklistItem(id: "nuc_p5", label: "Safety goggles (wraparound)", detail: nil),
        ]),
        ChecklistCategory(id: "sealing", name: "Shelter Sealing", items: [
            ChecklistItem(id: "nuc_se1", label: "6-mil plastic sheeting — pre-cut for each window/door", detail: nil),
            ChecklistItem(id: "nuc_se2", label: "Duct tape (10+ rolls)", detail: nil),
            ChecklistItem(id: "nuc_se3", label: "Pre-sealed 'safe room' identified and prepared", detail: "Interior room with fewest windows"),
        ]),
        ChecklistCategory(id: "decon", name: "Decontamination", items: [
            ChecklistItem(id: "nuc_d1", label: "Large plastic bags for contaminated clothing", detail: nil),
            ChecklistItem(id: "nuc_d2", label: "Unscented soap and shampoo (large bottles)", detail: "For decontamination shower"),
            ChecklistItem(id: "nuc_d3", label: "Extra water stored for decontamination (5+ gal)", detail: nil),
        ]),
        ChecklistCategory(id: "monitoring", name: "Monitoring", items: [
            ChecklistItem(id: "nuc_m1", label: "Radiation dosimeter or Geiger counter", detail: "Optional but extremely valuable"),
            ChecklistItem(id: "nuc_m2", label: "Battery-powered NOAA weather radio", detail: "Primary information source post-event"),
        ]),
    ]),

    Checklist(id: "vehicle", name: "Vehicle Emergency Kit", symbol: "car.fill", color: Color(red: 0.3, green: 0.3, blue: 0.3),
              description: "Supplies kept in your vehicle at all times for roadside emergencies and evacuation.",
              categories: [
        ChecklistCategory(id: "safety", name: "Safety", items: [
            ChecklistItem(id: "veh_sa1", label: "Jumper cables or lithium jump starter pack", detail: nil),
            ChecklistItem(id: "veh_sa2", label: "Warning triangles or road flares (3)", detail: nil),
            ChecklistItem(id: "veh_sa3", label: "Reflective safety vest", detail: nil),
            ChecklistItem(id: "veh_sa4", label: "ABC fire extinguisher (rated for vehicle fires)", detail: nil),
        ]),
        ChecklistCategory(id: "tools", name: "Tools", items: [
            ChecklistItem(id: "veh_t1", label: "Tire pressure gauge", detail: nil),
            ChecklistItem(id: "veh_t2", label: "12V tire inflator/compressor", detail: nil),
            ChecklistItem(id: "veh_t3", label: "Basic tool kit (wrenches, screwdrivers, pliers)", detail: nil),
            ChecklistItem(id: "veh_t4", label: "Duct tape and zip ties", detail: nil),
            ChecklistItem(id: "veh_t5", label: "Spare fuses (assorted)", detail: nil),
        ]),
        ChecklistCategory(id: "supplies", name: "Supplies", items: [
            ChecklistItem(id: "veh_su1", label: "1 gallon water per person", detail: nil),
            ChecklistItem(id: "veh_su2", label: "Emergency food bars (3-day)", detail: nil),
            ChecklistItem(id: "veh_su3", label: "First aid kit", detail: nil),
            ChecklistItem(id: "veh_su4", label: "Flashlight + extra batteries", detail: nil),
            ChecklistItem(id: "veh_su5", label: "Car phone charger", detail: nil),
            ChecklistItem(id: "veh_su6", label: "Paper road maps (Oahu + Hawaii)", detail: nil),
            ChecklistItem(id: "veh_su7", label: "Cash — small bills ($50+)", detail: nil),
        ]),
    ]),

    Checklist(id: "pet", name: "Pet Emergency Kit", symbol: "pawprint.fill", color: .green,
              description: "Emergency supplies for dogs and/or cats during evacuation or shelter-in-place.",
              categories: [
        ChecklistCategory(id: "docs", name: "Documents", items: [
            ChecklistItem(id: "pet_d1", label: "Vaccination records (copy)", detail: "Required for many shelters"),
            ChecklistItem(id: "pet_d2", label: "Photo of you with your pet (proof of ownership)", detail: nil),
            ChecklistItem(id: "pet_d3", label: "Vet contact information (primary + emergency)", detail: nil),
            ChecklistItem(id: "pet_d4", label: "Medication list with dosages", detail: nil),
        ]),
        ChecklistCategory(id: "supplies", name: "Supplies", items: [
            ChecklistItem(id: "pet_su1", label: "3-day food supply (dry or canned)", detail: "Rotate regularly"),
            ChecklistItem(id: "pet_su2", label: "Water + collapsible bowl", detail: nil),
            ChecklistItem(id: "pet_su3", label: "3-day medication supply", detail: nil),
            ChecklistItem(id: "pet_su4", label: "Waste bags and cat litter (if applicable)", detail: nil),
            ChecklistItem(id: "pet_su5", label: "Leash and spare collar with current ID tags", detail: nil),
            ChecklistItem(id: "pet_su6", label: "Carrier or travel crate", detail: "Many shelters require this"),
        ]),
        ChecklistCategory(id: "comfort", name: "Comfort & Medical", items: [
            ChecklistItem(id: "pet_c1", label: "Familiar toy or blanket", detail: "Reduces stress during displacement"),
            ChecklistItem(id: "pet_c2", label: "Pet first aid kit", detail: nil),
            ChecklistItem(id: "pet_c3", label: "Muzzle (even friendly dogs bite when stressed)", detail: nil),
        ]),
    ]),
]

// MARK: - Checklist Engine

@MainActor
class ChecklistEngine: ObservableObject {
    @Published var checked: [String: Set<String>] = [:]
    private let key = "checklist_state_v1"

    init() { load() }

    func isChecked(_ itemID: String, in listID: String) -> Bool {
        checked[listID]?.contains(itemID) ?? false
    }

    func toggle(_ itemID: String, in listID: String) {
        var set = checked[listID] ?? []
        if set.contains(itemID) { set.remove(itemID) } else { set.insert(itemID) }
        checked[listID] = set
        save()
    }

    func reset(_ listID: String) {
        checked[listID] = []
        save()
    }

    func progress(for list: Checklist) -> Double {
        let total = list.allItems.count
        guard total > 0 else { return 0 }
        let done = checked[list.id]?.count ?? 0
        return Double(done) / Double(total)
    }

    func completedCount(for list: Checklist) -> Int {
        checked[list.id]?.count ?? 0
    }

    private func save() {
        let encoded = checked.mapValues { Array($0) }
        if let d = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }

    private func load() {
        guard let d = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: d) else { return }
        checked = decoded.mapValues { Set($0) }
    }
}

// MARK: - Main View

struct ChecklistView: View {
    @StateObject private var engine = ChecklistEngine()
    @State private var selectedID = "kit72"

    private var selectedList: Checklist {
        allChecklists.first { $0.id == selectedID } ?? allChecklists[0]
    }

    var body: some View {
        HStack(spacing: 0) {
            // ── Left: list picker ─────────────────────────────────────────────
            VStack(spacing: 0) {
                Text("Checklists")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                Divider()

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(allChecklists) { list in
                            ChecklistSidebarRow(
                                list: list,
                                progress: engine.progress(for: list),
                                done: engine.completedCount(for: list),
                                isSelected: list.id == selectedID
                            )
                            .onTapGesture { selectedID = list.id }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                }
            }
            .frame(width: 220)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // ── Right: checklist detail ────────────────────────────────────────
            ChecklistDetailView(list: selectedList, engine: engine)
        }
    }
}

// MARK: - Sidebar Row

struct ChecklistSidebarRow: View {
    let list: Checklist
    let progress: Double
    let done: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(list.color.opacity(isSelected ? 0.2 : 0.1))
                    .frame(width: 30, height: 30)
                Image(systemName: list.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(list.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(list.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(NSColor.separatorColor))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(progressColor)
                            .frame(width: geo.size.width * progress, height: 3)
                    }
                }
                .frame(height: 3)

                Text("\(done) / \(list.allItems.count) items")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? list.color.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private var progressColor: Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.5 { return .blue }
        return list.color
    }
}

// MARK: - Checklist Detail

struct ChecklistDetailView: View {
    let list: Checklist
    @ObservedObject var engine: ChecklistEngine
    @State private var showResetAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(list.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: list.symbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(list.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.name)
                        .font(.title3.bold())
                    Text(list.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Overall progress ring
                ZStack {
                    Circle()
                        .stroke(Color(NSColor.separatorColor), lineWidth: 4)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: engine.progress(for: list))
                        .stroke(list.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(engine.progress(for: list) * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                }

                Button {
                    showResetAlert = true
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .alert("Reset \(list.name)?", isPresented: $showResetAlert) {
                    Button("Reset", role: .destructive) { engine.reset(list.id) }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("All checkboxes will be cleared.")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(list.categories) { category in
                        VStack(alignment: .leading, spacing: 6) {
                            // Category header
                            HStack {
                                Text(category.name.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(list.color)
                                Spacer()
                                let catDone = category.items.filter {
                                    engine.isChecked($0.id, in: list.id)
                                }.count
                                Text("\(catDone)/\(category.items.count)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 2)

                            VStack(spacing: 0) {
                                ForEach(category.items) { item in
                                    ChecklistItemRow(
                                        item: item,
                                        isChecked: engine.isChecked(item.id, in: list.id),
                                        color: list.color
                                    ) {
                                        engine.toggle(item.id, in: list.id)
                                    }

                                    if item.id != category.items.last?.id {
                                        Divider().padding(.leading, 40)
                                    }
                                }
                            }
                            .background(Color(NSColor.controlBackgroundColor),
                                        in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1))
                        }
                    }
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Checklist Item Row

struct ChecklistItemRow: View {
    let item: ChecklistItem
    let isChecked: Bool
    let color: Color
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isChecked ? color : Color(NSColor.separatorColor))
                    .animation(.easeInOut(duration: 0.15), value: isChecked)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.system(size: 13))
                        .strikethrough(isChecked, color: .secondary)
                        .foregroundStyle(isChecked ? .secondary : .primary)
                    if let detail = item.detail {
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
