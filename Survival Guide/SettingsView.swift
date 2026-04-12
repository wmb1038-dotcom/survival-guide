import SwiftUI
import Combine
import UserNotifications

// MARK: - App Settings Model

struct AppSettings: Codable {
    var preferredOllamaModel   : String  = ""          // empty = auto-detect
    var libraryBasePath        : String  = "/Volumes/20TB_HDD/offline-library"
    var waterRotationMonths    : Int     = 6
    var generatorTestMonths    : Int     = 1
    var dailyCaloriesAdult     : Double  = 2000
    var dailyCaloriesChild     : Double  = 1500
    var notifyFoodExpiration   : Bool    = true
    var notifyWaterRotation    : Bool    = true
    var notifyGeneratorTest    : Bool    = true
    var notifyMedications      : Bool    = true
    var notifyDrills           : Bool    = true
    var enableWebServer        : Bool    = false
    var webServerPort          : UInt16  = 8080
}

@MainActor
class AppSettingsStore: ObservableObject {
    static let shared = AppSettingsStore()
    private let key   = "app_settings_v1"

    @Published var settings = AppSettings()

    init() { load() }

    func save() {
        if let d = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(d, forKey: key) }
    }
    private func load() {
        guard let d = UserDefaults.standard.data(forKey: key),
              let v = try? JSONDecoder().decode(AppSettings.self, from: d) else { return }
        settings = v
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @StateObject private var store       = AppSettingsStore.shared
    @StateObject private var notifMgr    = NotificationManager.shared
    @StateObject private var mapManager  = OfflineMapManager.shared
    @EnvironmentObject private var locationStore: LocationStore
    @EnvironmentObject private var supplyEngine : SupplyEngine

    @State private var availableModels  : [String]  = []
    @State private var ollamaStatus     : String     = "Checking…"
    @State private var isGenerating     : Bool       = false
    @State private var generatorLog     : [String]   = []
    @State private var showResetConfirm : Bool       = false
    @State private var showResetWizard  : Bool       = false
    @State private var showCustomRegion : Bool       = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                settingsHeader

                locationSection
                ollamaSection
                offlineMapsSection
                webServerSection
                notificationsSection
                calorieSection
                dataSection
            }
            .padding(24)
        }
        .task {
            await checkOllama()
            await notifMgr.refreshStatus()
        }
        .alert("Reset All Data?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Reset Everything", role: .destructive) { resetAllData() }
        } message: {
            Text("This will erase all supplies, food items, medications, drills, outage logs, seeds, water sources, and skill progress. This cannot be undone.")
        }
    }

    // MARK: - Header

    private var settingsHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text("Settings").font(.system(size: 22, weight: .bold))
                Text("App configuration and maintenance")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Location & Wizard

    private var locationSection: some View {
        SettingsCard(title: "Location & Setup", symbol: "location.fill", color: .orange) {
            VStack(alignment: .leading, spacing: 12) {
                let cfg = locationStore.config
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(cfg.displayName.isEmpty ? "Not configured" : cfg.displayName)
                            .font(.system(size: 14, weight: .semibold))
                        Text(cfg.regionTypes.map(\.rawValue).joined(separator: " · "))
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        if !cfg.hazards.isEmpty {
                            Text(cfg.hazards.map(\.rawValue).joined(separator: ", "))
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Button("Re-run Wizard") { showResetWizard = true }
                        .buttonStyle(.bordered)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Regenerate AI Survival Guides")
                            .font(.system(size: 13, weight: .medium))
                        Text("Re-runs Ollama generation for your current location")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isGenerating {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Button("Regenerate") { Task { await regenerateGuides() } }
                            .buttonStyle(.bordered)
                    }
                }

                if !generatorLog.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(generatorLog.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(line.hasPrefix("✓") ? .green :
                                                     line.hasPrefix("✗") ? .red : .secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    }
                    .frame(height: 100)
                    .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .alert("Re-run Setup Wizard?", isPresented: $showResetWizard) {
            Button("Cancel", role: .cancel) { }
            Button("Re-run Wizard", role: .destructive) {
                var cfg = locationStore.config
                cfg.isConfigured = false
                locationStore.save(cfg)
            }
        } message: {
            Text("This will return to the setup wizard. Your existing data will be preserved.")
        }
    }

    // MARK: - Ollama

    private var ollamaSection: some View {
        SettingsCard(title: "AI / Ollama", symbol: "cpu", color: .purple) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(ollamaStatus == "Connected" ? Color.green : .red)
                        .frame(width: 8, height: 8)
                    Text(ollamaStatus)
                        .font(.system(size: 12))
                        .foregroundStyle(ollamaStatus == "Connected" ? .green : .red)
                    Spacer()
                    Button("Refresh") { Task { await checkOllama() } }
                        .buttonStyle(.bordered).font(.system(size: 11))
                }

                if !availableModels.isEmpty {
                    HStack {
                        Text("Preferred Model")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $store.settings.preferredOllamaModel) {
                            Text("Auto-detect").tag("")
                            ForEach(availableModels, id: \.self) { Text($0).tag($0) }
                        }
                        .frame(width: 200)
                        .onChange(of: store.settings.preferredOllamaModel) { _, _ in store.save() }
                    }
                }

                Text("Model is used for AI chat and survival guide generation. Auto-detect picks the best available model.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Offline Maps

    private var offlineMapsSection: some View {
        SettingsCard(title: "Offline Maps", symbol: "map.fill", color: .teal) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Download map tiles to your 20TB HDD for fully offline use in the Water Sources map. Tiles are stored at /Volumes/20TB_HDD/offline-library/offline-maps/")
                    .font(.system(size: 11)).foregroundStyle(.secondary)

                // Active download progress
                if mapManager.isDownloading {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(mapManager.activeRegionName)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text(String(format: "%.0f tiles/s", mapManager.tilesPerSec))
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                            Button("Cancel") { mapManager.cancelDownload() }
                                .buttonStyle(.bordered).tint(.red)
                                .font(.system(size: 11))
                        }
                        ProgressView(value: mapManager.downloadProgress) {
                            Text(String(format: "%d / %d tiles  (%.1f%%)",
                                        mapManager.downloadedTiles,
                                        mapManager.totalTiles,
                                        mapManager.downloadProgress * 100))
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        .progressViewStyle(.linear)

                        if !mapManager.log.isEmpty {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 1) {
                                    ForEach(Array(mapManager.log.enumerated()), id: \.offset) { _, line in
                                        Text(line)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(line.hasPrefix("✓") ? .green :
                                                             line.hasPrefix("✗") ? .red : .secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(6)
                            }
                            .frame(height: 80)
                            .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(10)
                    .background(Color.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

                    Divider()
                }

                // Region list
                VStack(spacing: 6) {
                    ForEach(mapManager.regions) { region in
                        OfflineMapRegionRow(
                            region: region,
                            isDownloaded: mapManager.isDownloaded(region),
                            diskUsage: mapManager.isDownloaded(region) ? mapManager.diskUsage(region) : nil,
                            isActiveDownload: mapManager.isDownloading && mapManager.activeRegionName == region.name,
                            canDownload: !mapManager.isDownloading,
                            onDownload: { mapManager.startDownload(region) },
                            onDelete: { mapManager.deleteRegion(region) }
                        )
                    }
                }

                HStack {
                    Spacer()
                    Button("Add Custom Region…") { showCustomRegion = true }
                        .buttonStyle(.bordered)
                        .font(.system(size: 12))
                }
            }
        }
        .sheet(isPresented: $showCustomRegion) {
            CustomRegionSheet { mapManager.addCustomRegion($0) }
        }
    }

    // MARK: - Web Server

    private var webServerSection: some View {
        let server = LocalWebServer.shared
        return SettingsCard(title: "Network Dashboard", symbol: "network", color: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Serve a live read-only status dashboard to any phone or computer on your local network. Shows water/food days, power status, expiring items, drills, and a link to the offline library.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)

                HStack {
                    Toggle("Enable on LAN", isOn: $store.settings.enableWebServer)
                        .font(.system(size: 13))
                        .toggleStyle(.switch)
                        .onChange(of: store.settings.enableWebServer) { _, enabled in
                            store.save()
                            if enabled { server.start(port: store.settings.webServerPort) }
                            else        { server.stop() }
                        }
                }

                if store.settings.enableWebServer {
                    HStack {
                        Text("Port").font(.system(size: 13))
                        Spacer()
                        TextField("8080", value: $store.settings.webServerPort, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .onChange(of: store.settings.webServerPort) { _, _ in
                                store.save()
                                if server.isRunning {
                                    server.stop()
                                    server.start(port: store.settings.webServerPort)
                                }
                            }
                    }
                }

                if server.isRunning {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Circle().fill(.green).frame(width: 8, height: 8)
                            Text("Running")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.green)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("By IP (always works)")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                            Text(server.localURL)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.blue)
                                .textSelection(.enabled)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("By name (Apple devices & Windows 10+)")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                            Text(server.bonjourURL)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.cyan)
                                .textSelection(.enabled)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 2) {
                            Text("To shorten the name address:")
                                .font(.system(size: 11, weight: .semibold))
                            Text("System Settings → General → Sharing → Local Hostname")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text("Set it to a single word like 'home' or 'base' and this becomes http://home.local:8080")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }

                        Text("Dashboard auto-refreshes every 60 s · Append /api/status for JSON")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        SettingsCard(title: "Notifications", symbol: "bell.fill", color: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(notifMgr.authStatus == .authorized ? "Notifications: Enabled" : "Notifications: Disabled")
                        .font(.system(size: 13))
                        .foregroundStyle(notifMgr.authStatus == .authorized ? .green : .red)
                    Spacer()
                    if notifMgr.authStatus != .authorized {
                        Button("Enable") { Task { await notifMgr.requestPermission() } }
                            .buttonStyle(.borderedProminent).tint(.blue)
                            .font(.system(size: 11))
                    }
                }

                Divider()

                Group {
                    SettingsToggle("Food Expiration Alerts", isOn: $store.settings.notifyFoodExpiration)
                    SettingsToggle("Water Rotation Reminder", isOn: $store.settings.notifyWaterRotation)
                    SettingsToggle("Generator Test Reminder", isOn: $store.settings.notifyGeneratorTest)
                    SettingsToggle("Medication Refill Reminders", isOn: $store.settings.notifyMedications)
                    SettingsToggle("Drill Reminders", isOn: $store.settings.notifyDrills)
                }
                .onChange(of: store.settings.notifyFoodExpiration)   { _, _ in store.save() }
                .onChange(of: store.settings.notifyWaterRotation)    { _, _ in store.save() }
                .onChange(of: store.settings.notifyGeneratorTest)    { _, _ in store.save() }
                .onChange(of: store.settings.notifyMedications)      { _, _ in store.save() }
                .onChange(of: store.settings.notifyDrills)           { _, _ in store.save() }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Water Rotation Interval")
                            .font(.system(size: 13))
                        Text("Reminder to empty and refill stored water")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Stepper("\(store.settings.waterRotationMonths) months",
                            value: $store.settings.waterRotationMonths, in: 1...12)
                        .onChange(of: store.settings.waterRotationMonths) { _, _ in store.save() }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Generator Test Interval")
                            .font(.system(size: 13))
                        Text("Reminder to run generator under load")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Stepper("\(store.settings.generatorTestMonths) month\(store.settings.generatorTestMonths == 1 ? "" : "s")",
                            value: $store.settings.generatorTestMonths, in: 1...6)
                        .onChange(of: store.settings.generatorTestMonths) { _, _ in store.save() }
                }
            }
        }
    }

    // MARK: - Calorie Defaults

    private var calorieSection: some View {
        SettingsCard(title: "Calorie Targets", symbol: "flame.fill", color: .orange) {
            VStack(spacing: 10) {
                HStack {
                    Text("Adult (per day)")
                        .font(.system(size: 13))
                    Spacer()
                    TextField("2000", value: $store.settings.dailyCaloriesAdult, format: .number)
                        .multilineTextAlignment(.trailing).frame(width: 80)
                        .onChange(of: store.settings.dailyCaloriesAdult) { _, _ in store.save() }
                    Text("cal").foregroundStyle(.secondary).font(.system(size: 12))
                }
                HStack {
                    Text("Child (per day)")
                        .font(.system(size: 13))
                    Spacer()
                    TextField("1500", value: $store.settings.dailyCaloriesChild, format: .number)
                        .multilineTextAlignment(.trailing).frame(width: 80)
                        .onChange(of: store.settings.dailyCaloriesChild) { _, _ in store.save() }
                    Text("cal").foregroundStyle(.secondary).font(.system(size: 12))
                }
                Text("Used to calculate days-of-supply in the Food Rotation tracker.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Data Management

    private var dataSection: some View {
        SettingsCard(title: "Data Management", symbol: "externaldrive.fill", color: .red) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Offline Library Path")
                            .font(.system(size: 13, weight: .medium))
                        Text(store.settings.libraryBasePath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("To change, edit `libraryBasePath` in OfflineLibraryApp.swift and rebuild.")
                            .font(.system(size: 10)).foregroundStyle(.secondary.opacity(0.7))
                    }
                    Spacer()
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clear All Pending Notifications")
                            .font(.system(size: 13))
                        Text("Removes all scheduled alerts")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Clear") { NotificationManager.shared.cancelAll() }
                        .buttonStyle(.bordered)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset All App Data")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.red)
                        Text("Erases supplies, food, medications, drills, outages, seeds, water sources, skills")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Reset…") { showResetConfirm = true }
                        .buttonStyle(.bordered)
                        .tint(.red)
                }
            }
        }
    }

    // MARK: - Actions

    private func checkOllama() async {
        let available = await OllamaClient.isAvailable()
        if available {
            availableModels = await OllamaClient.availableModels()
            ollamaStatus = "Connected — \(availableModels.count) model\(availableModels.count == 1 ? "" : "s") available"
        } else {
            ollamaStatus = "Not reachable (localhost:11434)"
            availableModels = []
        }
    }

    private func regenerateGuides() async {
        guard !isGenerating else { return }
        isGenerating = true
        generatorLog = []
        let gen = SurvivalGuideGenerator()
        // Mirror log into local state
        let task = Task {
            await gen.generate(config: locationStore.config)
        }
        // Poll for log updates
        while !gen.isComplete {
            generatorLog = gen.log.map(\.text)
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        await task.value
        generatorLog = gen.log.map(\.text)
        isGenerating = false
    }

    private func resetAllData() {
        let keys = ["supply_items_v1", "household_v1", "food_rotation_v1",
                    "medications_v1", "drills_v1", "outage_events_v1",
                    "fuel_log_v1", "battery_log_v1", "seeds_v1",
                    "garden_beds_v1", "water_sources_v1", "skills_v1",
                    "quick_ref_cards_v1", "checklist_completed_v1",
                    "documents_vault_v1"]          // legacy plaintext migration remnant
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        VaultEngine().deleteAll()                  // wipe Keychain vault
        NotificationManager.shared.cancelAll()
    }
}

// MARK: - Reusable Components

private struct SettingsCard<Content: View>: View {
    let title: String
    let symbol: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            content()
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08)))
    }
}

private struct SettingsToggle: View {
    let label: String
    @Binding var isOn: Bool
    init(_ label: String, isOn: Binding<Bool>) { self.label = label; _isOn = isOn }
    var body: some View {
        Toggle(label, isOn: $isOn)
            .font(.system(size: 13))
            .toggleStyle(.switch)
    }
}

// MARK: - Offline Map Region Row

private struct OfflineMapRegionRow: View {
    let region          : OfflineMapRegion
    let isDownloaded    : Bool
    let diskUsage       : String?
    let isActiveDownload: Bool
    let canDownload     : Bool
    let onDownload      : () -> Void
    let onDelete        : () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isDownloaded ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(isDownloaded ? .green : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(region.name)
                    .font(.system(size: 12, weight: .medium))
                HStack(spacing: 6) {
                    Text("Zoom \(region.minZoom)–\(region.maxZoom)")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Text("·")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Text("~\(String(format: "%.1f GB", region.estimatedGB)) est.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    if let usage = diskUsage {
                        Text("·")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                        Text(usage + " on disk")
                            .font(.system(size: 10)).foregroundStyle(.green)
                    }
                    Text(region.source.rawValue)
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isActiveDownload {
                ProgressView().scaleEffect(0.6)
            } else if isDownloaded {
                Button("Delete") { onDelete() }
                    .buttonStyle(.bordered).tint(.red)
                    .font(.system(size: 11))
            } else {
                Button("Download") { onDownload() }
                    .buttonStyle(.bordered).tint(.teal)
                    .font(.system(size: 11))
                    .disabled(!canDownload)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Custom Region Sheet

private struct CustomRegionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (OfflineMapRegion) -> Void

    @State private var name    = ""
    @State private var minLat  = ""
    @State private var maxLat  = ""
    @State private var minLon  = ""
    @State private var maxLon  = ""
    @State private var minZoom = 8
    @State private var maxZoom = 16
    @State private var source  = TileSource.osm

    private var region: OfflineMapRegion? {
        guard !name.isEmpty,
              let mnLat = Double(minLat), let mxLat = Double(maxLat),
              let mnLon = Double(minLon), let mxLon = Double(maxLon),
              mnLat < mxLat, mnLon < mxLon else { return nil }
        return OfflineMapRegion(name: name,
                                minLat: mnLat, maxLat: mxLat,
                                minLon: mnLon, maxLon: mxLon,
                                minZoom: minZoom, maxZoom: maxZoom,
                                source: source)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Custom Region").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") {
                    if let r = region { onSave(r); dismiss() }
                }
                .buttonStyle(.borderedProminent).tint(.teal)
                .disabled(region == nil)
            }.padding()
            Divider()
            Form {
                Section("Name") {
                    TextField("e.g. My County, CA", text: $name)
                }
                Section("Bounding Box (decimal degrees)") {
                    HStack {
                        Text("Min Latitude");  Spacer()
                        TextField("e.g. 21.20", text: $minLat).frame(width: 120).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Max Latitude");  Spacer()
                        TextField("e.g. 21.78", text: $maxLat).frame(width: 120).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Min Longitude"); Spacer()
                        TextField("e.g. -158.35", text: $minLon).frame(width: 120).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Max Longitude"); Spacer()
                        TextField("e.g. -157.60", text: $maxLon).frame(width: 120).multilineTextAlignment(.trailing)
                    }
                }
                Section("Options") {
                    HStack {
                        Text("Min Zoom"); Spacer()
                        Stepper("\(minZoom)", value: $minZoom, in: 1...18)
                    }
                    HStack {
                        Text("Max Zoom"); Spacer()
                        Stepper("\(maxZoom)", value: $maxZoom, in: minZoom...18)
                    }
                    Picker("Tile Source", selection: $source) {
                        ForEach(TileSource.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                if let r = region {
                    Section("Estimate") {
                        Text("~\(r.estimatedTileCount) tiles · ~\(String(format: "%.1f GB", r.estimatedGB))")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 440, minHeight: 480)
    }
}
