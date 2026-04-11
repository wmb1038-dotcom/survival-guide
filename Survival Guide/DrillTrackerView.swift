import SwiftUI
import Combine
import UserNotifications

// MARK: - Models

enum DrillType: String, Codable, CaseIterable, Identifiable {
    case fireEvacuation  = "Fire Evacuation"
    case earthquake      = "Earthquake (Drop/Cover/Hold)"
    case shelterInPlace  = "Shelter-in-Place"
    case bugOut          = "Bug-Out Drill"
    case medical         = "Medical Response"
    case communications  = "Communications Check"
    case waterTreatment  = "Water Treatment"
    case powerOutage     = "Power Outage Simulation"
    case generatorStart  = "Generator Start & Transfer"
    case other           = "Other"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .fireEvacuation:  return "flame.fill"
        case .earthquake:      return "waveform.path"
        case .shelterInPlace:  return "house.fill"
        case .bugOut:          return "backpack.fill"
        case .medical:         return "cross.case.fill"
        case .communications:  return "antenna.radiowaves.left.and.right"
        case .waterTreatment:  return "drop.fill"
        case .powerOutage:     return "bolt.slash.fill"
        case .generatorStart:  return "engine.combustion.fill"
        case .other:           return "checklist"
        }
    }
    var color: Color {
        switch self {
        case .fireEvacuation:  return .orange
        case .earthquake:      return Color(red: 0.7, green: 0.5, blue: 0.2)
        case .shelterInPlace:  return .blue
        case .bugOut:          return Color(red: 0.4, green: 0.6, blue: 0.3)
        case .medical:         return .red
        case .communications:  return .green
        case .waterTreatment:  return .cyan
        case .powerOutage:     return .yellow
        case .generatorStart:  return Color(red: 0.7, green: 0.6, blue: 0.1)
        case .other:           return .gray
        }
    }
    // Recommended interval between drills
    var recommendedIntervalMonths: Int {
        switch self {
        case .fireEvacuation: return 6
        case .earthquake:     return 12
        case .medical:        return 6
        case .communications: return 3
        case .generatorStart: return 1
        default:              return 12
        }
    }
}

enum DrillOutcome: String, Codable, CaseIterable, Identifiable {
    case pass        = "Pass"
    case partial     = "Needs Work"
    case fail        = "Fail"
    case practiceOnly = "Practice Only"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .pass:         return .green
        case .partial:      return .yellow
        case .fail:         return .red
        case .practiceOnly: return .secondary
        }
    }
}

struct DrillSession: Codable, Identifiable {
    var id               = UUID()
    var date             : Date        = Date()
    var type             : DrillType   = .fireEvacuation
    var participants     : Int         = 1
    var durationMinutes  : Int         = 15
    var outcome          : DrillOutcome = .pass
    var notes            : String      = ""
    var lessonsLearned   : String      = ""
    var nextScheduled    : Date?       = nil
}

// MARK: - Engine

@MainActor
class DrillEngine: ObservableObject {
    static let shared = DrillEngine()
    private let key   = "drills_v1"

    @Published var sessions: [DrillSession] = []

    init() { load() }

    func upsert(_ s: DrillSession) {
        if let i = sessions.firstIndex(where: { $0.id == s.id }) { sessions[i] = s }
        else { sessions.insert(s, at: 0) }
        save()
        if let next = s.nextScheduled {
            scheduleReminder(for: s.type, date: next)
        }
    }

    func delete(_ s: DrillSession) { sessions.removeAll { $0.id == s.id }; save() }

    // MARK: Computed

    var upcoming: [DrillSession] {
        sessions.filter { s in (s.nextScheduled ?? .distantPast) > Date() }
                .sorted { $0.nextScheduled! < $1.nextScheduled! }
    }

    var sessionsThisYear: [DrillSession] {
        let start = Calendar.current.date(from:
            DateComponents(year: Calendar.current.component(.year, from: Date()))) ?? Date()
        return sessions.filter { $0.date >= start }
    }

    /// Drill types with no session in past N months (overdue)
    var overdue: [(DrillType, lastDate: Date?)] {
        DrillType.allCases.compactMap { type in
            let last = sessions.filter { $0.type == type }.sorted { $0.date > $1.date }.first
            let cutoff = Calendar.current.date(
                byAdding: .month, value: -type.recommendedIntervalMonths, to: Date()) ?? Date()
            if last == nil || last!.date < cutoff { return (type, last?.date) }
            return nil
        }
    }

    // MARK: Persistence

    private func save() {
        if let d = try? JSONEncoder().encode(sessions) { UserDefaults.standard.set(d, forKey: key) }
    }
    private func load() {
        guard let d = UserDefaults.standard.data(forKey: key),
              let v = try? JSONDecoder().decode([DrillSession].self, from: d) else { return }
        sessions = v
    }

    private func scheduleReminder(for type: DrillType, date: Date) {
        let id = "drill_\(type.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let content      = UNMutableNotificationContent()
        content.title    = "Drill Reminder"
        content.body     = "\(type.rawValue) drill scheduled for today"
        content.sound    = .default
        let comps   = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

// MARK: - Main View

struct DrillTrackerView: View {
    @StateObject private var engine = DrillEngine.shared
    @State private var tab      = 0
    @State private var showAdd  = false
    @State private var editing  : DrillSession? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                DrillStat(value: "\(engine.sessionsThisYear.count)", label: "Drills This Year", color: .green)
                DrillStat(value: "\(engine.upcoming.count)", label: "Upcoming", color: .blue)
                let od = engine.overdue.count
                if od > 0 {
                    DrillStat(value: "\(od)", label: "Overdue", color: .orange)
                }
                Spacer()
                Button { showAdd = true } label: {
                    Label("Log Drill", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent).tint(.green)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(Color.white.opacity(0.04))

            Picker("", selection: $tab) {
                Text("History").tag(0)
                Text("Upcoming").tag(1)
                Text("Overdue").tag(2)
            }
            .pickerStyle(.segmented).padding(.horizontal, 20).padding(.vertical, 10)
            Divider().opacity(0.3)

            switch tab {
            case 0: drillList(engine.sessions)
            case 1: upcomingTab
            case 2: overdueTab
            default: EmptyView()
            }
        }
        .sheet(isPresented: $showAdd) {
            DrillSessionSheet(session: DrillSession()) { engine.upsert($0) }
        }
        .sheet(item: $editing) { s in
            DrillSessionSheet(session: s) { engine.upsert($0) }
        }
    }

    // MARK: - Tabs

    private func drillList(_ sessions: [DrillSession]) -> some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView("No Drills Logged",
                    systemImage: "checklist",
                    description: Text("Log a drill to start tracking your preparedness practice."))
            } else {
                List {
                    ForEach(sessions) { s in
                        DrillRow(session: s)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = s }
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { idx in idx.forEach { engine.delete(engine.sessions[$0]) } }
                }
                .listStyle(.plain)
            }
        }
    }

    private var upcomingTab: some View {
        Group {
            if engine.upcoming.isEmpty {
                ContentUnavailableView("No Upcoming Drills",
                    systemImage: "calendar.badge.clock",
                    description: Text("Schedule a next date when logging a drill."))
            } else {
                List {
                    ForEach(engine.upcoming) { s in
                        UpcomingDrillRow(session: s)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = s }
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var overdueTab: some View {
        Group {
            if engine.overdue.isEmpty {
                ContentUnavailableView("All Drills Current",
                    systemImage: "checkmark.shield.fill",
                    description: Text("All drill types are within their recommended intervals."))
                    .foregroundStyle(.green)
            } else {
                List {
                    ForEach(engine.overdue, id: \.0) { type, lastDate in
                        OverdueDrillRow(type: type, lastDate: lastDate)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                var s = DrillSession()
                                s.type = type
                                editing = s
                            }
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Rows

private struct DrillRow: View {
    let session: DrillSession
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.type.symbol)
                .font(.system(size: 14))
                .foregroundStyle(session.type.color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(session.type.rawValue)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    OutcomeBadge(outcome: session.outcome)
                }
                HStack(spacing: 8) {
                    Text(session.date, style: .date)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Text("\(session.durationMinutes) min · \(session.participants) participant\(session.participants == 1 ? "" : "s")")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                if !session.lessonsLearned.isEmpty {
                    Text("💡 \(session.lessonsLearned)")
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct UpcomingDrillRow: View {
    let session: DrillSession
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.type.symbol)
                .font(.system(size: 14)).foregroundStyle(session.type.color).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.type.rawValue).font(.system(size: 13, weight: .medium))
                if let next = session.nextScheduled {
                    Text(next, style: .date).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let next = session.nextScheduled {
                let days = Calendar.current.dateComponents([.day], from: Date(), to: next).day ?? 0
                Text(days == 0 ? "Today" : "in \(days)d")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(days < 3 ? .orange : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct OverdueDrillRow: View {
    let type: DrillType
    let lastDate: Date?
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.symbol)
                .font(.system(size: 14)).foregroundStyle(type.color).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(type.rawValue).font(.system(size: 13, weight: .medium))
                Text(lastDate == nil ? "Never practiced"
                     : "Last: \(lastDate!.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Text("Overdue")
                .font(.system(size: 10, weight: .bold)).foregroundStyle(.orange)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct OutcomeBadge: View {
    let outcome: DrillOutcome
    var body: some View {
        Text(outcome.rawValue)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(outcome.color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(outcome.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
    }
}

private struct DrillStat: View {
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

// MARK: - Sheet

struct DrillSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: DrillSession
    @State private var hasNext = false
    private let onSave: (DrillSession) -> Void

    init(session: DrillSession, onSave: @escaping (DrillSession) -> Void) {
        _session = State(initialValue: session)
        _hasNext = State(initialValue: session.nextScheduled != nil)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(session.type.rawValue).font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(session); dismiss() }
                    .buttonStyle(.borderedProminent).tint(.green)
            }.padding()
            Divider()
            Form {
                Section("Drill") {
                    Picker("Type", selection: $session.type) {
                        ForEach(DrillType.allCases) {
                            Label($0.rawValue, systemImage: $0.symbol).tag($0)
                        }
                    }
                    DatePicker("Date", selection: $session.date, displayedComponents: .date)
                }
                Section("Details") {
                    HStack {
                        Text("Participants"); Spacer()
                        Stepper("\(session.participants)",
                                value: $session.participants, in: 1...50)
                    }
                    HStack {
                        Text("Duration (minutes)"); Spacer()
                        TextField("15", value: $session.durationMinutes, format: .number)
                            .multilineTextAlignment(.trailing).frame(width: 70)
                    }
                    Picker("Outcome", selection: $session.outcome) {
                        ForEach(DrillOutcome.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("After-Action") {
                    TextField("Notes", text: $session.notes, axis: .vertical)
                        .lineLimit(3...5)
                    TextField("Lessons Learned", text: $session.lessonsLearned, axis: .vertical)
                        .lineLimit(3...5)
                }
                Section("Schedule Next") {
                    Toggle("Schedule next drill", isOn: $hasNext)
                        .onChange(of: hasNext) { _, on in
                            session.nextScheduled = on
                                ? Calendar.current.date(byAdding: .month,
                                    value: session.type.recommendedIntervalMonths, to: Date())
                                : nil
                        }
                    if hasNext {
                        DatePicker("Next drill date", selection: Binding(
                            get: { session.nextScheduled ?? Date() },
                            set: { session.nextScheduled = $0 }),
                            displayedComponents: .date)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 440, minHeight: 540)
    }
}
