import SwiftUI
import Combine

struct ResilienceStatus: Codable {
    var status: String = "GREEN"
    var label: String = ""
    var details: String = ""
    var hoverText: String = ""

    enum CodingKeys: String, CodingKey {
        case status, label, details
        case hoverText = "hover_text"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "GREEN"
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? "Alert"
        
        let rawHover = try container.decodeIfPresent(String.self, forKey: .hoverText) ?? ""
        let rawDetails = try container.decodeIfPresent(String.self, forKey: .details) ?? ""
        
        // If details are missing, use the first line of the breakdown
        if rawDetails.isEmpty || rawDetails == "Status normal" {
            details = rawHover.components(separatedBy: "\n").first?.replacingOccurrences(of: "• ", with: "") ?? "Active monitoring"
        } else {
            details = rawDetails
        }
        
        hoverText = rawHover.isEmpty ? details : rawHover
    }
    
    init(status: String = "GREEN", label: String = "", details: String = "", hoverText: String = "") {
        self.status = status
        self.label = label
        self.details = details
        self.hoverText = hoverText
    }

    var color: Color {
        switch status.uppercased() {
        case "RED": return .red
        case "YELLOW": return .yellow
        case "GREEN": return .green
        default: return .secondary
        }
    }
}

struct ResilienceState: Codable {
    var city: String = ""
    var timestamp: String = ""
    var weather: ResilienceStatus = ResilienceStatus(label: "Weather")
    var geological: ResilienceStatus = ResilienceStatus(label: "Geological")
    var logistics: ResilienceStatus = ResilienceStatus(label: "Logistics")
    var resources: ResilienceStatus = ResilienceStatus(label: "Resources")
}

@MainActor
class ResilienceEngine: ObservableObject {
    static let shared = ResilienceEngine()
    private let key = "resilience_state_v5"
    
    @Published var state = ResilienceState()
    
    init() { load() }
    
    func update(from json: Data) {
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode(ResilienceState.self, from: json) {
            self.state = decoded
            save()
        } else if let obj = try? JSONSerialization.jsonObject(with: json) as? [String: Any] {
            parseGeminiStructure(obj)
        }
    }
    
    private func parseGeminiStructure(_ obj: [String: Any]) {
        let lights = (obj["STOPLIGHTS"] as? [String: Any]) ?? obj
        
        var newState = ResilienceState()
        newState.timestamp = obj["TIMESTAMP"] as? String ?? ""
        newState.city = obj["CITY"] as? String ?? ""
        
        func map(_ key: String) -> ResilienceStatus {
            guard let dict = (lights[key.uppercased()] ?? lights[key.lowercased()]) as? [String: Any],
                  let data = try? JSONSerialization.data(withJSONObject: dict),
                  let status = try? JSONDecoder().decode(ResilienceStatus.self, from: data) else {
                return ResilienceStatus(label: key.capitalized, details: "Awaiting Data")
            }
            return status
        }
        
        newState.weather = map("WEATHER")
        newState.geological = map("GEOLOGICAL")
        newState.logistics = map("LOGISTICS")
        newState.resources = map("RESOURCES")
        
        self.state = newState
        save()
    }
    
    func save() {
        if let d = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }
    
    private func load() {
        guard let d = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ResilienceState.self, from: d) else { return }
        self.state = decoded
    }
}
