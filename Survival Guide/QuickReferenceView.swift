import SwiftUI
import Combine

// MARK: - Models

struct QREntry: Codable, Identifiable {
    var id = UUID()
    var label: String = ""
    var value: String = ""
    var notes: String = ""
}

struct QRCardData: Codable, Identifiable {
    var id = UUID()
    var title: String = ""
    var symbol: String = "list.bullet"
    var colorName: String = "blue"
    var entries: [QREntry] = []

    var color: Color { QRCardData.colorFor(colorName) }

    static func colorFor(_ name: String) -> Color {
        switch name {
        case "red":    return .red
        case "green":  return .green
        case "blue":   return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return Color(red: 0.85, green: 0.70, blue: 0.0)
        case "teal":   return .teal
        case "cyan":   return .cyan
        case "brown":  return .brown
        case "indigo": return .indigo
        default:       return .gray
        }
    }

    static let colorOptions = ["red","green","blue","orange","purple","yellow","teal","cyan","brown","indigo","gray"]
    static let symbolOptions = [
        "phone.fill", "antenna.radiowaves.left.and.right", "cross.case.fill",
        "house.fill", "exclamationmark.triangle.fill", "map.fill",
        "car.fill", "person.2.fill", "shield.fill", "drop.fill",
        "flame.fill", "bolt.fill", "list.bullet", "doc.text.fill"
    ]
}

// MARK: - Engine

@MainActor
class QuickReferenceEngine: ObservableObject {
    @Published var cards: [QRCardData] = []
    static let shared = QuickReferenceEngine()
    private let key = "quick_ref_cards_v1"

    init() { load(); if cards.isEmpty { seedDefaults() } }

    func addCard(_ c: QRCardData) { cards.append(c); save() }

    func updateCard(_ c: QRCardData) {
        if let i = cards.firstIndex(where: { $0.id == c.id }) { cards[i] = c; save() }
    }

    func deleteCard(_ c: QRCardData) { cards.removeAll { $0.id == c.id }; save() }

    func moveCards(from: IndexSet, to: Int) { cards.move(fromOffsets: from, toOffset: to); save() }

    func save() {
        if let d = try? JSONEncoder().encode(cards) { UserDefaults.standard.set(d, forKey: key) }
    }

    private func load() {
        guard let d = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([QRCardData].self, from: d) else { return }
        cards = decoded
    }

    private func seedDefaults() {
        cards = [
            QRCardData(title: "Emergency Contacts", symbol: "phone.fill", colorName: "red", entries: [
                QREntry(label: "Emergency",             value: "911"),
                QREntry(label: "Coast Guard (HNL)",     value: "(808) 535-3333"),
                QREntry(label: "Poison Control",        value: "1-800-222-1222"),
                QREntry(label: "Hawaii Emergency Mgmt", value: "(808) 733-4300"),
                QREntry(label: "Red Cross Hawaii",      value: "(808) 734-2101"),
                QREntry(label: "FEMA Helpline",         value: "1-800-621-3362"),
                QREntry(label: "Suicide/Crisis",        value: "988"),
            ]),
            QRCardData(title: "Radio Frequencies", symbol: "antenna.radiowaves.left.and.right", colorName: "green", entries: [
                QREntry(label: "NOAA Weather",     value: "162.550 MHz"),
                QREntry(label: "ARES Repeater",    value: "147.06 (+) MHz"),
                QREntry(label: "HPD Dispatch",     value: "155.910 MHz"),
                QREntry(label: "HFD Dispatch",     value: "154.280 MHz"),
                QREntry(label: "Civil Air Patrol", value: "148.150 MHz"),
                QREntry(label: "Marine (Distress)",value: "156.800 MHz (Ch 16)"),
                QREntry(label: "AM Emergency",     value: "590 KSSK / 830 KHVH"),
            ]),
            QRCardData(title: "Hospitals & Trauma Centers", symbol: "cross.case.fill", colorName: "red", entries: [
                QREntry(label: "Queen's Medical (Level I)",   value: "1301 Punchbowl St"),
                QREntry(label: "Tripler Army Med (Level I)",  value: "1 Jarrett White Rd"),
                QREntry(label: "Pali Momi Medical",           value: "98-1079 Moanalua Rd"),
                QREntry(label: "Castle Medical (Kailua)",     value: "640 Ulukahiki St"),
                QREntry(label: "Kapiolani (Women/Children)",  value: "1319 Punahou St"),
                QREntry(label: "Straub Medical",              value: "888 S King St"),
                QREntry(label: "Kapolei VA Clinic",           value: "91-2114 Fort Weaver Rd"),
            ]),
            QRCardData(title: "Hurricane Shelters", symbol: "house.fill", colorName: "blue", entries: [
                QREntry(label: "Neal Blaisdell Center",  value: "777 Ward Ave"),
                QREntry(label: "McKinley High School",   value: "1039 S King St"),
                QREntry(label: "Farrington High School", value: "1564 N King St"),
                QREntry(label: "Kaiser High School",     value: "511 Lunalilo Home Rd"),
                QREntry(label: "Current shelters",       value: "Call 211"),
            ]),
            QRCardData(title: "Critical Local Facts", symbol: "exclamationmark.triangle.fill", colorName: "orange", entries: [
                QREntry(label: "Food supply on island",     value: "7–14 days"),
                QREntry(label: "Food imported",             value: "~85–90%"),
                QREntry(label: "Tsunami warning (Alaska)",  value: "4–5 hours"),
                QREntry(label: "Tsunami warning (local)",   value: "Minutes only"),
                QREntry(label: "Hurricane season",          value: "June – November"),
                QREntry(label: "Water source",              value: "BWS Groundwater"),
                QREntry(label: "Power grid",                value: "HECO (island isolated)"),
                QREntry(label: "Distance to US mainland",   value: "2,390 miles"),
                QREntry(label: "Key evacuation routes",     value: "H-1, H-2, H-3, Pali Hwy"),
                QREntry(label: "Tunnels in earthquake",     value: "May close — use alternate"),
                QREntry(label: "Fallout arrival (nuclear)", value: "15–60 min after detonation"),
                QREntry(label: "Shelter-in-place minimum",  value: "24 hours for nuclear"),
            ]),
        ]
        save()
    }
}

// MARK: - Quick Reference View

struct QuickReferenceView: View {
    @StateObject private var engine = QuickReferenceEngine.shared
    @State private var selectedScenario = "Nuclear"
    @ObservedObject private var locationStore = LocationStore.shared
    @State private var showAddCard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Header ────────────────────────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Emergency Quick Reference")
                            .font(.title2.bold())
                        let loc = locationStore.config.displayName
                        Text("\(loc.isEmpty ? "Your Location" : loc) · Available offline at all times")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { showAddCard = true } label: {
                        Label("Add Card", systemImage: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    Label("Offline · Always available", systemImage: "checkmark.shield.fill")
                        .font(.caption).foregroundStyle(.green)
                        .padding(.leading, 8)
                }

                // ── Data Cards (2-column grid) ────────────────────────────────
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(engine.cards) { card in
                        EditableQRCard(card: card, engine: engine)
                    }
                }

                // ── Immediate Action Plans ────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Text("Immediate Action Plans")
                        .font(.headline)

                    Picker("Scenario", selection: $selectedScenario) {
                        Text("☢️  Nuclear").tag("Nuclear")
                        Text("🌊  Tsunami").tag("Tsunami")
                        Text("🌀  Hurricane").tag("Hurricane")
                        Text("⚡  Grid Down").tag("Grid Down")
                        Text("🩺  Medical").tag("Medical")
                    }
                    .pickerStyle(.segmented)

                    Group {
                        switch selectedScenario {
                        case "Nuclear":   NuclearPlan()
                        case "Tsunami":   TsunamiPlan()
                        case "Hurricane": HurricanePlan()
                        case "Medical":   MedicalPlan()
                        default:          GridDownPlan()
                        }
                    }
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showAddCard) {
            QRCardEditorSheet(card: QRCardData()) { engine.addCard($0) }
        }
    }
}

// MARK: - Editable Card

private struct EditableQRCard: View {
    let card: QRCardData
    @ObservedObject var engine: QuickReferenceEngine
    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: card.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(card.color)
                Text(card.title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { showEdit = true } label: {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit card")
            }
            Divider()
            ForEach(card.entries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top) {
                        Text(entry.label)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text(entry.value)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                    }
                    if !entry.notes.isEmpty {
                        Text(entry.notes)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 1)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(card.color.opacity(0.2), lineWidth: 1))
        .sheet(isPresented: $showEdit) {
            QRCardEditorSheet(card: card) { engine.updateCard($0) }
        }
    }
}

// MARK: - Card Editor Sheet

struct QRCardEditorSheet: View {
    @State var card: QRCardData
    let onSave: (QRCardData) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var editingEntry: QREntry?
    @State private var addingEntry = false

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(card.title.isEmpty ? "New Card" : "Edit: \(card.title)")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(card); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .disabled(card.title.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            Form {
                Section("Card") {
                    TextField("Title", text: $card.title)

                    Picker("Color", selection: $card.colorName) {
                        ForEach(QRCardData.colorOptions, id: \.self) { name in
                            HStack(spacing: 6) {
                                Circle().fill(QRCardData.colorFor(name)).frame(width: 10, height: 10)
                                Text(name.capitalized)
                            }
                            .tag(name)
                        }
                    }

                    Picker("Icon", selection: $card.symbol) {
                        ForEach(QRCardData.symbolOptions, id: \.self) { sym in
                            Label(sym, systemImage: sym).tag(sym)
                        }
                    }
                }

                Section {
                    ForEach(card.entries) { entry in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.label.isEmpty ? "Untitled" : entry.label)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(entry.value.isEmpty ? "—" : entry.value)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                if !entry.notes.isEmpty {
                                    Text(entry.notes)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            Button {
                                editingEntry = entry
                            } label: {
                                Image(systemName: "pencil").font(.system(size: 11))
                            }
                            .buttonStyle(.plain).foregroundStyle(.secondary)

                            Button {
                                card.entries.removeAll { $0.id == entry.id }
                            } label: {
                                Image(systemName: "trash").font(.system(size: 11))
                            }
                            .buttonStyle(.plain).foregroundStyle(.red.opacity(0.7))
                        }
                        .padding(.vertical, 2)
                    }
                    .onMove { card.entries.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { card.entries.remove(atOffsets: $0) }

                    Button {
                        addingEntry = true
                    } label: {
                        Label("Add Entry", systemImage: "plus")
                            .font(.system(size: 13))
                    }
                } header: {
                    HStack {
                        Text("Entries (\(card.entries.count))")
                        Spacer()
                        Text("Drag to reorder")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 500, minHeight: 520)
        .sheet(item: $editingEntry) { entry in
            QREntrySheet(entry: entry) { updated in
                if let i = card.entries.firstIndex(where: { $0.id == updated.id }) {
                    card.entries[i] = updated
                }
            }
        }
        .sheet(isPresented: $addingEntry) {
            QREntrySheet(entry: QREntry()) { card.entries.append($0) }
        }
    }
}

// MARK: - Entry Editor Sheet

struct QREntrySheet: View {
    @State var entry: QREntry
    let onSave: (QREntry) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry.label.isEmpty ? "Add Entry" : "Edit Entry")
                .font(.headline)
                .padding(.horizontal)

            Form {
                Section {
                    TextField("Label (e.g. Coast Guard)", text: $entry.label)
                    TextField("Value (e.g. (808) 535-3333)", text: $entry.value)
                }
                Section("Additional Notes (optional)") {
                    TextField("Any extra details, hours, caveats…", text: $entry.notes)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(entry); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .disabled(entry.label.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .frame(width: 420)
    }
}

// MARK: - Action Plans

private struct NuclearPlan: View {
    var body: some View {
        ActionPlanCard(color: .orange, steps: [
            ActionStep(n: 1, title: "GET INSIDE immediately",
                       detail: "Any solid building. Move to interior rooms, away from windows. Higher floors if not coastal."),
            ActionStep(n: 2, title: "SEAL the space",
                       detail: "Close all windows, doors, fireplace dampers. Tape plastic sheeting over gaps if available."),
            ActionStep(n: 3, title: "STAY INSIDE — minimum 24 hours",
                       detail: "Fallout arrives 15–60 min after detonation. Radioactivity drops ~90% in the first 7 hours."),
            ActionStep(n: 4, title: "Remove outer clothing if exposed",
                       detail: "Removing clothes eliminates ~80% of fallout. Shower with soap and water immediately."),
            ActionStep(n: 5, title: "TUNE to NOAA 162.550 MHz",
                       detail: "Follow official instructions for evacuation or extended shelter-in-place."),
            ActionStep(n: 6, title: "Do NOT use KI unless directed",
                       detail: "Potassium iodide only protects the thyroid. Take only if radioactive iodine release is confirmed by officials."),
        ])
    }
}

private struct TsunamiPlan: View {
    var body: some View {
        ActionPlanCard(color: .blue, steps: [
            ActionStep(n: 1, title: "Strong or long earthquake = GO NOW",
                       detail: "Don't wait for a siren. If you feel a strong quake near the coast, move inland immediately — local tsunamis arrive in minutes."),
            ActionStep(n: 2, title: "Move inland and uphill",
                       detail: "Minimum 100 ft elevation or 1 mile from shore. H-3, Pali Highway, or H-1 east toward Kailua/Kaneohe."),
            ActionStep(n: 3, title: "Alaska source: 4–5 hour warning",
                       detail: "Sirens will sound. Tune to NOAA 162.550 MHz. Leave blue (high-risk) inundation zones immediately."),
            ActionStep(n: 4, title: "Do NOT watch from the shore",
                       detail: "Tsunami receding water is a sign of imminent wave. People die doing this every event."),
            ActionStep(n: 5, title: "First wave may not be largest",
                       detail: "Waves continue for hours. Stay put until official ALL-CLEAR from Civil Defense."),
            ActionStep(n: 6, title: "Avoid flooded roads after",
                       detail: "6 inches of moving water can knock a person down. 12 inches can sweep a vehicle."),
        ])
    }
}

private struct HurricanePlan: View {
    var body: some View {
        ActionPlanCard(color: Color(red: 0.5, green: 0.0, blue: 0.5), steps: [
            ActionStep(n: 1, title: "48 hours before: prepare",
                       detail: "Fill all water containers and bathtubs. Fuel vehicles. Charge all devices. Secure or bring in outdoor items."),
            ActionStep(n: 2, title: "Cat 1–2: shelter in place",
                       detail: "Interior room, lowest floor, away from windows. Bring supplies: water, food, radio, first aid."),
            ActionStep(n: 3, title: "Cat 3+: evacuate if ordered",
                       detail: "Mandatory evacuation for flood zones and mobile homes. Leave early — roads jam fast."),
            ActionStep(n: 4, title: "During: stay in safe room",
                       detail: "Do not go outside during storm. Calm 'eye' lasts 20–30 min — the other eyewall follows immediately."),
            ActionStep(n: 5, title: "After: watch for flooding",
                       detail: "Most hurricane deaths occur from flooding, not wind. Don't drive through flooded roads."),
            ActionStep(n: 6, title: "Downed power lines = deadly",
                       detail: "Stay 30+ feet from downed lines. Assume all lines are live. Report to HEI: (808) 548-7311."),
        ])
    }
}

private struct GridDownPlan: View {
    var body: some View {
        ActionPlanCard(color: .yellow, steps: [
            ActionStep(n: 1, title: "Fill ALL water containers now",
                       detail: "BWS pumps run on electricity. Fill bathtubs, pots, every container before pressure drops."),
            ActionStep(n: 2, title: "Prioritize fresh food first",
                       detail: "Eat refrigerator contents first (4 hrs), then freezer (24–48 hrs unopened), then shelf-stable."),
            ActionStep(n: 3, title: "Turn off main breaker",
                       detail: "Prevents power surge damage when grid restores. Turn back on appliance-by-appliance after power returns."),
            ActionStep(n: 4, title: "Generator OUTSIDE only",
                       detail: "Carbon monoxide is invisible and odorless. Never run generator indoors, in garage, or near windows."),
            ActionStep(n: 5, title: "Conserve phone battery",
                       detail: "Enable airplane mode except when checking for information. A charged phone lasts days in airplane mode."),
            ActionStep(n: 6, title: "Community coordination",
                       detail: "Check on elderly neighbors. Pool resources. ARES net on 147.06 MHz for community information."),
        ])
    }
}

private struct MedicalPlan: View {
    @State private var selectedCondition = "CPR"
    private let conditions = ["CPR", "Choking", "Bleeding", "Shock", "Burns", "Hypothermia", "Heat Stroke", "Fracture"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(conditions, id: \.self) { c in
                        Button { selectedCondition = c } label: {
                            Text(c)
                                .font(.system(size: 11, weight: selectedCondition == c ? .semibold : .regular))
                                .foregroundStyle(selectedCondition == c ? .white : .primary)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(selectedCondition == c ? Color.red : Color.primary.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            switch selectedCondition {
            case "CPR":
                ActionPlanCard(color: .red, steps: [
                    ActionStep(n: 1, title: "Check scene safety, then responsiveness", detail: "Tap shoulders firmly: 'Are you okay?' — if no response, call 911 or send someone."),
                    ActionStep(n: 2, title: "Open airway, check breathing (10 sec)", detail: "Tilt head back, lift chin. Look for chest rise, listen, feel for breath."),
                    ActionStep(n: 3, title: "30 chest compressions — HARD and FAST", detail: "Heel of hand, center of chest. 2–2.4 inch depth. 100–120/min (Stayin' Alive tempo)."),
                    ActionStep(n: 4, title: "2 rescue breaths", detail: "Pinch nose, form seal, breathe until chest rises (1 sec each). Skip if untrained — hands-only CPR is effective."),
                    ActionStep(n: 5, title: "Repeat 30:2 until AED arrives or help comes", detail: "Don't stop unless the person breathes normally, you're physically unable to continue, or a trained rescuer takes over."),
                    ActionStep(n: 6, title: "Child / infant: same ratio, less force", detail: "Child: 1 hand, 1.5\" depth. Infant: 2 fingers, 1.5\" depth, cradle head during breaths."),
                ])
            case "Choking":
                ActionPlanCard(color: .orange, steps: [
                    ActionStep(n: 1, title: "Confirm choking — can they speak or cough?", detail: "If they can speak or cough forcefully, let them. Only intervene if they cannot breathe, cough, or speak."),
                    ActionStep(n: 2, title: "5 firm back blows between shoulder blades", detail: "Heel of hand, lean them forward slightly. Alternate with abdominal thrusts."),
                    ActionStep(n: 3, title: "5 abdominal thrusts (Heimlich)", detail: "Stand behind, one foot forward. Fist above navel, pull sharply inward and upward."),
                    ActionStep(n: 4, title: "Alternate 5+5 until clear or unconscious", detail: "If they go unconscious: lower to ground, start CPR, look in mouth before each breath, remove object if visible."),
                    ActionStep(n: 5, title: "Pregnant or obese: chest thrusts only", detail: "Replace abdominal thrusts with chest thrusts at breastbone center — same firm inward motion."),
                    ActionStep(n: 6, title: "Infant (under 1 year): different technique", detail: "5 back blows face-down on forearm, then 5 chest thrusts face-up on forearm. NEVER abdominal thrusts on infant."),
                ])
            case "Bleeding":
                ActionPlanCard(color: Color(red: 0.7, green: 0.0, blue: 0.0), steps: [
                    ActionStep(n: 1, title: "Apply direct firm pressure immediately", detail: "Use cloth, gauze, or clothing. Press hard and don't let go. Do NOT peek — lifting releases clot."),
                    ActionStep(n: 2, title: "Limb bleeding: tourniquet if severe", detail: "Apply 2–3 inches above wound (not over joint). Tighten until bleeding stops. Write time on forehead or tourniquet."),
                    ActionStep(n: 3, title: "Deep wound: pack with gauze", detail: "Push gauze deeply into the wound. Apply 3 minutes of firm pressure without releasing."),
                    ActionStep(n: 4, title: "Elevate the limb above heart level", detail: "Only if no fracture suspected. Combine with direct pressure."),
                    ActionStep(n: 5, title: "Do NOT remove embedded objects", detail: "Stabilize the object in place with bulky dressings around it. Removing can cause massive bleeding."),
                    ActionStep(n: 6, title: "Watch for shock signs", detail: "Pale/cold/clammy skin, rapid weak pulse, confusion. See Shock protocol."),
                ])
            case "Shock":
                ActionPlanCard(color: .purple, steps: [
                    ActionStep(n: 1, title: "Lay person flat on their back", detail: "Do not allow them to sit or stand. Lying flat maintains blood flow to brain."),
                    ActionStep(n: 2, title: "Elevate legs 12 inches if no spine injury", detail: "Improves blood return to vital organs. Do NOT elevate if head/neck/back injury is suspected."),
                    ActionStep(n: 3, title: "Keep warm — prevent heat loss", detail: "Cover with blanket or extra clothing. Cold worsens shock significantly."),
                    ActionStep(n: 4, title: "Control any bleeding", detail: "See Bleeding protocol. Shock is often caused by blood loss."),
                    ActionStep(n: 5, title: "No food or water by mouth", detail: "Risk of vomiting and aspiration. Moisten lips only if conscious and not vomiting."),
                    ActionStep(n: 6, title: "Monitor and reassure — stay with them", detail: "Check breathing every 2 minutes. Keep them calm. Anxiety worsens shock."),
                ])
            case "Burns":
                ActionPlanCard(color: Color(red: 0.8, green: 0.3, blue: 0.0), steps: [
                    ActionStep(n: 1, title: "Remove from heat source safely", detail: "Don't burn yourself rescuing them. Remove clothing and jewelry near burn unless stuck to skin."),
                    ActionStep(n: 2, title: "Cool with room-temperature running water 10–20 min", detail: "NOT ice, NOT ice water, NOT butter, NOT toothpaste. Cool water only. Ice causes additional tissue damage."),
                    ActionStep(n: 3, title: "Cover loosely with clean non-stick material", detail: "Cling wrap (non-circular), clean cloth, or sterile dressing. Do not wrap tightly."),
                    ActionStep(n: 4, title: "Do NOT pop blisters", detail: "Blisters protect against infection. Popped blisters dramatically increase infection risk."),
                    ActionStep(n: 5, title: "Seek care for burns larger than palm", detail: "Burns on face, hands, feet, genitals, or joints, or any electrical/chemical burn need immediate medical attention."),
                    ActionStep(n: 6, title: "Chemical burn: flush continuously 20+ min", detail: "Brush off dry chemicals first. Flush with large amounts of water. Remove contaminated clothing."),
                ])
            case "Hypothermia":
                ActionPlanCard(color: .blue, steps: [
                    ActionStep(n: 1, title: "Remove from cold — gentle handling", detail: "Rough movement can trigger cardiac arrest in severe hypothermia. Handle gently."),
                    ActionStep(n: 2, title: "Remove wet clothing carefully", detail: "Cut clothing off if needed. Wet clothing continues to pull heat even indoors."),
                    ActionStep(n: 3, title: "Warm the core first, not extremities", detail: "Warm trunk (armpits, neck, groin) with warm packs or body heat. Warming extremities first can cause rewarming shock."),
                    ActionStep(n: 4, title: "Insulate from below and above", detail: "Lying on cold ground continues heat loss. Use sleeping bag, blankets, or dry clothing underneath."),
                    ActionStep(n: 5, title: "Warm fluids only if fully conscious", detail: "Warm (NOT hot) non-alcoholic drinks if person is alert and can swallow safely. No alcohol."),
                    ActionStep(n: 6, title: "Severe cases: monitor pulse for 60 seconds", detail: "Pulse may be very slow and hard to detect. If no pulse found after 60 sec, begin CPR."),
                ])
            case "Heat Stroke":
                ActionPlanCard(color: .orange, steps: [
                    ActionStep(n: 1, title: "Move to shade or cool indoors immediately", detail: "Heat stroke (103°F+ body temp, no sweating, confused) is life-threatening. Act fast."),
                    ActionStep(n: 2, title: "Remove excess clothing", detail: "Airflow over skin is critical for cooling. Keep only minimal, loose clothing."),
                    ActionStep(n: 3, title: "Apply cold water to skin and fan aggressively", detail: "Focus ice or cold packs on neck, armpits, and groin. This cools major blood vessels fastest."),
                    ActionStep(n: 4, title: "Do NOT give fluids if confused or unconscious", detail: "Aspiration risk. If alert and able to swallow, cool water or electrolyte drink is appropriate."),
                    ActionStep(n: 5, title: "Do NOT give fever-reducing medications", detail: "Aspirin and acetaminophen do not help heat stroke and may cause additional harm."),
                    ActionStep(n: 6, title: "Heat exhaustion vs. heat stroke", detail: "Exhaustion: heavy sweating, pale, weak — move to cool area, hydrate. Stroke: no sweat, hot red skin, confusion — emergency."),
                ])
            default:  // Fracture
                ActionPlanCard(color: .brown, steps: [
                    ActionStep(n: 1, title: "Do NOT attempt to straighten the limb", detail: "Splint it in the position found. Straightening can cause additional injury and severe pain."),
                    ActionStep(n: 2, title: "Check circulation before and after splinting", detail: "Feel pulse below the injury, check sensation and movement in fingers/toes. Recheck every 15 minutes."),
                    ActionStep(n: 3, title: "Immobilize one joint above and below break", detail: "Rigid splint (board, rolled magazine, sticks) padded with cloth. Secure above and below fracture site."),
                    ActionStep(n: 4, title: "Elevate the injured limb if possible", detail: "Reduces swelling and pain. Do NOT elevate if movement causes increased pain."),
                    ActionStep(n: 5, title: "Watch for compartment syndrome", detail: "5 Ps: Pain (increasing), Pressure (tight), Paralysis, Paresthesia (pins/needles), Pallor. Medical emergency."),
                    ActionStep(n: 6, title: "Open fracture: cover wound, do not push bone in", detail: "Cover exposed bone with clean moist dressing. Treat for severe bleeding. Infection risk is very high."),
                ])
            }
        }
    }
}

// MARK: - Shared Components

struct ActionStep: Identifiable {
    let id = UUID()
    let n: Int
    let title: String
    let detail: String
}

struct ActionPlanCard: View {
    let color: Color
    let steps: [ActionStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(steps) { step in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle().fill(color.opacity(0.15)).frame(width: 26, height: 26)
                        Text("\(step.n)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title).font(.system(size: 13, weight: .semibold))
                        Text(step.detail)
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if step.n < steps.count { Divider().padding(.leading, 38) }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.25), lineWidth: 1))
    }
}
