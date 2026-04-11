import SwiftUI
import Combine

// MARK: - Models

struct EmergencyContact: Codable, Identifiable {
    var id = UUID()
    var name: String = ""
    var role: String = ""
    var phone: String = ""
    var notes: String = ""
}

struct MeetingPoint: Codable, Identifiable {
    var id = UUID()
    var label: String = ""
    var address: String = ""
    var description: String = ""
    var scenario: String = "Any emergency"
}

struct FamilyMember: Codable, Identifiable {
    var id = UUID()
    var name: String = ""
    var phone: String = ""
    var daytimeLocation: String = ""    // school, work address
    var notes: String = ""
}

struct EmergencyPlan: Codable {
    var members: [FamilyMember] = []
    var contacts: [EmergencyContact] = []
    var meetingPoints: [MeetingPoint] = []
    var outOfStateContact: String = ""
    var outOfStatePhone: String = ""
    var notes: String = ""
}

// MARK: - Engine

@MainActor
class EmergencyPlanEngine: ObservableObject {
    @Published var plan = EmergencyPlan()
    private let key = "emergency_plan_v1"
    static let shared = EmergencyPlanEngine()

    init() { load() }

    func save() {
        if let d = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }

    private func load() {
        guard let d = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(EmergencyPlan.self, from: d) else { return }
        plan = decoded
    }
}

// MARK: - Main View

struct EmergencyPlanView: View {
    @StateObject private var engine = EmergencyPlanEngine.shared
    @State private var selectedTab = "Family"
    @State private var showAddMember = false
    @State private var showAddContact = false
    @State private var showAddPoint = false
    @State private var editMember: FamilyMember?
    @State private var editContact: EmergencyContact?
    @State private var editPoint: MeetingPoint?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Family Emergency Plan")
                            .font(.title2.bold())
                        Text("Keep updated — print a copy and store it offline")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        // Placeholder for future print/export
                    } label: {
                        Label("Print / Export", systemImage: "printer.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }

                Picker("Tab", selection: $selectedTab) {
                    Text("Family").tag("Family")
                    Text("Contacts").tag("Contacts")
                    Text("Meet Points").tag("Meet Points")
                    Text("Notes").tag("Notes")
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case "Family":     FamilyTab(engine: engine, showAdd: $showAddMember, editItem: $editMember)
                case "Contacts":   ContactsTab(engine: engine, showAdd: $showAddContact, editItem: $editContact)
                case "Meet Points":MeetPointsTab(engine: engine, showAdd: $showAddPoint, editItem: $editPoint)
                default:           NotesTab(engine: engine)
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showAddMember) {
            FamilyMemberSheet(member: FamilyMember()) { m in
                engine.plan.members.append(m); engine.save()
            }
        }
        .sheet(isPresented: $showAddContact) {
            ContactSheet(contact: EmergencyContact()) { c in
                engine.plan.contacts.append(c); engine.save()
            }
        }
        .sheet(isPresented: $showAddPoint) {
            MeetingPointSheet(point: MeetingPoint()) { p in
                engine.plan.meetingPoints.append(p); engine.save()
            }
        }
        .sheet(item: $editMember) { m in
            FamilyMemberSheet(member: m) { updated in
                if let i = engine.plan.members.firstIndex(where: { $0.id == updated.id }) {
                    engine.plan.members[i] = updated; engine.save()
                }
            }
        }
        .sheet(item: $editContact) { c in
            ContactSheet(contact: c) { updated in
                if let i = engine.plan.contacts.firstIndex(where: { $0.id == updated.id }) {
                    engine.plan.contacts[i] = updated; engine.save()
                }
            }
        }
        .sheet(item: $editPoint) { p in
            MeetingPointSheet(point: p) { updated in
                if let i = engine.plan.meetingPoints.firstIndex(where: { $0.id == updated.id }) {
                    engine.plan.meetingPoints[i] = updated; engine.save()
                }
            }
        }
    }
}

// MARK: - Family Tab

private struct FamilyTab: View {
    @ObservedObject var engine: EmergencyPlanEngine
    @Binding var showAdd: Bool
    @Binding var editItem: FamilyMember?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Out-of-state contact
            PlanCard(title: "Out-of-State Contact", symbol: "phone.arrow.up.right.fill", color: .green) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("After a disaster, local lines may be jammed. A single out-of-state contact can relay messages between separated family members.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        PlanField(label: "Name", placeholder: "Contact name",
                                  text: Binding(get: { engine.plan.outOfStateContact },
                                                set: { engine.plan.outOfStateContact = $0; engine.save() }))
                        PlanField(label: "Phone", placeholder: "(555) 555-5555",
                                  text: Binding(get: { engine.plan.outOfStatePhone },
                                                set: { engine.plan.outOfStatePhone = $0; engine.save() }))
                    }
                }
            }

            // Family members
            PlanCard(title: "Family Members", symbol: "person.3.fill", color: .blue) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(engine.plan.members) { m in
                        MemberRow(member: m) {
                            editItem = m
                        } onDelete: {
                            engine.plan.members.removeAll { $0.id == m.id }
                            engine.save()
                        }
                    }
                    if engine.plan.members.isEmpty {
                        Text("Add each family member — name, cell, and where they are during the day.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Button { showAdd = true } label: {
                        Label("Add Family Member", systemImage: "plus.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }
        }
    }
}

private struct MemberRow: View {
    let member: FamilyMember
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.fill")
                .font(.system(size: 14))
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name.isEmpty ? "Unnamed" : member.name)
                    .font(.system(size: 13, weight: .semibold))
                if !member.phone.isEmpty {
                    Text(member.phone)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if !member.daytimeLocation.isEmpty {
                    Text(member.daytimeLocation)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: onEdit) { Image(systemName: "pencil").font(.system(size: 12)) }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            Button(action: onDelete) { Image(systemName: "trash").font(.system(size: 12)) }
                .buttonStyle(.plain).foregroundStyle(.red.opacity(0.7))
        }
        .padding(8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Contacts Tab

private struct ContactsTab: View {
    @ObservedObject var engine: EmergencyPlanEngine
    @Binding var showAdd: Bool
    @Binding var editItem: EmergencyContact?

    var body: some View {
        PlanCard(title: "Emergency Contacts", symbol: "phone.fill", color: .red) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(engine.plan.contacts) { c in
                    ContactRow(contact: c) {
                        editItem = c
                    } onDelete: {
                        engine.plan.contacts.removeAll { $0.id == c.id }
                        engine.save()
                    }
                }
                if engine.plan.contacts.isEmpty {
                    Text("Add neighbors, doctors, local emergency coordinators, and other key contacts.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Button { showAdd = true } label: {
                    Label("Add Contact", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain).foregroundStyle(.red)
            }
        }
    }
}

private struct ContactRow: View {
    let contact: EmergencyContact
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.red.opacity(0.8))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(contact.name.isEmpty ? "Unnamed" : contact.name)
                        .font(.system(size: 13, weight: .semibold))
                    if !contact.role.isEmpty {
                        Text(contact.role)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }
                Text(contact.phone.isEmpty ? "No phone" : contact.phone)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                if !contact.notes.isEmpty {
                    Text(contact.notes).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button(action: onEdit) { Image(systemName: "pencil").font(.system(size: 12)) }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            Button(action: onDelete) { Image(systemName: "trash").font(.system(size: 12)) }
                .buttonStyle(.plain).foregroundStyle(.red.opacity(0.7))
        }
        .padding(8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Meeting Points Tab

private struct MeetPointsTab: View {
    @ObservedObject var engine: EmergencyPlanEngine
    @Binding var showAdd: Bool
    @Binding var editItem: MeetingPoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InfoBannerPlan(
                symbol: "info.circle", color: .orange,
                text: "Have two meeting points: one near home (house fire), one outside the neighborhood (large disaster). Everyone must know both."
            )
            PlanCard(title: "Meeting Points", symbol: "mappin.circle.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(engine.plan.meetingPoints) { p in
                        MeetPointRow(point: p) {
                            editItem = p
                        } onDelete: {
                            engine.plan.meetingPoints.removeAll { $0.id == p.id }
                            engine.save()
                        }
                    }
                    if engine.plan.meetingPoints.isEmpty {
                        Text("No meeting points set. Add at least two.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Button { showAdd = true } label: {
                        Label("Add Meeting Point", systemImage: "plus.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain).foregroundStyle(.orange)
                }
            }
        }
    }
}

private struct MeetPointRow: View {
    let point: MeetingPoint
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(point.label.isEmpty ? "Unnamed" : point.label)
                    .font(.system(size: 13, weight: .semibold))
                if !point.address.isEmpty {
                    Text(point.address)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if !point.scenario.isEmpty {
                    Text(point.scenario)
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                if !point.description.isEmpty {
                    Text(point.description)
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button(action: onEdit) { Image(systemName: "pencil").font(.system(size: 12)) }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            Button(action: onDelete) { Image(systemName: "trash").font(.system(size: 12)) }
                .buttonStyle(.plain).foregroundStyle(.red.opacity(0.7))
        }
        .padding(8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Notes Tab

private struct NotesTab: View {
    @ObservedObject var engine: EmergencyPlanEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InfoBannerPlan(symbol: "lightbulb.fill", color: .yellow,
                           text: "Include: insurance policy numbers, utility shutoff locations, pet info, medical conditions, vehicle descriptions and plates.")
            PlanCard(title: "Plan Notes", symbol: "note.text", color: .purple) {
                TextEditor(text: Binding(
                    get: { engine.plan.notes },
                    set: { engine.plan.notes = $0; engine.save() }
                ))
                .font(.system(size: 13))
                .frame(minHeight: 200)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

// MARK: - Sheets

struct FamilyMemberSheet: View {
    @State var member: FamilyMember
    let onSave: (FamilyMember) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Family Member").font(.headline).padding(.horizontal)
            Form {
                TextField("Full name", text: $member.name)
                TextField("Cell phone", text: $member.phone)
                TextField("School / Work location", text: $member.daytimeLocation)
                TextField("Notes (medical, special needs, etc.)", text: $member.notes)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(member); dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .frame(width: 400)
    }
}

struct ContactSheet: View {
    @State var contact: EmergencyContact
    let onSave: (EmergencyContact) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Emergency Contact").font(.headline).padding(.horizontal)
            Form {
                TextField("Name", text: $contact.name)
                TextField("Role (neighbor, doctor, CERT team, etc.)", text: $contact.role)
                TextField("Phone number", text: $contact.phone)
                TextField("Notes", text: $contact.notes)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(contact); dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .frame(width: 400)
    }
}

struct MeetingPointSheet: View {
    @State var point: MeetingPoint
    let onSave: (MeetingPoint) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meeting Point").font(.headline).padding(.horizontal)
            Form {
                TextField("Label (e.g. Front of Smith Park)", text: $point.label)
                TextField("Full address", text: $point.address)
                TextField("Scenario (house fire, evacuation, etc.)", text: $point.scenario)
                TextField("Landmarks / directions", text: $point.description)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(point); dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .frame(width: 400)
    }
}

// MARK: - Shared Components

struct PlanCard<Content: View>: View {
    let title: String; let symbol: String; let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            Divider()
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

struct PlanField: View {
    let label: String; let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(7)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
        }
    }
}

struct InfoBannerPlan: View {
    let symbol: String; let color: Color; let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color).font(.system(size: 14, weight: .semibold))
            Text(text).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2), lineWidth: 1))
    }
}
