import Foundation
import MapKit
import Combine

// MARK: - Tile Math

func osmTileXY(lat: Double, lon: Double, zoom: Int) -> (x: Int, y: Int) {
    let n   = pow(2.0, Double(zoom))
    let x   = Int(floor((lon + 180.0) / 360.0 * n))
    let rad = lat * .pi / 180.0
    let y   = Int(floor((1.0 - log(tan(rad) + 1.0 / cos(rad)) / .pi) / 2.0 * n))
    let maxIdx = Int(n) - 1
    return (min(maxIdx, max(0, x)), min(maxIdx, max(0, y)))
}

func tileCountInRegion(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double,
                       minZoom: Int, maxZoom: Int) -> Int {
    var count = 0
    for z in minZoom...maxZoom {
        let (x1, y1) = osmTileXY(lat: maxLat, lon: minLon, zoom: z)
        let (x2, y2) = osmTileXY(lat: minLat, lon: maxLon, zoom: z)
        count += (abs(x2 - x1) + 1) * (abs(y2 - y1) + 1)
    }
    return count
}

// MARK: - Tile Source

enum TileSource: String, Codable, CaseIterable, Identifiable {
    case osm  = "OpenStreetMap"
    case topo = "OpenTopoMap"
    var id: String { rawValue }
    var urlTemplate: String {
        switch self {
        case .osm:  return "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        case .topo: return "https://opentopomap.org/{z}/{x}/{y}.png"
        }
    }
    func url(z: Int, x: Int, y: Int) -> URL? {
        URL(string: urlTemplate
            .replacingOccurrences(of: "{z}", with: "\(z)")
            .replacingOccurrences(of: "{x}", with: "\(x)")
            .replacingOccurrences(of: "{y}", with: "\(y)"))
    }
}

// MARK: - Map Region

struct OfflineMapRegion: Codable, Identifiable, Hashable {
    var id         = UUID()
    var name       : String
    var minLat     : Double
    var maxLat     : Double
    var minLon     : Double
    var maxLon     : Double
    var minZoom    : Int        = 8
    var maxZoom    : Int        = 18
    var source     : TileSource = .osm

    var estimatedTileCount: Int {
        tileCountInRegion(minLat: minLat, maxLat: maxLat,
                          minLon: minLon, maxLon: maxLon,
                          minZoom: minZoom, maxZoom: maxZoom)
    }

    var estimatedGB: Double { Double(estimatedTileCount) * 15_000 / 1_073_741_824 }

    static func == (lhs: OfflineMapRegion, rhs: OfflineMapRegion) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Pre-defined Regions

extension OfflineMapRegion {
    /// Returns a region centered on the given coordinate with a degree buffer on each side.
    static func around(name: String, lat: Double, lon: Double, buffer: Double = 0.35) -> OfflineMapRegion {
        OfflineMapRegion(name: name,
                         minLat: lat - buffer, maxLat: lat + buffer,
                         minLon: lon - buffer, maxLon: lon + buffer)
    }

    static let builtIn: [OfflineMapRegion] = [
        // Islands get tight hand-crafted boxes
        OfflineMapRegion(name: "Oahu, HI",
                         minLat: 21.20, maxLat: 21.78,
                         minLon: -158.35, maxLon: -157.60),
        OfflineMapRegion(name: "Maui, HI",
                         minLat: 20.55, maxLat: 21.05,
                         minLon: -156.75, maxLon: -155.95),
        OfflineMapRegion(name: "Hawaii (Big Island)",
                         minLat: 18.85, maxLat: 20.30,
                         minLon: -156.10, maxLon: -154.75),
        // Mainland cities
        .around(name: "Anchorage, AK",       lat: 61.218,  lon: -149.900, buffer: 0.5),
        .around(name: "Seattle, WA",          lat: 47.606,  lon: -122.332),
        .around(name: "Portland, OR",         lat: 45.523,  lon: -122.676),
        .around(name: "San Francisco, CA",    lat: 37.775,  lon: -122.419),
        .around(name: "Los Angeles, CA",      lat: 34.052,  lon: -118.244, buffer: 0.5),
        .around(name: "San Diego, CA",        lat: 32.716,  lon: -117.161),
        .around(name: "Las Vegas, NV",        lat: 36.170,  lon: -115.140),
        .around(name: "Phoenix, AZ",          lat: 33.448,  lon: -112.074, buffer: 0.5),
        .around(name: "Denver, CO",           lat: 39.739,  lon: -104.990),
        .around(name: "Albuquerque, NM",      lat: 35.084,  lon: -106.650),
        .around(name: "Dallas, TX",           lat: 32.777,  lon: -96.797,  buffer: 0.5),
        .around(name: "Houston, TX",          lat: 29.760,  lon: -95.370,  buffer: 0.5),
        .around(name: "San Antonio, TX",      lat: 29.424,  lon: -98.494),
        .around(name: "Oklahoma City, OK",    lat: 35.468,  lon: -97.516),
        .around(name: "Kansas City, MO",      lat: 39.100,  lon: -94.579),
        .around(name: "Minneapolis, MN",      lat: 44.978,  lon: -93.265),
        .around(name: "Chicago, IL",          lat: 41.878,  lon: -87.630,  buffer: 0.5),
        .around(name: "Detroit, MI",          lat: 42.331,  lon: -83.046),
        .around(name: "Indianapolis, IN",     lat: 39.768,  lon: -86.158),
        .around(name: "Columbus, OH",         lat: 39.961,  lon: -82.999),
        .around(name: "Cleveland, OH",        lat: 41.499,  lon: -81.694),
        .around(name: "Pittsburgh, PA",       lat: 40.441,  lon: -79.996),
        .around(name: "Atlanta, GA",          lat: 33.749,  lon: -84.388, buffer: 0.5),
        .around(name: "Miami, FL",            lat: 25.762,  lon: -80.192),
        .around(name: "Orlando, FL",          lat: 28.538,  lon: -81.379),
        .around(name: "Tampa, FL",            lat: 27.951,  lon: -82.457),
        .around(name: "New Orleans, LA",      lat: 29.951,  lon: -90.072),
        .around(name: "Nashville, TN",        lat: 36.163,  lon: -86.782),
        .around(name: "Charlotte, NC",        lat: 35.227,  lon: -80.843),
        .around(name: "Washington, DC",       lat: 38.907,  lon: -77.037),
        .around(name: "Baltimore, MD",        lat: 39.290,  lon: -76.612),
        .around(name: "Philadelphia, PA",     lat: 39.953,  lon: -75.165),
        .around(name: "New York, NY",         lat: 40.713,  lon: -74.006,  buffer: 0.5),
        .around(name: "Boston, MA",           lat: 42.360,  lon: -71.059),
        .around(name: "Richmond, VA",         lat: 37.541,  lon: -77.436),
        .around(name: "Louisville, KY",       lat: 38.253,  lon: -85.759),
        .around(name: "St. Louis, MO",        lat: 38.627,  lon: -90.199),
        .around(name: "Omaha, NE",            lat: 41.257,  lon: -95.935),
        .around(name: "Salt Lake City, UT",   lat: 40.761,  lon: -111.891),
        .around(name: "Boise, ID",            lat: 43.615,  lon: -116.202),
    ]
}

// MARK: - Local Tile Overlay

class LocalTileOverlay: MKTileOverlay {
    private let tilesDir: URL
    private let fallback: MKTileOverlay?

    init(tilesDir: URL, source: TileSource) {
        self.tilesDir = tilesDir
        self.fallback = MKTileOverlay(urlTemplate: source.urlTemplate)
        self.fallback?.canReplaceMapContent = false
        super.init(urlTemplate: nil)
        self.canReplaceMapContent = true
        self.minimumZ = 0
        self.maximumZ = 19
    }

    override func loadTile(at path: MKTileOverlayPath,
                           result: @escaping (Data?, Error?) -> Void) {
        let fileURL = tilesDir
            .appendingPathComponent("\(path.z)")
            .appendingPathComponent("\(path.x)")
            .appendingPathComponent("\(path.y).png")

        if let data = try? Data(contentsOf: fileURL) {
            result(data, nil)
            return
        }

        // Tile not cached — fall back to live network
        fallback?.loadTile(at: path, result: result)
    }
}

// MARK: - Offline Map Manager

@MainActor
class OfflineMapManager: ObservableObject {
    static let shared = OfflineMapManager()

    private let regionsKey = "offline_map_regions_v1"
    private let baseDir    = URL(fileURLWithPath: "/Volumes/20TB_HDD/offline-library/offline-maps")

    @Published var regions           : [OfflineMapRegion] = []
    @Published var isDownloading     : Bool               = false
    @Published var downloadProgress  : Double             = 0       // 0–1
    @Published var downloadedTiles   : Int                = 0
    @Published var totalTiles        : Int                = 0
    @Published var currentZoom       : Int                = 0
    @Published var tilesPerSec       : Double             = 0
    @Published var activeRegionName  : String             = ""
    @Published var log               : [String]           = []
    @Published var isCancelled       : Bool               = false

    private var downloadTask: Task<Void, Never>? = nil

    init() { load() }

    // MARK: - Directory helpers

    func tilesDir(for region: OfflineMapRegion) -> URL {
        let safe = region.name
            .lowercased()
            .replacingOccurrences(of: ", ", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return baseDir.appendingPathComponent("\(safe)-\(region.source.rawValue.lowercased())")
    }

    func isDownloaded(_ region: OfflineMapRegion) -> Bool {
        let dir = tilesDir(for: region)
        return FileManager.default.fileExists(atPath: dir.path)
    }

    func diskUsage(_ region: OfflineMapRegion) -> String {
        let dir = tilesDir(for: region)
        guard let enumerator = FileManager.default.enumerator(
            at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return "0 B" }
        var bytes = 0
        for case let url as URL in enumerator {
            bytes += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        if bytes < 1_024            { return "\(bytes) B" }
        if bytes < 1_048_576        { return String(format: "%.1f KB", Double(bytes)/1_024) }
        if bytes < 1_073_741_824    { return String(format: "%.1f MB", Double(bytes)/1_048_576) }
        return String(format: "%.2f GB", Double(bytes)/1_073_741_824)
    }

    func countDownloadedTiles(_ region: OfflineMapRegion) -> Int {
        let dir = tilesDir(for: region)
        return (try? FileManager.default.subpathsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".png") }.count) ?? 0
    }

    // MARK: - Download

    func startDownload(_ region: OfflineMapRegion) {
        guard !isDownloading else { return }
        isCancelled   = false
        isDownloading = true
        downloadProgress = 0
        downloadedTiles  = 0
        totalTiles       = region.estimatedTileCount
        activeRegionName = region.name
        log              = []

        downloadTask = Task { await performDownload(region) }
    }

    func cancelDownload() {
        isCancelled = true
        downloadTask?.cancel()
        downloadTask = nil
    }

    func deleteRegion(_ region: OfflineMapRegion) {
        let dir = tilesDir(for: region)
        try? FileManager.default.removeItem(at: dir)
    }

    func addCustomRegion(_ region: OfflineMapRegion) {
        regions.append(region)
        save()
    }

    func removeRegion(_ region: OfflineMapRegion) {
        deleteRegion(region)
        regions.removeAll { $0.id == region.id }
        save()
    }

    // MARK: - Overlay

    func overlay(for region: OfflineMapRegion) -> LocalTileOverlay {
        LocalTileOverlay(tilesDir: tilesDir(for: region), source: region.source)
    }

    /// Best overlay for a given location — first downloaded region that contains it, else nil
    func bestOverlay(lat: Double, lon: Double) -> LocalTileOverlay? {
        let downloaded = regions.filter { isDownloaded($0) }
        guard let match = downloaded.first(where: {
            lat >= $0.minLat && lat <= $0.maxLat && lon >= $0.minLon && lon <= $0.maxLon
        }) else { return nil }
        return overlay(for: match)
    }

    // MARK: - Private download implementation

    private func performDownload(_ region: OfflineMapRegion) async {
        let dir = tilesDir(for: region)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            log.append("✗ Could not create directory: \(error.localizedDescription)")
            isDownloading = false
            return
        }

        // Build full tile list
        var tiles: [(z: Int, x: Int, y: Int)] = []
        for z in region.minZoom...region.maxZoom {
            let (x1, y1) = osmTileXY(lat: region.maxLat, lon: region.minLon, zoom: z)
            let (x2, y2) = osmTileXY(lat: region.minLat, lon: region.maxLon, zoom: z)
            for x in min(x1,x2)...max(x1,x2) {
                for y in min(y1,y2)...max(y1,y2) {
                    tiles.append((z, x, y))
                }
            }
        }

        totalTiles = tiles.count
        log.append("→ \(region.name) · \(region.source.rawValue)")
        log.append("  Tiles: \(tiles.count) · Zoom \(region.minZoom)–\(region.maxZoom)")
        log.append("  Est. size: \(String(format: "%.1f GB", region.estimatedGB))")
        log.append("")

        let startTime = Date()
        var completed = 0

        // 2 concurrent workers (respects OSM usage policy)
        await withTaskGroup(of: Void.self) { group in
            var index = 0
            let concurrency = 2

            // Seed initial workers
            for _ in 0..<min(concurrency, tiles.count) {
                let tile = tiles[index]; index += 1
                group.addTask { await self.downloadTile(tile, dir: dir, region: region) }
            }

            for await _ in group {
                guard !isCancelled else { break }

                completed += 1
                downloadedTiles = completed
                downloadProgress = Double(completed) / Double(tiles.count)

                let elapsed = Date().timeIntervalSince(startTime)
                tilesPerSec = elapsed > 0 ? Double(completed) / elapsed : 0

                // Log zoom level changes
                if completed > 0, completed < tiles.count {
                    let nextTile = tiles[min(completed, tiles.count - 1)]
                    if nextTile.z != currentZoom {
                        currentZoom = nextTile.z
                        log.append("  Zoom \(nextTile.z)…")
                    }
                }

                // Queue next tile
                if index < tiles.count {
                    let tile = tiles[index]; index += 1
                    group.addTask { await self.downloadTile(tile, dir: dir, region: region) }
                }
            }
        }

        if isCancelled {
            log.append("⚠ Download cancelled at \(completed)/\(tiles.count) tiles")
        } else {
            log.append("✓ Complete — \(completed) tiles")
            log.append("  Disk: \(diskUsage(region))")
        }

        isDownloading = false
        downloadProgress = isCancelled ? downloadProgress : 1.0
    }

    private func downloadTile(_ tile: (z: Int, x: Int, y: Int),
                               dir: URL, region: OfflineMapRegion) async {
        let tileDir  = dir.appendingPathComponent("\(tile.z)/\(tile.x)")
        let tileFile = tileDir.appendingPathComponent("\(tile.y).png")

        // Skip already-downloaded tiles (allows resume)
        if FileManager.default.fileExists(atPath: tileFile.path) { return }

        guard let url = region.source.url(z: tile.z, x: tile.x, y: tile.y) else { return }

        var req = URLRequest(url: url)
        req.setValue("SurvivalGuideApp/1.0 (personal offline preparedness; contact via GitHub wmb1038-dotcom/survival-guide)",
                     forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15

        do {
            try FileManager.default.createDirectory(at: tileDir, withIntermediateDirectories: true)
            let (data, _) = try await URLSession.shared.data(for: req)
            try data.write(to: tileFile)
        } catch {
            // Skip silently — partial downloads can be resumed
        }
    }

    // MARK: - Persistence

    private func save() {
        if let d = try? JSONEncoder().encode(regions) {
            UserDefaults.standard.set(d, forKey: regionsKey)
        }
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: regionsKey),
           let v = try? JSONDecoder().decode([OfflineMapRegion].self, from: d) {
            regions = v
        } else {
            // Seed built-in list on first run
            regions = OfflineMapRegion.builtIn
            save()
        }
    }
}
