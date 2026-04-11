import SwiftUI
import Combine

// MARK: - Shared Skill Store (syncs with SkillsLogView via same UserDefaults key)

@MainActor
class SkillTreeStore: ObservableObject {
    static let shared = SkillTreeStore()
    private let key = "skills_v1"

    @Published var completed: Set<String> = []

    init() { load() }

    func toggle(_ id: String) {
        if completed.contains(id) { completed.remove(id) } else { completed.insert(id) }
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

// MARK: - Skill Tree Data
// Reuses SkillItem definitions via the `allSkills` array in SkillsLogView.swift.
// Tiers map directly from SkillItem.priority: 1→Tier 1 (Critical), 2→Tier 2, 3→Tier 3

private let treeCategories: [(name: String, color: Color, symbol: String)] = [
    ("Medical & First Aid",  .red,    "cross.case.fill"),
    ("Communications",       .green,  "antenna.radiowaves.left.and.right"),
    ("Water & Sanitation",   .blue,   "drop.fill"),
    ("Fire & Energy",        .orange, "flame.fill"),
    ("Food & Foraging",      .yellow, "leaf.fill"),
    ("Navigation",           .teal,   "location.fill"),
    ("Security & Defense",   .purple, "shield.fill"),
    ("Tools & Construction", Color(red: 0.6, green: 0.4, blue: 0.1), "hammer.fill"),
]

// MARK: - Main View

struct SkillTreeView: View {
    @StateObject private var store = SkillTreeStore.shared
    @State private var selectedCategory: String? = nil

    private var categories: [String] {
        Array(Set(allSkills.map(\.category))).sorted()
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(selection: $selectedCategory) {
                ForEach(treeCategories, id: \.name) { cat in
                    if categories.contains(cat.name) {
                        SkillCategoryRow(
                            name: cat.name,
                            color: cat.color,
                            symbol: cat.symbol,
                            skills: allSkills.filter { $0.category == cat.name },
                            store: store
                        )
                        .tag(cat.name)
                    }
                }
                // Catch-all for categories not in treeCategories
                ForEach(categories.filter { c in !treeCategories.map(\.name).contains(c) }, id: \.self) { cat in
                    SkillCategoryRow(
                        name: cat,
                        color: .gray,
                        symbol: "star.fill",
                        skills: allSkills.filter { $0.category == cat },
                        store: store
                    )
                    .tag(cat)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Skill Tree")
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            if let cat = selectedCategory {
                SkillCategoryDetail(
                    categoryName: cat,
                    color: treeCategories.first(where: { $0.name == cat })?.color ?? .gray,
                    symbol: treeCategories.first(where: { $0.name == cat })?.symbol ?? "star.fill",
                    skills: allSkills.filter { $0.category == cat },
                    store: store
                )
            } else {
                SkillTreeOverview(store: store)
            }
        }
    }
}

// MARK: - Overview

private struct SkillTreeOverview: View {
    @ObservedObject var store: SkillTreeStore

    private var totalSkills: Int { allSkills.count }
    private var completedCount: Int { allSkills.filter { store.isCompleted($0.id) }.count }
    private var pct: Double { totalSkills > 0 ? Double(completedCount) / Double(totalSkills) : 0 }

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: pct)
                        .stroke(
                            LinearGradient(colors: [.orange, .green],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: pct)
                }
                .frame(width: 120, height: 120)
                .overlay {
                    VStack(spacing: 2) {
                        Text("\(Int(pct * 100))%")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text("\(completedCount)/\(totalSkills)")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }

                Text("Overall Preparedness")
                    .font(.system(size: 14, weight: .semibold))
                Text("Select a category to view and mark skills")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }

            // Tier summary
            VStack(spacing: 8) {
                ForEach(1...3, id: \.self) { tier in
                    let tierSkills = allSkills.filter { $0.priority == tier }
                    let tierDone   = tierSkills.filter { store.isCompleted($0.id) }.count
                    TierSummaryRow(tier: tier, done: tierDone, total: tierSkills.count)
                }
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TierSummaryRow: View {
    let tier: Int; let done: Int; let total: Int
    var color: Color { tier == 1 ? .red : tier == 2 ? .yellow : .secondary }
    var label: String { tier == 1 ? "Tier 1 · Critical" : tier == 2 ? "Tier 2 · Important" : "Tier 3 · Useful" }
    var pct: Double { total > 0 ? Double(done) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
                Spacer()
                Text("\(done)/\(total)").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.7))
                        .frame(width: geo.size.width * pct)
                        .animation(.easeInOut, value: pct)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Category Sidebar Row

private struct SkillCategoryRow: View {
    let name: String
    let color: Color
    let symbol: String
    let skills: [SkillItem]
    @ObservedObject var store: SkillTreeStore

    private var done: Int { skills.filter { store.isCompleted($0.id) }.count }
    private var pct: Double { skills.isEmpty ? 0 : Double(done) / Double(skills.count) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(name).font(.system(size: 12))
            Spacer()
            ZStack {
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(done)").font(.system(size: 8, weight: .bold)).foregroundStyle(color)
            }
            .frame(width: 26, height: 26)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Category Detail

private struct SkillCategoryDetail: View {
    let categoryName: String
    let color: Color
    let symbol: String
    let skills: [SkillItem]
    @ObservedObject var store: SkillTreeStore

    private var tier1: [SkillItem] { skills.filter { $0.priority == 1 } }
    private var tier2: [SkillItem] { skills.filter { $0.priority == 2 } }
    private var tier3: [SkillItem] { skills.filter { $0.priority == 3 } }

    private var done: Int { skills.filter { store.isCompleted($0.id) }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Category header
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(color.opacity(0.15)).frame(width: 52, height: 52)
                        Image(systemName: symbol).font(.system(size: 24)).foregroundStyle(color)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(categoryName).font(.system(size: 20, weight: .bold))
                        Text("\(done) of \(skills.count) skills learned")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                if !tier1.isEmpty { tierSection("Tier 1 — Critical", skills: tier1, color: .red) }
                if !tier2.isEmpty { tierSection("Tier 2 — Important", skills: tier2, color: .yellow) }
                if !tier3.isEmpty { tierSection("Tier 3 — Useful", skills: tier3, color: Color.secondary) }
            }
            .padding(.vertical, 20)
        }
    }

    private func tierSection(_ title: String, skills: [SkillItem], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 24)

            ForEach(skills, id: \.id) { skill in
                SkillCard(skill: skill, accentColor: self.color, store: store)
                    .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Skill Card

private struct SkillCard: View {
    let skill: SkillItem
    let accentColor: Color
    @ObservedObject var store: SkillTreeStore

    private var learned: Bool { store.isCompleted(skill.id) }

    var body: some View {
        HStack(spacing: 12) {
            Button { store.toggle(skill.id) } label: {
                ZStack {
                    Circle()
                        .fill(learned ? accentColor.opacity(0.2) : Color.white.opacity(0.06))
                        .frame(width: 30, height: 30)
                    Image(systemName: learned ? "checkmark" : "circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(learned ? accentColor : Color.secondary.opacity(0.5))
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(skill.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(learned ? Color.primary : Color.primary.opacity(0.8))
                    .strikethrough(false)
                Text(skill.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(
            learned
                ? accentColor.opacity(0.06)
                : Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(learned ? accentColor.opacity(0.25) : Color.clear, lineWidth: 1)
        )
    }
}
