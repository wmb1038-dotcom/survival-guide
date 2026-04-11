import SwiftUI
import Combine

// MARK: - Models

struct SkillItem: Identifiable {
    let id: String     // stable unique ID for persistence
    let category: String
    let name: String
    let description: String
    let priority: Int  // 1 = critical, 2 = important, 3 = useful
}

// MARK: - Skill Database

let allSkills: [SkillItem] = [
    // Medical & First Aid
    SkillItem(id: "med_cpr_adult",     category: "Medical & First Aid", name: "CPR — Adult",                 description: "30 compressions : 2 breaths, 100–120/min, 2+ inches depth",       priority: 1),
    SkillItem(id: "med_cpr_child",     category: "Medical & First Aid", name: "CPR — Child / Infant",         description: "Same ratio but 1 hand, 1.5\" depth; 2 fingers for infant",         priority: 1),
    SkillItem(id: "med_aed",           category: "Medical & First Aid", name: "AED Use",                      description: "Power on, attach pads, follow prompts, resume CPR immediately",    priority: 1),
    SkillItem(id: "med_tourniquet",    category: "Medical & First Aid", name: "Tourniquet Application",        description: "2–3\" above wound, tighten until bleeding stops, note time",       priority: 1),
    SkillItem(id: "med_wound_pack",    category: "Medical & First Aid", name: "Wound Packing (hemostatic)",    description: "Pack deeply with gauze, apply firm 3-minute pressure",             priority: 1),
    SkillItem(id: "med_heimlich",      category: "Medical & First Aid", name: "Heimlich Maneuver",             description: "5 back blows + 5 abdominal thrusts — repeat until clear",         priority: 1),
    SkillItem(id: "med_firstaid_cert", category: "Medical & First Aid", name: "First Aid Certified (Red Cross or equivalent)", description: "Maintains current certification",                priority: 1),
    SkillItem(id: "med_splint",        category: "Medical & First Aid", name: "Improvised Splinting",          description: "Immobilize fracture with rigid material + padding",               priority: 2),
    SkillItem(id: "med_shock",         category: "Medical & First Aid", name: "Treating Shock",                description: "Lay flat, elevate legs, keep warm, do not give fluids",          priority: 2),
    SkillItem(id: "med_burns",         category: "Medical & First Aid", name: "Burn Treatment",                description: "Cool water 10+ min, no butter or ice, cover loosely",            priority: 2),
    SkillItem(id: "med_hypothermia",   category: "Medical & First Aid", name: "Hypothermia Response",          description: "Warm core first, remove wet clothes, warm drink if conscious",   priority: 2),
    SkillItem(id: "med_heatstroke",    category: "Medical & First Aid", name: "Heat Stroke Response",          description: "Move to shade, cool rapidly with wet cloth to neck/armpits/groin", priority: 2),
    SkillItem(id: "med_suture",        category: "Medical & First Aid", name: "Wound Closure (steri-strips)",  description: "Clean wound, close with steri-strips or wound closure strips",    priority: 3),

    // Communications
    SkillItem(id: "comm_noaa",         category: "Communications", name: "Monitor NOAA Weather Radio",         description: "Knows primary frequency (162.550) and how to receive alerts",     priority: 1),
    SkillItem(id: "comm_ham_tech",     category: "Communications", name: "Ham Radio — Technician License",     description: "FCC Technician license — VHF/UHF operation",                     priority: 1),
    SkillItem(id: "comm_ham_general",  category: "Communications", name: "Ham Radio — General License",        description: "HF privilege — long-range emergency communication",               priority: 2),
    SkillItem(id: "comm_ares",         category: "Communications", name: "ARES / RACES Member",                description: "Amateur Radio Emergency Service — local emergency nets",          priority: 2),
    SkillItem(id: "comm_phonetic",     category: "Communications", name: "NATO Phonetic Alphabet (from memory)",description: "Can spell messages clearly: Alpha, Bravo, Charlie…",            priority: 2),
    SkillItem(id: "comm_morse",        category: "Communications", name: "Morse Code (SOS + basics)",          description: "Can send and receive SOS (··· ––– ···) and basic messages",      priority: 2),
    SkillItem(id: "comm_frs",          category: "Communications", name: "FRS/GMRS Radio Operation",           description: "Understands channels, range, battery, and protocol",             priority: 2),
    SkillItem(id: "comm_ch16",         category: "Communications", name: "Marine Radio Ch 16 Protocol",        description: "Knows MAYDAY procedure and working channel switch",              priority: 3),
    SkillItem(id: "comm_signal_mirror",category: "Communications", name: "Signal Mirror Use",                  description: "Can aim mirror flash at distant aircraft or vessel",             priority: 3),

    // Water & Food
    SkillItem(id: "wf_bleach",         category: "Water & Food", name: "Water Purification — Bleach",          description: "8 drops/gal (6% bleach), 30 min wait, check smell",             priority: 1),
    SkillItem(id: "wf_boil",           category: "Water & Food", name: "Water Purification — Boiling",         description: "Rolling boil 1 min (3 min above 6,500 ft)",                     priority: 1),
    SkillItem(id: "wf_storage",        category: "Water & Food", name: "Water Storage (14-day supply)",        description: "Maintains adequate stored water for household",                  priority: 1),
    SkillItem(id: "wf_filter",         category: "Water & Food", name: "Improvised Water Filter",              description: "Gravity filter: gravel → sand → charcoal → cloth",              priority: 2),
    SkillItem(id: "wf_rainwater",      category: "Water & Food", name: "Rainwater Collection",                 description: "Set up collection system from roof/tarp to container",          priority: 2),
    SkillItem(id: "wf_canning",        category: "Water & Food", name: "Home Canning (pressure or water bath)", description: "Safely preserves food for long-term storage",                  priority: 2),
    SkillItem(id: "wf_foraging",       category: "Water & Food", name: "Local Edible Plant Identification",    description: "Can identify 5+ safe edible plants in local area",              priority: 3),
    SkillItem(id: "wf_fishing",        category: "Water & Food", name: "Fishing (basic)",                      description: "Can catch fish with rod, line, or improvised methods",          priority: 3),
    SkillItem(id: "wf_garden",         category: "Water & Food", name: "Vegetable Gardening",                  description: "Grows food — knows planting seasons for local area",            priority: 3),

    // Shelter & Fire
    SkillItem(id: "sf_tarp",           category: "Shelter & Fire", name: "Emergency Tarp Shelter",             description: "Can rig weatherproof tarp with ridgeline and stakes",           priority: 1),
    SkillItem(id: "sf_fire_lighter",   category: "Shelter & Fire", name: "Fire Starting — Lighter/Matches",    description: "Knows fire triangle, tinder prep, wind protection",             priority: 1),
    SkillItem(id: "sf_fire_ferro",     category: "Shelter & Fire", name: "Fire Starting — Ferrocerium Rod",    description: "Sparks onto dry tinder using ferro rod",                        priority: 2),
    SkillItem(id: "sf_fire_friction",  category: "Shelter & Fire", name: "Fire Starting — Friction (bow drill)", description: "Primitive fire starting without modern tools",               priority: 3),
    SkillItem(id: "sf_insulation",     category: "Shelter & Fire", name: "Cold Weather Layering",              description: "Base/mid/outer layer system — avoids cotton, manages moisture", priority: 2),
    SkillItem(id: "sf_repairs",        category: "Shelter & Fire", name: "Basic Home Repairs",                 description: "Can patch roof, seal windows, fix plumbing shutoff",           priority: 2),
    SkillItem(id: "sf_generator",      category: "Shelter & Fire", name: "Generator Operation & Safety",       description: "Safe refueling, CO awareness, load management, storage",       priority: 2),
    SkillItem(id: "sf_chainsaw",       category: "Shelter & Fire", name: "Chainsaw Operation",                 description: "Safe use, felling, limbing — PPE and kickback awareness",      priority: 3),

    // Navigation
    SkillItem(id: "nav_map",           category: "Navigation", name: "Topographic Map Reading",               description: "Understands contour lines, scale, legend, grid coordinates",    priority: 2),
    SkillItem(id: "nav_compass",       category: "Navigation", name: "Compass Navigation",                    description: "Takes a bearing, follows it, accounts for declination",         priority: 2),
    SkillItem(id: "nav_stars",         category: "Navigation", name: "Celestial Navigation (basic)",          description: "Finds north using Polaris or Southern Cross at night",          priority: 3),
    SkillItem(id: "nav_sun",           category: "Navigation", name: "Sun Shadow Stick Navigation",           description: "Determines east-west using shadow tip method",                  priority: 3),
    SkillItem(id: "nav_roads",         category: "Navigation", name: "Local Evacuation Routes (memorized)",   description: "Knows primary + backup routes out of the area without GPS",    priority: 1),

    // Security & Community
    SkillItem(id: "sec_cert",          category: "Security & Community", name: "CERT Training (Community Emergency Response)", description: "FEMA CERT certification — team structure, triage, fire safety", priority: 2),
    SkillItem(id: "sec_neighbor",      category: "Security & Community", name: "Neighborhood Preparedness Network", description: "Connected with neighbors for mutual aid and information",  priority: 1),
    SkillItem(id: "sec_perimeter",     category: "Security & Community", name: "Home Security / Hardening",    description: "Reinforced doors, secondary lighting, perimeter awareness",     priority: 2),

    // Mental & Practical
    SkillItem(id: "mp_plan",           category: "Mental & Practical", name: "Written Family Emergency Plan",  description: "Plan exists with meeting points, contacts, out-of-state contact", priority: 1),
    SkillItem(id: "mp_72hr",           category: "Mental & Practical", name: "72-Hour Kit Ready",              description: "Bag packed and accessible with 3-day supply",                  priority: 1),
    SkillItem(id: "mp_bugout",         category: "Mental & Practical", name: "Bug-Out Bag Ready",              description: "7-day bag packed with documents, food, water, first aid",      priority: 1),
    SkillItem(id: "mp_stress",         category: "Mental & Practical", name: "Stress Inoculation / Mental Toughness", description: "Has practiced uncomfortable scenarios under simulated stress", priority: 2),
    SkillItem(id: "mp_knots",          category: "Mental & Practical", name: "Essential Knots (5+)",           description: "Bowline, clove hitch, square, sheet bend, trucker's hitch",    priority: 2),
]

// MARK: - Engine

@MainActor
class SkillsEngine: ObservableObject {
    @Published var completed: Set<String> = []
    private let key = "skills_v1"

    init() { load() }

    func toggle(_ id: String) {
        if completed.contains(id) { completed.remove(id) }
        else { completed.insert(id) }
        save()
    }

    func isCompleted(_ id: String) -> Bool { completed.contains(id) }

    private func save() {
        UserDefaults.standard.set(Array(completed), forKey: key)
    }

    private func load() {
        if let arr = UserDefaults.standard.array(forKey: key) as? [String] {
            completed = Set(arr)
        }
    }
}

// MARK: - Main View

struct SkillsLogView: View {
    @StateObject private var engine = SkillsEngine()
    @State private var selectedCategory: String? = nil
    @State private var showCriticalOnly = false

    private var categories: [String] {
        var seen = [String]()
        for skill in allSkills where !seen.contains(skill.category) { seen.append(skill.category) }
        return seen
    }

    private var displayedSkills: [SkillItem] {
        var pool = allSkills
        if showCriticalOnly { pool = pool.filter { $0.priority == 1 } }
        if let cat = selectedCategory { pool = pool.filter { $0.category == cat } }
        return pool
    }

    private var completedCount: Int { allSkills.filter { engine.isCompleted($0.id) }.count }
    private var criticalCompleted: Int { allSkills.filter { $0.priority == 1 && engine.isCompleted($0.id) }.count }
    private var criticalTotal: Int { allSkills.filter { $0.priority == 1 }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Skills Log")
                            .font(.title2.bold())
                        Text("Track skills you've practiced — preparedness takes practice")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("Critical only", isOn: $showCriticalOnly)
                        .toggleStyle(.switch)
                        .font(.caption)
                }

                // Progress
                SkillProgressBar(
                    completed: completedCount,
                    total: allSkills.count,
                    criticalCompleted: criticalCompleted,
                    criticalTotal: criticalTotal
                )

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChipSkill(label: "All", isSelected: selectedCategory == nil) { selectedCategory = nil }
                        ForEach(categories, id: \.self) { cat in
                            FilterChipSkill(
                                label: cat,
                                isSelected: selectedCategory == cat
                            ) { selectedCategory = selectedCategory == cat ? nil : cat }
                        }
                    }
                }

                // Skills grouped by category
                let grouped = Dictionary(grouping: displayedSkills, by: { $0.category })
                ForEach(categories.filter { grouped[$0] != nil }, id: \.self) { cat in
                    if let skills = grouped[cat] {
                        SkillCategorySection(category: cat, skills: skills, engine: engine)
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Progress Bar

private struct SkillProgressBar: View {
    let completed: Int; let total: Int
    let criticalCompleted: Int; let criticalTotal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 20) {
                SkillStat(label: "Overall", value: "\(completed)/\(total)", color: .purple)
                SkillStat(label: "Critical skills", value: "\(criticalCompleted)/\(criticalTotal)", color: .red)
                SkillStat(label: "Completion", value: "\(total > 0 ? Int(Double(completed)/Double(total)*100) : 0)%", color: .green)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Overall progress").font(.system(size: 10)).foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4).fill(Color.purple)
                            .frame(width: geo.size.width * (total > 0 ? CGFloat(completed)/CGFloat(total) : 0), height: 8)
                    }
                }.frame(height: 8)

                Text("Critical skills progress").font(.system(size: 10)).foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4).fill(Color.red)
                            .frame(width: geo.size.width * (criticalTotal > 0 ? CGFloat(criticalCompleted)/CGFloat(criticalTotal) : 0), height: 8)
                    }
                }.frame(height: 8)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.2), lineWidth: 1))
    }
}

private struct SkillStat: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Category Section

private struct SkillCategorySection: View {
    let category: String
    let skills: [SkillItem]
    @ObservedObject var engine: SkillsEngine

    private var doneCount: Int { skills.filter { engine.isCompleted($0.id) }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(category)
                    .font(.system(size: 13, weight: .semibold))
                Text("\(doneCount)/\(skills.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.primary.opacity(0.07), in: Capsule())
            }
            VStack(spacing: 4) {
                ForEach(skills) { skill in
                    SkillRow(skill: skill, isCompleted: engine.isCompleted(skill.id)) {
                        engine.toggle(skill.id)
                    }
                }
            }
        }
    }
}

private struct SkillRow: View {
    let skill: SkillItem
    let isCompleted: Bool
    let onToggle: () -> Void

    private var priorityColor: Color {
        switch skill.priority {
        case 1: return .red
        case 2: return .orange
        default: return .blue
        }
    }

    private var priorityLabel: String {
        switch skill.priority {
        case 1: return "CRITICAL"
        case 2: return "IMPORTANT"
        default: return "USEFUL"
        }
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isCompleted ? .green : .secondary)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(skill.name)
                            .font(.system(size: 13, weight: isCompleted ? .regular : .semibold))
                            .foregroundStyle(isCompleted ? .secondary : .primary)
                            .strikethrough(isCompleted)
                        if skill.priority == 1 {
                            Text(priorityLabel)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(priorityColor)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(priorityColor.opacity(0.12), in: Capsule())
                        }
                    }
                    Text(skill.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(10)
            .background(
                isCompleted ? Color.green.opacity(0.05) : Color(NSColor.controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isCompleted ? Color.green.opacity(0.2) : Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Chip

private struct FilterChipSkill: View {
    let label: String; let isSelected: Bool; let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(isSelected ? Color.purple : Color.primary.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
