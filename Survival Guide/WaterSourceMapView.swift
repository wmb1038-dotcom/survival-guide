import SwiftUI
import MapKit
import Combine

// MARK: - Models

enum WaterSourceType: String, Codable, CaseIterable, Identifiable {
    case well          = "Well"
    case spring        = "Spring"
    case stream        = "Stream / River"
    case lake          = "Lake / Pond"
    case rainCollection = "Rain Collection"
    case municipalTap  = "Municipal Tap"
    case other         = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .well:           return "circle.dotted"
        case .spring:         return "drop.circle.fill"
        case .stream:         return "water.waves"
        case .lake:           return "drop.fill"
        case .rainCollection: return "cloud.rain.fill"
        case .municipalTap:   return "spigot.fill"
        case .other:          return "mappin.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .well:           return Color(red: 0.5, green: 0.8, blue: 0.4)
        case .spring:         return .cyan
        case .stream:         return .blue
        case .lake:           return Color(red: 0.2, green: 0.5, blue: 0.9)
        case .rainCollection: return Color(red: 0.4, green: 0.7, blue: 1.0)
        case .municipalTap:   return .teal
        case .other:          return .gray
        }
    }
}

enum WaterReliability: String, Codable, CaseIterable, Identifiable {
    case yearRound = "Year-Round"
    case seasonal  = "Seasonal"
    case unknown   = "Unknown"
    var id: String { rawValue }
}

struct WaterSource: Codable, Identifiable {
    var id               = UUID()
    var name             : String           = ""
    var type             : WaterSourceType  = .well
    var latitude         : Double           = 0
    var longitude        : Double           = 0
    var reliability      : WaterReliability = .unknown
    var treatmentRequired: Bool             = true
    var estimatedGPD     : Double?          = nil
    var notes            : String           = ""
    var dateAdded        : Date             = Date()

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Engine

@MainActor
class WaterSourceEngine: ObservableObject {
    static let shared = WaterSourceEngine()
    private let key   = "water_sources_v1"

    @Published var sources: [WaterSource] = []

    init() { load() }

    func upsert(_ s: WaterSource) {
        if let i = sources.firstIndex(where: { $0.id == s.id }) { sources[i] = s }
        else { sources.append(s) }
        save()
    }

    func delete(_ s: WaterSource) { sources.removeAll { $0.id == s.id }; save() }

    private func save() {
        if let d = try? JSONEncoder().encode(sources) { UserDefaults.standard.set(d, forKey: key) }
    }
    private func load() {
        guard let d = UserDefaults.standard.data(forKey: key),
              let v = try? JSONDecoder().decode([WaterSource].self, from: d) else { return }
        sources = v
    }
}

// MARK: - Map Style

enum WaterMapStyle: String, CaseIterable, Identifiable {
    case standard  = "Standard"
    case terrain   = "Terrain"
    case satellite = "Satellite"
    case hybrid    = "Hybrid"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .standard:  return "map"
        case .terrain:   return "mountain.2"
        case .satellite: return "globe.americas.fill"
        case .hybrid:    return "map.fill"
        }
    }
}

// MARK: - MKMapView wrapper (macOS 13+ compatible, supports tap-to-place)

struct WaterMapView: NSViewRepresentable {
    @Binding var sources: [WaterSource]
    @Binding var pendingCoordinate: CLLocationCoordinate2D?
    var mapStyle: WaterMapStyle
    var initialCenter: CLLocationCoordinate2D
    var onTap: (CLLocationCoordinate2D) -> Void
    var onSelect: (WaterSource) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsZoomControls = true

        // Set initial region
        let region = MKCoordinateRegion(center: initialCenter,
                                        span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4))
        map.setRegion(region, animated: false)

        // Apply offline tile overlay if tiles are downloaded for this area
        let mgr = OfflineMapManager.shared
        if let overlay = mgr.bestOverlay(lat: initialCenter.latitude, lon: initialCenter.longitude) {
            map.addOverlay(overlay, level: .aboveRoads)
            context.coordinator.appliedOverlay = overlay
        }

        let click = NSClickGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.handleClick(_:)))
        click.numberOfClicksRequired = 2
        map.addGestureRecognizer(click)
        return map
    }

    func updateNSView(_ map: MKMapView, context: Context) {
        // Apply map style
        let newConfig: MKMapConfiguration
        switch mapStyle {
        case .standard:
            newConfig = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .default)
        case .terrain:
            newConfig = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .default)
        case .satellite:
            newConfig = MKImageryMapConfiguration(elevationStyle: .realistic)
        case .hybrid:
            newConfig = MKHybridMapConfiguration(elevationStyle: .realistic)
        }
        // Only update if changed (avoids flicker)
        if type(of: map.preferredConfiguration) != type(of: newConfig)
            || mapStyle != (map.preferredConfiguration as? MKStandardMapConfiguration).map({
                $0.elevationStyle == .realistic ? WaterMapStyle.terrain : .standard
            }) {
            map.preferredConfiguration = newConfig
        }

        // Sync annotations
        let existing = map.annotations.compactMap { $0 as? WaterAnnotation }
        let existingIDs = Set(existing.map(\.source.id))
        let newIDs = Set(sources.map(\.id))

        let toRemove = existing.filter { !newIDs.contains($0.source.id) }
        map.removeAnnotations(toRemove)

        for source in sources where !existingIDs.contains(source.id) {
            map.addAnnotation(WaterAnnotation(source: source))
        }

        // Update pending pin
        let existingPending = map.annotations.compactMap { $0 as? PendingAnnotation }
        map.removeAnnotations(existingPending)
        if let coord = pendingCoordinate {
            map.addAnnotation(PendingAnnotation(coordinate: coord))
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: WaterMapView
        var appliedOverlay: LocalTileOverlay? = nil

        init(_ parent: WaterMapView) { self.parent = parent }

        @objc func handleClick(_ recognizer: NSClickGestureRecognizer) {
            guard let map = recognizer.view as? MKMapView else { return }
            let point = recognizer.location(in: map)
            // Let clicks on built-in controls (zoom buttons, etc.) pass through
            if let hit = map.hitTest(point), !(hit is MKMapView) { return }
            let coord = map.convert(point, toCoordinateFrom: map)
            parent.onTap(coord)
        }

        func mapView(_ mapView: MKMapView, didSelect annotationView: MKAnnotationView) {
            if let wa = annotationView.annotation as? WaterAnnotation {
                parent.onSelect(wa.source)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let wa = annotation as? WaterAnnotation {
                let id = "water"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation    = wa
                view.glyphText     = wa.source.type.symbol.isEmpty ? "💧" : nil
                view.glyphImage    = nil
                view.markerTintColor = NSColor(wa.source.type.color)
                view.titleVisibility = .hidden
                view.canShowCallout  = true
                let detail = NSTextField(labelWithString: wa.source.type.rawValue)
                detail.font = .systemFont(ofSize: 11)
                view.detailCalloutAccessoryView = detail
                return view
            }
            if annotation is PendingAnnotation {
                let id = "pending"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation    = annotation
                view.markerTintColor = .systemOrange
                view.glyphText     = "+"
                return view
            }
            return nil
        }
    }
}

private class WaterAnnotation: NSObject, MKAnnotation {
    let source: WaterSource
    var coordinate: CLLocationCoordinate2D { source.coordinate }
    var title: String?    { source.name }
    var subtitle: String? { source.type.rawValue }
    init(source: WaterSource) { self.source = source }
}

private class PendingAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String? { "New Source" }
    init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
}

// MARK: - Main View

struct WaterSourceMapView: View {
    @StateObject private var engine         = WaterSourceEngine.shared
    @EnvironmentObject private var locationStore: LocationStore

    @State private var pendingCoord : CLLocationCoordinate2D? = nil
    @State private var showAddSheet : Bool           = false
    @State private var editing      : WaterSource?   = nil
    @State private var selectedForDetail: WaterSource? = nil
    @State private var mapStyle     : WaterMapStyle  = .standard

    var body: some View {
        HSplitView {
            // Map
            ZStack(alignment: .topTrailing) {
                WaterMapView(
                    sources: $engine.sources,
                    pendingCoordinate: $pendingCoord,
                    mapStyle: mapStyle,
                    initialCenter: defaultCenter,
                    onTap: { coord in
                        pendingCoord = coord
                        var s = WaterSource()
                        s.latitude  = coord.latitude
                        s.longitude = coord.longitude
                        editing = s
                        showAddSheet = true
                    },
                    onSelect: { source in selectedForDetail = source }
                )

                VStack(alignment: .trailing, spacing: 8) {
                    // Map style picker
                    HStack(spacing: 0) {
                        ForEach(WaterMapStyle.allCases) { style in
                            Button {
                                mapStyle = style
                            } label: {
                                Image(systemName: style.symbol)
                                    .font(.system(size: 11))
                                    .frame(width: 28, height: 26)
                                    .background(mapStyle == style
                                                ? Color.accentColor.opacity(0.8)
                                                : Color.clear)
                                    .foregroundStyle(mapStyle == style ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            .help(style.rawValue)
                        }
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.15)))
                    .padding(.top, 12)
                    .padding(.trailing, 12)

                    Button {
                        var s = WaterSource()
                        s.latitude  = defaultCenter.latitude
                        s.longitude = defaultCenter.longitude
                        editing = s
                        showAddSheet = true
                    } label: {
                        Label("Add Source", systemImage: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)

                    Text("Double-click map to place a source")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .padding(.trailing, 12)
                }
            }

            // Sidebar list
            VStack(spacing: 0) {
                HStack {
                    Text("Water Sources")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(engine.sources.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider()

                if engine.sources.isEmpty {
                    Spacer()
                    Text("No sources yet.\nClick the map to add one.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(engine.sources) { source in
                            WaterSourceRow(source: source)
                                .contentShape(Rectangle())
                                .onTapGesture { editing = source; showAddSheet = true }
                                .listRowBackground(
                                    selectedForDetail?.id == source.id
                                        ? Color.blue.opacity(0.12) : Color.clear
                                )
                        }
                        .onDelete { idx in idx.forEach { engine.delete(engine.sources[$0]) } }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 220, maxWidth: 260)
            .background(Color.white.opacity(0.04))
        }
        .sheet(isPresented: $showAddSheet, onDismiss: { pendingCoord = nil }) {
            if let s = editing {
                WaterSourceSheet(source: s) { saved in
                    engine.upsert(saved)
                    pendingCoord = nil
                }
            }
        }
    }

    private var defaultCenter: CLLocationCoordinate2D {
        guard !locationStore.config.nearestClimateCity.isEmpty else {
            return CLLocationCoordinate2D(latitude: 37.09, longitude: -95.71)
        }
        return cityCoords[locationStore.config.nearestClimateCity]
            ?? CLLocationCoordinate2D(latitude: 37.09, longitude: -95.71)
    }
}

// MARK: - Row

private struct WaterSourceRow: View {
    let source: WaterSource
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: source.type.symbol)
                .font(.system(size: 12))
                .foregroundStyle(source.type.color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name.isEmpty ? "Unnamed Source" : source.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(source.type.rawValue)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    if source.treatmentRequired {
                        Text("⚠ Treat")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.yellow)
                    }
                }
            }
            Spacer()
            Text(source.reliability.rawValue)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Add / Edit Sheet

struct WaterSourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var source: WaterSource
    private let onSave: (WaterSource) -> Void

    init(source: WaterSource, onSave: @escaping (WaterSource) -> Void) {
        _source = State(initialValue: source)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(source.name.isEmpty ? "New Water Source" : source.name)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(source); dismiss() }
                    .buttonStyle(.borderedProminent).tint(.blue)
                    .disabled(source.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding()
            Divider()
            Form {
                Section("Identity") {
                    TextField("Name", text: $source.name)
                    Picker("Type", selection: $source.type) {
                        ForEach(WaterSourceType.allCases) {
                            Label($0.rawValue, systemImage: $0.symbol).tag($0)
                        }
                    }
                    Picker("Reliability", selection: $source.reliability) {
                        ForEach(WaterReliability.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("Treatment Required Before Drinking", isOn: $source.treatmentRequired)
                }
                Section("Location") {
                    HStack {
                        Text("Latitude")
                        Spacer()
                        TextField("0.000000", value: $source.latitude, format: .number)
                            .multilineTextAlignment(.trailing).frame(width: 120)
                    }
                    HStack {
                        Text("Longitude")
                        Spacer()
                        TextField("0.000000", value: $source.longitude, format: .number)
                            .multilineTextAlignment(.trailing).frame(width: 120)
                    }
                }
                Section("Capacity") {
                    HStack {
                        Text("Est. gallons / day")
                        Spacer()
                        TextField("Optional", value: $source.estimatedGPD,
                                  format: .number)
                            .multilineTextAlignment(.trailing).frame(width: 80)
                    }
                }
                Section { TextField("Notes", text: $source.notes, axis: .vertical).lineLimit(3...6) }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 420, minHeight: 460)
    }
}

// MARK: - City coordinate lookup

private let cityCoords: [String: CLLocationCoordinate2D] = {
    func c(_ lat: Double, _ lon: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    return [
        "Honolulu":      c(21.307,  -157.858),
        "Anchorage":     c(61.218,  -149.900),
        "Juneau":        c(58.301,  -134.420),
        "Fairbanks":     c(64.838,  -147.716),
        "Seattle":       c(47.606,  -122.332),
        "Portland":      c(45.523,  -122.676),
        "San Francisco": c(37.775,  -122.419),
        "Los Angeles":   c(34.052,  -118.244),
        "San Diego":     c(32.716,  -117.161),
        "Las Vegas":     c(36.170,  -115.140),
        "Phoenix":       c(33.448,  -112.074),
        "Denver":        c(39.739,  -104.990),
        "Albuquerque":   c(35.084,  -106.650),
        "Dallas":        c(32.777,  -96.797),
        "Houston":       c(29.760,  -95.370),
        "San Antonio":   c(29.424,  -98.494),
        "Oklahoma City": c(35.468,  -97.516),
        "Kansas City":   c(39.100,  -94.579),
        "Minneapolis":   c(44.978,  -93.265),
        "Chicago":       c(41.878,  -87.630),
        "Detroit":       c(42.331,  -83.046),
        "Indianapolis":  c(39.768,  -86.158),
        "Columbus":      c(39.961,  -82.999),
        "Cleveland":     c(41.499,  -81.694),
        "Pittsburgh":    c(40.441,  -79.996),
        "Atlanta":       c(33.749,  -84.388),
        "Miami":         c(25.762,  -80.192),
        "Orlando":       c(28.538,  -81.379),
        "Tampa":         c(27.951,  -82.457),
        "New Orleans":   c(29.951,  -90.072),
        "Nashville":     c(36.163,  -86.782),
        "Memphis":       c(35.150,  -90.049),
        "Charlotte":     c(35.227,  -80.843),
        "Washington":    c(38.907,  -77.037),
        "Baltimore":     c(39.290,  -76.612),
        "Philadelphia":  c(39.953,  -75.165),
        "New York":      c(40.713,  -74.006),
        "Boston":        c(42.360,  -71.059),
        "Hartford":      c(41.766,  -72.685),
        "Providence":    c(41.824,  -71.413),
        "Burlington":    c(44.476,  -73.212),
        "Portland ME":   c(43.659,  -70.257),
        "Caribou":       c(46.861,  -68.012),
        "Richmond":      c(37.541,  -77.436),
        "Louisville":    c(38.253,  -85.759),
        "St. Louis":     c(38.627,  -90.199),
        "Omaha":         c(41.257,  -95.935),
        "Salt Lake City":c(40.761,  -111.891),
        "Boise":         c(43.615,  -116.202),
    ]
}()
