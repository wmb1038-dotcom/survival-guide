import SwiftUI
import Combine

// MARK: - Enums

enum RegionType: String, Codable, CaseIterable, Identifiable {
    case island      = "Island"
    case coastalLow  = "Coastal (low elevation)"
    case coastalHigh = "Coastal (elevated)"
    case inland      = "Inland / Urban"
    case mountainous = "Mountainous"
    case desert      = "Desert / Arid"
    case plains      = "Plains / Flatlands"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .island:      return "water.waves"
        case .coastalLow:  return "beach.umbrella.fill"
        case .coastalHigh: return "mountain.2.fill"
        case .inland:      return "building.2.fill"
        case .mountainous: return "mountain.2.fill"
        case .desert:      return "sun.max.fill"
        case .plains:      return "wind"
        }
    }
}

enum HazardType: String, Codable, CaseIterable, Identifiable {
    case hurricane   = "Hurricane / Tropical Storm"
    case tornado     = "Tornado"
    case earthquake  = "Earthquake"
    case tsunami     = "Tsunami"
    case flood       = "Flood / Flash Flood"
    case wildfire    = "Wildfire"
    case winter      = "Winter Storm / Blizzard"
    case nuclear     = "Nuclear / Radiological"
    case volcano     = "Volcano"
    case heatwave    = "Extreme Heat / Heat Wave"
    case drought     = "Drought"
    case supplyChain = "Supply Chain Disruption"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .hurricane:   return "hurricane"
        case .tornado:     return "tornado"
        case .earthquake:  return "waveform.path"
        case .tsunami:     return "water.waves"
        case .flood:       return "drop.triangle.fill"
        case .wildfire:    return "flame.fill"
        case .winter:      return "snowflake"
        case .nuclear:     return "atom"
        case .volcano:     return "mountain.2.fill"
        case .heatwave:    return "thermometer.sun.fill"
        case .drought:     return "sun.dust.fill"
        case .supplyChain: return "shippingbox.fill"
        }
    }

    var color: Color {
        switch self {
        case .hurricane:   return Color(red: 0.3, green: 0.5, blue: 0.9)
        case .tornado:     return .purple
        case .earthquake:  return .brown
        case .tsunami:     return .blue
        case .flood:       return Color(red: 0.1, green: 0.4, blue: 0.8)
        case .wildfire:    return .orange
        case .winter:      return Color(red: 0.6, green: 0.8, blue: 1.0)
        case .nuclear:     return .yellow
        case .volcano:     return Color(red: 0.8, green: 0.2, blue: 0.0)
        case .heatwave:    return Color(red: 0.9, green: 0.4, blue: 0.0)
        case .drought:     return Color(red: 0.7, green: 0.6, blue: 0.2)
        case .supplyChain: return .gray
        }
    }

    /// Brief survival tip for this hazard, used in the AI prompt
    var promptFact: String {
        switch self {
        case .hurricane:
            return "Hurricane season preparedness: shelter-in-place for Cat 1-2, evacuate for Cat 3+, storm surge is the #1 killer"
        case .tornado:
            return "Tornado: lowest floor interior room away from windows, mobile homes are deadly — evacuate to sturdy structure"
        case .earthquake:
            return "Earthquake: Drop/Cover/Hold On, expect aftershocks, gas leaks and structural damage are primary secondary threats"
        case .tsunami:
            return "Tsunami: strong or long earthquake means GO NOW to high ground — don't wait for sirens (local source = minutes)"
        case .flood:
            return "Flood: 6 inches of moving water knocks a person down, 12 inches sweeps a vehicle — Turn Around Don't Drown"
        case .wildfire:
            return "Wildfire: evacuate early when ordered, close all vents and doors, N95 masks for smoke, ember showers start new fires"
        case .winter:
            return "Winter storm: stay home, pipes freeze below 20°F, carbon monoxide from generators/heaters kills indoors"
        case .nuclear:
            return "Nuclear: GET INSIDE any solid building, STAY INSIDE 24+ hrs, fallout arrives 15-60 min after detonation, remove outer clothing"
        case .volcano:
            return "Volcano: evacuate lava flow zones immediately, volcanic ash clogs engines and causes roof collapse — brush off regularly"
        case .heatwave:
            return "Heat: drink water before thirsty, 103°F body temp is life-threatening, check on elderly neighbors, wet towels cool core temp"
        case .drought:
            return "Drought/water shortage: collect rainwater, repair leaks immediately, prioritize drinking over irrigation"
        case .supplyChain:
            return "Supply chain disruption: maintain 30-day food/water supply, local food production, barter networks, community coordination"
        }
    }
}

// MARK: - Location Config

struct LocationConfig: Codable {
    var city: String           = ""
    var stateOrRegion: String  = ""
    var country: String        = "United States"
    var regionTypes: [RegionType] = [.inland]
    var hazards: [HazardType]  = []
    var isConfigured: Bool     = false
    var nearestClimateCity: String = ""  // matched city in ClimateDatabase

    var displayName: String {
        [city, stateOrRegion, country == "United States" ? "" : country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var hazardSummary: String {
        hazards.map { $0.rawValue }.joined(separator: ", ")
    }

    /// System prompt text for this location
    var systemPromptContext: String {
        var lines: [String] = []
        lines.append("You are an offline survival assistant for \(displayName).")
        lines.append("")
        lines.append("REGION TYPE: \(regionTypes.map { $0.rawValue }.joined(separator: " + "))")
        lines.append("")

        if !hazards.isEmpty {
            lines.append("PRIMARY HAZARDS FOR THIS AREA:")
            for h in hazards {
                lines.append("- \(h.rawValue): \(h.promptFact)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Location Store

@MainActor
class LocationStore: ObservableObject {
    @Published var config = LocationConfig()
    private let key = "location_config_v1"

    static let shared = LocationStore()

    init() { load() }

    func save(_ config: LocationConfig) {
        self.config = config
        if let d = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }

    private func load() {
        guard let d = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(LocationConfig.self, from: d) else { return }
        config = decoded
    }

    func reset() {
        config = LocationConfig()
        UserDefaults.standard.removeObject(forKey: key)
    }
}
