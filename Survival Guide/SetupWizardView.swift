import SwiftUI

// MARK: - Setup Wizard

struct SetupWizardView: View {
    @ObservedObject var store: LocationStore
    @ObservedObject var supplyEngine: SupplyEngine

    @State private var step: Int = 1
    @State private var city: String = ""
    @State private var stateOrRegion: String = ""
    @State private var country: String = "United States"
    @State private var selectedClimateCity: String = ""
    @State private var selectedRegionTypes: Set<RegionType> = []
    @State private var selectedHazards: Set<HazardType> = []
    @State private var adults: Int = 2
    @State private var children: Int = 0
    @State private var dogs: Int = 0
    @State private var cats: Int = 0
    @State private var smallAnimals: Int = 0

    @StateObject private var generator = SurvivalGuideGenerator()
    @State private var pendingConfig: LocationConfig? = nil

    private let totalSteps = 5   // wizard steps; step 6 = generation (shown separately)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.10, blue: 0.14), Color(red: 0.12, green: 0.15, blue: 0.20)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // Progress bar — hide on step 6 (generation screen)
                if step <= totalSteps {
                    ProgressBar(current: step, total: totalSteps)
                        .padding(.horizontal, 40)
                        .padding(.top, 30)
                        .padding(.bottom, 24)
                } else {
                    Spacer().frame(height: 30)
                }

                // Step content
                Group {
                    switch step {
                    case 1: WelcomeStep()
                    case 2: LocationStep(city: $city, stateOrRegion: $stateOrRegion,
                                         country: $country, selectedClimateCity: $selectedClimateCity)
                    case 3: RegionStep(selectedRegionTypes: $selectedRegionTypes)
                    case 4: HazardStep(selectedHazards: $selectedHazards)
                    case 5: HouseholdStep(adults: $adults, children: $children,
                                          dogs: $dogs, cats: $cats, smallAnimals: $smallAnimals)
                    case 6: GeneratingGuidesStep(generator: generator)
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: step == 6 ? .infinity : 680)
                .frame(maxWidth: .infinity)

                Spacer()

                // Navigation buttons
                HStack(spacing: 16) {
                    // Back — hidden during and after generation
                    if step > 1 && step < 6 {
                        Button("Back") { withAnimation { step -= 1 } }
                            .buttonStyle(WizardSecondaryButtonStyle())
                    }
                    Spacer()

                    if step < totalSteps {
                        Button("Continue") { withAnimation { step += 1 } }
                            .buttonStyle(WizardPrimaryButtonStyle())
                            .disabled(step == 2 && city.trimmingCharacters(in: .whitespaces).isEmpty)
                            .disabled(step == 3 && selectedRegionTypes.isEmpty)
                    } else if step == totalSteps {
                        Button("Finish Setup") { beginFinish() }
                            .buttonStyle(WizardPrimaryButtonStyle())
                    } else {
                        // Step 6 — Open App button
                        Button("Open Survival Guide") { completeSetup() }
                            .buttonStyle(WizardPrimaryButtonStyle())
                            .disabled(generator.isGenerating)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
        .frame(minWidth: 740, minHeight: 560)
    }

    // MARK: - Finish flow

    /// Called when user taps "Finish Setup" on step 5.
    /// Saves household, stores pending config, advances to step 6, kicks off generation.
    private func beginFinish() {
        var config = LocationConfig()
        config.city            = city.trimmingCharacters(in: .whitespaces)
        config.stateOrRegion   = stateOrRegion.trimmingCharacters(in: .whitespaces)
        config.country         = country.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? "United States"
                                    : country.trimmingCharacters(in: .whitespaces)
        config.regionTypes     = Array(selectedRegionTypes).sorted { $0.rawValue < $1.rawValue }
        config.hazards         = Array(selectedHazards).sorted { $0.rawValue < $1.rawValue }
        config.nearestClimateCity = selectedClimateCity
        config.isConfigured    = false  // set true only after generation screen
        pendingConfig = config

        var hh = supplyEngine.household
        hh.adults = adults; hh.children = children
        hh.dogs = dogs; hh.cats = cats; hh.smallAnimals = smallAnimals
        supplyEngine.updateHousehold(hh)

        withAnimation { step = 6 }
        Task { await generator.generate(config: config) }
    }

    /// Called when user taps "Open Survival Guide" on step 6.
    private func completeSetup() {
        guard var config = pendingConfig else { return }
        config.isConfigured = true
        store.save(config)
    }
}

// MARK: - Step Views

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "shield.lefthalf.filled.slash")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.orange)

            VStack(spacing: 10) {
                Text("Welcome to Survival Guide")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text("This app builds a personalized preparedness plan for your location. It works completely offline — no internet required.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            VStack(alignment: .leading, spacing: 12) {
                WizardFeatureRow(symbol: "location.fill", color: .blue, text: "Tailored to your city and hazards")
                WizardFeatureRow(symbol: "cloud.sun.fill", color: .cyan, text: "Historical weather forecasts for your region")
                WizardFeatureRow(symbol: "cpu.fill", color: .purple, text: "AI assistant with local context")
                WizardFeatureRow(symbol: "cabinet.fill", color: .green, text: "Supply tracking sized to your household")
            }
            .padding(20)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(40)
    }
}

private struct LocationStep: View {
    @Binding var city: String
    @Binding var stateOrRegion: String
    @Binding var country: String
    @Binding var selectedClimateCity: String

    private var matchedCity: String {
        // Auto-suggest nearest climate city based on city input
        let cityLower = city.lowercased()
        for name in allCityNames {
            if name.lowercased().contains(cityLower) { return name }
        }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WizardStepHeader(
                symbol: "location.circle.fill",
                color: .blue,
                title: "Where are you located?",
                subtitle: "Used to tailor hazard guidance, weather forecasts, and AI responses."
            )

            VStack(alignment: .leading, spacing: 14) {
                WizardField(label: "City *", placeholder: "e.g. Honolulu, Miami, Seattle", text: $city)

                HStack(spacing: 12) {
                    WizardField(label: "State / Province", placeholder: "e.g. Hawaii, FL, BC", text: $stateOrRegion)
                    WizardField(label: "Country", placeholder: "United States", text: $country)
                }

                // Climate data picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Climate Data City")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))

                    Picker("Climate data city", selection: $selectedClimateCity) {
                        Text("— Select nearest city —").tag("")
                        ForEach(allCityNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                    if selectedClimateCity.isEmpty && !city.isEmpty {
                        let suggestion = matchedCity
                        if !suggestion.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                Text("Suggested: \(suggestion)")
                                    .font(.caption)
                                Button("Use this") { selectedClimateCity = suggestion }
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            .foregroundStyle(.white.opacity(0.6))
                        }
                    }

                    Text("Controls which historical normals are used for weather forecasting.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 40)
    }
}

private struct RegionStep: View {
    @Binding var selectedRegionTypes: Set<RegionType>

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WizardStepHeader(
                symbol: "map.fill",
                color: .orange,
                title: "Describe your terrain",
                subtitle: "Select all that apply — you can choose multiple terrains."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(RegionType.allCases) { region in
                    RegionTypeCard(region: region, isSelected: selectedRegionTypes.contains(region)) {
                        if selectedRegionTypes.contains(region) {
                            selectedRegionTypes.remove(region)
                        } else {
                            selectedRegionTypes.insert(region)
                        }
                    }
                }
            }

            if selectedRegionTypes.isEmpty {
                Label("Select at least one terrain type.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 40)
    }
}

private struct HazardStep: View {
    @Binding var selectedHazards: Set<HazardType>

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WizardStepHeader(
                symbol: "exclamationmark.triangle.fill",
                color: .red,
                title: "Select your hazards",
                subtitle: "Choose all hazards that apply to your area. These focus the AI assistant and your checklists."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(HazardType.allCases) { hazard in
                    HazardToggleCard(hazard: hazard, isSelected: selectedHazards.contains(hazard)) {
                        if selectedHazards.contains(hazard) {
                            selectedHazards.remove(hazard)
                        } else {
                            selectedHazards.insert(hazard)
                        }
                    }
                }
            }

            if selectedHazards.isEmpty {
                Label("Select at least one hazard for the best experience.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 40)
    }
}

private struct HouseholdStep: View {
    @Binding var adults: Int
    @Binding var children: Int
    @Binding var dogs: Int
    @Binding var cats: Int
    @Binding var smallAnimals: Int

    private var dailyWater: Double {
        Double(adults) * 1.0 + Double(children) * 0.75 +
        Double(dogs) * 0.5 + Double(cats) * 0.25 +
        Double(smallAnimals) * 0.1
    }
    private var target14Day: Double { dailyWater * 14 }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WizardStepHeader(
                symbol: "person.3.fill",
                color: .green,
                title: "Who's in your household?",
                subtitle: "Used to calculate water and food supply targets in the Supply Tracker."
            )

            VStack(spacing: 0) {
                HouseholdRow(label: "Adults", symbol: "person.fill", color: .blue, value: $adults, range: 1...20)
                Divider().background(Color.white.opacity(0.1))
                HouseholdRow(label: "Children", symbol: "figure.child", color: .yellow, value: $children, range: 0...15)
                Divider().background(Color.white.opacity(0.1))
                HouseholdRow(label: "Dogs", symbol: "pawprint.fill", color: .orange, value: $dogs, range: 0...10)
                Divider().background(Color.white.opacity(0.1))
                HouseholdRow(label: "Cats", symbol: "cat.fill", color: .purple, value: $cats, range: 0...10)
                Divider().background(Color.white.opacity(0.1))
                HouseholdRow(label: "Small Animals (birds, rodents, chickens…)", symbol: "bird.fill", color: Color(red: 0.3, green: 0.7, blue: 0.4), value: $smallAnimals, range: 0...50)
            }
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

            // Water summary
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily water need")
                        .font(.caption).foregroundStyle(.white.opacity(0.5))
                    Text(String(format: "%.1f gallons/day", dailyWater))
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                }
                Divider().frame(height: 36).background(Color.white.opacity(0.15))
                VStack(alignment: .leading, spacing: 3) {
                    Text("14-day supply target")
                        .font(.caption).foregroundStyle(.white.opacity(0.5))
                    Text(String(format: "%.0f gallons", target14Day))
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.cyan)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Step 6: Generating Guides

private struct GeneratingGuidesStep: View {
    @ObservedObject var generator: SurvivalGuideGenerator

    var body: some View {
        VStack(spacing: 24) {

            // Icon + title
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: iconName)
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(iconColor)
                        .symbolEffect(.pulse, isActive: generator.isGenerating)
                }

                Text(generator.isGenerating ? "Generating Survival Guides" : "Guides Ready")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Text(generator.isGenerating
                     ? generator.currentTask
                     : generator.outputDirectory.map { "Saved to: \($0.path)" } ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 500)
            }

            // Progress bar
            if generator.isGenerating || (generator.isComplete && generator.progress > 0) {
                ProgressView(value: generator.progress)
                    .tint(generator.isComplete ? .green : .orange)
                    .frame(maxWidth: 420)
                    .animation(.easeInOut, value: generator.progress)
            }

            // Terminal log
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(generator.log) { line in
                            Text(line.text)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(lineColor(line.kind))
                                .id(line.id)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06)))
                .frame(maxWidth: 520, minHeight: 160, maxHeight: 220)
                .onChange(of: generator.log.count) { _ in
                    if let last = generator.log.last {
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id) }
                    }
                }
            }

            if generator.isComplete {
                Text("Click \"Open Survival Guide\" to enter the app.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 60)
        .padding(.top, 10)
    }

    private var iconName: String {
        generator.isComplete ? "checkmark.shield.fill" : "cpu"
    }

    private var iconColor: Color {
        generator.isComplete ? .green : .orange
    }

    private func lineColor(_ kind: SurvivalGuideGenerator.LogLine.Kind) -> Color {
        switch kind {
        case .success:  return .green
        case .error:    return Color(red: 1, green: 0.4, blue: 0.4)
        case .warning:  return .yellow
        case .progress: return .orange
        case .info:     return Color.white.opacity(0.55)
        }
    }
}

// MARK: - Reusable Wizard Components

private struct ProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.orange)
                        .frame(width: geo.size.width * CGFloat(current) / CGFloat(total), height: 4)
                        .animation(.easeInOut(duration: 0.3), value: current)
                }
            }
            .frame(height: 4)

            HStack {
                Text("Step \(current) of \(total)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            }
        }
    }
}

private struct WizardStepHeader: View {
    let symbol: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 28))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct WizardField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }
}

private struct WizardFeatureRow: View {
    let symbol: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

private struct RegionTypeCard: View {
    let region: RegionType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: region.symbol)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
                    .frame(width: 22)
                Text(region.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.8))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.6))
                }
            }
            .padding(12)
            .background(isSelected ? Color.orange : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.orange : Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct HazardToggleCard: View {
    let hazard: HazardType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                Image(systemName: hazard.symbol)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .white : hazard.color.opacity(0.7))
                Text(hazard.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(isSelected ? hazard.color.opacity(0.35) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? hazard.color : Color.white.opacity(0.10), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

private struct HouseholdRow: View {
    let label: String
    let symbol: String
    let color: Color
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(color)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            HStack(spacing: 0) {
                Button { if value > range.lowerBound { value -= 1 } } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                Text("\(value)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30)
                Button { if value < range.upperBound { value += 1 } } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Button Styles

struct WizardPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isEnabled ? .black : .white.opacity(0.4))
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(isEnabled ? Color.orange : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct WizardSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
