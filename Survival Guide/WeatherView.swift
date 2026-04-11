import SwiftUI
import Combine

// MARK: - Enums & Models

enum WeatherCondition: String, Codable, CaseIterable {
    case sunny        = "Sunny"
    case partlyCloudy = "Partly Cloudy"
    case mostlyCloudy = "Mostly Cloudy"
    case overcast     = "Overcast"
    case lightRain    = "Light Rain"
    case heavyRain    = "Heavy Rain"
    case stormy       = "Stormy"

    var symbol: String {
        switch self {
        case .sunny:        return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .mostlyCloudy: return "cloud.fill"
        case .overcast:     return "smoke.fill"
        case .lightRain:    return "cloud.drizzle.fill"
        case .heavyRain:    return "cloud.rain.fill"
        case .stormy:       return "cloud.bolt.rain.fill"
        }
    }

    var color: Color {
        switch self {
        case .sunny:        return .yellow
        case .partlyCloudy: return .orange
        case .mostlyCloudy: return Color(red: 0.55, green: 0.65, blue: 0.75)
        case .overcast:     return .gray
        case .lightRain:    return Color(red: 0.3, green: 0.55, blue: 0.9)
        case .heavyRain:    return Color(red: 0.1, green: 0.3, blue: 0.85)
        case .stormy:       return .purple
        }
    }

    /// Whether this condition counts as a "rain day" for bias tracking
    var isRainy: Bool {
        switch self {
        case .lightRain, .heavyRain, .stormy: return true
        default: return false
        }
    }
}

struct DailyObservation: Codable, Identifiable {
    var id = UUID()
    let date: Date
    var highF: Double?
    var lowF: Double?
    var condition: WeatherCondition
    var windMph: Double?
    var rainInches: Double?
    var notes: String
}

struct ClimateNormal {
    let month: Int
    let highF: Double
    let lowF: Double
    let rainProbability: Double  // 0–1
    let avgWindMph: Double
}

struct ForecastDay {
    let date: Date
    let norm: ClimateNormal
    let highF: Double
    let lowF: Double
    let rainProb: Double
    let condition: WeatherCondition
    let isObserved: Bool            // user already logged this day
    let observation: DailyObservation?
}

// MARK: - Fallback climate normals (temperate mid-latitude)

private let fallbackNormals: [ClimateNormal] = [
    ClimateNormal(month: 1,  highF: 45.0, lowF: 28.0, rainProbability: 0.30, avgWindMph: 10),
    ClimateNormal(month: 2,  highF: 48.0, lowF: 30.0, rainProbability: 0.28, avgWindMph: 10),
    ClimateNormal(month: 3,  highF: 55.0, lowF: 36.0, rainProbability: 0.30, avgWindMph: 11),
    ClimateNormal(month: 4,  highF: 64.0, lowF: 44.0, rainProbability: 0.28, avgWindMph: 11),
    ClimateNormal(month: 5,  highF: 73.0, lowF: 53.0, rainProbability: 0.27, avgWindMph: 10),
    ClimateNormal(month: 6,  highF: 82.0, lowF: 62.0, rainProbability: 0.22, avgWindMph: 9),
    ClimateNormal(month: 7,  highF: 87.0, lowF: 67.0, rainProbability: 0.20, avgWindMph: 8),
    ClimateNormal(month: 8,  highF: 86.0, lowF: 66.0, rainProbability: 0.21, avgWindMph: 8),
    ClimateNormal(month: 9,  highF: 79.0, lowF: 58.0, rainProbability: 0.24, avgWindMph: 9),
    ClimateNormal(month: 10, highF: 68.0, lowF: 47.0, rainProbability: 0.27, avgWindMph: 10),
    ClimateNormal(month: 11, highF: 56.0, lowF: 38.0, rainProbability: 0.29, avgWindMph: 10),
    ClimateNormal(month: 12, highF: 47.0, lowF: 30.0, rainProbability: 0.30, avgWindMph: 10),
]

/// Returns the ClimateNormal for the given date using LocationStore config.
/// Falls back to temperate normals if no match is found in ClimateDatabase.
func locationNormal(for date: Date) -> ClimateNormal {
    let m = Calendar.current.component(.month, from: date)
    let config = LocationStore.shared.config
    if let city = findClimateNormals(for: config) {
        return city.months[m - 1]
    }
    return fallbackNormals[m - 1]
}

private func conditionForRainProb(_ p: Double) -> WeatherCondition {
    switch p {
    case ..<0.15: return .sunny
    case ..<0.25: return .partlyCloudy
    case ..<0.38: return .mostlyCloudy
    case ..<0.52: return .overcast
    case ..<0.68: return .lightRain
    default:      return .heavyRain
    }
}

// MARK: - Forecast Engine

@MainActor
class WeatherEngine: ObservableObject {
    @Published var observations: [DailyObservation] = []
    @Published var forecast: [ForecastDay] = []

    private let key = "oahu_obs_v1"

    init() { load(); recompute() }

    // MARK: Persistence

    func load() {
        guard let d = UserDefaults.standard.data(forKey: key),
              let obs = try? JSONDecoder().decode([DailyObservation].self, from: d) else { return }
        observations = obs.sorted { $0.date > $1.date }
    }

    func save() {
        if let d = try? JSONEncoder().encode(observations) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }

    func addOrUpdate(_ obs: DailyObservation) {
        let cal = Calendar.current
        observations.removeAll { cal.isDate($0.date, inSameDayAs: obs.date) }
        observations.append(obs)
        observations.sort { $0.date > $1.date }
        save()
        recompute()
    }

    func delete(_ obs: DailyObservation) {
        observations.removeAll { $0.id == obs.id }
        save()
        recompute()
    }

    // MARK: Bias

    /// Weighted bias (actual − historical) from the last 10 days.
    /// Recent days weighted more heavily (factor 0.8 per day back).
    private func bias() -> (high: Double, low: Double, rain: Double) {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        let recent = observations.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return (0, 0, 0) }

        var highW = 0.0, lowW = 0.0, rainW = 0.0, wSum = 0.0
        for obs in recent {
            let daysAgo = max(0, cal.dateComponents([.day], from: obs.date, to: Date()).day ?? 0)
            let w = pow(0.8, Double(daysAgo))
            let norm = locationNormal(for: obs.date)
            if let h = obs.highF { highW += (h - norm.highF) * w }
            if let l = obs.lowF  { lowW  += (l - norm.lowF)  * w }
            rainW += ((obs.condition.isRainy ? 1.0 : 0.0) - norm.rainProbability) * w
            wSum += w
        }
        guard wSum > 0 else { return (0, 0, 0) }
        return (highW / wSum, lowW / wSum, rainW / wSum)
    }

    // MARK: Forecast Computation

    func recompute() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let b = bias()
        let hasRecent = observations.contains {
            $0.date >= (cal.date(byAdding: .day, value: -3, to: Date()) ?? Date())
        }

        forecast = (0..<5).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: today)!
            let norm = locationNormal(for: date)

            // Bias decays further into the future
            let decay = hasRecent ? pow(0.60, Double(offset)) : 0.0
            let adjHigh = norm.highF + b.high * decay
            let adjLow  = norm.lowF  + b.low  * decay
            let adjRain = min(1, max(0, norm.rainProbability + b.rain * decay))

            let obs = observations.first { cal.isDate($0.date, inSameDayAs: date) }

            return ForecastDay(
                date: date,
                norm: norm,
                highF: adjHigh,
                lowF:  adjLow,
                rainProb: adjRain,
                condition: obs?.condition ?? conditionForRainProb(adjRain),
                isObserved: obs != nil,
                observation: obs
            )
        }
    }
}

// MARK: - Main View

struct WeatherView: View {
    @StateObject private var engine = WeatherEngine()
    @ObservedObject private var locationStore = LocationStore.shared

    private let dayFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE"; return f }()
    private let dateFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d"; return f }()

    private var forecastTitle: String {
        let loc = locationStore.config.displayName
        return loc.isEmpty ? "5-Day Forecast" : "\(loc) 5-Day Forecast"
    }

    private var forecastSubtitle: String {
        let climateCity = locationStore.config.nearestClimateCity
        if climateCity.isEmpty {
            return "Historical averages · NOAA climate normals"
        }
        return "Historical averages · \(climateCity) · NOAA climate normals"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {

                // ── Header ────────────────────────────────────────────────────
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(forecastTitle)
                            .font(.title2.bold())
                        Text(forecastSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !engine.observations.isEmpty {
                        Label("\(engine.observations.count) day\(engine.observations.count == 1 ? "" : "s") logged", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                }

                // ── 5-Day Strip ───────────────────────────────────────────────
                HStack(spacing: 10) {
                    ForEach(Array(engine.forecast.enumerated()), id: \.offset) { i, day in
                        ForecastDayCard(
                            day: day,
                            isToday: i == 0,
                            dayLabel: i == 0 ? "Today" : dayFmt.string(from: day.date),
                            dateLabel: dateFmt.string(from: day.date)
                        )
                    }
                }

                // ── Status banner ─────────────────────────────────────────────
                if engine.observations.isEmpty {
                    InfoBanner(
                        symbol: "info.circle", color: .blue,
                        text: "Showing pure historical averages. Log today's conditions below and the forecast will adjust based on your observations."
                    )
                } else {
                    InfoBanner(
                        symbol: "sparkles", color: .purple,
                        text: "Forecast adjusted from your \(engine.observations.count) logged day(s). Adjustment fades over 5 days."
                    )
                }

                Divider()

                // ── Log form ──────────────────────────────────────────────────
                Text("Log Conditions")
                    .font(.headline)
                ObservationForm(engine: engine)

                // ── History ───────────────────────────────────────────────────
                if !engine.observations.isEmpty {
                    Divider()
                    Text("Observation History")
                        .font(.headline)
                    VStack(spacing: 5) {
                        ForEach(engine.observations.prefix(30)) { obs in
                            ObsRow(obs: obs) { engine.delete(obs) }
                        }
                    }
                }

                // ── Reference table ───────────────────────────────────────────
                Divider()
                ClimateTable()
            }
            .padding(20)
        }
    }
}

// MARK: - Forecast Day Card

struct ForecastDayCard: View {
    let day: ForecastDay
    let isToday: Bool
    let dayLabel: String
    let dateLabel: String

    var body: some View {
        VStack(spacing: 7) {
            Text(dayLabel)
                .font(.system(size: 12, weight: isToday ? .bold : .medium))
                .foregroundStyle(isToday ? .primary : .secondary)
            Text(dateLabel)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            ZStack {
                Circle()
                    .fill(day.condition.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: day.condition.symbol)
                    .font(.system(size: 21))
                    .foregroundStyle(day.condition.color)
            }
            .padding(.vertical, 2)

            Text("\(Int(day.highF.rounded()))°F")
                .font(.system(size: 17, weight: .semibold))
            Text("\(Int(day.lowF.rounded()))°F")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 3) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.blue)
                Text("\(Int((day.rainProb * 100).rounded()))%")
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)
            }

            HStack(spacing: 3) {
                Image(systemName: "wind")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text("\(Int(day.norm.avgWindMph)) mph NE")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            if day.isObserved {
                Text("Logged ✓")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.12), in: Capsule())
            } else {
                Spacer().frame(height: 16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(isToday ? 0.10 : 0.05),
                        radius: isToday ? 6 : 3, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isToday ? Color.blue.opacity(0.35) : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Info Banner

struct InfoBanner: View {
    let symbol: String
    let color: Color
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Observation Log Form

struct ObservationForm: View {
    @ObservedObject var engine: WeatherEngine

    @State private var date = Date()
    @State private var highStr = ""
    @State private var lowStr  = ""
    @State private var cond: WeatherCondition = .sunny
    @State private var windStr = ""
    @State private var rainStr = ""
    @State private var notes   = ""
    @State private var saved   = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Date:")
                    .font(.system(size: 13, weight: .medium))
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: date) { _, d in prefill(for: d) }
                Spacer()
            }

            // Numeric fields row
            HStack(spacing: 16) {
                SmallField(label: "High °F",  hint: "88", text: $highStr)
                SmallField(label: "Low °F",   hint: "72", text: $lowStr)
                SmallField(label: "Wind mph", hint: "12", text: $windStr)
                SmallField(label: "Rain in.", hint: "0.0", text: $rainStr)
            }

            // Condition picker
            HStack(spacing: 12) {
                Text("Sky/Conditions:")
                    .font(.system(size: 13, weight: .medium))
                Picker("", selection: $cond) {
                    ForEach(WeatherCondition.allCases, id: \.self) { c in
                        Label(c.rawValue, systemImage: c.symbol).tag(c)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
                .labelsHidden()
                Spacer()
            }

            TextField("Notes (optional)…", text: $notes)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            Button {
                let obs = DailyObservation(
                    date: date,
                    highF: Double(highStr),
                    lowF:  Double(lowStr),
                    condition: cond,
                    windMph:    Double(windStr),
                    rainInches: Double(rainStr),
                    notes: notes
                )
                engine.addOrUpdate(obs)
                saved = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
            } label: {
                Label(saved ? "Saved!" : "Save Observation",
                      systemImage: saved ? "checkmark.circle.fill" : "plus.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(saved ? .green : .blue)
        }
        .onAppear { prefill(for: date) }
    }

    private func prefill(for d: Date) {
        let cal = Calendar.current
        guard let obs = engine.observations.first(where: { cal.isDate($0.date, inSameDayAs: d) }) else {
            highStr = ""; lowStr = ""; windStr = ""; rainStr = ""; notes = ""; cond = .sunny
            return
        }
        highStr = obs.highF.map { String(format: "%.0f", $0) } ?? ""
        lowStr  = obs.lowF.map  { String(format: "%.0f", $0) } ?? ""
        windStr = obs.windMph.map { String(format: "%.0f", $0) } ?? ""
        rainStr = obs.rainInches.map { String(format: "%.2f", $0) } ?? ""
        notes   = obs.notes
        cond    = obs.condition
    }
}

struct SmallField: View {
    let label: String
    let hint: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(hint, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .frame(width: 78)
        }
    }
}

// MARK: - Observation Row

struct ObsRow: View {
    let obs: DailyObservation
    let onDelete: () -> Void

    private let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE MMM d"; return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: obs.condition.symbol)
                .font(.system(size: 13))
                .foregroundStyle(obs.condition.color)
                .frame(width: 18)

            Text(fmt.string(from: obs.date))
                .font(.system(size: 12, weight: .medium))
                .frame(width: 90, alignment: .leading)

            Group {
                if let h = obs.highF, let l = obs.lowF {
                    Text("\(Int(h))° / \(Int(l))°")
                } else {
                    Text("— / —")
                }
            }
            .font(.system(size: 12))
            .frame(width: 72, alignment: .leading)

            Text(obs.condition.rawValue)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            if let w = obs.windMph {
                HStack(spacing: 2) {
                    Image(systemName: "wind").font(.system(size: 10))
                    Text("\(Int(w)) mph")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            if let r = obs.rainInches, r > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill").font(.system(size: 10)).foregroundStyle(.blue)
                    Text(String(format: "%.2f\"", r))
                }
                .font(.system(size: 11))
                .foregroundStyle(.blue)
            }

            Spacer()

            if !obs.notes.isEmpty {
                Text(obs.notes)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button(action: onDelete) {
                Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete observation")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Monthly Climate Reference Table

struct ClimateTable: View {
    private let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    private let currentMonth = Calendar.current.component(.month, from: Date()) - 1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Monthly Climate Reference")
                    .font(.headline)
                Text("Honolulu Airport · NOAA 1991–2020 normals")
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Text("Month") .font(.system(size: 11, weight: .semibold)).frame(width: 44, alignment: .leading)
                Text("High")  .font(.system(size: 11, weight: .semibold)).frame(width: 54, alignment: .trailing)
                Text("Low")   .font(.system(size: 11, weight: .semibold)).frame(width: 54, alignment: .trailing)
                Text("Rain %").font(.system(size: 11, weight: .semibold)).frame(width: 54, alignment: .trailing)
                Text("Wind")  .font(.system(size: 11, weight: .semibold)).frame(width: 60, alignment: .trailing)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)

            Divider()

            ForEach(0..<12, id: \.self) { i in
                let n = locationNormal(for: Calendar.current.date(from: DateComponents(month: i + 1)) ?? Date())
                HStack {
                    Text(months[i]).font(.system(size: 12)).frame(width: 44, alignment: .leading)
                    Text("\(Int(n.highF))°F").font(.system(size: 12)).frame(width: 54, alignment: .trailing)
                    Text("\(Int(n.lowF))°F") .font(.system(size: 12)).frame(width: 54, alignment: .trailing)
                    Text("\(Int(n.rainProbability * 100))%")
                        .font(.system(size: 12)).foregroundStyle(.blue).frame(width: 54, alignment: .trailing)
                    Text("\(Int(n.avgWindMph)) mph NE")
                        .font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    i == currentMonth ? Color.blue.opacity(0.09) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 5)
                )
            }
        }
    }
}
