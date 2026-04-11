import SwiftUI

@main
struct Survival_GuideApp: App {
    @StateObject private var locationStore = LocationStore.shared
    @StateObject private var supplyEngine = SupplyEngine()

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
        }
        .windowStyle(.titleBar)
    }
}
