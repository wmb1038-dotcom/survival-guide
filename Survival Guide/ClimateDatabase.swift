import Foundation

// MARK: - City Climate Normal (monthly)

struct CityClimateNormals {
    let city: String
    let state: String
    let country: String
    let months: [ClimateNormal]   // 12 entries, index 0 = January

    func normal(for date: Date) -> ClimateNormal {
        let m = Calendar.current.component(.month, from: date)
        return months[m - 1]
    }
}

// MARK: - Database (NOAA / WMO 1991-2020 normals)

let climateDatabase: [CityClimateNormals] = [

    // ── Hawaii ────────────────────────────────────────────────────────────────
    CityClimateNormals(city: "Honolulu", state: "HI", country: "US", months: [
        ClimateNormal(month:1,  highF:80.4, lowF:66.4, rainProbability:0.33, avgWindMph:12),
        ClimateNormal(month:2,  highF:80.8, lowF:65.9, rainProbability:0.27, avgWindMph:12),
        ClimateNormal(month:3,  highF:81.9, lowF:67.2, rainProbability:0.29, avgWindMph:13),
        ClimateNormal(month:4,  highF:83.6, lowF:68.4, rainProbability:0.20, avgWindMph:13),
        ClimateNormal(month:5,  highF:85.5, lowF:70.3, rainProbability:0.19, avgWindMph:13),
        ClimateNormal(month:6,  highF:87.4, lowF:72.4, rainProbability:0.17, avgWindMph:11),
        ClimateNormal(month:7,  highF:88.7, lowF:73.8, rainProbability:0.16, avgWindMph:11),
        ClimateNormal(month:8,  highF:89.5, lowF:74.5, rainProbability:0.16, avgWindMph:11),
        ClimateNormal(month:9,  highF:89.2, lowF:73.8, rainProbability:0.20, avgWindMph:12),
        ClimateNormal(month:10, highF:87.3, lowF:72.6, rainProbability:0.23, avgWindMph:12),
        ClimateNormal(month:11, highF:84.3, lowF:69.9, rainProbability:0.30, avgWindMph:12),
        ClimateNormal(month:12, highF:81.4, lowF:67.3, rainProbability:0.32, avgWindMph:12),
    ]),

    // ── Florida ───────────────────────────────────────────────────────────────
    CityClimateNormals(city: "Miami", state: "FL", country: "US", months: [
        ClimateNormal(month:1,  highF:75.9, lowF:59.5, rainProbability:0.20, avgWindMph:10),
        ClimateNormal(month:2,  highF:77.3, lowF:60.6, rainProbability:0.19, avgWindMph:11),
        ClimateNormal(month:3,  highF:79.8, lowF:64.0, rainProbability:0.19, avgWindMph:12),
        ClimateNormal(month:4,  highF:83.1, lowF:67.8, rainProbability:0.17, avgWindMph:12),
        ClimateNormal(month:5,  highF:86.5, lowF:72.4, rainProbability:0.30, avgWindMph:11),
        ClimateNormal(month:6,  highF:89.2, lowF:75.6, rainProbability:0.50, avgWindMph:10),
        ClimateNormal(month:7,  highF:90.5, lowF:76.7, rainProbability:0.57, avgWindMph: 9),
        ClimateNormal(month:8,  highF:90.4, lowF:76.9, rainProbability:0.57, avgWindMph: 9),
        ClimateNormal(month:9,  highF:88.7, lowF:75.7, rainProbability:0.50, avgWindMph: 9),
        ClimateNormal(month:10, highF:85.0, lowF:71.3, rainProbability:0.30, avgWindMph:10),
        ClimateNormal(month:11, highF:79.9, lowF:65.3, rainProbability:0.22, avgWindMph:10),
        ClimateNormal(month:12, highF:76.5, lowF:60.7, rainProbability:0.20, avgWindMph:10),
    ]),
    CityClimateNormals(city: "Orlando", state: "FL", country: "US", months: [
        ClimateNormal(month:1,  highF:71.5, lowF:50.4, rainProbability:0.20, avgWindMph: 9),
        ClimateNormal(month:2,  highF:73.9, lowF:51.9, rainProbability:0.19, avgWindMph:10),
        ClimateNormal(month:3,  highF:78.3, lowF:56.5, rainProbability:0.17, avgWindMph:10),
        ClimateNormal(month:4,  highF:83.5, lowF:61.5, rainProbability:0.13, avgWindMph:10),
        ClimateNormal(month:5,  highF:88.8, lowF:67.6, rainProbability:0.27, avgWindMph: 9),
        ClimateNormal(month:6,  highF:91.5, lowF:72.6, rainProbability:0.50, avgWindMph: 8),
        ClimateNormal(month:7,  highF:92.3, lowF:74.2, rainProbability:0.57, avgWindMph: 7),
        ClimateNormal(month:8,  highF:92.2, lowF:74.3, rainProbability:0.57, avgWindMph: 7),
        ClimateNormal(month:9,  highF:89.9, lowF:73.0, rainProbability:0.43, avgWindMph: 7),
        ClimateNormal(month:10, highF:84.0, lowF:65.9, rainProbability:0.23, avgWindMph: 8),
        ClimateNormal(month:11, highF:77.4, lowF:57.7, rainProbability:0.17, avgWindMph: 8),
        ClimateNormal(month:12, highF:72.3, lowF:51.9, rainProbability:0.17, avgWindMph: 9),
    ]),
    CityClimateNormals(city: "Tampa", state: "FL", country: "US", months: [
        ClimateNormal(month:1,  highF:70.8, lowF:51.0, rainProbability:0.20, avgWindMph:10),
        ClimateNormal(month:2,  highF:73.2, lowF:52.7, rainProbability:0.19, avgWindMph:11),
        ClimateNormal(month:3,  highF:77.7, lowF:57.5, rainProbability:0.17, avgWindMph:11),
        ClimateNormal(month:4,  highF:83.4, lowF:62.5, rainProbability:0.13, avgWindMph:11),
        ClimateNormal(month:5,  highF:88.8, lowF:68.4, rainProbability:0.23, avgWindMph:10),
        ClimateNormal(month:6,  highF:91.3, lowF:73.5, rainProbability:0.47, avgWindMph: 8),
        ClimateNormal(month:7,  highF:91.9, lowF:75.0, rainProbability:0.53, avgWindMph: 7),
        ClimateNormal(month:8,  highF:91.9, lowF:75.2, rainProbability:0.53, avgWindMph: 7),
        ClimateNormal(month:9,  highF:89.7, lowF:73.4, rainProbability:0.43, avgWindMph: 8),
        ClimateNormal(month:10, highF:83.9, lowF:65.5, rainProbability:0.23, avgWindMph: 8),
        ClimateNormal(month:11, highF:77.0, lowF:57.8, rainProbability:0.17, avgWindMph: 9),
        ClimateNormal(month:12, highF:71.5, lowF:52.5, rainProbability:0.17, avgWindMph: 9),
    ]),
    CityClimateNormals(city: "Jacksonville", state: "FL", country: "US", months: [
        ClimateNormal(month:1,  highF:64.2, lowF:43.2, rainProbability:0.23, avgWindMph: 9),
        ClimateNormal(month:2,  highF:67.5, lowF:45.5, rainProbability:0.23, avgWindMph:10),
        ClimateNormal(month:3,  highF:73.7, lowF:51.6, rainProbability:0.20, avgWindMph:10),
        ClimateNormal(month:4,  highF:80.2, lowF:57.8, rainProbability:0.17, avgWindMph:10),
        ClimateNormal(month:5,  highF:86.2, lowF:65.3, rainProbability:0.23, avgWindMph: 9),
        ClimateNormal(month:6,  highF:90.2, lowF:71.4, rainProbability:0.43, avgWindMph: 8),
        ClimateNormal(month:7,  highF:91.9, lowF:73.4, rainProbability:0.50, avgWindMph: 7),
        ClimateNormal(month:8,  highF:91.3, lowF:73.4, rainProbability:0.50, avgWindMph: 7),
        ClimateNormal(month:9,  highF:87.5, lowF:70.1, rainProbability:0.37, avgWindMph: 8),
        ClimateNormal(month:10, highF:80.1, lowF:60.7, rainProbability:0.23, avgWindMph: 8),
        ClimateNormal(month:11, highF:72.3, lowF:51.3, rainProbability:0.20, avgWindMph: 8),
        ClimateNormal(month:12, highF:65.7, lowF:44.7, rainProbability:0.20, avgWindMph: 9),
    ]),

    // ── Texas ─────────────────────────────────────────────────────────────────
    CityClimateNormals(city: "Houston", state: "TX", country: "US", months: [
        ClimateNormal(month:1,  highF:62.3, lowF:43.1, rainProbability:0.33, avgWindMph:10),
        ClimateNormal(month:2,  highF:65.6, lowF:46.0, rainProbability:0.27, avgWindMph:11),
        ClimateNormal(month:3,  highF:72.3, lowF:52.7, rainProbability:0.30, avgWindMph:11),
        ClimateNormal(month:4,  highF:79.1, lowF:60.0, rainProbability:0.30, avgWindMph:11),
        ClimateNormal(month:5,  highF:85.4, lowF:67.1, rainProbability:0.37, avgWindMph:10),
        ClimateNormal(month:6,  highF:91.0, lowF:73.1, rainProbability:0.37, avgWindMph: 9),
        ClimateNormal(month:7,  highF:94.0, lowF:75.4, rainProbability:0.33, avgWindMph: 8),
        ClimateNormal(month:8,  highF:94.2, lowF:75.4, rainProbability:0.33, avgWindMph: 8),
        ClimateNormal(month:9,  highF:89.3, lowF:70.4, rainProbability:0.37, avgWindMph: 8),
        ClimateNormal(month:10, highF:81.4, lowF:60.9, rainProbability:0.30, avgWindMph: 8),
        ClimateNormal(month:11, highF:71.0, lowF:51.5, rainProbability:0.30, avgWindMph: 9),
        ClimateNormal(month:12, highF:63.4, lowF:44.7, rainProbability:0.30, avgWindMph: 9),
    ]),
    CityClimateNormals(city: "Dallas", state: "TX", country: "US", months: [
        ClimateNormal(month:1,  highF:55.5, lowF:36.0, rainProbability:0.27, avgWindMph:12),
        ClimateNormal(month:2,  highF:60.3, lowF:40.0, rainProbability:0.23, avgWindMph:13),
        ClimateNormal(month:3,  highF:68.4, lowF:47.5, rainProbability:0.27, avgWindMph:13),
        ClimateNormal(month:4,  highF:76.9, lowF:56.4, rainProbability:0.30, avgWindMph:13),
        ClimateNormal(month:5,  highF:83.9, lowF:64.3, rainProbability:0.37, avgWindMph:12),
        ClimateNormal(month:6,  highF:92.4, lowF:72.6, rainProbability:0.27, avgWindMph:11),
        ClimateNormal(month:7,  highF:97.2, lowF:77.0, rainProbability:0.20, avgWindMph:10),
        ClimateNormal(month:8,  highF:96.8, lowF:76.5, rainProbability:0.20, avgWindMph:10),
        ClimateNormal(month:9,  highF:88.6, lowF:68.3, rainProbability:0.27, avgWindMph:10),
        ClimateNormal(month:10, highF:78.3, lowF:57.2, rainProbability:0.27, avgWindMph:11),
        ClimateNormal(month:11, highF:66.5, lowF:46.6, rainProbability:0.27, avgWindMph:11),
        ClimateNormal(month:12, highF:57.0, lowF:37.9, rainProbability:0.27, avgWindMph:11),
    ]),
    CityClimateNormals(city: "San Antonio", state: "TX", country: "US", months: [
        ClimateNormal(month:1,  highF:61.8, lowF:40.8, rainProbability:0.23, avgWindMph:10),
        ClimateNormal(month:2,  highF:65.9, lowF:44.3, rainProbability:0.23, avgWindMph:11),
        ClimateNormal(month:3,  highF:73.3, lowF:51.3, rainProbability:0.23, avgWindMph:11),
        ClimateNormal(month:4,  highF:80.4, lowF:59.1, rainProbability:0.27, avgWindMph:11),
        ClimateNormal(month:5,  highF:86.6, lowF:66.6, rainProbability:0.33, avgWindMph:10),
        ClimateNormal(month:6,  highF:93.0, lowF:73.3, rainProbability:0.27, avgWindMph: 9),
        ClimateNormal(month:7,  highF:96.3, lowF:76.0, rainProbability:0.23, avgWindMph: 8),
        ClimateNormal(month:8,  highF:96.5, lowF:75.9, rainProbability:0.20, avgWindMph: 8),
        ClimateNormal(month:9,  highF:90.4, lowF:69.7, rainProbability:0.27, avgWindMph: 8),
        ClimateNormal(month:10, highF:81.1, lowF:59.7, rainProbability:0.27, avgWindMph: 9),
        ClimateNormal(month:11, highF:70.1, lowF:49.7, rainProbability:0.23, avgWindMph: 9),
        ClimateNormal(month:12, highF:62.6, lowF:41.9, rainProbability:0.23, avgWindMph:10),
    ]),

    // ── Southeast ─────────────────────────────────────────────────────────────
    CityClimateNormals(city: "Atlanta", state: "GA", country: "US", months: [
        ClimateNormal(month:1,  highF:51.9, lowF:33.8, rainProbability:0.30, avgWindMph: 9),
        ClimateNormal(month:2,  highF:56.8, lowF:37.1, rainProbability:0.27, avgWindMph:10),
        ClimateNormal(month:3,  highF:64.5, lowF:43.5, rainProbability:0.30, avgWindMph:10),
        ClimateNormal(month:4,  highF:73.0, lowF:51.4, rainProbability:0.27, avgWindMph:10),
        ClimateNormal(month:5,  highF:79.9, lowF:59.4, rainProbability:0.30, avgWindMph: 9),
        ClimateNormal(month:6,  highF:87.1, lowF:67.3, rainProbability:0.33, avgWindMph: 8),
        ClimateNormal(month:7,  highF:89.6, lowF:70.9, rainProbability:0.40, avgWindMph: 7),
        ClimateNormal(month:8,  highF:88.7, lowF:70.4, rainProbability:0.37, avgWindMph: 7),
        ClimateNormal(month:9,  highF:83.1, lowF:64.3, rainProbability:0.27, avgWindMph: 7),
        ClimateNormal(month:10, highF:73.6, lowF:52.9, rainProbability:0.23, avgWindMph: 8),
        ClimateNormal(month:11, highF:63.1, lowF:43.4, rainProbability:0.27, avgWindMph: 8),
        ClimateNormal(month:12, highF:54.1, lowF:35.7, rainProbability:0.27, avgWindMph: 9),
    ]),
    CityClimateNormals(city: "New Orleans", state: "LA", country: "US", months: [
        ClimateNormal(month:1,  highF:61.8, lowF:45.0, rainProbability:0.33, avgWindMph: 9),
        ClimateNormal(month:2,  highF:65.5, lowF:48.1, rainProbability:0.27, avgWindMph:10),
        ClimateNormal(month:3,  highF:72.5, lowF:54.9, rainProbability:0.30, avgWindMph:11),
        ClimateNormal(month:4,  highF:79.5, lowF:62.1, rainProbability:0.30, avgWindMph:10),
        ClimateNormal(month:5,  highF:85.5, lowF:68.8, rainProbability:0.37, avgWindMph: 9),
        ClimateNormal(month:6,  highF:90.7, lowF:74.5, rainProbability:0.43, avgWindMph: 8),
        ClimateNormal(month:7,  highF:91.9, lowF:76.2, rainProbability:0.50, avgWindMph: 7),
        ClimateNormal(month:8,  highF:91.6, lowF:75.8, rainProbability:0.47, avgWindMph: 7),
        ClimateNormal(month:9,  highF:87.6, lowF:71.5, rainProbability:0.40, avgWindMph: 8),
        ClimateNormal(month:10, highF:79.3, lowF:61.0, rainProbability:0.27, avgWindMph: 8),
        ClimateNormal(month:11, highF:69.9, lowF:51.8, rainProbability:0.30, avgWindMph: 8),
        ClimateNormal(month:12, highF:63.0, lowF:46.3, rainProbability:0.33, avgWindMph: 9),
    ]),
    CityClimateNormals(city: "Nashville", state: "TN", country: "US", months: [
        ClimateNormal(month:1,  highF:47.2, lowF:29.9, rainProbability:0.33, avgWindMph: 9),
        ClimateNormal(month:2,  highF:52.3, lowF:33.5, rainProbability:0.30, avgWindMph:10),
        ClimateNormal(month:3,  highF:61.2, lowF:40.7, rainProbability:0.33, avgWindMph:10),
        ClimateNormal(month:4,  highF:70.8, lowF:49.5, rainProbability:0.33, avgWindMph:10),
        ClimateNormal(month:5,  highF:78.6, lowF:57.9, rainProbability:0.37, avgWindMph: 8),
        ClimateNormal(month:6,  highF:86.4, lowF:66.2, rainProbability:0.33, avgWindMph: 7),
        ClimateNormal(month:7,  highF:90.1, lowF:70.3, rainProbability:0.33, avgWindMph: 6),
        ClimateNormal(month:8,  highF:89.3, lowF:69.5, rainProbability:0.27, avgWindMph: 6),
        ClimateNormal(month:9,  highF:82.8, lowF:62.6, rainProbability:0.27, avgWindMph: 6),
        ClimateNormal(month:10, highF:71.7, lowF:50.6, rainProbability:0.27, avgWindMph: 7),
        ClimateNormal(month:11, highF:59.9, lowF:40.8, rainProbability:0.33, avgWindMph: 8),
        ClimateNormal(month:12, highF:49.9, lowF:32.4, rainProbability:0.33, avgWindMph: 9),
    ]),

    // ── Northeast ─────────────────────────────────────────────────────────────
    CityClimateNormals(city: "New York", state: "NY", country: "US", months: [
        ClimateNormal(month:1,  highF:38.9, lowF:26.2, rainProbability:0.33, avgWindMph:12),
        ClimateNormal(month:2,  highF:41.6, lowF:28.0, rainProbability:0.27, avgWindMph:13),
        ClimateNormal(month:3,  highF:50.6, lowF:34.5, rainProbability:0.33, avgWindMph:13),
        ClimateNormal(month:4,  highF:61.5, lowF:44.2, rainProbability:0.33, avgWindMph:12),
        ClimateNormal(month:5,  highF:71.5, lowF:53.9, rainProbability:0.33, avgWindMph:11),
        ClimateNormal(month:6,  highF:80.4, lowF:63.4, rainProbability:0.33, avgWindMph:10),
        ClimateNormal(month:7,  highF:85.2, lowF:68.8, rainProbability:0.33, avgWindMph: 9),
        ClimateNormal(month:8,  highF:83.8, lowF:67.6, rainProbability:0.33, avgWindMph: 9),
        ClimateNormal(month:9,  highF:76.9, lowF:60.6, rainProbability:0.27, avgWindMph: 9),
        ClimateNormal(month:10, highF:65.7, lowF:49.7, rainProbability:0.27, avgWindMph:10),
        ClimateNormal(month:11, highF:54.3, lowF:40.2, rainProbability:0.33, avgWindMph:11),
        ClimateNormal(month:12, highF:43.5, lowF:30.4, rainProbability:0.30, avgWindMph:12),
    ]),
    CityClimateNormals(city: "Boston", state: "MA", country: "US", months: [
        ClimateNormal(month:1,  highF:36.4, lowF:22.8, rainProbability:0.37, avgWindMph:14),
        ClimateNormal(month:2,  highF:38.8, lowF:24.6, rainProbability:0.33, avgWindMph:14),
        ClimateNormal(month:3,  highF:46.8, lowF:31.7, rainProbability:0.37, avgWindMph:14),
        ClimateNormal(month:4,  highF:57.3, lowF:41.2, rainProbability:0.37, avgWindMph:13),
        ClimateNormal(month:5,  highF:67.4, lowF:50.9, rainProbability:0.37, avgWindMph:12),
        ClimateNormal(month:6,  highF:76.7, lowF:60.1, rainProbability:0.33, avgWindMph:11),
        ClimateNormal(month:7,  highF:82.3, lowF:65.8, rainProbability:0.33, avgWindMph:10),
        ClimateNormal(month:8,  highF:80.6, lowF:64.7, rainProbability:0.30, avgWindMph:10),
        ClimateNormal(month:9,  highF:73.2, lowF:57.3, rainProbability:0.33, avgWindMph:10),
        ClimateNormal(month:10, highF:62.3, lowF:46.9, rainProbability:0.33, avgWindMph:11),
        ClimateNormal(month:11, highF:51.8, lowF:37.8, rainProbability:0.37, avgWindMph:13),
        ClimateNormal(month:12, highF:40.6, lowF:27.6, rainProbability:0.37, avgWindMph:14),
    ]),
    CityClimateNormals(city: "Philadelphia", state: "PA", country: "US", months: [
        ClimateNormal(month:1,  highF:40.0, lowF:26.0, rainProbability:0.30, avgWindMph:11),
        ClimateNormal(month:2,  highF:43.6, lowF:28.4, rainProbability:0.27, avgWindMph:11),
        ClimateNormal(month:3,  highF:53.1, lowF:35.6, rainProbability:0.30, avgWindMph:11),
        ClimateNormal(month:4,  highF:64.3, lowF:45.3, rainProbability:0.30, avgWindMph:11),
        ClimateNormal(month:5,  highF:73.9, lowF:55.2, rainProbability:0.33, avgWindMph:10),
        ClimateNormal(month:6,  highF:82.5, lowF:64.6, rainProbability:0.33, avgWindMph: 9),
        ClimateNormal(month:7,  highF:87.3, lowF:70.1, rainProbability:0.33, avgWindMph: 8),
        ClimateNormal(month:8,  highF:85.5, lowF:68.4, rainProbability:0.30, avgWindMph: 8),
        ClimateNormal(month:9,  highF:78.6, lowF:61.2, rainProbability:0.27, avgWindMph: 9),
        ClimateNormal(month:10, highF:67.0, lowF:49.4, rainProbability:0.27, avgWindMph: 9),
        ClimateNormal(month:11, highF:55.7, lowF:39.8, rainProbability:0.30, avgWindMph:10),
        ClimateNormal(month:12, highF:44.6, lowF:30.0, rainProbability:0.30, avgWindMph:10),
    ]),

    // ── Midwest ───────────────────────────────────────────────────────────────
    CityClimateNormals(city: "Chicago", state: "IL", country: "US", months: [
        ClimateNormal(month:1,  highF:32.2, lowF:18.6, rainProbability:0.30, avgWindMph:13),
        ClimateNormal(month:2,  highF:36.5, lowF:22.2, rainProbability:0.27, avgWindMph:13),
        ClimateNormal(month:3,  highF:47.5, lowF:31.5, rainProbability:0.33, avgWindMph:14),
        ClimateNormal(month:4,  highF:59.4, lowF:42.0, rainProbability:0.33, avgWindMph:13),
        ClimateNormal(month:5,  highF:70.1, lowF:51.8, rainProbability:0.37, avgWindMph:11),
        ClimateNormal(month:6,  highF:80.0, lowF:62.0, rainProbability:0.37, avgWindMph:10),
        ClimateNormal(month:7,  highF:84.6, lowF:67.3, rainProbability:0.33, avgWindMph: 9),
        ClimateNormal(month:8,  highF:82.7, lowF:65.6, rainProbability:0.30, avgWindMph: 9),
        ClimateNormal(month:9,  highF:75.4, lowF:57.9, rainProbability:0.30, avgWindMph:10),
        ClimateNormal(month:10, highF:62.8, lowF:46.3, rainProbability:0.30, avgWindMph:11),
        ClimateNormal(month:11, highF:48.2, lowF:34.9, rainProbability:0.33, avgWindMph:12),
        ClimateNormal(month:12, highF:35.7, lowF:23.2, rainProbability:0.30, avgWindMph:13),
    ]),
    CityClimateNormals(city: "Minneapolis", state: "MN", country: "US", months: [
        ClimateNormal(month:1,  highF:22.8, lowF: 6.3, rainProbability:0.30, avgWindMph:11),
        ClimateNormal(month:2,  highF:28.4, lowF:11.7, rainProbability:0.27, avgWindMph:11),
        ClimateNormal(month:3,  highF:41.9, lowF:24.8, rainProbability:0.30, avgWindMph:12),
        ClimateNormal(month:4,  highF:58.0, lowF:38.3, rainProbability:0.33, avgWindMph:12),
        ClimateNormal(month:5,  highF:70.3, lowF:49.5, rainProbability:0.37, avgWindMph:11),
        ClimateNormal(month:6,  highF:79.9, lowF:59.4, rainProbability:0.40, avgWindMph: 9),
        ClimateNormal(month:7,  highF:84.9, lowF:64.6, rainProbability:0.37, avgWindMph: 8),
        ClimateNormal(month:8,  highF:83.0, lowF:62.5, rainProbability:0.33, avgWindMph: 8),
        ClimateNormal(month:9,  highF:73.5, lowF:52.7, rainProbability:0.33, avgWindMph: 9),
        ClimateNormal(month:10, highF:59.1, lowF:40.3, rainProbability:0.30, avgWindMph:10),
        ClimateNormal(month:11, highF:40.9, lowF:26.0, rainProbability:0.30, avgWindMph:11),
        ClimateNormal(month:12, highF:26.7, lowF:12.4, rainProbability:0.27, avgWindMph:11),
    ]),

    // ── West Coast ────────────────────────────────────────────────────────────
    CityClimateNormals(city: "Los Angeles", state: "CA", country: "US", months: [
        ClimateNormal(month:1,  highF:68.4, lowF:48.8, rainProbability:0.27, avgWindMph: 7),
        ClimateNormal(month:2,  highF:69.8, lowF:50.5, rainProbability:0.23, avgWindMph: 8),
        ClimateNormal(month:3,  highF:70.2, lowF:52.4, rainProbability:0.17, avgWindMph: 8),
        ClimateNormal(month:4,  highF:72.4, lowF:55.1, rainProbability:0.10, avgWindMph: 8),
        ClimateNormal(month:5,  highF:74.0, lowF:58.3, rainProbability:0.07, avgWindMph: 8),
        ClimateNormal(month:6,  highF:78.2, lowF:62.6, rainProbability:0.03, avgWindMph: 8),
        ClimateNormal(month:7,  highF:83.5, lowF:65.8, rainProbability:0.03, avgWindMph: 7),
        ClimateNormal(month:8,  highF:84.3, lowF:66.8, rainProbability:0.03, avgWindMph: 7),
        ClimateNormal(month:9,  highF:82.6, lowF:65.2, rainProbability:0.07, avgWindMph: 7),
        ClimateNormal(month:10, highF:77.2, lowF:59.9, rainProbability:0.10, avgWindMph: 7),
        ClimateNormal(month:11, highF:72.3, lowF:53.5, rainProbability:0.17, avgWindMph: 7),
        ClimateNormal(month:12, highF:67.6, lowF:48.7, rainProbability:0.23, avgWindMph: 7),
    ]),
    CityClimateNormals(city: "San Francisco", state: "CA", country: "US", months: [
        ClimateNormal(month:1,  highF:57.0, lowF:46.2, rainProbability:0.40, avgWindMph:10),
        ClimateNormal(month:2,  highF:59.9, lowF:48.1, rainProbability:0.37, avgWindMph:11),
        ClimateNormal(month:3,  highF:62.0, lowF:49.4, rainProbability:0.30, avgWindMph:12),
        ClimateNormal(month:4,  highF:63.5, lowF:50.7, rainProbability:0.17, avgWindMph:13),
        ClimateNormal(month:5,  highF:65.0, lowF:52.5, rainProbability:0.10, avgWindMph:14),
        ClimateNormal(month:6,  highF:67.3, lowF:54.8, rainProbability:0.03, avgWindMph:14),
        ClimateNormal(month:7,  highF:66.9, lowF:55.3, rainProbability:0.03, avgWindMph:14),
        ClimateNormal(month:8,  highF:68.1, lowF:56.2, rainProbability:0.03, avgWindMph:13),
        ClimateNormal(month:9,  highF:70.4, lowF:56.5, rainProbability:0.07, avgWindMph:12),
        ClimateNormal(month:10, highF:68.4, lowF:54.0, rainProbability:0.17, avgWindMph:11),
        ClimateNormal(month:11, highF:62.2, lowF:50.3, rainProbability:0.33, avgWindMph:10),
        ClimateNormal(month:12, highF:57.2, lowF:46.8, rainProbability:0.40, avgWindMph:10),
    ]),
    CityClimateNormals(city: "Seattle", state: "WA", country: "US", months: [
        ClimateNormal(month:1,  highF:46.7, lowF:37.0, rainProbability:0.57, avgWindMph: 9),
        ClimateNormal(month:2,  highF:50.2, lowF:38.2, rainProbability:0.50, avgWindMph: 9),
        ClimateNormal(month:3,  highF:54.4, lowF:40.3, rainProbability:0.50, avgWindMph:10),
        ClimateNormal(month:4,  highF:59.4, lowF:43.7, rainProbability:0.43, avgWindMph: 9),
        ClimateNormal(month:5,  highF:65.6, lowF:48.5, rainProbability:0.37, avgWindMph: 9),
        ClimateNormal(month:6,  highF:70.5, lowF:53.1, rainProbability:0.27, avgWindMph: 8),
        ClimateNormal(month:7,  highF:77.4, lowF:57.5, rainProbability:0.13, avgWindMph: 8),
        ClimateNormal(month:8,  highF:77.5, lowF:58.0, rainProbability:0.13, avgWindMph: 7),
        ClimateNormal(month:9,  highF:71.4, lowF:53.6, rainProbability:0.23, avgWindMph: 7),
        ClimateNormal(month:10, highF:59.5, lowF:46.9, rainProbability:0.43, avgWindMph: 8),
        ClimateNormal(month:11, highF:50.5, lowF:40.7, rainProbability:0.57, avgWindMph: 8),
        ClimateNormal(month:12, highF:45.7, lowF:36.5, rainProbability:0.57, avgWindMph: 9),
    ]),

    // ── Mountain / Desert ─────────────────────────────────────────────────────
    CityClimateNormals(city: "Phoenix", state: "AZ", country: "US", months: [
        ClimateNormal(month:1,  highF:67.0, lowF:44.0, rainProbability:0.13, avgWindMph: 7),
        ClimateNormal(month:2,  highF:71.5, lowF:47.2, rainProbability:0.13, avgWindMph: 8),
        ClimateNormal(month:3,  highF:77.6, lowF:51.7, rainProbability:0.13, avgWindMph: 9),
        ClimateNormal(month:4,  highF:86.7, lowF:59.0, rainProbability:0.07, avgWindMph:10),
        ClimateNormal(month:5,  highF:96.0, lowF:67.9, rainProbability:0.07, avgWindMph:10),
        ClimateNormal(month:6,  highF:105.3, lowF:76.7, rainProbability:0.10, avgWindMph: 9),
        ClimateNormal(month:7,  highF:105.8, lowF:83.6, rainProbability:0.33, avgWindMph: 8),
        ClimateNormal(month:8,  highF:103.7, lowF:82.0, rainProbability:0.33, avgWindMph: 8),
        ClimateNormal(month:9,  highF:98.4, lowF:74.9, rainProbability:0.20, avgWindMph: 7),
        ClimateNormal(month:10, highF:87.3, lowF:62.9, rainProbability:0.13, avgWindMph: 7),
        ClimateNormal(month:11, highF:75.4, lowF:51.0, rainProbability:0.10, avgWindMph: 7),
        ClimateNormal(month:12, highF:66.8, lowF:44.4, rainProbability:0.13, avgWindMph: 7),
    ]),
    CityClimateNormals(city: "Denver", state: "CO", country: "US", months: [
        ClimateNormal(month:1,  highF:44.5, lowF:18.6, rainProbability:0.23, avgWindMph: 9),
        ClimateNormal(month:2,  highF:47.8, lowF:22.1, rainProbability:0.23, avgWindMph:10),
        ClimateNormal(month:3,  highF:54.7, lowF:28.4, rainProbability:0.30, avgWindMph:11),
        ClimateNormal(month:4,  highF:62.6, lowF:37.0, rainProbability:0.30, avgWindMph:11),
        ClimateNormal(month:5,  highF:71.5, lowF:46.2, rainProbability:0.37, avgWindMph:11),
        ClimateNormal(month:6,  highF:82.3, lowF:55.7, rainProbability:0.33, avgWindMph:10),
        ClimateNormal(month:7,  highF:88.7, lowF:62.1, rainProbability:0.37, avgWindMph: 9),
        ClimateNormal(month:8,  highF:86.1, lowF:60.3, rainProbability:0.33, avgWindMph: 9),
        ClimateNormal(month:9,  highF:77.4, lowF:50.5, rainProbability:0.27, avgWindMph: 9),
        ClimateNormal(month:10, highF:65.7, lowF:38.7, rainProbability:0.23, avgWindMph: 9),
        ClimateNormal(month:11, highF:52.4, lowF:27.5, rainProbability:0.23, avgWindMph: 9),
        ClimateNormal(month:12, highF:44.8, lowF:19.9, rainProbability:0.23, avgWindMph: 9),
    ]),
    CityClimateNormals(city: "Las Vegas", state: "NV", country: "US", months: [
        ClimateNormal(month:1,  highF:57.3, lowF:37.1, rainProbability:0.13, avgWindMph: 8),
        ClimateNormal(month:2,  highF:63.4, lowF:42.0, rainProbability:0.10, avgWindMph: 9),
        ClimateNormal(month:3,  highF:70.6, lowF:47.9, rainProbability:0.13, avgWindMph:10),
        ClimateNormal(month:4,  highF:80.2, lowF:56.5, rainProbability:0.07, avgWindMph:10),
        ClimateNormal(month:5,  highF:89.9, lowF:65.4, rainProbability:0.07, avgWindMph:10),
        ClimateNormal(month:6,  highF:100.2, lowF:74.8, rainProbability:0.07, avgWindMph: 9),
        ClimateNormal(month:7,  highF:104.5, lowF:81.1, rainProbability:0.17, avgWindMph: 8),
        ClimateNormal(month:8,  highF:101.9, lowF:78.9, rainProbability:0.17, avgWindMph: 8),
        ClimateNormal(month:9,  highF:94.5, lowF:70.8, rainProbability:0.10, avgWindMph: 7),
        ClimateNormal(month:10, highF:81.2, lowF:58.4, rainProbability:0.07, avgWindMph: 7),
        ClimateNormal(month:11, highF:66.7, lowF:46.1, rainProbability:0.10, avgWindMph: 7),
        ClimateNormal(month:12, highF:56.9, lowF:37.1, rainProbability:0.10, avgWindMph: 8),
    ]),

    // ── Alaska ────────────────────────────────────────────────────────────────
    CityClimateNormals(city: "Anchorage", state: "AK", country: "US", months: [
        ClimateNormal(month:1,  highF:22.5, lowF: 8.9, rainProbability:0.37, avgWindMph: 7),
        ClimateNormal(month:2,  highF:27.5, lowF:13.1, rainProbability:0.30, avgWindMph: 8),
        ClimateNormal(month:3,  highF:35.5, lowF:18.5, rainProbability:0.30, avgWindMph: 8),
        ClimateNormal(month:4,  highF:46.5, lowF:29.2, rainProbability:0.27, avgWindMph: 9),
        ClimateNormal(month:5,  highF:57.5, lowF:38.9, rainProbability:0.30, avgWindMph: 9),
        ClimateNormal(month:6,  highF:65.8, lowF:47.9, rainProbability:0.33, avgWindMph: 8),
        ClimateNormal(month:7,  highF:65.8, lowF:52.5, rainProbability:0.43, avgWindMph: 7),
        ClimateNormal(month:8,  highF:63.7, lowF:50.4, rainProbability:0.43, avgWindMph: 7),
        ClimateNormal(month:9,  highF:55.0, lowF:42.3, rainProbability:0.43, avgWindMph: 7),
        ClimateNormal(month:10, highF:40.6, lowF:29.2, rainProbability:0.43, avgWindMph: 7),
        ClimateNormal(month:11, highF:28.5, lowF:16.7, rainProbability:0.37, avgWindMph: 7),
        ClimateNormal(month:12, highF:22.5, lowF: 9.8, rainProbability:0.37, avgWindMph: 7),
    ]),

    // ── International ─────────────────────────────────────────────────────────
    CityClimateNormals(city: "London", state: "England", country: "UK", months: [
        ClimateNormal(month:1,  highF:46.6, lowF:37.9, rainProbability:0.43, avgWindMph:12),
        ClimateNormal(month:2,  highF:48.0, lowF:37.9, rainProbability:0.37, avgWindMph:12),
        ClimateNormal(month:3,  highF:52.9, lowF:40.8, rainProbability:0.37, avgWindMph:12),
        ClimateNormal(month:4,  highF:59.2, lowF:44.8, rainProbability:0.33, avgWindMph:11),
        ClimateNormal(month:5,  highF:65.7, lowF:49.5, rainProbability:0.33, avgWindMph:10),
        ClimateNormal(month:6,  highF:72.3, lowF:55.4, rainProbability:0.33, avgWindMph: 9),
        ClimateNormal(month:7,  highF:75.6, lowF:59.0, rainProbability:0.33, avgWindMph: 9),
        ClimateNormal(month:8,  highF:75.0, lowF:58.8, rainProbability:0.30, avgWindMph: 9),
        ClimateNormal(month:9,  highF:69.3, lowF:54.1, rainProbability:0.37, avgWindMph: 9),
        ClimateNormal(month:10, highF:61.3, lowF:48.2, rainProbability:0.43, avgWindMph:11),
        ClimateNormal(month:11, highF:52.7, lowF:42.8, rainProbability:0.43, avgWindMph:11),
        ClimateNormal(month:12, highF:47.5, lowF:38.8, rainProbability:0.43, avgWindMph:12),
    ]),
    CityClimateNormals(city: "Tokyo", state: "Kanto", country: "Japan", months: [
        ClimateNormal(month:1,  highF:49.1, lowF:35.1, rainProbability:0.17, avgWindMph: 9),
        ClimateNormal(month:2,  highF:51.1, lowF:37.0, rainProbability:0.20, avgWindMph:10),
        ClimateNormal(month:3,  highF:57.9, lowF:43.7, rainProbability:0.27, avgWindMph:10),
        ClimateNormal(month:4,  highF:67.6, lowF:53.4, rainProbability:0.33, avgWindMph:10),
        ClimateNormal(month:5,  highF:75.0, lowF:61.3, rainProbability:0.37, avgWindMph: 9),
        ClimateNormal(month:6,  highF:79.9, lowF:68.0, rainProbability:0.53, avgWindMph: 9),
        ClimateNormal(month:7,  highF:86.2, lowF:74.7, rainProbability:0.43, avgWindMph: 9),
        ClimateNormal(month:8,  highF:88.7, lowF:76.3, rainProbability:0.40, avgWindMph: 9),
        ClimateNormal(month:9,  highF:82.2, lowF:69.8, rainProbability:0.50, avgWindMph: 9),
        ClimateNormal(month:10, highF:72.0, lowF:59.2, rainProbability:0.37, avgWindMph: 9),
        ClimateNormal(month:11, highF:62.2, lowF:49.8, rainProbability:0.27, avgWindMph: 9),
        ClimateNormal(month:12, highF:53.6, lowF:40.3, rainProbability:0.17, avgWindMph: 9),
    ]),
    CityClimateNormals(city: "Sydney", state: "NSW", country: "Australia", months: [
        ClimateNormal(month:1,  highF:79.9, lowF:65.7, rainProbability:0.33, avgWindMph:11),
        ClimateNormal(month:2,  highF:79.5, lowF:65.7, rainProbability:0.33, avgWindMph:11),
        ClimateNormal(month:3,  highF:76.8, lowF:63.3, rainProbability:0.33, avgWindMph:10),
        ClimateNormal(month:4,  highF:71.4, lowF:57.9, rainProbability:0.30, avgWindMph: 9),
        ClimateNormal(month:5,  highF:65.3, lowF:52.2, rainProbability:0.30, avgWindMph: 9),
        ClimateNormal(month:6,  highF:60.8, lowF:47.5, rainProbability:0.33, avgWindMph: 9),
        ClimateNormal(month:7,  highF:59.9, lowF:46.4, rainProbability:0.27, avgWindMph:10),
        ClimateNormal(month:8,  highF:62.1, lowF:47.8, rainProbability:0.27, avgWindMph:10),
        ClimateNormal(month:9,  highF:66.6, lowF:51.8, rainProbability:0.27, avgWindMph:10),
        ClimateNormal(month:10, highF:71.6, lowF:56.8, rainProbability:0.30, avgWindMph:11),
        ClimateNormal(month:11, highF:75.6, lowF:60.6, rainProbability:0.30, avgWindMph:11),
        ClimateNormal(month:12, highF:78.4, lowF:63.9, rainProbability:0.30, avgWindMph:11),
    ]),
    CityClimateNormals(city: "Toronto", state: "Ontario", country: "Canada", months: [
        ClimateNormal(month:1,  highF:30.6, lowF:19.2, rainProbability:0.37, avgWindMph:12),
        ClimateNormal(month:2,  highF:32.5, lowF:20.1, rainProbability:0.33, avgWindMph:12),
        ClimateNormal(month:3,  highF:41.5, lowF:28.2, rainProbability:0.33, avgWindMph:12),
        ClimateNormal(month:4,  highF:54.5, lowF:38.7, rainProbability:0.37, avgWindMph:12),
        ClimateNormal(month:5,  highF:65.7, lowF:49.1, rainProbability:0.37, avgWindMph:10),
        ClimateNormal(month:6,  highF:75.2, lowF:58.5, rainProbability:0.37, avgWindMph: 9),
        ClimateNormal(month:7,  highF:80.2, lowF:63.7, rainProbability:0.33, avgWindMph: 9),
        ClimateNormal(month:8,  highF:78.8, lowF:62.6, rainProbability:0.30, avgWindMph: 9),
        ClimateNormal(month:9,  highF:70.3, lowF:54.9, rainProbability:0.33, avgWindMph: 9),
        ClimateNormal(month:10, highF:57.9, lowF:44.2, rainProbability:0.37, avgWindMph:10),
        ClimateNormal(month:11, highF:45.9, lowF:35.2, rainProbability:0.40, avgWindMph:11),
        ClimateNormal(month:12, highF:34.7, lowF:24.1, rainProbability:0.37, avgWindMph:12),
    ]),
]

// MARK: - Lookup

/// Find the best matching city or fall back to a generic temperate normal
func findClimateNormals(for config: LocationConfig) -> CityClimateNormals? {
    let city    = config.nearestClimateCity.lowercased().trimmingCharacters(in: .whitespaces)
    let entered = config.city.lowercased().trimmingCharacters(in: .whitespaces)

    // Try exact match on nearestClimateCity first, then city field
    for target in [city, entered] {
        if let match = climateDatabase.first(where: { $0.city.lowercased() == target }) {
            return match
        }
    }
    // Partial / contains match
    for target in [city, entered] where !target.isEmpty {
        if let match = climateDatabase.first(where: {
            $0.city.lowercased().contains(target) || target.contains($0.city.lowercased())
        }) {
            return match
        }
    }
    return nil
}

/// All city names for autocomplete / picker display
var allCityNames: [String] {
    climateDatabase.map { "\($0.city), \($0.state)" }.sorted()
}
