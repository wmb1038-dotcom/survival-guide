import Foundation
import Network
import Combine

class MaritimeAwarenessEngine: ObservableObject {
    static let shared = MaritimeAwarenessEngine()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "MaritimeMonitor")
    
    private var ingestProcess: Process?
    private var dashboardTimer: AnyCancellable?
    
    // Path configuration - Dynamically locate the project root relative to home
    private var projectRoot: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Desktop/Woody's Files/02_Hobbies/Apps/Survival Guide"
    }
    private var pythonPath: String { "\(projectRoot)/.venv/bin/python3" }
    
    @Published var isOnline = false
    @Published var isIngesting = false
    @Published var isGenerating = false
    
    let dashboardUpdated = PassthroughSubject<Void, Never>()
    
    init() {
        print("⚓️ MaritimeAwarenessEngine Initializing...")
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                // WiFi/Ethernet satisfied, excluding cellular
                let online = path.status == .satisfied && !path.usesInterfaceType(.cellular)
                print("⚓️ Network Path Status: \(path.status) (isOnline: \(online))")
                if online != self?.isOnline {
                    self?.isOnline = online
                    self?.handleConnectionChange(online: online)
                }
            }
        }
        monitor.start(queue: queue)
        
        // Safety: Initial check
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if self.isOnline {
                self.startAwareness()
            }
        }
    }
    
    private func handleConnectionChange(online: Bool) {
        if online {
            startAwareness()
        } else {
            stopAwareness()
        }
    }
    
    func startAwareness() {
        print("⚓️ Starting Maritime Awareness...")
        startIngest()
        forceGenerate()
        updateResilience() // Initial update on launch
        
        // Refresh every 5 minutes
        dashboardTimer = Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.forceGenerate()
                self?.updateResilience()
            }
    }
    
    func updateResilience() {
        print("🚦 Updating Situational Resilience Stoplights...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = URL(fileURLWithPath: projectRoot)
        // Run the update script directly
        process.arguments = [pythonPath, "scripts/update_dashboard.py"]
        
        // Run silently in background
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
        } catch {
            print("❌ Failed to trigger resilience update: \(error)")
        }
    }
    
    func stopAwareness() {
        print("⚓️ Stopping Maritime Awareness...")
        stopIngest()
        dashboardTimer?.cancel()
        dashboardTimer = nil
    }
    
    private func startIngest() {
        guard ingestProcess == nil else { return }
        print("⚓️ Launching AIS Ingest...")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = URL(fileURLWithPath: projectRoot)
        process.arguments = [pythonPath, "-m", "awareness.cli", "ingest-ais"]
        process.environment = ["PYTHONPATH": "."]
        
        // Silently capture logs
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            ingestProcess = process
            isIngesting = true
        } catch {
            print("❌ Failed to start ingest: \(error)")
        }
    }
    
    private func stopIngest() {
        ingestProcess?.terminate()
        ingestProcess = nil
        isIngesting = false
    }
    
    func forceGenerate() {
        guard !isGenerating else { return }
        isGenerating = true
        
        print("📊 Generating Unified Dashboard...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = URL(fileURLWithPath: projectRoot)
        process.arguments = [pythonPath, "-m", "awareness.cli", "dashboard"]
        process.environment = ["PYTHONPATH": "."]
        
        process.terminationHandler = { [weak self] _ in
            print("📊 Dashboard Generation Complete")
            DispatchQueue.main.async {
                self?.isGenerating = false
                self?.dashboardUpdated.send()
            }
        }
        
        do {
            try process.run()
        } catch {
            print("❌ Failed to generate dashboard: \(error)")
            isGenerating = false
        }
    }
}
