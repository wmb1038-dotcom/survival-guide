import SwiftUI
import Combine

// MARK: - Models

struct Medication: Codable, Identifiable {
    var id = UUID()
    var name: String = ""
    var dose: String = ""
    var frequency: String = ""
    var daysOnHand: Int = 0
    var refillDate: Date? = nil
    var prescriber: String = ""
    var notes: String = ""

    var statusColor: Color {
        switch daysOnHand {
        case 30...: return .green
        case 14...: return Color(red: 0.5, green: 0.8, blue: 0.0)
        case 7...:  return .orange
        default:    return .red
        }
    }

    var statusLabel: String {
        switch daysOnHand {
        case 30...: return "Stocked"
        case 14...: return "Getting low"
        case 7...:  return "Low — refill soon"
        default:    return "CRITICAL"
        }
    }
}

// MARK: - Engine

@MainActor
class MedicationEngine: ObservableObject {
    @Published var medications: [Medication] = []
    private let key = "medications_v1"

    init() { load() }

    func add(_ m: Medication) { medications.append(m); save() }

    func update(_ m: Medication) {
        if let i = medications.firstIndex(where: { $0.id == m.id }) {
            medications[i] = m; save()
        }
    }

    func delete(_ m: Medication) {
        medications.removeAll { $0.id == m.id }; save()
    }

    func save() {
        if let d = try? JSONEncoder().encode(medications) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }

    private func load() {
        guard let d = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Medication].self, from: d) else { return }
        medications = decoded
    }
}

// MARK: - Main View

struct MedicationTrackerView: View {
    @StateObject private var engine = MedicationEngine()
    @State private var showAdd = false
    @State private var editItem: Medication?
    @State private var showNotes = false

    private var criticalCount: Int { medications.filter { $0.daysOnHand < 7 }.count }
    private var medications: [Medication] { engine.medications.sorted { $0.daysOnHand < $1.daysOnHand } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Medication Tracker")
                            .font(.title2.bold())
                        Text("Track days on hand · Plan for disasters")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if criticalCount > 0 {
                        Label("\(criticalCount) critical", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.red.opacity(0.1), in: Capsule())
                    }
                    Button { showAdd = true } label: {
                        Label("Add Medication", systemImage: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if engine.medications.isEmpty {
                    EmptyMedState { showAdd = true }
                } else {
                    // Summary bar
                    MedSummaryBar(medications: medications)

                    // Medication list
                    VStack(spacing: 8) {
                        ForEach(medications) { med in
                            MedCard(med: med, onEdit: { editItem = med }, onDelete: { engine.delete(med) })
                        }
                    }
                }

                // Guidance card
                MedGuidanceCard()
            }
            .padding(20)
        }
        .sheet(isPresented: $showAdd) {
            MedicationSheet(med: Medication()) { engine.add($0) }
        }
        .sheet(item: $editItem) { med in
            MedicationSheet(med: med) { engine.update($0) }
        }
    }
}

// MARK: - Summary Bar

private struct MedSummaryBar: View {
    let medications: [Medication]

    private var byStatus: (critical: Int, low: Int, ok: Int) {
        let c = medications.filter { $0.daysOnHand < 7 }.count
        let l = medications.filter { $0.daysOnHand >= 7 && $0.daysOnHand < 30 }.count
        let o = medications.filter { $0.daysOnHand >= 30 }.count
        return (c, l, o)
    }

    var body: some View {
        HStack(spacing: 14) {
            MedStatBox(label: "Total meds",  value: "\(medications.count)",  color: .primary)
            MedStatBox(label: "Critical (<7 days)", value: "\(byStatus.critical)", color: .red)
            MedStatBox(label: "Low (<30 days)",     value: "\(byStatus.low)",      color: .orange)
            MedStatBox(label: "Stocked (30+ days)", value: "\(byStatus.ok)",       color: .green)
        }
    }
}

private struct MedStatBox: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Medication Card

private struct MedCard: View {
    let med: Medication
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            // Status pill
            VStack(spacing: 4) {
                Text("\(med.daysOnHand)")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(med.statusColor)
                Text("days")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50)
            .padding(.vertical, 8)
            .background(med.statusColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(med.name.isEmpty ? "Unnamed medication" : med.name)
                    .font(.system(size: 14, weight: .semibold))
                HStack(spacing: 8) {
                    if !med.dose.isEmpty {
                        Text(med.dose).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    if !med.frequency.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(med.frequency).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    Text(med.statusLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(med.statusColor)
                    if let refill = med.refillDate {
                        Text("·").foregroundStyle(.tertiary)
                        Text("Refill: \(refill.formatted(.dateTime.month().day().year()))")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    if !med.prescriber.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(med.prescriber).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil").font(.system(size: 13))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)

                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash").font(.system(size: 13))
                }
                .buttonStyle(.plain).foregroundStyle(.red.opacity(0.7))
                .confirmationDialog("Delete \(med.name)?", isPresented: $showDeleteConfirm) {
                    Button("Delete", role: .destructive) { onDelete() }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(med.statusColor.opacity(med.daysOnHand < 7 ? 0.5 : 0.15), lineWidth: 1)
        )
    }
}

// MARK: - Guidance Card

private struct MedGuidanceCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill").font(.system(size: 13)).foregroundStyle(.yellow)
                Text("Emergency Preparedness Tips").font(.system(size: 13, weight: .semibold))
            }
            Divider()
            VStack(alignment: .leading, spacing: 7) {
                GuidanceRow(text: "Ask your doctor or pharmacist for a 90-day supply — many insurers allow this once per year.")
                GuidanceRow(text: "Keep a 30-day minimum supply goal. FEMA recommends 30+ days for special needs individuals.")
                GuidanceRow(text: "Store medications in a cool, dry place — most degrade in heat and humidity (not the bathroom).")
                GuidanceRow(text: "Keep a written list in your go-bag and wallet: medication name, dose, prescriber, and pharmacy contact.")
                GuidanceRow(text: "For refrigerated medications (insulin, etc.): a medication cooler maintains 2–8°C for 24–48 hours.")
                GuidanceRow(text: "Contact your state's emergency pharmacy program before a disaster — many have stockpile mechanisms.")
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.2), lineWidth: 1))
    }
}

private struct GuidanceRow: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundStyle(.green).padding(.top, 1)
            Text(text).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Empty State

private struct EmptyMedState: View {
    let onAdd: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "pills.fill")
                .font(.system(size: 36))
                .foregroundStyle(.red.opacity(0.5))
            Text("No medications tracked")
                .font(.headline)
            Text("Track critical medications and how many days you have on hand. Get alerted when supplies run low.")
                .font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 360)
            Button("Add Medication", action: onAdd)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Add / Edit Sheet

struct MedicationSheet: View {
    @State var med: Medication
    let onSave: (Medication) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var hasRefillDate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(med.name.isEmpty ? "Add Medication" : "Edit Medication")
                .font(.headline).padding(.horizontal)

            Form {
                Section("Medication") {
                    TextField("Name (e.g. Metformin 500mg)", text: $med.name)
                    TextField("Dose (e.g. 500mg)", text: $med.dose)
                    TextField("Frequency (e.g. twice daily)", text: $med.frequency)
                }
                Section("Supply") {
                    Stepper("Days on hand: \(med.daysOnHand)", value: $med.daysOnHand, in: 0...365)
                    Toggle("Track refill date", isOn: $hasRefillDate)
                    if hasRefillDate {
                        DatePicker("Refill date", selection: Binding(
                            get: { med.refillDate ?? Date() },
                            set: { med.refillDate = $0 }
                        ), displayedComponents: .date)
                    }
                }
                Section("Details") {
                    TextField("Prescriber / Doctor", text: $med.prescriber)
                    TextField("Notes", text: $med.notes)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(med); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .disabled(med.name.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .frame(minWidth: 460, minHeight: 420)
        .onAppear { hasRefillDate = med.refillDate != nil }
    }
}
