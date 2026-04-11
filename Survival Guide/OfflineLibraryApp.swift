import SwiftUI
import PDFKit
import WebKit
import AppKit
import Combine

// ── Data Models ───────────────────────────────────────────────────────────────

struct LibraryItem: Identifiable, Hashable {
    enum ItemType: String {
        case pdf, html, txt, zim, epub, folder, other
    }
    let id = UUID()
    let section: String
    let title: String
    let type: ItemType
    let path: String
    let desc: String
    var fileURL: URL { URL(fileURLWithPath: path) }
}

struct SearchDoc: Codable, Hashable {
    let title: String
    let path: String
    let type: String
    let text: String
    let score: Int?
    let size_bytes: Int?
    let modified_epoch: Int?
}

// ── Section Theming ───────────────────────────────────────────────────────────

func sectionColor(_ section: String) -> Color {
    switch section {
    case "Quick Reference":   return .red
    case "Communications":    return .green
    case "Checklists":        return .green
    case "Supply Tracker":    return Color(red: 0.2, green: 0.5, blue: 0.9)
    case "Weather Forecast":  return .cyan
    case "Personal Plans":    return .pink
    case "Calculators":       return .teal
    case "Medication Tracker":return Color(red: 0.8, green: 0.1, blue: 0.2)
    case "Documents Vault":   return .indigo
    case "Skills Log":        return .purple
    case "Home Repair":       return Color(red: 0.55, green: 0.35, blue: 0.0)
    case "Survival Guides":   return .orange
    case "Military Manuals":  return Color(red: 0.4, green: 0.3, blue: 0.1)
    case "Survival Manuals":  return Color(red: 0.55, green: 0.35, blue: 0.0)
    case "Preparedness":      return Color(red: 0.6, green: 0.2, blue: 0.0)
    case "Medical":           return .red
    case "Reference":         return .blue
    case "Wikipedia":         return Color(red: 0.05, green: 0.60, blue: 0.55)
    case "Radio":             return .green
    case "Cooking":           return Color(red: 0.90, green: 0.45, blue: 0.0)
    case "Gardening & Water": return .teal
    case "Books":             return .purple
    case "Card Games":        return .indigo
    default:                  return .gray
    }
}

func sectionSymbol(_ section: String) -> String {
    switch section {
    case "Quick Reference":   return "exclamationmark.shield.fill"
    case "Communications":    return "antenna.radiowaves.left.and.right.fill"
    case "Checklists":        return "checklist"
    case "Supply Tracker":    return "cabinet.fill"
    case "Weather Forecast":  return "cloud.sun.fill"
    case "Personal Plans":    return "person.2.fill"
    case "Calculators":       return "function"
    case "Medication Tracker":return "pills.fill"
    case "Documents Vault":   return "lock.doc.fill"
    case "Skills Log":        return "checkmark.seal.fill"
    case "Home Repair":       return "hammer.fill"
    case "Survival Guides":   return "shield.lefthalf.filled"
    case "Military Manuals":  return "star.circle.fill"
    case "Survival Manuals":  return "map.fill"
    case "Preparedness":      return "checklist"
    case "Medical":           return "cross.case.fill"
    case "Reference":         return "books.vertical.fill"
    case "Wikipedia":         return "globe"
    case "Radio":             return "antenna.radiowaves.left.and.right"
    case "Cooking":           return "flame.fill"
    case "Gardening & Water": return "drop.fill"
    case "Books":             return "book.fill"
    case "Card Games":        return "suit.spade.fill"
    default:                  return "folder.fill"
    }
}

func itemSymbol(_ type: LibraryItem.ItemType) -> String {
    switch type {
    case .pdf:    return "doc.richtext.fill"
    case .html:   return "doc.text.fill"
    case .txt:    return "doc.plaintext.fill"
    case .zim:    return "books.vertical.fill"
    case .epub:   return "book.fill"
    case .folder: return "folder.fill"
    case .other:  return "doc.fill"
    }
}

func typeLabel(_ type: LibraryItem.ItemType) -> String {
    switch type {
    case .pdf:    return "PDF"
    case .html:   return "HTML"
    case .txt:    return "TXT"
    case .zim:    return "ZIM"
    case .epub:   return "EPUB"
    case .folder: return "DIR"
    case .other:  return "FILE"
    }
}

func typeColor(_ type: LibraryItem.ItemType) -> Color {
    switch type {
    case .pdf:    return .red
    case .html:   return .blue
    case .zim:    return .purple
    case .epub:   return .orange
    case .folder: return .yellow
    default:      return .gray
    }
}

// ── Reusable Components ───────────────────────────────────────────────────────

struct TypeBadge: View {
    let type: LibraryItem.ItemType
    var body: some View {
        Text(typeLabel(type))
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(typeColor(type))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(typeColor(type).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }
}

// Sidebar: one row per topic
struct TopicSidebarRow: View {
    let name: String
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(name == "All"
                          ? Color.blue.opacity(0.13)
                          : sectionColor(name).opacity(0.13))
                    .frame(width: 28, height: 28)
                Image(systemName: name == "All" ? "square.grid.2x2.fill" : sectionSymbol(name))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(name == "All" ? Color.blue : sectionColor(name))
            }
            Text(name == "All" ? "All Documents" : name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Spacer()
            Text("\(count)")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

// Main panel: one row per document
struct DocumentListRow: View {
    let item: LibraryItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(sectionColor(item.section).opacity(isSelected ? 0.22 : 0.11))
                    .frame(width: 36, height: 36)
                Image(systemName: itemSymbol(item.type))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(sectionColor(item.section))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(item.desc)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            TypeBadge(type: item.type)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

struct SearchResultRow: View {
    let doc: SearchDoc
    let query: String

    private func inferType() -> LibraryItem.ItemType {
        let p = doc.path.lowercased()
        if p.hasSuffix(".pdf")              { return .pdf }
        if p.hasSuffix(".html") || p.hasSuffix(".htm") { return .html }
        if p.hasSuffix(".txt") || p.hasSuffix(".md")   { return .txt }
        if p.hasSuffix(".zim")              { return .zim }
        if p.hasSuffix(".epub")             { return .epub }
        return .other
    }

    var snippet: String {
        let lower = doc.text.lowercased()
        let q = query.lowercased()
        guard let range = lower.range(of: q) else { return String(doc.text.prefix(180)) }
        let idx   = lower.distance(from: lower.startIndex, to: range.lowerBound)
        let start = max(0, idx - 70)
        let end   = min(doc.text.count, idx + q.count + 120)
        var result = String(doc.text[doc.text.index(doc.text.startIndex, offsetBy: start) ..<
                                     doc.text.index(doc.text.startIndex, offsetBy: end)])
                        .replacingOccurrences(of: "\n", with: " ")
        if start > 0 { result = "…" + result }
        if end < doc.text.count { result += "…" }
        return result
    }

    var body: some View {
        let t = inferType()
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(typeColor(t).opacity(0.13))
                    .frame(width: 30, height: 30)
                Image(systemName: itemSymbol(t))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(typeColor(t))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(doc.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(snippet)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            TypeBadge(type: t)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 3)
    }
}

// ── Content View ──────────────────────────────────────────────────────────────

struct ContentView: View {
    @State private var selectedSection = "All"
    @State private var query = ""
    @State private var selectedItem: LibraryItem?
    @State private var searchIndex: [SearchDoc] = []
    @State private var searchResults: [SearchDoc] = []
    @State private var expandedTerms: [String] = []
    @State private var isExpandingQuery = false
    @State private var expansionTask: Task<Void, Never>? = nil
    @State private var status = "Ready"
    @State private var copied = false
    @State private var showingPreview = false
    @State private var showingAssistant = false

    private let base = "/Volumes/20TB_HDD"

    private var items: [LibraryItem] {
        [
            LibraryItem(section: "Wikipedia", title: "Wikipedia (Full Offline)", type: .zim, path: "\(base)/offline-wikipedia/wikipedia_en_all_nopic_2026-03.zim", desc: "Full offline English Wikipedia in Kiwix."),
            LibraryItem(section: "Reference", title: "iFixit", type: .zim, path: "\(base)/offline-library/ifixit/ifixit_en_all_2025-12.zim", desc: "Offline repair guides in Kiwix."),
            LibraryItem(section: "Reference", title: "Wikibooks", type: .zim, path: "\(base)/offline-library/wikibooks/wikibooks_en_all_nopic_2026-01.zim", desc: "Offline how-to/reference books in Kiwix."),
            LibraryItem(section: "Reference", title: "Nuclear War Survival Skills", type: .pdf, path: "\(base)/offline-library/nuclear-guides/nuclear-war-survival-skills.pdf", desc: "Long-form nuclear survival reference."),
            LibraryItem(section: "Reference", title: "FEMA Hazard Info Sheets", type: .pdf, path: "\(base)/offline-library/nuclear-guides/fema_full-suite-hazard-info-sheets.pdf", desc: "Federal hazard guidance."),
            LibraryItem(section: "Cooking", title: "USDA Home Canning Guide", type: .pdf, path: "\(base)/offline-library/cooking/usda-preservation/GUIDE01_HomeCan_rev0715.pdf", desc: "Core home canning guide."),
            LibraryItem(section: "Cooking", title: "Home Canning Intro", type: .pdf, path: "\(base)/offline-library/cooking/usda-preservation/INTRO_HomeCanrev0715.pdf", desc: "Intro and principles for home canning."),
            LibraryItem(section: "Gardening & Water", title: "Rain Harvesting Guide", type: .pdf, path: "\(base)/offline-library/gardening-water/rainharvesting.pdf", desc: "Rainwater harvesting reference."),
            LibraryItem(section: "Gardening & Water", title: "Rainwater Handbook", type: .pdf, path: "\(base)/offline-library/gardening-water/rainwater_harvesting_handbook.pdf", desc: "Handbook for collection systems."),
            LibraryItem(section: "Gardening & Water", title: "NCHFP Home Page", type: .html, path: "\(base)/offline-library/gardening-water/nchfp_home.html", desc: "Food preservation landing page."),
            LibraryItem(section: "Radio", title: "ARES Field Resource Manual", type: .pdf, path: "\(base)/offline-library/radio/ARES_FR_Manual.pdf", desc: "Emergency comms manual."),
            LibraryItem(section: "Radio", title: "ARES Manual", type: .pdf, path: "\(base)/offline-library/radio/ARES_Manual.pdf", desc: "ARES operations reference."),
            LibraryItem(section: "Medical", title: "Human First Aid + CPR (No EMS)", type: .html, path: "\(base)/offline-library/medical-human/human_first_aid_no_ems.html", desc: "Offline human first aid, CPR, and symptom lookup."),
            LibraryItem(section: "Medical", title: "AVMA Pet First Aid", type: .html, path: "\(base)/offline-library/medical-pets/avma_pet_first_aid.html", desc: "Pet first aid basics."),
            LibraryItem(section: "Medical", title: "Merck Pet Emergency Guide", type: .html, path: "\(base)/offline-library/medical-pets/merck-html/what_to_do_in_dog_or_cat_emergency_merck.html", desc: "What to do in a dog/cat emergency."),
            LibraryItem(section: "Books", title: "The White House Cook Book", type: .epub, path: "\(base)/offline-library/books/The_White_House_Cook_Book.epub", desc: "Public-domain cookbook."),
            LibraryItem(section: "Books", title: "The Boston Cooking-School Cook Book", type: .epub, path: "\(base)/offline-library/books/The_Boston_Cooking_School_Cook_Book.epub", desc: "Classic cookbook."),
            LibraryItem(section: "Books", title: "Hoyle's Games Modernized", type: .epub, path: "\(base)/offline-library/books/Hoyles_Games_Modernized.epub", desc: "Card/parlor games."),
            LibraryItem(section: "Card Games", title: "Cribbage Rules", type: .html, path: "\(base)/offline-library/card-games/rules-html/cribbage_bicycle.html", desc: "Bicycle cribbage rules."),
            LibraryItem(section: "Card Games", title: "Canasta Rules", type: .html, path: "\(base)/offline-library/card-games/rules-html/canasta_bicycle.html", desc: "Bicycle canasta rules."),
            LibraryItem(section: "Card Games", title: "Hearts Rules", type: .html, path: "\(base)/offline-library/card-games/rules-html/hearts_pagat.html", desc: "Pagat hearts rules."),
            LibraryItem(section: "Survival Guides", title: "Oahu Nuclear Strike", type: .html, path: "\(base)/offline-library/survival-guides/oahu_nuclear_strike.html", desc: "Blast zones, fallout, shelter, and recovery specific to Oahu."),
            LibraryItem(section: "Survival Guides", title: "Oahu Tsunami & Hurricane", type: .html, path: "\(base)/offline-library/survival-guides/oahu_tsunami_hurricane.html", desc: "Evacuation zones, shelters, and action plans for Oahu wave and wind events."),
            LibraryItem(section: "Survival Guides", title: "Grid-Down / EMP — Oahu", type: .html, path: "\(base)/offline-library/survival-guides/oahu_grid_down_emp.html", desc: "Extended power outage and EMP survival on an island grid."),
            LibraryItem(section: "Survival Guides", title: "Hawaii Supply Chain Collapse", type: .html, path: "\(base)/offline-library/survival-guides/hawaii_supply_chain.html", desc: "Resupply failure, food/water/fuel rationing, and long-term island self-sufficiency."),
            LibraryItem(section: "Survival Guides", title: "Pandemic & Biological Event", type: .html, path: "\(base)/offline-library/survival-guides/pandemic_biological.html", desc: "Island quarantine, medical triage, and household disease management."),
            LibraryItem(section: "Survival Guides", title: "Oahu Ground Truth (Reference Facts)", type: .html, path: "\(base)/offline-library/survival-guides/oahu_ground_truth.html", desc: "Key Oahu facts: targets, infrastructure, frequencies, food, water, contacts."),
            // ── TruePrepper Military Manuals ──────────────────────────────────────
            LibraryItem(section: "Military Manuals", title: "FM 21-76 Army Survival Manual", type: .pdf, path: "\(base)/offline-library/trueprepper/military-manuals/FM-21-76-US-Army-Survival-Manual.pdf", desc: "The definitive US Army field survival manual."),
            LibraryItem(section: "Military Manuals", title: "FM 21-76-1 Survival, Evasion & Recovery", type: .pdf, path: "\(base)/offline-library/trueprepper/military-manuals/FM-21-76-1-Survival-Evasion-and-Recovery-Multiservice-Procedures.pdf", desc: "Multiservice SERE procedures."),
            LibraryItem(section: "Military Manuals", title: "FM 31-70 Basic Cold Weather Manual", type: .pdf, path: "\(base)/offline-library/trueprepper/military-manuals/FM-31-70-Basic-Cold-Weather-Manual.pdf", desc: "Cold weather survival and operations."),
            LibraryItem(section: "Military Manuals", title: "USMC Summer Survival Course Handbook", type: .pdf, path: "\(base)/offline-library/trueprepper/military-manuals/USMC-Summer-Survival-Course-Handbook.pdf", desc: "Marine Corps warm-weather survival."),
            LibraryItem(section: "Military Manuals", title: "USMC Winter Survival Course Handbook", type: .pdf, path: "\(base)/offline-library/trueprepper/military-manuals/USMC-Winter-Survival-Course-Handbook.pdf", desc: "Marine Corps cold-weather survival."),
            LibraryItem(section: "Military Manuals", title: "FM 3-3-1 Nuclear Contamination Avoidance", type: .pdf, path: "\(base)/offline-library/trueprepper/military-manuals/FM-3-3-1-Nuclear-Contamination-Avoidance.pdf", desc: "NBC contamination avoidance procedures."),
            LibraryItem(section: "Military Manuals", title: "FM 3-4 NBC Protection", type: .pdf, path: "\(base)/offline-library/trueprepper/military-manuals/FM-3-4-NBC-Protection.pdf", desc: "Nuclear, biological, chemical protection."),
            LibraryItem(section: "Military Manuals", title: "FM 3-5 NBC Decontamination", type: .pdf, path: "\(base)/offline-library/trueprepper/military-manuals/FM-3-5-NBC-Decontamination.pdf", desc: "NBC decontamination procedures."),
            LibraryItem(section: "Military Manuals", title: "FM 3-25.26 Map Reading & Land Navigation", type: .pdf, path: "\(base)/offline-library/trueprepper/military-manuals/FM-3-25-26-Map-Reading-and-Land-Navigation.pdf", desc: "Land navigation without electronics."),
            LibraryItem(section: "Military Manuals", title: "FM 4-25.11 First Aid", type: .pdf, path: "\(base)/offline-library/trueprepper/military-manuals/FM-4-25-11-First_Aid.pdf", desc: "US Army field first aid manual."),
            LibraryItem(section: "Military Manuals", title: "FM 21-10 Field Hygiene & Sanitation", type: .pdf, path: "\(base)/offline-library/trueprepper/military-manuals/FM-21-10-Field-Hygiene-and-Sanitation.pdf", desc: "Sanitation and hygiene in field conditions."),
            LibraryItem(section: "Military Manuals", title: "ST 31-91B Special Forces Medical Handbook", type: .pdf, path: "\(base)/offline-library/trueprepper/military-manuals/ST-31-91B-US-Army-Special-Forces-Medical-Handbook.pdf", desc: "Advanced field medicine reference."),
            LibraryItem(section: "Military Manuals", title: "TCCC Army Tactical Combat Casualty Care", type: .pdf, path: "\(base)/offline-library/trueprepper/military-manuals/TCCC-17-13-Army-Tactical-Combat-Casualty-Care.pdf", desc: "Battlefield trauma care."),
            LibraryItem(section: "Military Manuals", title: "NAVMED P-5010 Navy Preventive Medicine", type: .pdf, path: "\(base)/offline-library/trueprepper/military-manuals/NAVMED-P-5010-US-Navy-Manual-of-Preventive-Medicine.pdf", desc: "Navy preventive medicine manual."),
            LibraryItem(section: "Military Manuals", title: "FM 5-103 Survivability", type: .pdf, path: "\(base)/offline-library/trueprepper/military-manuals/FM-5-103-Survivability.pdf", desc: "Field fortification and survivability."),
            LibraryItem(section: "Military Manuals", title: "FM 20-3 Camouflage, Concealment & Decoys", type: .pdf, path: "\(base)/offline-library/trueprepper/military-manuals/FM-20-3-Camouflage-Concealment-and-Decoys.pdf", desc: "Camouflage techniques."),
            // ── TruePrepper Survival Manuals ──────────────────────────────────────
            LibraryItem(section: "Survival Manuals", title: "Canadian Military Fieldcraft", type: .pdf, path: "\(base)/offline-library/trueprepper/survival-manuals/Canadian-Military-Fieldcraft.pdf", desc: "Canadian Forces fieldcraft fundamentals."),
            LibraryItem(section: "Survival Manuals", title: "Down But Not Out (Canadian Survival)", type: .pdf, path: "\(base)/offline-library/trueprepper/survival-manuals/Down-But-Not-Out-Canadian-Survival-Manual.pdf", desc: "Canadian Forces survival manual."),
            LibraryItem(section: "Survival Manuals", title: "Introduction to Survival (CIA)", type: .pdf, path: "\(base)/offline-library/trueprepper/survival-manuals/CIA-RDP78-Introdution-to-Survival.pdf", desc: "Declassified CIA survival introduction."),
            LibraryItem(section: "Survival Manuals", title: "Boy Scout Handbook 1911", type: .pdf, path: "\(base)/offline-library/trueprepper/survival-manuals/Boy-Scout-Handbook-1911.pdf", desc: "Classic public-domain fieldcraft guide."),
            LibraryItem(section: "Survival Manuals", title: "Deadfalls and Snares", type: .pdf, path: "\(base)/offline-library/trueprepper/survival-manuals/Deadfalls-and-Snares.pdf", desc: "1907 trapping reference."),
            LibraryItem(section: "Survival Manuals", title: "Shelters, Shacks, and Shanties", type: .pdf, path: "\(base)/offline-library/trueprepper/survival-manuals/Shelters-Shacks-and-Shanties.pdf", desc: "1916 shelter construction reference."),
            LibraryItem(section: "Survival Manuals", title: "Paleo-Pocalypse", type: .pdf, path: "\(base)/offline-library/trueprepper/survival-manuals/Paleo-Pocalypse.pdf", desc: "Primitive skills and wilderness survival."),
            // ── TruePrepper Preparedness ──────────────────────────────────────────
            LibraryItem(section: "Preparedness", title: "FEMA Citizen Preparedness Guide", type: .pdf, path: "\(base)/offline-library/trueprepper/preparedness/FEMA-Citizen-Preparedness-Guide.pdf", desc: "FEMA household preparedness guide."),
            LibraryItem(section: "Preparedness", title: "DoD Emergency Preparedness Guide", type: .pdf, path: "\(base)/offline-library/trueprepper/preparedness/DoD-Emergency-Preparedness-Guide.pdf", desc: "Department of Defense family preparedness."),
            LibraryItem(section: "Preparedness", title: "LDS Preparedness Manual", type: .pdf, path: "\(base)/offline-library/trueprepper/preparedness/LDS-Preparedness-Manual.pdf", desc: "Comprehensive household preparedness manual."),
            LibraryItem(section: "Preparedness", title: "Sweden — In Case of Crisis or War", type: .pdf, path: "\(base)/offline-library/trueprepper/preparedness/Sweden-In-Case-of-Crisis-or-War.pdf", desc: "Swedish national civil preparedness guide."),
            LibraryItem(section: "Preparedness", title: "Norway — One Week Preparedness Guide", type: .pdf, path: "\(base)/offline-library/trueprepper/preparedness/Norway-One-Week-Preparedness-Guide.pdf", desc: "Norwegian national emergency guide."),
            LibraryItem(section: "Preparedness", title: "Estonia — Be Prepared Crisis Guide", type: .pdf, path: "\(base)/offline-library/trueprepper/preparedness/Be-Prepared-Estonia-Crisis-Guide-Paasteamet-ERB.pdf", desc: "Estonian national crisis preparedness."),
            LibraryItem(section: "Preparedness", title: "US National Risk Index 2025", type: .pdf, path: "\(base)/offline-library/trueprepper/preparedness/US-National-Risk-Index-2025.pdf", desc: "FEMA hazard risk index by county."),
            LibraryItem(section: "Preparedness", title: "UK National Risk Register 2025", type: .pdf, path: "\(base)/offline-library/trueprepper/preparedness/UK-National-Risk-Register-2025.pdf", desc: "UK government national risk assessment."),
            LibraryItem(section: "Preparedness", title: "EMP Collateral Damage to Satellites (DTRA)", type: .pdf, path: "\(base)/offline-library/trueprepper/preparedness/DTRA-Collateral-Damage-to-Satellites-from-an-EMP-Attack.pdf", desc: "Defense Threat Reduction Agency EMP analysis."),
            LibraryItem(section: "Preparedness", title: "Nuclear Winter — Anthropology of Human Survival", type: .pdf, path: "\(base)/offline-library/trueprepper/preparedness/Nuclear-Winter-The-Anthropology-of-Human-Survival.pdf", desc: "Long-term nuclear winter survival analysis."),
            // ── TruePrepper First Aid ─────────────────────────────────────────────
            LibraryItem(section: "Medical", title: "Where There Is No Doctor", type: .pdf, path: "\(base)/offline-library/trueprepper/first-aid/Where-There-is-no-Doctor-a-Village-Health-Care-Handbook.pdf", desc: "Village health care handbook for austere environments."),
            LibraryItem(section: "Medical", title: "Where There Is No Dentist", type: .pdf, path: "\(base)/offline-library/trueprepper/first-aid/Where-There-is-No-Dentist.pdf", desc: "Dental care without professional access."),
            // ── TruePrepper Nuclear/Radiation ─────────────────────────────────────
            LibraryItem(section: "Reference", title: "Planning Guidance: Nuclear Detonation (FEMA 2022)", type: .pdf, path: "\(base)/offline-library/trueprepper/nuclear-radiation/Planning-Guidance-for-Response-to-Nuclear-Detonation-May-2022-FEMA.pdf", desc: "FEMA 2022 nuclear detonation response guidance."),
            LibraryItem(section: "Reference", title: "Personal & Family Survival (Civil Defense)", type: .pdf, path: "\(base)/offline-library/trueprepper/nuclear-radiation/Personal-and-Family-Survival-SM-3-11.pdf", desc: "Civil defense personal survival manual."),
            LibraryItem(section: "Reference", title: "Family Shelter Designs (DoD Civil Defense)", type: .pdf, path: "\(base)/offline-library/trueprepper/nuclear-radiation/Family-Shelter-Designs-DOD-Civil-Defense.pdf", desc: "Fallout shelter construction designs."),
            LibraryItem(section: "Reference", title: "Build a Protective Fallout Shelter", type: .pdf, path: "\(base)/offline-library/trueprepper/nuclear-radiation/Build-a-Protective-Fallout-Shelter.pdf", desc: "DIY fallout shelter construction guide."),
            // ── TruePrepper Checklists ────────────────────────────────────────────
            LibraryItem(section: "Checklists", title: "Basic Emergency Plan", type: .pdf, path: "\(base)/offline-library/trueprepper/checklists/Basic-Emergency-Plan.pdf", desc: "Household emergency plan template."),
            LibraryItem(section: "Checklists", title: "Home Survival Kit Checklist", type: .pdf, path: "\(base)/offline-library/trueprepper/checklists/Home-Survival-Kit-Checklist-v3-2-Page.pdf", desc: "Complete home survival kit list."),
            LibraryItem(section: "Checklists", title: "Survival Food Checklist", type: .pdf, path: "\(base)/offline-library/trueprepper/checklists/Survival-Food-Checklist-v3.pdf", desc: "Food storage and provisioning checklist."),
            LibraryItem(section: "Checklists", title: "Bug Out Bag Checklist", type: .pdf, path: "\(base)/offline-library/trueprepper/checklists/Bug-Out-Bag-Checklist-v3-2-Page.pdf", desc: "72-hour bug-out bag packing list."),
            LibraryItem(section: "Checklists", title: "Get Home Bag Checklist", type: .pdf, path: "\(base)/offline-library/trueprepper/checklists/Get-Home-Bag-Checklist-v3-2-Page.pdf", desc: "Get-home bag for commuters."),
            LibraryItem(section: "Checklists", title: "Everyday Carry Checklist", type: .pdf, path: "\(base)/offline-library/trueprepper/checklists/Everyday-Carry-Checklist-v3-2-Page.pdf", desc: "EDC gear checklist."),
            LibraryItem(section: "Checklists", title: "Nuclear Survival Kit Checklist", type: .pdf, path: "\(base)/offline-library/trueprepper/checklists/Nuclear-Survival-Kit-Checklist-v3.pdf", desc: "Nuclear event survival kit list."),
            LibraryItem(section: "Checklists", title: "Hurricane Survival Kit Checklist", type: .pdf, path: "\(base)/offline-library/trueprepper/checklists/Hurricane-Survival-Kit-Checklist.pdf", desc: "Hurricane preparedness kit."),
            LibraryItem(section: "Checklists", title: "Flood Survival Kit Checklist", type: .pdf, path: "\(base)/offline-library/trueprepper/checklists/Flood-Survival-Kit-Checklist-v3.pdf", desc: "Flood emergency kit."),
            LibraryItem(section: "Checklists", title: "Dog Bug Out Bag Checklist", type: .pdf, path: "\(base)/offline-library/trueprepper/checklists/Dog-Bug-Out-Bag-Checklist-v3.pdf", desc: "Bug-out bag for dogs."),
            LibraryItem(section: "Checklists", title: "Car Emergency Kit Checklist", type: .pdf, path: "\(base)/offline-library/trueprepper/checklists/Car-Emergency-Kit-Checklist-v3.pdf", desc: "Vehicle emergency kit."),
            LibraryItem(section: "Checklists", title: "Survival First Aid Kit Checklist", type: .pdf, path: "\(base)/offline-library/trueprepper/checklists/Survival-First-Aid-Kit-Checklist-v3.pdf", desc: "Survival-grade first aid kit list."),
            // ── TruePrepper Reference ─────────────────────────────────────────────
            LibraryItem(section: "Reference", title: "Military Phonetic Alphabet", type: .pdf, path: "\(base)/offline-library/trueprepper/reference/Printable-PDF-of-the-Military-Phonetic-Alphabet.pdf", desc: "NATO phonetic alphabet reference card."),
            LibraryItem(section: "Reference", title: "Universal Edibility Test", type: .pdf, path: "\(base)/offline-library/trueprepper/reference/Printable-PDF-of-the-Universal-Edibility-Test-for-Survival.pdf", desc: "Field test for unknown plant edibility."),
            // ── Home Repair ───────────────────────────────────────────────────────────
            LibraryItem(section: "Home Repair", title: "FEMA P-499 Coastal Construction Guide", type: .pdf, path: "\(base)/offline-library/home-repair/fema-p499-coastal-construction.pdf", desc: "Technical guidance for building in coastal environments."),
            LibraryItem(section: "Home Repair", title: "FEMA P-804 Wind Retrofit Guide", type: .pdf, path: "\(base)/offline-library/home-repair/fema-p804-wind-retrofit.pdf", desc: "Retrofitting residential buildings for high-wind resilience."),
            LibraryItem(section: "Home Repair", title: "FEMA P-2055 Post-Disaster Safety Evaluation", type: .pdf, path: "\(base)/offline-library/home-repair/fema-p2055-post-disaster-safety.pdf", desc: "Evaluating structural safety after earthquakes, hurricanes, and floods."),
            LibraryItem(section: "Home Repair", title: "FEMA Earthquake Safety — Home Retrofit Guide", type: .pdf, path: "\(base)/offline-library/home-repair/fema-earthquake-retrofit-homes.pdf", desc: "Cripple wall, water heater, and anchor bolt retrofits for earthquake resistance."),
            LibraryItem(section: "Home Repair", title: "FEMA Flood Damage Repairs & Mitigation", type: .pdf, path: "\(base)/offline-library/home-repair/fema-flood-damage-repairs.pdf", desc: "Repairing and hardening homes after flood damage."),
            LibraryItem(section: "Home Repair", title: "USDA Rural Home Repair & Rehabilitation", type: .pdf, path: "\(base)/offline-library/home-repair/usda-rural-repair-rehabilitation.pdf", desc: "Home repair guidance for rural housing — plumbing, structure, weatherization."),
            LibraryItem(section: "Home Repair", title: "HUD Healthy Homes Maintenance Guide", type: .pdf, path: "\(base)/offline-library/home-repair/hud-healthy-homes-maintenance.pdf", desc: "Housing maintenance covering plumbing, electrical, HVAC, pest, and mold."),
            LibraryItem(section: "Home Repair", title: "DOE Weatherization Field Guide", type: .pdf, path: "\(base)/offline-library/home-repair/doe-weatherization-field-guide.pdf", desc: "Insulation, air sealing, and energy-efficient heating/cooling."),
            LibraryItem(section: "Home Repair", title: "Basic Plumbing Reference Guide", type: .pdf, path: "\(base)/offline-library/home-repair/basic-plumbing-reference.pdf", desc: "Shutoff locations, pipe repair, leak fixes, and drain clearing."),
            LibraryItem(section: "Home Repair", title: "Electrical Safety for Homeowners", type: .pdf, path: "\(base)/offline-library/home-repair/electrical-safety-homeowners.pdf", desc: "Breaker panels, GFCI, safe wiring, and post-disaster electrical hazards."),
            // ── Folders ───────────────────────────────────────────────────────────────
            LibraryItem(section: "Folders", title: "Offline Library Root", type: .folder, path: "\(base)/offline-library", desc: "Main library folder."),
            LibraryItem(section: "Folders", title: "Movies", type: .folder, path: "\(base)/offline-library/movies", desc: "Movie files and pages."),
            LibraryItem(section: "Folders", title: "Audiobooks", type: .folder, path: "\(base)/offline-library/audiobooks", desc: "Audiobook files and pages.")
        ]
    }

    private let sectionOrder = ["All", "Survival Guides", "Home Repair", "Military Manuals", "Survival Manuals",
                                "Preparedness", "Medical", "Reference", "Wikipedia", "Radio",
                                "Cooking", "Gardening & Water", "Books", "Checklists", "Card Games", "Folders"]

    private var allSections: [String] {
        let existing = Set(items.map { $0.section })
        return sectionOrder.filter { $0 == "All" || existing.contains($0) }
    }

    private var sectionCounts: [String: Int] {
        var counts = ["All": items.count]
        for item in items { counts[item.section, default: 0] += 1 }
        return counts
    }

    // Documents shown in the top list panel
    private var listedItems: [LibraryItem] {
        let pool = selectedSection == "All" ? items : items.filter { $0.section == selectedSection }
        guard !query.isEmpty else { return pool.sorted { $0.title < $1.title } }

        // Combine original query terms + any expanded terms for title/desc matching
        let baseTerms = queryTerms(query.lowercased())
        let allTerms  = baseTerms + expandedTerms

        return pool.compactMap { item -> (LibraryItem, Int)? in
            let haystack = (item.title + " " + item.desc + " " + item.section).lowercased()
            let score = allTerms.reduce(0) { $0 + (haystack.contains($1) ? 1 : 0) }
            return score > 0 ? (item, score) : nil
        }
        .sorted { $0.1 > $1.1 }
        .map { $0.0 }
    }

    var body: some View {
        NavigationSplitView {
            // ── Left sidebar: topics only ──────────────────────────────────────
            List(selection: $selectedSection) {
                Section("Tools") {
                    TopicSidebarRow(name: "Quick Reference", count: 0)
                        .tag("Quick Reference")
                    TopicSidebarRow(name: "Communications", count: 0)
                        .tag("Communications")
                    TopicSidebarRow(name: "Checklists", count: 0)
                        .tag("Checklists")
                    TopicSidebarRow(name: "Supply Tracker", count: 0)
                        .tag("Supply Tracker")
                    TopicSidebarRow(name: "Weather Forecast", count: 0)
                        .tag("Weather Forecast")
                    TopicSidebarRow(name: "Personal Plans", count: 0)
                        .tag("Personal Plans")
                    TopicSidebarRow(name: "Calculators", count: 0)
                        .tag("Calculators")
                    TopicSidebarRow(name: "Medication Tracker", count: 0)
                        .tag("Medication Tracker")
                    TopicSidebarRow(name: "Documents Vault", count: 0)
                        .tag("Documents Vault")
                    TopicSidebarRow(name: "Skills Log", count: 0)
                        .tag("Skills Log")
                }
                Section("Library") {
                    ForEach(allSections, id: \.self) { section in
                        TopicSidebarRow(name: section, count: sectionCounts[section] ?? 0)
                            .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Survival Guide")
            .onChange(of: selectedSection) { _, _ in
                selectedItem = nil
                showingPreview = false
                query = ""
                searchResults = []
                expandedTerms = []
                expansionTask?.cancel()
            }
        } detail: {
            Group {
                if selectedSection == "Quick Reference" {
                    QuickReferenceView()
                } else if selectedSection == "Communications" {
                    CommunicationsView()
                } else if selectedSection == "Checklists" {
                    ChecklistView()
                } else if selectedSection == "Supply Tracker" {
                    SupplyTrackerView()
                } else if selectedSection == "Weather Forecast" {
                    WeatherView()
                } else if selectedSection == "Personal Plans" {
                    EmergencyPlanView()
                } else if selectedSection == "Calculators" {
                    CalculatorsView()
                } else if selectedSection == "Medication Tracker" {
                    MedicationTrackerView()
                } else if selectedSection == "Documents Vault" {
                    DocumentsVaultView()
                } else if selectedSection == "Skills Log" {
                    SkillsLogView()
                } else if showingPreview, let item = selectedItem {
                    DetailView(item: item, status: $status, copied: $copied) {
                        withAnimation(.easeInOut(duration: 0.18)) { showingPreview = false }
                    }
                } else {
                    VStack(spacing: 0) {
                        // ── Search bar ─────────────────────────────────────────
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField(
                                selectedSection == "All"
                                    ? "Search all \(items.count) documents…"
                                    : "Search \(selectedSection) (\(sectionCounts[selectedSection] ?? 0) docs)…",
                                text: $query
                            )
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .onChange(of: query) { _, _ in updateSearchResults() }
                            if !query.isEmpty {
                                Button { query = ""; searchResults = [] } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(NSColor.controlBackgroundColor))

                        // ── Expanded terms chips ───────────────────────────────
                        if !expandedTerms.isEmpty && !query.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    if isExpandingQuery {
                                        ProgressView().scaleEffect(0.6)
                                    } else {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.purple)
                                    }
                                    ForEach(expandedTerms, id: \.self) { term in
                                        Text(term)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.purple)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(Color.purple.opacity(0.10), in: Capsule())
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                            }
                            .background(Color.purple.opacity(0.04))
                        }
                        Divider()

                        // ── Main content area ──────────────────────────────────
                        if !query.isEmpty {
                            if listedItems.isEmpty && searchResults.isEmpty {
                                ContentUnavailableView.search(text: query)
                            } else {
                                List {
                                    if !searchResults.isEmpty {
                                        Section {
                                            ForEach(searchResults.prefix(20), id: \.self) { doc in
                                                Button {
                                                    if let item = libraryItem(from: doc) {
                                                        selectedItem = item
                                                        withAnimation(.easeInOut(duration: 0.18)) { showingPreview = true }
                                                    }
                                                } label: {
                                                    SearchResultRow(doc: doc, query: query)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        } header: {
                                            Label("Full-text matches", systemImage: "text.magnifyingglass")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    if !listedItems.isEmpty {
                                        Section {
                                            ForEach(listedItems) { item in
                                                Button {
                                                    selectedItem = item
                                                    withAnimation(.easeInOut(duration: 0.18)) { showingPreview = true }
                                                } label: {
                                                    DocumentListRow(item: item, isSelected: selectedItem?.id == item.id)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        } header: {
                                            if !searchResults.isEmpty {
                                                Label("Title matches", systemImage: "doc.text.magnifyingglass")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                .listStyle(.plain)
                            }
                        } else if selectedSection == "All" {
                            SectionHomeGrid(
                                sections: allSections.filter { $0 != "All" },
                                sectionCounts: sectionCounts,
                                onSelect: { sec in
                                    withAnimation(.easeInOut(duration: 0.15)) { selectedSection = sec }
                                }
                            )
                        } else {
                            DocumentBrowseView(items: listedItems) { item in
                                selectedItem = item
                                withAnimation(.easeInOut(duration: 0.18)) { showingPreview = true }
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAssistant = true } label: {
                        Label("Assistant", systemImage: "bubble.left.and.bubble.right")
                    }
                }
            }
            .sheet(isPresented: $showingAssistant) {
                AgentChatView()
                    .frame(minWidth: 520, minHeight: 640)
            }
        }
        .onAppear { loadIndex() }
    }

    private func libraryItem(from doc: SearchDoc) -> LibraryItem? {
        // Only allow paths that resolve to within the known library root.
        // This prevents a tampered search index from opening arbitrary files.
        let resolvedPath = URL(fileURLWithPath: doc.path).standardized.path
        guard resolvedPath.hasPrefix("/Volumes/20TB_HDD/") else { return nil }
        return LibraryItem(section: "Search", title: doc.title, type: inferType(from: doc.path),
                           path: resolvedPath, desc: "Full-text search result.")
    }

    private func inferType(from path: String) -> LibraryItem.ItemType {
        let p = path.lowercased()
        if p.hasSuffix(".pdf")              { return .pdf }
        if p.hasSuffix(".html") || p.hasSuffix(".htm") { return .html }
        if p.hasSuffix(".txt") || p.hasSuffix(".md")   { return .txt }
        if p.hasSuffix(".zim")              { return .zim }
        if p.hasSuffix(".epub")             { return .epub }
        return .other
    }

    private func loadIndex() {
        let candidates = [
            URL(fileURLWithPath: "/Volumes/20TB_HDD/offline_search_index.json"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop/offline_search_index.json")
        ]
        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let data = try? Data(contentsOf: url) else {
            status = "No search index found"
            return
        }
        do {
            let docs = try JSONDecoder().decode([SearchDoc].self, from: data)
            searchIndex = docs
            status = "\(docs.count) documents indexed"
        } catch {
            status = "Index load failed"
        }
    }

    private func updateSearchResults() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else {
            searchResults = []
            expandedTerms = []
            isExpandingQuery = false
            expansionTask?.cancel()
            return
        }

        // Instant multi-word keyword results
        searchResults = keywordSearch(terms: queryTerms(q))

        // Cancel any in-flight expansion and start a new one after a short debounce
        expansionTask?.cancel()
        expandedTerms = []
        isExpandingQuery = true
        expansionTask = Task {
            // Debounce: wait 400 ms before hitting Ollama
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await expandAndSearch(originalQuery: q)
        }
    }

    /// Split a query into individual non-trivial words
    private func queryTerms(_ q: String) -> [String] {
        let stopWords: Set<String> = ["a","an","the","and","or","of","in","to","for","is","are","with","how","do","i","my","what"]
        return q.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty && !stopWords.contains($0) }
    }

    /// Score and rank documents against a set of terms
    private func keywordSearch(terms: [String]) -> [SearchDoc] {
        let q = terms.joined(separator: " ")
        return searchIndex.compactMap { doc -> (SearchDoc, Int)? in
            var score = 0
            for term in terms {
                score += (doc.title.lowercased().components(separatedBy: term).count - 1) * 20
                score += (doc.text.lowercased().components(separatedBy:  term).count - 1)
            }
            // Exact phrase bonus
            score += (doc.title.lowercased().components(separatedBy: q).count - 1) * 50
            score += (doc.text.lowercased().components(separatedBy:  q).count - 1) * 5
            return score > 0 ? (doc, score) : nil
        }
        .sorted { $0.1 > $1.1 }
        .map { $0.0 }
    }

    /// Ask Ollama to expand the query into related terms, then re-run search
    private func expandAndSearch(originalQuery q: String) async {
        guard let url = URL(string: "http://localhost:11434/api/generate") else {
            await MainActor.run { isExpandingQuery = false }
            return
        }

        // Ask for related survival terms — no explanation, just the list
        let prompt = """
        Give me 8 short search terms related to "\(q)" for a survival and emergency preparedness library. \
        Return ONLY a comma-separated list, no explanations, no numbering.
        Example for "water purification": filter, boiling, contamination, treatment, iodine, purify, chlorine, clean water
        Now for "\(q)":
        """

        // Detect which model is available
        let model = await detectModel() ?? "phi3:mini"

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "options": ["temperature": 0.2, "num_predict": 80]
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            await MainActor.run { isExpandingQuery = false }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 12

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled else { return }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let response = json["response"] as? String {
                let terms = response
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines)
                              .trimmingCharacters(in: .punctuationCharacters)
                              .lowercased() }
                    .filter { !$0.isEmpty && $0.count < 40 }

                let allTerms = queryTerms(q) + terms
                let expanded = keywordSearch(terms: allTerms)

                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    expandedTerms = terms
                    isExpandingQuery = false
                    if !expanded.isEmpty { searchResults = expanded }
                }
            } else {
                await MainActor.run { isExpandingQuery = false }
            }
        } catch {
            await MainActor.run { isExpandingQuery = false }
        }
    }

    private func detectModel() async -> String? {
        guard let url = URL(string: "http://localhost:11434/api/tags"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else { return nil }
        let names = models.compactMap { $0["name"] as? String }
        return names.first(where: { $0.hasPrefix("llama3") })
            ?? names.first(where: { $0.hasPrefix("mistral") })
            ?? names.first
    }

    private func relevance(_ doc: SearchDoc, query q: String) -> Int {
        (doc.title.lowercased().components(separatedBy: q).count - 1) * 10 +
        (doc.text.lowercased().components(separatedBy:  q).count - 1)
    }
}

// ── Section Home Grid ─────────────────────────────────────────────────────────

struct SectionHomeGrid: View {
    let sections: [String]
    let sectionCounts: [String: Int]
    let onSelect: (String) -> Void
    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Topics")
                    .font(.title2.bold())
                    .padding(.top, 4)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(sections, id: \.self) { section in
                        SectionCard(
                            name: section,
                            count: sectionCounts[section] ?? 0,
                            onSelect: { onSelect(section) }
                        )
                    }
                }
            }
            .padding(20)
        }
    }
}

struct SectionCard: View {
    let name: String
    let count: Int
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(sectionColor(name).opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: sectionSymbol(name))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(sectionColor(name))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("\(count) document\(count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: .black.opacity(isHovered ? 0.12 : 0.06), radius: isHovered ? 8 : 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isHovered ? sectionColor(name).opacity(0.35) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// ── Document Browse Grid ───────────────────────────────────────────────────────

struct DocumentBrowseView: View {
    let items: [LibraryItem]
    let onSelect: (LibraryItem) -> Void
    private let columns = [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 14)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(items) { item in
                    DocumentCard(item: item, onSelect: { onSelect(item) })
                }
            }
            .padding(16)
        }
    }
}

struct DocumentCard: View {
    let item: LibraryItem
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(sectionColor(item.section).opacity(0.13))
                            .frame(width: 36, height: 36)
                        Image(systemName: itemSymbol(item.type))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(sectionColor(item.section))
                    }
                    Spacer()
                    TypeBadge(type: item.type)
                }
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(item.desc)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: .black.opacity(isHovered ? 0.10 : 0.05), radius: isHovered ? 6 : 3, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? sectionColor(item.section).opacity(0.4) : Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// ── Detail View ───────────────────────────────────────────────────────────────

struct DetailView: View {
    let item: LibraryItem
    @Binding var status: String
    @Binding var copied: Bool
    var onBack: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // ── Inline header bar ─────────────────────────────────────────────
            HStack(spacing: 12) {
                if let back = onBack {
                    Button(action: back) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    Divider().frame(height: 20)
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(sectionColor(item.section).opacity(0.13))
                        .frame(width: 34, height: 34)
                    Image(systemName: itemSymbol(item.type))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(sectionColor(item.section))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(item.desc)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                TypeBadge(type: item.type)
                HStack(spacing: 6) {
                    if item.type == .zim {
                        Button("Open in Kiwix") { openInApp(bundleID: "org.kiwix.desktop", fallbackAppName: "Kiwix") }
                            .buttonStyle(.borderedProminent)
                    } else if item.type == .epub {
                        Button("Open in Books") { openInApp(bundleID: "com.apple.iBooksX", fallbackAppName: "Books") }
                            .buttonStyle(.borderedProminent)
                    } else if item.type != .folder {
                        Button("Open") { openDirect() }
                            .buttonStyle(.borderedProminent)
                    }
                    Button { openFinder() } label: {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .help("Reveal in Finder")
                    Button { copyPath() } label: {
                        Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                            .foregroundColor(copied ? .green : .primary)
                    }
                    .help("Copy path")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // ── Content ───────────────────────────────────────────────────────
            Group {
                switch item.type {
                case .pdf:    PDFPreview(url: item.fileURL)
                case .html, .txt: WebPreview(url: item.fileURL)
                case .zim:    PlaceholderView(symbol: "books.vertical.fill", color: .purple,
                                              title: "Open in Kiwix",
                                              message: "ZIM archive — press the button above.")
                case .epub:   PlaceholderView(symbol: "book.fill", color: .orange,
                                              title: "Open in Books",
                                              message: "EPUB — press the button above.")
                case .folder: PlaceholderView(symbol: "folder.fill", color: .yellow,
                                              title: "Folder",
                                              message: "Use Reveal in Finder to browse.")
                case .other:  PlaceholderView(symbol: "doc.fill", color: .gray,
                                              title: "No Preview",
                                              message: "This file type has no embedded preview.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func copyPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.path, forType: .string)
        copied = true
        status = "Path copied"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }

    private func openFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
        status = "Revealed in Finder"
    }

    private func openDirect() {
        NSWorkspace.shared.open(item.fileURL)
        status = "Opened file"
    }

    private func openInApp(bundleID: String, fallbackAppName: String) {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.open([item.fileURL], withApplicationAt: appURL,
                                    configuration: NSWorkspace.OpenConfiguration()) { _, error in
                DispatchQueue.main.async {
                    status = error.map { "Open failed: \($0.localizedDescription)" } ?? "Opened in \(fallbackAppName)"
                }
            }
        } else {
            NSWorkspace.shared.open(item.fileURL)
            status = "\(fallbackAppName) not found — opened with default app"
        }
    }
}

// ── PDF Preview ───────────────────────────────────────────────────────────────

struct PDFPreview: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        return v
    }
    func updateNSView(_ v: PDFView, context: Context) {
        v.document = PDFDocument(url: url)
    }
}

// ── Web Preview ───────────────────────────────────────────────────────────────

/// Escape characters that are special in HTML to prevent injection.
private func htmlEscape(_ string: String) -> String {
    string
        .replacingOccurrences(of: "&",  with: "&amp;")
        .replacingOccurrences(of: "<",  with: "&lt;")
        .replacingOccurrences(of: ">",  with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'",  with: "&#39;")
}

private func errorPage(title: String, detail: String) -> String {
    "<html><body style='font-family:-apple-system;padding:24px'><h2>\(htmlEscape(title))</h2><p>\(htmlEscape(detail))</p></body></html>"
}

struct WebPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let wv = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        wv.navigationDelegate = context.coordinator
        return wv
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
        guard context.coordinator.lastLoadedPath != url.path else { return }
        context.coordinator.lastLoadedPath = url.path
        guard FileManager.default.fileExists(atPath: url.path) else {
            wv.loadHTMLString(errorPage(title: "File not found", detail: url.path), baseURL: nil)
            return
        }
        do {
            var html = try String(contentsOf: url, encoding: .utf8)
            html = WebPreview.inlineImages(in: html, baseDir: url.deletingLastPathComponent())
            wv.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
        } catch {
            wv.loadHTMLString(errorPage(title: "Unable to load", detail: error.localizedDescription), baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func inlineImages(in html: String, baseDir: URL) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"src=(["'])([^"']+)\1"#) else { return html }
        let basePath = baseDir.standardized.path
        var result = ""
        var lastEnd = html.startIndex
        for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let fullRange = Range(match.range, in: html),
                  let srcRange  = Range(match.range(at: 2), in: html) else { continue }
            let src = String(html[srcRange])
            // Block absolute paths, remote URLs, data URIs, and path traversal sequences
            guard !src.hasPrefix("http"), !src.hasPrefix("//"),
                  !src.hasPrefix("data:"), !src.hasPrefix("/"),
                  !src.contains("..") else { continue }
            result.append(contentsOf: html[lastEnd..<fullRange.lowerBound])
            let imgURL = baseDir.appendingPathComponent(src).standardized
            // Ensure resolved path stays within the base directory
            guard imgURL.path.hasPrefix(basePath + "/") || imgURL.path == basePath else {
                result.append(contentsOf: html[fullRange]); lastEnd = fullRange.upperBound; continue
            }
            if let data = try? Data(contentsOf: imgURL) {
                let mime: String
                switch imgURL.pathExtension.lowercased() {
                case "jpg", "jpeg": mime = "image/jpeg"
                case "png":         mime = "image/png"
                case "svg":         mime = "image/svg+xml"
                case "gif":         mime = "image/gif"
                case "webp":        mime = "image/webp"
                default:
                    result.append(contentsOf: html[fullRange]); lastEnd = fullRange.upperBound; continue
                }
                let q = html[fullRange.lowerBound..<srcRange.lowerBound].last ?? "\""
                result.append("src=\(q)data:\(mime);base64,\(data.base64EncodedString())\(q)")
            } else {
                result.append(contentsOf: html[fullRange])
            }
            lastEnd = fullRange.upperBound
        }
        result.append(contentsOf: html[lastEnd...])
        return result
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastLoadedPath = ""

        /// Allowed base directories for file:// navigation.
        private let allowedBasePaths = [
            "/Volumes/20TB_HDD/",
            NSHomeDirectory() + "/Desktop/"
        ]

        func webView(_ wv: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { decisionHandler(.cancel); return }

            switch url.scheme {
            case "about", "blob":
                // Allow about:blank and blob URLs used by renderer internals
                decisionHandler(.allow)

            case "file":
                // Only permit file:// URLs within the known library base paths
                let path = url.standardized.path
                if allowedBasePaths.contains(where: { path.hasPrefix($0) }) {
                    decisionHandler(.allow)
                } else {
                    decisionHandler(.cancel)
                }

            case "http", "https":
                // Block all external web navigation; open in default browser instead
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)

            default:
                decisionHandler(.cancel)
            }
        }

        func webView(_ wv: WKWebView, didFinish _: WKNavigation!) {
            wv.evaluateJavaScript("""
            (function(){
                var remote=Array.from(document.querySelectorAll('link[rel="stylesheet"]'))
                    .some(function(l){return l.href&&(l.href.startsWith('http://')||l.href.startsWith('https://'));});
                if(!remote)return;
                var s=document.createElement('style');
                s.textContent='body{background:#fff!important;color:#1a1a1a!important;}'+
                    'header,footer{display:none!important;}a{color:#0066cc!important;}';
                document.head.appendChild(s);
            })();
            """, completionHandler: nil)
        }

        func webView(_ wv: WKWebView, didFail _: WKNavigation!, withError error: Error) {
            wv.loadHTMLString(errorPage(title: "Load failed", detail: error.localizedDescription), baseURL: nil)
        }
    }
}

// ── Placeholder / Empty State ─────────────────────────────────────────────────

struct PlaceholderView: View {
    let symbol: String
    let color: Color
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(color)
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(.title2.bold())
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ── Agent Chat ────────────────────────────────────────────────────────────────

struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String
}

@MainActor
class AgentViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var input: String = ""
    @Published var isThinking: Bool = false
    @Published var modelStatus: String = "Checking…"
    @Published var selectedModel: String = "llama3"
    @Published var availableModels: [String] = []

    private let ollamaBase = "http://localhost:11434"

    private var systemPrompt: String {
        let loc = LocationStore.shared.config
        var lines: [String] = []

        // Location-specific context from LocationConfig
        lines.append(loc.systemPromptContext)

        lines.append("""
RESPONSE FORMAT — always follow this structure:
1. **Direct answer first** — one or two sentences. Give the key number or action immediately.
2. **Simple breakdown** — short bullet list if needed. Each bullet is one plain fact or step. No jargon.
3. **What to do next** — 1–3 action items the person can do right now.
4. **📚 Read more:** — end every response with this line, listing 1–3 relevant documents from the library below. Format: `📚 Read more: Document Name, Document Name`

WRITING RULES:
- The user is a beginner — assume they have no prior survival knowledge. Explain things simply and practically.
- Write like you're explaining to a nervous neighbor, not a soldier.
- No markdown asterisks for italics. Use **bold** only for the most critical number or action.
- No filler ("Great question", "It's important to note", "Certainly").
- Never restate the question.
- Be specific: "14 gallons" not "enough water."

LIBRARY DOCUMENTS (reference these by exact name):
Water/Food: Rain Harvesting Guide, Rainwater Handbook, USDA Home Canning Guide, Survival Food Checklist, Home Survival Kit Checklist
Medical: Where There Is No Doctor, Where There Is No Dentist, FM 4-25.11 First Aid, AVMA Pet First Aid, Merck Pet Emergency Guide
Shelter/Survival: FM 21-76 Army Survival Manual, Shelters Shacks and Shanties, LDS Preparedness Manual
Nuclear: Nuclear War Survival Skills, Build a Protective Fallout Shelter
Checklists: Bug Out Bag Checklist, Get Home Bag Checklist, Car Emergency Kit Checklist, Nuclear Survival Kit Checklist
Scenarios: Pandemic & Biological Event
Comms: ARES Field Resource Manual

This is offline — never suggest checking the internet.
""")

        return lines.joined(separator: "\n")
    }

    func checkOllama() async {
        // Try to connect first
        if await pingOllama() { return }

        // Not running — launch it automatically
        modelStatus = "Starting Ollama…"
        launchOllamaServe()

        // Retry up to 10 times (~10 seconds)
        for attempt in 1...10 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            modelStatus = "Starting Ollama… (\(attempt)s)"
            if await pingOllama() { return }
        }

        modelStatus = "Could not start Ollama — open Ollama.app manually"
    }

    @discardableResult
    private func pingOllama() async -> Bool {
        guard let url = URL(string: "\(ollamaBase)/api/tags") else { return false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                let names = models.compactMap { $0["name"] as? String }
                availableModels = names
                if let first = names.first {
                    selectedModel = names.first(where: { $0.hasPrefix("llama3") })
                        ?? names.first(where: { $0.hasPrefix("mistral") })
                        ?? first
                    modelStatus = "\(names.count) model\(names.count == 1 ? "" : "s") available · first response may be slow"
                } else {
                    modelStatus = "No models — run: ollama pull phi3:mini"
                }
                return true
            }
        } catch {}
        return false
    }

    private func launchOllamaServe() {
        // Candidate paths for the ollama binary
        let candidates = [
            "/usr/local/bin/ollama",
            "/opt/homebrew/bin/ollama",
            "/Applications/Ollama.app/Contents/Resources/ollama"
        ]
        guard let binary = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            modelStatus = "Ollama not found — install from ollama.com"
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["serve"]

        // Point model storage at the HDD if it's mounted, otherwise default
        var env = ProcessInfo.processInfo.environment
        let hddModels = "/Volumes/20TB_HDD/local-models"
        if FileManager.default.fileExists(atPath: hddModels) {
            env["OLLAMA_MODELS"] = hddModels
        }
        process.environment = env

        // Discard stdout/stderr so it doesn't pollute the app's console
        process.standardOutput = FileHandle.nullDevice
        process.standardError  = FileHandle.nullDevice

        try? process.run()
    }

    func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        input = ""
        messages.append(ChatMessage(role: .user, text: text))
        isThinking = true

        var payload: [[String: String]] = [["role": "system", "content": systemPrompt]]
        for msg in messages.dropLast() {
            payload.append(["role": msg.role == .user ? "user" : "assistant", "content": msg.text])
        }
        payload.append(["role": "user", "content": text])

        guard let url = URL(string: "\(ollamaBase)/api/chat"),
              let body = try? JSONSerialization.data(withJSONObject: ["model": selectedModel, "messages": payload, "stream": true]) else {
            isThinking = false; return
        }
        var req = URLRequest(url: url, timeoutInterval: 300)   // 5 min — llama3 first load is slow
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        var replyIndex: Int? = nil

        do {
            let (bytes, _) = try await URLSession.shared.bytes(for: req)
            for try await line in bytes.lines {
                guard !line.isEmpty,
                      let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let msgObj = json["message"] as? [String: Any],
                      let chunk = msgObj["content"] as? String,
                      !chunk.isEmpty else { continue }
                // Add placeholder bubble on first real token
                if replyIndex == nil {
                    replyIndex = messages.count
                    messages.append(ChatMessage(role: .assistant, text: ""))
                }
                messages[replyIndex!].text += chunk
            }
        } catch {
            if replyIndex == nil {
                replyIndex = messages.count
                messages.append(ChatMessage(role: .assistant, text: ""))
            }
            messages[replyIndex!].text = "Error: \(error.localizedDescription)"
        }
        isThinking = false
    }
}

struct AgentChatView: View {
    @StateObject private var vm = AgentViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Survival Assistant")
                        .font(.headline)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(vm.availableModels.isEmpty ? Color.orange : Color.green)
                            .frame(width: 6, height: 6)
                        Text(vm.modelStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !vm.availableModels.isEmpty {
                    Picker("", selection: $vm.selectedModel) {
                        ForEach(vm.availableModels, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 180)
                    .labelsHidden()
                }
                if !vm.messages.isEmpty {
                    Button {
                        vm.messages.removeAll()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear conversation")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            // ── Messages ──
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if vm.messages.isEmpty {
                            VStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(Color.blue.opacity(0.1)).frame(width: 64, height: 64)
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .font(.system(size: 26))
                                        .foregroundStyle(.blue)
                                }
                                Text("Ask me anything about survival, emergency procedures, local hazards, water, food, radio frequencies, or your offline library.")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 380)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 70)
                        }
                        ForEach(vm.messages) { msg in
                            ChatBubble(message: msg).id(msg.id)
                        }
                        if vm.isThinking && vm.messages.last?.role == .user {
                            TypingIndicator().id("typing")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        if let last = vm.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onChange(of: vm.messages.last?.text) { _, _ in
                    if let last = vm.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            Divider()

            // ── Input bar ──
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask a survival question…", text: $vm.input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(1...6)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(NSColor.separatorColor), lineWidth: 1))
                    .onSubmit { Task { await vm.send() } }

                Button {
                    Task { await vm.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isThinking ? .gray.opacity(0.4) : .blue)
                }
                .buttonStyle(.plain)
                .disabled(vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isThinking)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .task { await vm.checkOllama() }
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 80) }

            if message.role == .assistant {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                .padding(.bottom, 2)
            }

            Group {
                let raw = message.text.isEmpty ? " " : message.text
                if let attributed = try? AttributedString(markdown: raw,
                    options: AttributedString.MarkdownParsingOptions(
                        interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(attributed)
                } else {
                    Text(raw)
                }
            }
            .textSelection(.enabled)
            .font(.body)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                message.role == .user
                    ? Color.blue
                    : Color(NSColor.controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .foregroundStyle(message.role == .user ? Color.white : Color.primary)
            .shadow(color: .black.opacity(0.07), radius: 3, x: 0, y: 1)

            if message.role == .user {
                ZStack {
                    Circle().fill(Color(NSColor.tertiaryLabelColor).opacity(0.3)).frame(width: 28, height: 28)
                    Image(systemName: "person.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 2)
            }

            if message.role == .assistant { Spacer(minLength: 80) }
        }
    }
}

struct TypingIndicator: View {
    @State private var phase = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.15)).frame(width: 28, height: 28)
                Image(systemName: "cpu.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary.opacity(phase == i ? 1.0 : 0.3))
                        .frame(width: 7, height: 7)
                        .animation(.easeInOut(duration: 0.3), value: phase)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
            Spacer(minLength: 80)
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}
