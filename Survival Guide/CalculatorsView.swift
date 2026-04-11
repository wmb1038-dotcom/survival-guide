import SwiftUI
import Combine

// MARK: - Solar System Config

struct SolarConfig: Codable {
    var batteryName: String     = "Tesla Powerwall 2"
    var batteryCapacityKWh: Double = 12.5
    var batteryUsablePct: Double  = 90.0   // % of capacity usable
    var batteryMaxOutputKW: Double = 5.0   // continuous output kW
    var batteryCount: Int          = 1

    var inverterModel: String  = "Enphase IQ8H"
    var inverterCount: Int     = 18
    var wattsPerInverter: Int  = 384       // IQ8H peak AC output
    var peakSunHours: Double   = 5.5       // hrs/day (Hawaii avg)

    var usableKWh: Double     { batteryCapacityKWh * Double(batteryCount) * batteryUsablePct / 100.0 }
    var peakSolarKW: Double   { Double(inverterCount * wattsPerInverter) / 1000.0 }
    var dailyGenKWh: Double   { peakSolarKW * peakSunHours }
}

@MainActor
class SolarEngine: ObservableObject {
    @Published var config = SolarConfig()
    static let shared = SolarEngine()
    private let key = "solar_config_v1"
    init() { load() }
    func save() { if let d = try? JSONEncoder().encode(config) { UserDefaults.standard.set(d, forKey: key) } }
    private func load() {
        guard let d = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(SolarConfig.self, from: d) else { return }
        config = decoded
    }
}

// MARK: - Calculators View

struct CalculatorsView: View {
    @State private var selectedTab = "Water"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Emergency Calculators")
                            .font(.title2.bold())
                        Text("Water treatment · Power & fuel · Solar · Offline")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Picker("Tab", selection: $selectedTab) {
                    Text("Water Treatment").tag("Water")
                    Text("Power & Fuel").tag("Power")
                    Text("Solar Power").tag("Solar")
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case "Water": WaterCalcTab()
                case "Solar": SolarCalcTab()
                default:      PowerCalcTab()
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Water Treatment Calculator

private enum WaterMethod: String, CaseIterable {
    case bleach6  = "Unscented Bleach 6–8%"
    case bleach85 = "Concentrated Bleach 8.25%+"
    case iodineC  = "Iodine (clear water)"
    case iodineCL = "Iodine (cloudy/cold water)"
    case boil     = "Boiling"
}

private struct WaterCalcTab: View {
    @State private var gallons: Double = 1
    @State private var gallonsText = "1"
    @State private var method: WaterMethod = .bleach6
    @State private var elevation: Double = 0

    private var result: (amount: String, wait: String, notes: String) {
        let g = max(0.1, gallons)
        let qt = g * 4
        switch method {
        case .bleach6:
            let drops = Int(g * 8)
            let tsp   = g >= 1 ? String(format: "≈ %.2f tsp", Double(drops) / 98.0) : ""
            return ("**\(drops) drops** \(tsp)",
                    "30 minutes (60 min if cold/cloudy)",
                    "Water should have faint chlorine smell after treating. If no smell, repeat dose and wait 15 more minutes. Use plain, unscented bleach only.")
        case .bleach85:
            let drops = Int(g * 6)
            return ("**\(drops) drops**",
                    "30 minutes (60 min if cold/cloudy)",
                    "For bleach labeled 8.25%+ sodium hypochlorite. Do not use scented, splashless, or color-safe bleach.")
        case .iodineC:
            let tabs = Int(ceil(qt))
            return ("**\(tabs) tablet\(tabs == 1 ? "" : "s")**",
                    "30 minutes",
                    "Iodine does not kill Cryptosporidium. Filter or pre-settle turbid water. Not for pregnant women or people with thyroid conditions.")
        case .iodineCL:
            let tabs = Int(ceil(qt * 2))
            return ("**\(tabs) tablet\(tabs == 1 ? "" : "s")** (double dose)",
                    "60 minutes",
                    "Cold water (<41°F / 5°C) or cloudy water requires double tablets and longer wait time.")
        case .boil:
            let altFt = elevation
            let minutes = altFt > 6500 ? 3 : 1
            return ("Rolling boil for **\(minutes) minute\(minutes == 1 ? "" : "s")**",
                    "Let cool before drinking",
                    altFt > 6500
                        ? "At elevations above 6,500 ft, water boils at a lower temperature — 3 minutes required."
                        : "Boiling is the most reliable method. Let cool in a covered container. Add a pinch of salt to improve taste.")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            CalcCard(title: "Treatment Calculator", symbol: "drop.triangle.fill", color: .blue) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Gallons to treat").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                TextField("1", text: $gallonsText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .frame(width: 70)
                                    .padding(8)
                                    .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                                    .onChange(of: gallonsText) { _, v in
                                        gallons = Double(v) ?? gallons
                                    }
                                Text("gal")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if method == .boil {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Elevation (ft)").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                                HStack(spacing: 4) {
                                    Button { elevation = max(0, elevation - 1000) } label: {
                                        Image(systemName: "minus").frame(width: 28, height: 28)
                                    }.buttonStyle(.plain)
                                    Text("\(Int(elevation))")
                                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                        .frame(width: 55)
                                    Button { elevation = min(20000, elevation + 1000) } label: {
                                        Image(systemName: "plus").frame(width: 28, height: 28)
                                    }.buttonStyle(.plain)
                                }
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Treatment method").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        Picker("Method", selection: $method) {
                            ForEach(WaterMethod.allCases, id: \.self) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Result
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("TREATMENT").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                                if let attributed = try? AttributedString(markdown: result.amount,
                                    options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                                    Text(attributed).font(.system(size: 18, weight: .semibold)).foregroundStyle(.blue)
                                } else {
                                    Text(result.amount).font(.system(size: 18, weight: .semibold)).foregroundStyle(.blue)
                                }
                            }
                            Divider().frame(height: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("WAIT TIME").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                                Text(result.wait).font(.system(size: 14, weight: .semibold))
                            }
                        }
                        Text(result.notes)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            CalcCard(title: "Always Pre-Filter Cloudy Water", symbol: "exclamationmark.triangle.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 6) {
                    WaterStepRow(n: 1, text: "Let water settle for 30+ minutes, or pour through a cloth/coffee filter")
                    WaterStepRow(n: 2, text: "Treat with chosen method (see calculator above)")
                    WaterStepRow(n: 3, text: "Store in clean, covered container — do not contaminate with hands")
                    WaterStepRow(n: 4, text: "Label container with treatment date")
                }
            }

            CalcCard(title: "Bleach Shelf Life", symbol: "clock.arrow.circlepath", color: .purple) {
                VStack(alignment: .leading, spacing: 5) {
                    WaterInfoRow(label: "Unopened bleach",        value: "1 year from manufacture")
                    WaterInfoRow(label: "Opened bleach",          value: "6 months at full strength")
                    WaterInfoRow(label: "Degraded bleach",        value: "Double the dose if >1 year old")
                    WaterInfoRow(label: "Cannot use bleach that", value: "Is scented, colored, or gel")
                    WaterInfoRow(label: "Water storage life",     value: "6 months in clean sealed container")
                }
            }

            CalcCard(title: "Purification Comparison", symbol: "checklist", color: .green) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Method").font(.system(size: 10, weight: .bold)).frame(width: 120, alignment: .leading)
                        Text("Bacteria").font(.system(size: 10, weight: .bold)).frame(width: 55)
                        Text("Virus").font(.system(size: 10, weight: .bold)).frame(width: 50)
                        Text("Crypto†").font(.system(size: 10, weight: .bold)).frame(width: 52)
                        Text("Nuclear‡").font(.system(size: 10, weight: .bold)).frame(width: 58)
                        Spacer()
                    }
                    .foregroundStyle(.secondary).padding(.bottom, 4)
                    Divider()
                    PurifyRow(method: "Boiling",            bacteria: true,  virus: true,  crypto: true,  nuclear: false)
                    PurifyRow(method: "Bleach / Chlorine",  bacteria: true,  virus: true,  crypto: false, nuclear: false)
                    PurifyRow(method: "Iodine",             bacteria: true,  virus: true,  crypto: false, nuclear: false)
                    PurifyRow(method: "Ceramic filter",     bacteria: true,  virus: false, crypto: true,  nuclear: false)
                    PurifyRow(method: "UV purifier",        bacteria: true,  virus: true,  crypto: true,  nuclear: false)
                    PurifyRow(method: "LifeStraw / Sawyer", bacteria: true,  virus: false, crypto: true,  nuclear: false)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("† Crypto = Cryptosporidium — a chlorine-resistant protozoan parasite. Removed by boiling, UV, and mechanical filters only.")
                            .font(.system(size: 9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Text("‡ Nuclear/Radiological — none of the above reliably remove dissolved radioactive isotopes (Cs-137, Sr-90, I-131). Use sealed bottled water or activated carbon + reverse osmosis. Boiling concentrates dissolved contaminants.")
                            .font(.system(size: 9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}

private struct WaterStepRow: View {
    let n: Int; let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.15)).frame(width: 20, height: 20)
                Text("\(n)").font(.system(size: 10, weight: .bold)).foregroundStyle(.orange)
            }
            Text(text).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WaterInfoRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
    }
}

private struct PurifyRow: View {
    let method: String; let bacteria: Bool; let virus: Bool; let crypto: Bool; let nuclear: Bool
    var body: some View {
        HStack {
            Text(method).font(.system(size: 11)).frame(width: 120, alignment: .leading)
            StatusDot(on: bacteria).frame(width: 55)
            StatusDot(on: virus).frame(width: 50)
            StatusDot(on: crypto).frame(width: 52)
            StatusDot(on: nuclear).frame(width: 58)
            Spacer()
        }
        .padding(.vertical, 3)
        Divider()
    }
}

private struct StatusDot: View {
    let on: Bool
    var body: some View {
        Image(systemName: on ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(on ? .green : .red.opacity(0.5))
            .font(.system(size: 13))
    }
}

// MARK: - Power & Fuel Calculator

private let commonAppliances: [(String, Int)] = [
    ("Refrigerator (running avg)",    150),
    ("Chest freezer",                 100),
    ("Window AC (5,000 BTU)",         500),
    ("Window AC (10,000 BTU)",       1000),
    ("Split-unit AC (8,000 BTU)",     700),
    ("Space heater (low)",            750),
    ("Space heater (high)",          1500),
    ("Sump pump",                     800),
    ("Well pump (1/2 HP)",            900),
    ("Microwave",                    1000),
    ("Coffee maker",                  900),
    ("Electric skillet",             1200),
    ("Laptop",                         65),
    ("Phone charger",                  18),
    ("LED light (each)",               10),
    ("Box fan",                        50),
    ("Ceiling fan",                    75),
    ("TV (LED 40\")",                  60),
    ("CPAP machine",                   30),
    ("Nebulizer",                     200),
]

private struct PowerCalcTab: View {
    @State private var genWatts: Double = 3500
    @State private var genWattsText = "3500"
    @State private var fuelTank: Double = 5
    @State private var fuelTankText = "5"
    @State private var consumptionRate: Double = 0.25  // gal/hr at 50% load
    @State private var consumptionText = "0.25"
    @State private var applianceQtys: [Int: Int] = [:]
    @State private var customItems: [CustomAppliance] = []
    @State private var loadPercent: Double = 50

    private var selectedWatts: Int {
        let preset = applianceQtys.reduce(0) { $0 + $1.value * commonAppliances[$1.key].1 }
        let custom = customItems.reduce(0) { $0 + $1.totalWatts }
        return preset + custom
    }

    private var loadFraction: Double { loadPercent / 100.0 }

    private var adjustedConsumption: Double {
        // Fuel consumption scales roughly with load
        consumptionRate * (0.4 + 0.6 * loadFraction)
    }

    private var runtimeHours: Double {
        guard adjustedConsumption > 0 else { return 0 }
        return fuelTank / adjustedConsumption
    }

    private var loadStatus: (String, Color) {
        let ratio = Double(selectedWatts) / max(1, genWatts)
        if ratio > 1.0 { return ("OVERLOAD — reduce load", .red) }
        if ratio > 0.8 { return ("Heavy load — reduce if possible", .orange) }
        if ratio > 0.5 { return ("Normal load", .green) }
        return ("Light load — efficient", .blue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            CalcCard(title: "Generator Configuration", symbol: "bolt.fill", color: .yellow) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        CalcInputField(label: "Generator Watts", value: $genWattsText, unit: "W") {
                            genWatts = Double(genWattsText) ?? genWatts
                        }
                        CalcInputField(label: "Fuel Tank", value: $fuelTankText, unit: "gal") {
                            fuelTank = Double(fuelTankText) ?? fuelTank
                        }
                        CalcInputField(label: "Consumption (50% load)", value: $consumptionText, unit: "gal/hr") {
                            consumptionRate = Double(consumptionText) ?? consumptionRate
                        }
                    }
                    Text("Typical consumption at 50% load: 1kW=0.10, 2kW=0.14, 3.5kW=0.22, 5kW=0.35, 7.5kW=0.50 gal/hr")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }

            CalcCard(title: "Appliance Load Selector", symbol: "powerplug.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 8) {
                    ApplianceQuantityGrid(qtys: $applianceQtys, customItems: $customItems)
                    Divider()
                    HStack {
                        Text("Selected load:")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Text("\(selectedWatts) W")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                        Text("of \(Int(genWatts)) W capacity")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer()
                        Text(loadStatus.0)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(loadStatus.1)
                    }
                    if selectedWatts > 0 {
                        ProgressView(value: min(1.0, Double(selectedWatts) / max(1, genWatts)))
                            .tint(loadStatus.1)
                    }
                }
            }

            CalcCard(title: "Runtime Estimate", symbol: "clock.fill", color: .green) {
                if fuelTank > 0 && consumptionRate > 0 {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("RUNTIME").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                            Text(String(format: "%.1f hrs", runtimeHours))
                                .font(.system(size: 28, weight: .bold)).foregroundStyle(.green)
                            Text(String(format: "≈ %.1f days", runtimeHours / 24))
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Divider().frame(height: 60)
                        VStack(alignment: .leading, spacing: 5) {
                            PowerInfoRow(label: "Tank size",        value: "\(String(format: "%.1f", fuelTank)) gal")
                            PowerInfoRow(label: "Consumption rate", value: "\(String(format: "%.2f", adjustedConsumption)) gal/hr (adjusted)")
                            PowerInfoRow(label: "Effective load",   value: "\(selectedWatts > 0 ? "\(selectedWatts)W" : "—")")
                        }
                    }
                } else {
                    Text("Enter fuel tank and consumption rate above.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }

            CalcCard(title: "Generator Safety Rules", symbol: "exclamationmark.triangle.fill", color: .red) {
                VStack(alignment: .leading, spacing: 6) {
                    SafetyRow(text: "NEVER run indoors, in garage, or near any window or door — CO kills silently")
                    SafetyRow(text: "Keep 20+ feet from any opening to the house")
                    SafetyRow(text: "Install CO detectors on every floor")
                    SafetyRow(text: "Let generator cool before refueling — fuel on hot engine causes fires")
                    SafetyRow(text: "Use a transfer switch or interlock kit — NEVER backfeed the utility grid")
                    SafetyRow(text: "Store fuel with stabilizer — untreated fuel degrades in 30–60 days")
                }
            }
        }
    }
}

private struct CalcInputField: View {
    let label: String
    @Binding var value: String
    let unit: String
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField("0", text: $value)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .frame(width: 70)
                    .padding(6)
                    .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
                    .onChange(of: value) { _, _ in onChange() }
                Text(unit).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PowerInfoRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
    }
}

private struct SafetyRow: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
                .padding(.top, 1)
            Text(text).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Appliance Quantity Selector (shared by Power & Solar tabs)

struct CustomAppliance: Identifiable {
    let id = UUID()
    var name: String = ""
    var wattsText: String = ""
    var qty: Int = 1
    var watts: Int { Int(wattsText) ?? 0 }
    var totalWatts: Int { watts * qty }
}

private struct ApplianceQuantityGrid: View {
    @Binding var qtys: [Int: Int]
    @Binding var customItems: [CustomAppliance]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                ForEach(Array(commonAppliances.enumerated()), id: \.offset) { i, appliance in
                    ApplianceQtyRow(
                        name: appliance.0,
                        watts: appliance.1,
                        qty: Binding(
                            get: { qtys[i] ?? 0 },
                            set: { qtys[i] = $0 > 0 ? $0 : nil }
                        )
                    )
                }
            }

            if !customItems.isEmpty {
                Divider().padding(.vertical, 2)
                Text("Custom Appliances")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                ForEach($customItems) { $item in
                    CustomApplianceRow(item: $item) {
                        customItems.removeAll { $0.id == item.id }
                    }
                }
            }

            if customItems.count < 10 {
                Button {
                    customItems.append(CustomAppliance())
                } label: {
                    Label("Add Custom Appliance", systemImage: "plus.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }
}

private struct ApplianceQtyRow: View {
    let name: String
    let watts: Int
    @Binding var qty: Int

    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 0) {
                Button { if qty > 0 { qty -= 1 } } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 18, height: 20)
                        .foregroundStyle(qty > 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                }
                .buttonStyle(.plain)

                Text("\(qty)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .frame(width: 22, alignment: .center)

                Button { qty += 1 } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 18, height: 20)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .background(Color.primary.opacity(qty > 0 ? 0.10 : 0.05), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(qty > 0 ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1))

            Text(name)
                .font(.system(size: 11))
                .foregroundStyle(qty > 0 ? .primary : .secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text("\(watts)W")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(qty > 0 ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.tertiary))
        }
    }
}

private struct CustomApplianceRow: View {
    @Binding var item: CustomAppliance
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            // Quantity stepper
            HStack(spacing: 0) {
                Button { if item.qty > 1 { item.qty -= 1 } } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 18, height: 20)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Text("\(item.qty)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .frame(width: 22, alignment: .center)

                Button { item.qty += 1 } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 18, height: 20)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.blue.opacity(0.3), lineWidth: 1))

            TextField("Appliance name", text: $item.name)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(.vertical, 3).padding(.horizontal, 6)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))

            TextField("W", text: $item.wattsText)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 52)
                .padding(.vertical, 3).padding(.horizontal, 6)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))

            Text("W").font(.system(size: 10)).foregroundStyle(.secondary)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Solar Power Calculator

private struct SolarCalcTab: View {
    @StateObject private var engine = SolarEngine.shared
    @State private var applianceQtys: [Int: Int] = [:]
    @State private var customItems: [CustomAppliance] = []
    @State private var showConfig = false

    private var selectedWatts: Int {
        let preset = applianceQtys.reduce(0) { $0 + $1.value * commonAppliances[$1.key].1 }
        let custom = customItems.reduce(0) { $0 + $1.totalWatts }
        return preset + custom
    }
    private var loadKW: Double { Double(selectedWatts) / 1000.0 }

    // Battery-only runtime
    private var batteryHours: Double {
        guard loadKW > 0 else { return 0 }
        let maxOutput = engine.config.batteryMaxOutputKW
        let effectiveLoad = min(loadKW, maxOutput)
        return engine.config.usableKWh / effectiveLoad
    }

    // Daily energy balance
    private var dailyConsumptionKWh: Double { loadKW * 24.0 }
    private var dailyNetKWh: Double { engine.config.dailyGenKWh - dailyConsumptionKWh }
    private var isSustainable: Bool { dailyNetKWh >= 0 }

    // With solar assist: how long battery lasts if load > generation
    private var combinedHours: Double {
        guard loadKW > 0 else { return 0 }
        if isSustainable { return .infinity }
        let netDeficitKW = loadKW - engine.config.peakSolarKW  // simplified: solar runs ~peakSunHours/day
        // More accurate: during sun hours solar covers load, rest comes from battery
        let hourlyBatteryDrain = max(0, loadKW - engine.config.peakSolarKW * (engine.config.peakSunHours / 24.0))
        guard hourlyBatteryDrain > 0 else { return .infinity }
        return engine.config.usableKWh / hourlyBatteryDrain
    }

    private var loadVsOutputStatus: (String, Color) {
        guard loadKW > 0 else { return ("No load selected", .secondary) }
        if loadKW > engine.config.batteryMaxOutputKW { return ("Exceeds Powerwall max output (\(String(format: "%.0f", engine.config.batteryMaxOutputKW)) kW)", .red) }
        if loadKW > engine.config.peakSolarKW { return ("Load exceeds solar peak — battery supplements", .orange) }
        return ("Solar can fully cover this load at peak", .green)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── System Config ────────────────────────────────────────────
            CalcCard(title: "Solar System Configuration", symbol: "sun.max.fill", color: .yellow) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            SolarSpecRow(label: "Battery",
                                         value: "\(engine.config.batteryCount)× \(engine.config.batteryName)",
                                         detail: "\(String(format: "%.1f", engine.config.batteryCapacityKWh * Double(engine.config.batteryCount))) kWh total · \(String(format: "%.1f", engine.config.usableKWh)) kWh usable (\(Int(engine.config.batteryUsablePct))%) · \(String(format: "%.0f", engine.config.batteryMaxOutputKW)) kW max output")
                            SolarSpecRow(label: "Solar",
                                         value: "\(engine.config.inverterCount)× \(engine.config.inverterModel)",
                                         detail: "\(engine.config.wattsPerInverter)W each · \(String(format: "%.1f", engine.config.peakSolarKW)) kW peak · \(String(format: "%.1f", engine.config.dailyGenKWh)) kWh/day est.")
                            SolarSpecRow(label: "Peak sun hours",
                                         value: "\(String(format: "%.1f", engine.config.peakSunHours)) hrs/day",
                                         detail: "Hawaii avg ≈ 5–6 hrs · Mainland varies by region")
                        }
                        Spacer()
                        Button { showConfig = true } label: {
                            Label("Edit System", systemImage: "pencil.circle")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            // ── Appliance Load Selector ───────────────────────────────────
            CalcCard(title: "Appliance Load Selector", symbol: "powerplug.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 8) {
                    ApplianceQuantityGrid(qtys: $applianceQtys, customItems: $customItems)
                    Divider()
                    HStack {
                        Text("Selected load:")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Text(String(format: "%.2f kW", loadKW))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                        Spacer()
                        Text(loadVsOutputStatus.0)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(loadVsOutputStatus.1)
                    }
                    if selectedWatts > 0 {
                        ProgressView(value: min(1.0, loadKW / max(0.1, engine.config.peakSolarKW)))
                            .tint(loadVsOutputStatus.1)
                        Text("vs. \(String(format: "%.1f", engine.config.peakSolarKW)) kW solar peak")
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
            }

            // ── Battery Runtime ───────────────────────────────────────────
            CalcCard(title: "Battery-Only Runtime", symbol: "battery.75", color: .green) {
                if loadKW == 0 {
                    Text("Select appliances above to calculate runtime.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("BATTERY ONLY").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                            Text(String(format: "%.1f hrs", batteryHours))
                                .font(.system(size: 28, weight: .bold)).foregroundStyle(.green)
                            Text(String(format: "≈ %.1f days", batteryHours / 24))
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Divider().frame(height: 60)
                        VStack(alignment: .leading, spacing: 5) {
                            PowerInfoRow(label: "Usable capacity",  value: String(format: "%.1f kWh", engine.config.usableKWh))
                            PowerInfoRow(label: "Load",             value: String(format: "%.2f kW", loadKW))
                            PowerInfoRow(label: "Max output",       value: String(format: "%.0f kW", engine.config.batteryMaxOutputKW))
                            if loadKW > engine.config.batteryMaxOutputKW {
                                Text("⚠️ Load exceeds max output — shed loads")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }

            // ── Solar Generation & Balance ────────────────────────────────
            CalcCard(title: "Solar Generation & Energy Balance", symbol: "sun.and.horizon.fill", color: Color(red: 0.9, green: 0.55, blue: 0.0)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("DAILY GENERATION").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                            Text(String(format: "%.1f kWh", engine.config.dailyGenKWh))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color(red: 0.9, green: 0.55, blue: 0.0))
                            Text("est. per day (clear sky)")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Divider().frame(height: 50)
                        if loadKW > 0 {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("DAILY CONSUMPTION").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                                Text(String(format: "%.1f kWh", dailyConsumptionKWh))
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.primary)
                                Text("at selected load (24/7)")
                                    .font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Divider().frame(height: 50)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(isSustainable ? "DAILY SURPLUS" : "DAILY DEFICIT")
                                    .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                                Text(String(format: "%+.1f kWh", dailyNetKWh))
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(isSustainable ? .green : .red)
                                Text(isSustainable ? "System self-sustaining" : "Battery depletes over time")
                                    .font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                        }
                    }

                    if loadKW > 0 {
                        Divider()
                        if isSustainable {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text("Solar generation exceeds load — system runs indefinitely in good sun. Battery stores surplus for nights and clouds.")
                                    .font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 3) {
                                    if combinedHours == .infinity {
                                        Text("Solar partially covers load. Battery buffer extends runtime significantly.")
                                            .font(.system(size: 11))
                                    } else {
                                        Text(String(format: "With solar assist, battery lasts est. %.0f hrs (%.1f days) before depletion.", combinedHours, combinedHours / 24))
                                            .font(.system(size: 11))
                                    }
                                    Text("Reduce load or wait for sun to recharge.")
                                        .font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            // ── Tips ─────────────────────────────────────────────────────
            CalcCard(title: "Solar Emergency Tips", symbol: "lightbulb.fill", color: .purple) {
                VStack(alignment: .leading, spacing: 6) {
                    SolarTipRow(text: "Prioritize high-draw appliances during peak sun hours (10am–2pm) to draw directly from panels, sparing the battery.")
                    SolarTipRow(text: "Powerwall 2 default reserve is 10% — change to 20–30% in the Tesla app before a storm as an emergency buffer.")
                    SolarTipRow(text: "Microinverters (like IQ8H) can operate in grid-forming mode during outages — ensure your system is configured for storm mode.")
                    SolarTipRow(text: "Clouds reduce output to 10–25% of peak. Assume 50% generation on partly cloudy days for conservative planning.")
                    SolarTipRow(text: "Refrigerator (~150W avg) + CPAP + phone/laptop charging = ≈350W — most systems sustain this load indefinitely in Hawaii sun.")
                    SolarTipRow(text: "Do not run EV charging during a grid outage — it will rapidly drain your Powerwall and leave nothing for essential loads.")
                }
            }
        }
        .sheet(isPresented: $showConfig) {
            SolarConfigSheet(config: engine.config) {
                engine.config = $0
                engine.save()
            }
        }
    }
}

private struct SolarSpecRow: View {
    let label: String; let value: String; let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
            }
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.leading, 98)
        }
    }
}

private struct SolarTipRow: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "sun.min.fill")
                .font(.system(size: 10)).foregroundStyle(.yellow).padding(.top, 1)
            Text(text).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Solar Config Sheet

struct SolarConfigSheet: View {
    @State var config: SolarConfig
    let onSave: (SolarConfig) -> Void
    @Environment(\.dismiss) private var dismiss

    // Text-field mirrors
    @State private var capText   = ""
    @State private var usableText = ""
    @State private var maxKWText = ""
    @State private var countText = ""
    @State private var wpiText   = ""
    @State private var sunText   = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Solar System Configuration")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    applyTextFields()
                    onSave(config)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            Divider()

            Form {
                Section("Battery Storage") {
                    TextField("Battery name", text: $config.batteryName)
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Capacity (kWh)").font(.system(size: 10)).foregroundStyle(.secondary)
                            TextField("12.5", text: $capText)
                                .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                                .padding(6).background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Usable (%)").font(.system(size: 10)).foregroundStyle(.secondary)
                            TextField("90", text: $usableText)
                                .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                                .padding(6).background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Max output (kW)").font(.system(size: 10)).foregroundStyle(.secondary)
                            TextField("5", text: $maxKWText)
                                .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                                .padding(6).background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("# of units").font(.system(size: 10)).foregroundStyle(.secondary)
                            Stepper("\(config.batteryCount)", value: $config.batteryCount, in: 1...10)
                        }
                    }
                    Text("Powerwall 2 default: 13.5 kWh capacity, 90% usable, 5 kW max continuous output")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Solar Panels / Microinverters") {
                    TextField("Inverter/panel model", text: $config.inverterModel)
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("# of inverters").font(.system(size: 10)).foregroundStyle(.secondary)
                            TextField("18", text: $countText)
                                .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                                .padding(6).background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Watts/inverter").font(.system(size: 10)).foregroundStyle(.secondary)
                            TextField("384", text: $wpiText)
                                .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                                .padding(6).background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Peak sun hrs/day").font(.system(size: 10)).foregroundStyle(.secondary)
                            TextField("5.5", text: $sunText)
                                .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                                .padding(6).background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    Text("IQ8H: 384W AC output. Peak sun hrs: Hawaii ≈ 5–6 · SW US ≈ 6–7 · NW US ≈ 3–4 · Southeast ≈ 4.5–5.5")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section {
                    let kw = Double(Int(wpiText) ?? config.wattsPerInverter) * Double(Int(countText) ?? config.inverterCount) / 1000.0
                    let daily = kw * (Double(sunText) ?? config.peakSunHours)
                    let usable = (Double(capText) ?? config.batteryCapacityKWh) * Double(config.batteryCount) * (Double(usableText) ?? config.batteryUsablePct) / 100.0
                    VStack(alignment: .leading, spacing: 5) {
                        PowerInfoRow(label: "Peak solar output", value: String(format: "%.2f kW", kw))
                        PowerInfoRow(label: "Daily generation (est.)", value: String(format: "%.1f kWh/day", daily))
                        PowerInfoRow(label: "Usable battery storage", value: String(format: "%.1f kWh", usable))
                    }
                } header: { Text("Calculated Summary") }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 520, minHeight: 480)
        .onAppear { loadTextFields() }
    }

    private func loadTextFields() {
        capText    = String(format: "%.1f", config.batteryCapacityKWh)
        usableText = String(format: "%.0f", config.batteryUsablePct)
        maxKWText  = String(format: "%.1f", config.batteryMaxOutputKW)
        countText  = "\(config.inverterCount)"
        wpiText    = "\(config.wattsPerInverter)"
        sunText    = String(format: "%.1f", config.peakSunHours)
    }

    private func applyTextFields() {
        if let v = Double(capText)   { config.batteryCapacityKWh  = v }
        if let v = Double(usableText){ config.batteryUsablePct    = min(100, max(0, v)) }
        if let v = Double(maxKWText) { config.batteryMaxOutputKW  = v }
        if let v = Int(countText)    { config.inverterCount       = max(1, v) }
        if let v = Int(wpiText)      { config.wattsPerInverter    = max(1, v) }
        if let v = Double(sunText)   { config.peakSunHours        = max(0.1, v) }
    }
}

// MARK: - Shared Card

struct CalcCard<Content: View>: View {
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
