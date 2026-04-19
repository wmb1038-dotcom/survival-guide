import SwiftUI

@main
struct Survival_GuideApp: App {
    @StateObject private var locationStore = LocationStore.shared
    @StateObject private var supplyEngine  = SupplyEngine()

    var body: some Scene {
        WindowGroup {
            Group {
                if locationStore.config.isConfigured {
                    ContentView()
                        .frame(minWidth: 1100, minHeight: 720)
                } else {
                    SetupWizardView(store: locationStore, supplyEngine: supplyEngine)
                        .frame(minWidth: 740, minHeight: 560)
                }
            }
            .environmentObject(locationStore)
            .environmentObject(supplyEngine)
            .task {
                // Auto-start the local web server if it was enabled on last launch
                let settings = AppSettingsStore.shared.settings
                if settings.enableWebServer {
                    print("🌐 Starting Local Web Server on port \(settings.webServerPort)...")
                    LocalWebServer.shared.start(port: settings.webServerPort)
                }
                
                // Start engines
                let _ = MaritimeAwarenessEngine.shared
                let _ = ResilienceEngine.shared
            }
        }
        .windowStyle(.titleBar)
    }
}
