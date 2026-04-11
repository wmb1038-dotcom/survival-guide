import SwiftUI

// MARK: - Quick Reference View

struct QuickReferenceView: View {
    @State private var selectedScenario = "Nuclear"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Header ────────────────────────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Emergency Quick Reference")
                            .font(.title2.bold())
                        Text("Oahu, Hawaii · Available offline at all times")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label("Offline · Always available", systemImage: "checkmark.shield.fill")
                        .font(.caption).foregroundStyle(.green)
                }

                // ── Row 1: Contacts + Frequencies ────────────────────────────
                HStack(alignment: .top, spacing: 14) {
                    QRCard(title: "Emergency Contacts", symbol: "phone.fill", color: .red) {
                        QRRow(label: "Emergency",              value: "911")
                        QRRow(label: "Coast Guard (HNL)",      value: "(808) 535-3333")
                        QRRow(label: "Poison Control",         value: "1-800-222-1222")
                        QRRow(label: "Hawaii Emergency Mgmt",  value: "(808) 733-4300")
                        QRRow(label: "Red Cross Hawaii",       value: "(808) 734-2101")
                        QRRow(label: "FEMA Helpline",          value: "1-800-621-3362")
                        QRRow(label: "Suicide/Crisis",         value: "988")
                    }

                    QRCard(title: "Radio Frequencies", symbol: "antenna.radiowaves.left.and.right", color: .green) {
                        QRRow(label: "NOAA Weather",           value: "162.550 MHz")
                        QRRow(label: "ARES Repeater",          value: "147.06 (+) MHz")
                        QRRow(label: "HPD Dispatch",           value: "155.910 MHz")
                        QRRow(label: "HFD Dispatch",           value: "154.280 MHz")
                        QRRow(label: "Civil Air Patrol",       value: "148.150 MHz")
                        QRRow(label: "Marine (Distress)",      value: "156.800 MHz (Ch 16)")
                        QRRow(label: "AM Emergency",           value: "590 KSSK / 830 KHVH")
                    }
                }

                // ── Row 2: Hospitals + Shelters ───────────────────────────────
                HStack(alignment: .top, spacing: 14) {
                    QRCard(title: "Hospitals & Trauma Centers", symbol: "cross.case.fill", color: .red) {
                        QRRow(label: "Queen's Medical (Level I)",  value: "1301 Punchbowl St")
                        QRRow(label: "Tripler Army Med (Level I)", value: "1 Jarrett White Rd")
                        QRRow(label: "Pali Momi Medical",          value: "98-1079 Moanalua Rd")
                        QRRow(label: "Castle Medical (Kailua)",    value: "640 Ulukahiki St")
                        QRRow(label: "Kapiolani (Women/Children)", value: "1319 Punahou St")
                        QRRow(label: "Straub Medical",             value: "888 S King St")
                    }

                    QRCard(title: "Hurricane Shelters", symbol: "house.fill", color: .blue) {
                        QRRow(label: "Neal Blaisdell Center",  value: "777 Ward Ave")
                        QRRow(label: "Aloha Stadium",          value: "99-500 Salt Lake Blvd")
                        QRRow(label: "McKinley High School",   value: "1039 S King St")
                        QRRow(label: "Farrington High School", value: "1564 N King St")
                        QRRow(label: "Kaiser High School",     value: "511 Lunalilo Home Rd")
                        QRRow(label: "Current shelters",       value: "Call 211")
                    }
                }

                // ── Critical Facts ────────────────────────────────────────────
                QRCard(title: "Critical Oahu Facts", symbol: "exclamationmark.triangle.fill", color: .orange) {
                    HStack(alignment: .top, spacing: 30) {
                        VStack(alignment: .leading, spacing: 7) {
                            QRFact(label: "Food supply on island",    value: "7–14 days")
                            QRFact(label: "Food imported",            value: "~85–90%")
                            QRFact(label: "Tsunami warning (Alaska)", value: "4–5 hours")
                            QRFact(label: "Tsunami warning (local)",  value: "Minutes only")
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            QRFact(label: "Hurricane season",         value: "June – November")
                            QRFact(label: "Water source",             value: "BWS Groundwater")
                            QRFact(label: "Power grid",               value: "HECO (island isolated)")
                            QRFact(label: "Distance to US mainland",  value: "2,390 miles")
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            QRFact(label: "Key evacuation routes",    value: "H-1, H-2, H-3, Pali Hwy")
                            QRFact(label: "Tunnels in earthquake",    value: "May close — use alternate")
                            QRFact(label: "Fallout arrival (nuclear)",value: "15–60 min after detonation")
                            QRFact(label: "Shelter-in-place minimum", value: "24 hours for nuclear")
                        }
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
                    }
                    .pickerStyle(.segmented)

                    Group {
                        switch selectedScenario {
                        case "Nuclear":   NuclearPlan()
                        case "Tsunami":   TsunamiPlan()
                        case "Hurricane": HurricanePlan()
                        default:          GridDownPlan()
                        }
                    }
                }
            }
            .padding(20)
        }
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

// MARK: - Reusable Components

struct QRCard<Content: View>: View {
    let title: String
    let symbol: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            Divider()
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(color.opacity(0.2), lineWidth: 1))
    }
}

struct QRRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }
}

struct QRFact: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
        }
    }
}

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
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 26, height: 26)
                        Text("\(step.n)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.system(size: 13, weight: .semibold))
                        Text(step.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
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
