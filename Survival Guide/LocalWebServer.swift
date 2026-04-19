import Foundation
import Network
import Combine

// MARK: - HTTP Request helper

private struct HTTPRequest {
    let method  : String
    let path    : String
    let segments: [String]       // path split on "/", empties removed
    let body    : Data

    /// Last path segment if it looks like a UUID (for /api/resource/:id)
    var idSegment: String? {
        guard segments.count >= 3 else { return nil }
        let last = segments[segments.count - 1]
        return UUID(uuidString: last) != nil ? last : nil
    }

    func jsonDict() -> [String: Any]? {
        guard !body.isEmpty else { return nil }
        return try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    }
}

// MARK: - ISO 8601 helpers (shared encoders)

private let isoEnc: JSONEncoder = {
    let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
}()
private let isoDec: JSONDecoder = {
    let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
}()
private func isoDate(_ s: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
}
private func ok<T: Encodable>(_ v: T, status: Int = 200) -> (Int, String, Data) {
    ((try? isoEnc.encode(v)) ?? Data()).asJSON(status: status)
}
extension Data {
    func asJSON(status: Int = 200) -> (Int, String, Data) { (status, "application/json", self) }
}

// MARK: - Local Web Server

@MainActor
class LocalWebServer: ObservableObject {
    static let shared = LocalWebServer()

    @Published var isRunning  = false
    @Published var localURL   = ""
    @Published var bonjourURL = ""

    private var listener: NWListener?

    // MARK: Control

    func start(port: UInt16 = 8080) {
        guard !isRunning,
              let nwPort = NWEndpoint.Port(rawValue: port),
              let l = try? NWListener(using: .tcp, on: nwPort) else { return }
        listener = l

        l.newConnectionHandler = { [weak self] conn in
            Task { @MainActor [weak self] in self?.accept(conn) }
        }
        l.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    self.isRunning  = true
                    self.localURL   = "http://\(self.localIP()):\(port)"
                    self.bonjourURL = "http://\(self.bonjourHostname()):\(port)"
                case .failed, .cancelled:
                    self.isRunning = false; self.localURL = ""; self.bonjourURL = ""
                default: break
                }
            }
        }
        l.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel(); listener = nil
        isRunning = false; localURL = ""; bonjourURL = ""
    }

    // MARK: Accept

    private func accept(_ conn: NWConnection) {
        conn.start(queue: .global(qos: .utility))
        // Accumulate data for up to 5 seconds or 1MB
        var accumulatedData = Data()
        
        func receive() {
            conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
                if let data = data {
                    accumulatedData.append(data)
                }
                
                if isComplete || error != nil || accumulatedData.count > 1_000_000 {
                    self?.processAccumulatedData(accumulatedData, conn: conn)
                } else {
                    // Check if we have the full HTTP request (headers + body)
                    let raw = String(data: accumulatedData, encoding: .utf8) ?? ""
                    if raw.contains("\r\n\r\n") {
                        // Very basic check for Content-Length vs accumulated body
                        let parts = raw.components(separatedBy: "\r\n\r\n")
                        let headers = parts[0]
                        if let range = headers.range(of: "Content-Length: ", options: .caseInsensitive) {
                            let lengthStr = headers[range.upperBound...].components(separatedBy: "\r\n")[0]
                            if let length = Int(lengthStr.trimmingCharacters(in: .whitespaces)),
                               parts.count > 1, parts[1].utf8.count >= length {
                                self?.processAccumulatedData(accumulatedData, conn: conn)
                                return
                            }
                        } else if !headers.contains("POST") {
                            // GET requests don't need body
                            self?.processAccumulatedData(accumulatedData, conn: conn)
                            return
                        }
                    }
                    receive() // Keep receiving
                }
            }
        }
        receive()
    }

    private func processAccumulatedData(_ data: Data, conn: NWConnection) {
        let raw = String(data: data, encoding: .utf8) ?? ""
        let req = Self.parse(raw)
        Task { @MainActor [weak self] in
            guard let self else { return }
            let response = self.respond(req)
            conn.send(content: response, completion: .contentProcessed { _ in conn.cancel() })
        }
    }

    private static func parse(_ raw: String) -> HTTPRequest {
        let lines    = raw.components(separatedBy: "\r\n")
        let first    = lines.first ?? ""
        let parts    = first.components(separatedBy: " ")
        let method   = parts.count >= 1 ? parts[0] : "GET"
        let fullPath = parts.count >= 2 ? parts[1] : "/"
        let path     = fullPath.components(separatedBy: "?").first ?? "/"
        let segments = path.components(separatedBy: "/").filter { !$0.isEmpty }

        let body: Data
        if let bodyStr = raw.components(separatedBy: "\r\n\r\n").dropFirst().first {
            body = bodyStr.data(using: .utf8) ?? Data()
        } else { body = Data() }

        return HTTPRequest(method: method, path: path, segments: segments, body: body)
    }

    // MARK: Router

    private func respond(_ req: HTTPRequest) -> Data {
        print("🌐 Web Server: \(req.method) \(req.path)")
        let (status, mime, body) = route(req)
        let phrase: String
        switch status {
        case 200: phrase = "OK"
        case 201: phrase = "Created"
        case 204: phrase = "No Content"
        case 400: phrase = "Bad Request"
        case 404: phrase = "Not Found"
        case 405: phrase = "Method Not Allowed"
        default:  phrase = "Error"
        }
        let header = "HTTP/1.1 \(status) \(phrase)\r\n"
                   + "Content-Type: \(mime); charset=utf-8\r\n"
                   + "Content-Length: \(body.count)\r\n"
                   + "Connection: close\r\nCache-Control: no-store\r\n"
                   + "Access-Control-Allow-Origin: *\r\n\r\n"
        return (header.data(using: .utf8) ?? Data()) + body
    }

    private func route(_ req: HTTPRequest) -> (Int, String, Data) {
        let seg0 = req.segments.first ?? ""
        let seg1 = req.segments.count >= 2 ? req.segments[1] : ""

        if seg0 == "api" {
            switch seg1 {
            case "status":     return handleStatus()
            case "resilience": return handleResilience(req)
            case "food":   return handleFood(req)
            case "supply": return handleSupply(req)
            case "meds":   return handleMeds(req)
            case "drills": return handleDrills(req)
            case "water":  return handleWater(req)
            case "map":    return handleMap()
            default: return (404, "text/plain", "Not found".utf8data)
            }
        }
        // Everything else serves the SPA
        return (200, "text/html", appHTML().utf8data)
    }

    // MARK: - API: Status

    private func handleStatus() -> (Int, String, Data) {
        let food    = FoodRotationEngine.shared
        let power   = PowerOutageEngine.shared
        let supply  = SupplyEngine()
        let skills  = SkillTreeStore.shared
        let drills  = DrillEngine.shared
        let seeds   = SeedBankEngine.shared
        let meds    = MedicationEngine.shared
        let sources = WaterSourceEngine.shared
        let s       = AppSettingsStore.shared.settings
        let hh      = supply.household
        let res     = ResilienceEngine.shared.state

        let dailyCal  = Double(hh.adults) * s.dailyCaloriesAdult + Double(hh.children) * s.dailyCaloriesChild
        let foodDays  = dailyCal > 0 ? Int(food.totalCalories / dailyCal) : 0
        let waterGal  = supply.items.filter { $0.category == .water }.reduce(0.0) { $0 + $1.quantity }
        let waterDays = hh.waterNeededPerDay > 0 ? Int(waterGal / hh.waterNeededPerDay) : 0

        var d: [String: Any] = [
            "location":       LocationStore.shared.config.displayName,
            "resilience":     (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(res))) ?? [:],
            "water_days":     waterDays,
            "food_days":      foodDays,
            "food_expiring":  food.expiringSoon.count,
            "power_outage":   power.currentOutage != nil,
            "outages_year":   power.outagesThisYear.count,
            "medications":    meds.medications.count,
            "skills_done":    skills.completed.count,
            "skills_total":   allSkills.count,
            "drills_overdue": drills.overdue.count,
            "water_sources":  sources.sources.count,
            "seed_varieties": seeds.seeds.count,
            "generated_at":   ISO8601DateFormatter().string(from: Date()),
        ]
        if let o = power.currentOutage {
            d["outage_elapsed_min"] = Int(Date().timeIntervalSince(o.startDate) / 60)
        }
        return (try? JSONSerialization.data(withJSONObject: d, options: .prettyPrinted))
            .map { ($0).asJSON() } ?? (200, "application/json", "{}".utf8data)
    }

    private func handleResilience(_ req: HTTPRequest) -> (Int, String, Data) {
        switch req.method {
        case "POST":
            ResilienceEngine.shared.update(from: req.body)
            return (204, "text/plain", Data())
        default:
            return ok(ResilienceEngine.shared.state)
        }
    }

    // MARK: - API: Food

    private func handleFood(_ req: HTTPRequest) -> (Int, String, Data) {
        let engine = FoodRotationEngine.shared
        switch req.method {
        case "GET":
            return ok(engine.items.sorted { ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture) })
        case "POST":
            guard let item = try? isoDec.decode(FoodItem.self, from: req.body) else {
                return (400, "text/plain", "Invalid body".utf8data)
            }
            engine.upsert(item)
            return ok(item, status: 201)
        case "PATCH":
            guard let idStr = req.idSegment, let uuid = UUID(uuidString: idStr),
                  var item = engine.items.first(where: { $0.id == uuid }),
                  let j = req.jsonDict() else { return (404, "text/plain", "Not found".utf8data) }
            if let v = j["name"]           as? String { item.name = v }
            if let v = j["quantity"]       as? Double { item.quantity = v }
            if let v = j["unit"]           as? String { item.unit = v }
            if let v = j["caloriesPerUnit"]as? Double { item.caloriesPerUnit = v }
            if let v = j["category"]       as? String { item.category = FoodCategory(rawValue: v) ?? item.category }
            if let v = j["notes"]          as? String { item.notes = v }
            if let v = j["expirationDate"] as? String { item.expirationDate = isoDate(v) }
            else if j["expirationDate"]    is NSNull  { item.expirationDate = nil }
            engine.upsert(item)
            return ok(item)
        case "DELETE":
            guard let idStr = req.idSegment, let uuid = UUID(uuidString: idStr),
                  let item = engine.items.first(where: { $0.id == uuid }) else {
                return (404, "text/plain", "Not found".utf8data)
            }
            engine.delete(item)
            return (204, "text/plain", Data())
        default: return (405, "text/plain", "Method not allowed".utf8data)
        }
    }

    // MARK: - API: Supply

    private func handleSupply(_ req: HTTPRequest) -> (Int, String, Data) {
        let engine = SupplyEngine()          // loads snapshot from UserDefaults
        // We need the live engine — use the shared approach via UserDefaults round-trip
        // Supply doesn't have a static shared, so we read+write through UserDefaults directly.
        // All mutations save back to UserDefaults; the Mac UI engine will observe the change
        // on its next update cycle (or force a reload by posting a notification).
        switch req.method {
        case "GET":
            return ok(engine.items)
        case "POST":
            guard let item = try? isoDec.decode(SupplyItem.self, from: req.body) else {
                return (400, "text/plain", "Invalid body".utf8data)
            }
            engine.add(item)
            return ok(item, status: 201)
        case "PATCH":
            guard let idStr = req.idSegment, let uuid = UUID(uuidString: idStr),
                  var item = engine.items.first(where: { $0.id == uuid }),
                  let j = req.jsonDict() else { return (404, "text/plain", "Not found".utf8data) }
            if let v = j["quantity"]   as? Double { item.quantity = v }
            if let v = j["unit"]       as? String { item.unit = v }
            if let v = j["notes"]      as? String { item.notes = v }
            if let v = j["expiryDate"] as? String { item.expiryDate = isoDate(v) }
            else if j["expiryDate"]    is NSNull  { item.expiryDate = nil }
            engine.update(item)
            return ok(item)
        case "DELETE":
            guard let idStr = req.idSegment, let uuid = UUID(uuidString: idStr),
                  let item = engine.items.first(where: { $0.id == uuid }) else {
                return (404, "text/plain", "Not found".utf8data)
            }
            engine.delete(item)
            return (204, "text/plain", Data())
        default: return (405, "text/plain", "Method not allowed".utf8data)
        }
    }

    // MARK: - API: Medications

    private func handleMeds(_ req: HTTPRequest) -> (Int, String, Data) {
        let engine = MedicationEngine.shared
        switch req.method {
        case "GET":
            return ok(engine.medications)
        case "POST":
            guard let med = try? isoDec.decode(Medication.self, from: req.body) else {
                return (400, "text/plain", "Invalid body".utf8data)
            }
            engine.add(med)
            return ok(med, status: 201)
        case "PATCH":
            guard let idStr = req.idSegment, let uuid = UUID(uuidString: idStr),
                  var med = engine.medications.first(where: { $0.id == uuid }),
                  let j = req.jsonDict() else { return (404, "text/plain", "Not found".utf8data) }
            if let v = j["name"]       as? String { med.name = v }
            if let v = j["dose"]       as? String { med.dose = v }
            if let v = j["daysOnHand"] as? Int    { med.daysOnHand = v }
            if let v = j["notes"]      as? String { med.notes = v }
            if let v = j["refillDate"] as? String { med.refillDate = isoDate(v) }
            else if j["refillDate"]    is NSNull  { med.refillDate = nil }
            engine.update(med)
            return ok(med)
        case "DELETE":
            guard let idStr = req.idSegment, let uuid = UUID(uuidString: idStr),
                  let med = engine.medications.first(where: { $0.id == uuid }) else {
                return (404, "text/plain", "Not found".utf8data)
            }
            engine.delete(med)
            return (204, "text/plain", Data())
        default: return (405, "text/plain", "Method not allowed".utf8data)
        }
    }

    // MARK: - API: Drills

    private func handleDrills(_ req: HTTPRequest) -> (Int, String, Data) {
        let engine = DrillEngine.shared
        switch req.method {
        case "GET":
            struct DrillResponse: Encodable {
                let sessions: [DrillSession]
                let overdue: [[String: String]]
            }
            let overdueList = engine.overdue.map { (type, last) -> [String: String] in
                var d: [String: String] = ["type": type.rawValue]
                if let last { d["lastDate"] = ISO8601DateFormatter().string(from: last) }
                return d
            }
            let resp = DrillResponse(sessions: engine.sessions, overdue: overdueList)
            return ok(resp)
        case "POST":
            guard let session = try? isoDec.decode(DrillSession.self, from: req.body) else {
                return (400, "text/plain", "Invalid body".utf8data)
            }
            engine.upsert(session)
            return ok(session, status: 201)
        default: return (405, "text/plain", "Method not allowed".utf8data)
        }
    }

    // MARK: - API: Water Sources

    private func handleWater(_ req: HTTPRequest) -> (Int, String, Data) {
        let engine = WaterSourceEngine.shared
        switch req.method {
        case "GET":
            return ok(engine.sources)
        case "POST":
            guard let source = try? isoDec.decode(WaterSource.self, from: req.body) else {
                return (400, "text/plain", "Invalid body".utf8data)
            }
            engine.upsert(source)
            return ok(source, status: 201)
        case "PATCH":
            guard let idStr = req.idSegment, let uuid = UUID(uuidString: idStr),
                  var source = engine.sources.first(where: { $0.id == uuid }),
                  let j = req.jsonDict() else { return (404, "text/plain", "Not found".utf8data) }
            if let v = j["name"]              as? String { source.name = v }
            if let v = j["notes"]             as? String { source.notes = v }
            if let v = j["reliability"]       as? String { source.reliability = WaterReliability(rawValue: v) ?? source.reliability }
            if let v = j["treatmentRequired"] as? Bool   { source.treatmentRequired = v }
            engine.upsert(source)
            return ok(source)
        case "DELETE":
            guard let idStr = req.idSegment, let uuid = UUID(uuidString: idStr),
                  let source = engine.sources.first(where: { $0.id == uuid }) else {
                return (404, "text/plain", "Not found".utf8data)
            }
            engine.delete(source)
            return (204, "text/plain", Data())
        default: return (405, "text/plain", "Method not allowed".utf8data)
        }
    }

    // MARK: - API: Map

    private func handleMap() -> (Int, String, Data) {
        // Use Application Support for reliability
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let path = appSupport.appendingPathComponent("awareness/dashboard.html").path
        
        if fm.fileExists(atPath: path), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            return (200, "text/html", data)
        }
        return (404, "text/plain", "Map not found. Awareness engine is working in the background...".utf8data)
    }

    // MARK: - Single-Page App HTML

    // swiftlint:disable function_body_length
    private func appHTML() -> String {
        let loc     = LocationStore.shared.config.displayName
        let display = loc.isEmpty ? "Home Base" : loc
        let now     = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <meta name="apple-mobile-web-app-capable" content="yes">
        <title>\(escape(display))</title>
        <style>
        *{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}
        :root{--bg:#0d1117;--card:#161b22;--border:#21262d;--text:#c9d1d9;--dim:#8b949e;--green:#3fb950;--yellow:#d29922;--red:#f85149;--blue:#388bfd;--cyan:#39c5cf;--accent:#388bfd}
        html,body{background:var(--bg);color:var(--text);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;height:100%;overscroll-behavior:none}
        #app{display:flex;flex-direction:column;height:100vh;max-width:540px;margin:0 auto}
        #header{padding:.75rem 1rem .5rem;flex-shrink:0}
        #header h1{font-size:1.1rem;font-weight:700;color:#e6edf3}
        #header p{font-size:.7rem;color:var(--dim);margin-top:.1rem}
        #content{flex:1;overflow-y:auto;padding:.75rem 1rem 1rem}
        #tabs{display:flex;border-top:1px solid var(--border);flex-shrink:0;background:var(--card)}
        .tab-btn{flex:1;padding:.55rem .2rem .45rem;background:none;border:none;color:var(--dim);font-size:.62rem;display:flex;flex-direction:column;align-items:center;gap:.2rem;cursor:pointer;transition:color .15s}
        .tab-btn svg{width:20px;height:20px;fill:currentColor}
        .tab-btn.active{color:var(--accent)}
        /* Cards & Lists */
        .card{background:var(--card);border:1px solid var(--border);border-radius:10px;margin-bottom:.6rem;overflow:hidden}
        .row{display:flex;align-items:center;padding:.7rem .9rem;gap:.7rem;cursor:pointer;transition:background .1s}
        .row:active{background:#1c2128}
        .row+.row{border-top:1px solid var(--border)}
        .row-icon{width:28px;height:28px;border-radius:7px;display:flex;align-items:center;justify-content:center;font-size:1rem;flex-shrink:0}
        .row-body{flex:1;min-width:0}
        .row-title{font-size:.9rem;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
        .row-sub{font-size:.75rem;color:var(--dim);margin-top:.1rem}
        .row-right{text-align:right;flex-shrink:0}
        .badge{font-size:.7rem;font-weight:700;padding:.15rem .5rem;border-radius:99px}
        .badge-green{background:rgba(63,185,80,.15);color:var(--green)}
        .badge-yellow{background:rgba(210,153,34,.15);color:var(--yellow)}
        .badge-red{background:rgba(248,81,73,.15);color:var(--red)}
        .badge-dim{background:rgba(139,148,158,.1);color:var(--dim)}
        /* Section headers */
        .section-header{font-size:.7rem;font-weight:600;text-transform:uppercase;letter-spacing:.07em;color:var(--dim);padding:.6rem 0 .3rem}
        /* FAB */
        .fab{position:fixed;bottom:4.5rem;right:1rem;width:48px;height:48px;border-radius:50%;background:var(--accent);border:none;color:#fff;font-size:1.5rem;display:flex;align-items:center;justify-content:center;cursor:pointer;box-shadow:0 4px 16px rgba(0,0,0,.5);z-index:10}
        /* Sheet (bottom drawer) */
        .sheet-overlay{position:fixed;inset:0;background:rgba(0,0,0,.6);z-index:20;opacity:0;pointer-events:none;transition:opacity .2s}
        .sheet-overlay.open{opacity:1;pointer-events:auto}
        .sheet{position:fixed;bottom:0;left:0;right:0;max-width:540px;margin:0 auto;background:var(--card);border-radius:16px 16px 0 0;z-index:21;transform:translateY(100%);transition:transform .3s cubic-bezier(.32,1,.23,1);max-height:90vh;display:flex;flex-direction:column}
        .sheet.open{transform:translateY(0)}
        .sheet-handle{width:36px;height:4px;background:var(--border);border-radius:2px;margin:.75rem auto .5rem}
        .sheet-title{font-size:1rem;font-weight:700;padding:.25rem 1rem .75rem;color:#e6edf3}
        .sheet-body{overflow-y:auto;padding:0 1rem 1rem;flex:1}
        /* Form elements */
        .field{margin-bottom:.9rem}
        .field label{display:block;font-size:.75rem;font-weight:600;color:var(--dim);margin-bottom:.35rem;text-transform:uppercase;letter-spacing:.05em}
        .field input,.field select,.field textarea{width:100%;background:#0d1117;border:1px solid var(--border);border-radius:8px;padding:.6rem .75rem;color:var(--text);font-size:.95rem;-webkit-appearance:none;outline:none}
        .field input:focus,.field select:focus,.field textarea:focus{border-color:var(--accent)}
        .field textarea{min-height:70px;resize:vertical}
        .field select option{background:#0d1117}
        .btn-row{display:flex;gap:.5rem;margin-top:.25rem}
        .btn{flex:1;padding:.7rem;border-radius:8px;border:none;font-size:.9rem;font-weight:600;cursor:pointer}
        .btn-primary{background:var(--accent);color:#fff}
        .btn-danger{background:rgba(248,81,73,.15);color:var(--red);border:1px solid rgba(248,81,73,.3)}
        .btn-secondary{background:rgba(139,148,158,.1);color:var(--text)}
        /* Alert */
        .alert-bar{background:rgba(210,153,34,.08);border:1px solid rgba(210,153,34,.3);border-radius:8px;padding:.6rem .9rem;margin-bottom:.75rem;font-size:.82rem;color:var(--yellow)}
        /* Stoplights */
        .resilience-row{display:flex;gap:.5rem;margin-bottom:.75rem}
        .stoplight{flex:1;background:var(--card);border:1px solid var(--border);border-radius:8px;padding:.5rem;display:flex;flex-direction:column;gap:.2rem;cursor:help;transition:background .1s}
        .stoplight:active{background:#1c2128}
        .stoplight-header{display:flex;align-items:center;gap:.35rem}
        .stoplight-dot{width:7px;height:7px;border-radius:50%}
        .stoplight-label{font-size:.58rem;font-weight:700;text-transform:uppercase;color:var(--dim);letter-spacing:.05em}
        .stoplight-detail{font-size:.65rem;font-weight:500;line-height:1.2;height:1.6rem;overflow:hidden;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical}
        .bg-red{background:rgba(248,81,73,.12);border-color:rgba(248,81,73,.3)}
        .bg-yellow{background:rgba(210,153,34,.12);border-color:rgba(210,153,34,.3)}
        .bg-green{background:rgba(63,185,80,.12);border-color:rgba(63,185,80,.3)}
        .dot-red{background:var(--red);box-shadow:0 0 4px var(--red)}
        .dot-yellow{background:var(--yellow);box-shadow:0 0 4px var(--yellow)}
        .dot-green{background:var(--green);box-shadow:0 0 4px var(--green)}
        /* Empty state */
        .empty{text-align:center;padding:3rem 1rem;color:var(--dim);font-size:.9rem}
        /* Spinner */
        .spinner{text-align:center;padding:2rem;color:var(--dim);font-size:.85rem}
        /* Toast */
        #toast{position:fixed;top:1rem;left:50%;transform:translateX(-50%) translateY(-80px);background:#3fb950;color:#0d1117;font-weight:700;font-size:.85rem;padding:.5rem 1.2rem;border-radius:8px;z-index:99;transition:transform .3s}
        #toast.show{transform:translateX(-50%) translateY(0)}
        </style>
        </head>
        <body>
        <div id="app">
          <div id="header">
            <h1 id="loc-name">\(escape(display))</h1>
            <p id="loc-sub">\(now)</p>
          </div>
          <div id="content"><div class="spinner">Loading…</div></div>
          <nav id="tabs">
            <button class="tab-btn active" onclick="nav('home')" id="tab-home">
              <svg viewBox="0 0 24 24"><path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/></svg>Home
            </button>
            <button class="tab-btn" onclick="nav('food')" id="tab-food">
              <svg viewBox="0 0 24 24"><path d="M18.06 22.99h1.66c.84 0 1.53-.64 1.63-1.46L23 5.05h-5V1h-1.97v4.05h-4.97l.3 2.34c1.71.47 3.31 1.32 4.27 2.26 1.44 1.42 2.43 2.89 2.43 5.29v8.05zM1 21.99V21h15.03v.99c0 .55-.45 1-1.01 1H2.01c-.56 0-1.01-.45-1.01-1zm15.03-7c0-8.17-15.03-8.17-15.03 0h15.03zM1.02 17h15v2h-15z"/></svg>Food
            </button>
            <button class="tab-btn" onclick="nav('supply')" id="tab-supply">
              <svg viewBox="0 0 24 24"><path d="M20 6h-2.18c.07-.44.18-.88.18-1.33C18 2.54 15.96.5 13.5.5c-1.32 0-2.46.56-3.27 1.44L9 3.17l-1.23-1.23C6.96 1.06 5.82.5 4.5.5 2.04.5 0 2.54 0 5c0 .45.11.89.18 1.33H0v13c0 1.1.9 2 2 2h20c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-7.5-4c1.24 0 2 .76 2 2s-.76 2-2 2-2-.76-2-2 .76-2 2-2zM4.5 2.5c1.24 0 2 .76 2 2s-.76 2-2 2-2-.76-2-2 .76-2 2-2zM20 19H4v-2h16v2zm0-5H4v-6h4.08L6 10.83 7.62 12 10 8.76l1.5 2.14L13 8.76l2.5 3.53L17.38 12l-2.08-1.83H20v6z"/></svg>Supply
            </button>
            <button class="tab-btn" onclick="nav('meds')" id="tab-meds">
              <svg viewBox="0 0 24 24"><path d="M6.5 10h-2v3h-3v2h3v3h2v-3h3v-2h-3zm9-5c-3.87 0-7 3.13-7 7s3.13 7 7 7 7-3.13 7-7-3.13-7-7-7zm0 12c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm-1-7.5h2V13h-2zm0 3h2v2h-2z"/></svg>Meds
            </button>
            <button class="tab-btn" onclick="nav('more')" id="tab-more">
              <svg viewBox="0 0 24 24"><path d="M4 8h4V4H4v4zm6 12h4v-4h-4v4zm-6 0h4v-4H4v4zm0-6h4v-4H4v4zm6 0h4v-4h-4v4zm6-10v4h4V4h-4zm-6 4h4V4h-4v4zm6 6h4v-4h-4v4zm0 6h4v-4h-4v4z"/></svg>More
            </button>
          </nav>
        </div>
        <div class="sheet-overlay" id="overlay" onclick="closeSheet()"></div>
        <div class="sheet" id="sheet"><div class="sheet-handle"></div><div class="sheet-title" id="sheet-title"></div><div class="sheet-body" id="sheet-body"></div></div>
        <div id="toast"></div>

        <script>
        // ─── Core ────────────────────────────────────────────────────────────────
        let currentTab = 'home';
        function nav(tab) {
          currentTab = tab;
          document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
          document.getElementById('tab-' + tab).classList.add('active');
          render(tab);
        }
        function render(tab) {
          const c = document.getElementById('content');
          c.innerHTML = '<div class="spinner">Loading…</div>';
          if (tab === 'home')   renderHome();
          else if (tab === 'food')   renderFood();
          else if (tab === 'supply') renderSupply();
          else if (tab === 'meds')   renderMeds();
          else if (tab === 'more')   renderMore();
        }
        async function api(method, path, body) {
          const opts = { method, headers: {'Content-Type':'application/json'} };
          if (body) opts.body = JSON.stringify(body);
          const r = await fetch('/api/' + path, opts);
          if (r.status === 204) return null;
          return r.json().catch(() => null);
        }
        function toast(msg, color='#3fb950') {
          const t = document.getElementById('toast');
          t.textContent = msg; t.style.background = color;
          t.classList.add('show');
          setTimeout(() => t.classList.remove('show'), 2200);
        }
        function openSheet(title, html) {
          document.getElementById('sheet-title').textContent = title;
          document.getElementById('sheet-body').innerHTML = html;
          document.getElementById('overlay').classList.add('open');
          document.getElementById('sheet').classList.add('open');
        }
        function closeSheet() {
          document.getElementById('overlay').classList.remove('open');
          document.getElementById('sheet').classList.remove('open');
        }
        function isoToInput(iso) {
          if (!iso) return '';
          return iso.substring(0, 10);
        }
        function daysUntil(iso) {
          if (!iso) return null;
          const ms = new Date(iso) - new Date();
          return Math.round(ms / 86400000);
        }
        function expiryBadge(days) {
          if (days === null) return '<span class="badge badge-dim">No date</span>';
          if (days < 0)  return '<span class="badge badge-red">Expired</span>';
          if (days < 30) return '<span class="badge badge-red">' + days + 'd</span>';
          if (days < 90) return '<span class="badge badge-yellow">' + days + 'd</span>';
          return '<span class="badge badge-green">' + days + 'd</span>';
        }

        // ─── Home ────────────────────────────────────────────────────────────────
        async function renderHome() {
          const s = await api('GET','status');
          if (!s) { document.getElementById('content').innerHTML = '<div class="empty">Could not load status.</div>'; return; }
          const wc = s.water_days >= 14 ? 'green' : s.water_days >= 3 ? 'yellow' : 'red';
          const fc = s.food_days  >= 30 ? 'green' : s.food_days  >= 7 ? 'yellow' : 'red';
          const pc = s.power_outage ? 'red' : 'green';
          const dc = s.drills_overdue === 0 ? 'green' : 'yellow';
          const pct = s.skills_total ? Math.round(s.skills_done/s.skills_total*100) : 0;
          const sc = pct >= 50 ? 'green' : pct >= 25 ? 'yellow' : 'yellow';
          let html = '';
          if (s.power_outage) html += '<div class="alert-bar">⚡ POWER OUTAGE ACTIVE' + (s.outage_elapsed_min ? ' — ' + s.outage_elapsed_min + ' min' : '') + '</div>';
          if (s.food_expiring > 0) html += '<div class="alert-bar">⚠ ' + s.food_expiring + ' food item' + (s.food_expiring>1?'s':'') + ' expiring within 30 days</div>';
          if (s.drills_overdue > 0) html += '<div class="alert-bar">⚠ ' + s.drills_overdue + ' drill type' + (s.drills_overdue>1?'s':'') + ' overdue</div>';
          
          // Resilience Stoplights
          if (s.resilience) {
            html += '<div class="resilience-row">';
            ['weather','geological','logistics','resources'].forEach(key => {
              const r = s.resilience[key];
              if (!r) return;
              const color = r.status.toLowerCase();
              html += `<div class="stoplight bg-${color}" title="${esc(r.hoverText || r.details)}">
                <div class="stoplight-header">
                  <div class="stoplight-dot dot-${color}"></div>
                  <div class="stoplight-label">${esc(r.label)}</div>
                </div>
                <div class="stoplight-detail">${esc(r.details)}</div>
              </div>`;
            });
            html += '</div>';
          }

          const grid = [
            {v:s.water_days, u:'days', l:'Water', c:wc},
            {v:s.food_days,  u:'days', l:'Food',  c:fc},
            {v:s.power_outage?'OUT':'OK', u:s.power_outage?(s.outage_elapsed_min+'m'):(s.outages_year+' this yr'), l:'Power', c:pc},
            {v:s.drills_overdue, u:'overdue', l:'Drills', c:dc},
            {v:pct+'%', u:s.skills_done+'/'+s.skills_total, l:'Skills', c:sc},
            {v:s.medications, u:'tracked', l:'Meds', c:'text'},
            {v:s.water_sources, u:'mapped', l:'Water Src', c:'text'},
            {v:s.seed_varieties, u:'varieties', l:'Seeds', c:'text'},
          ];
          const colors = {green:'var(--green)',yellow:'var(--yellow)',red:'var(--red)',text:'var(--text)'};
          html += '<div style="display:grid;grid-template-columns:1fr 1fr;gap:.65rem;margin-bottom:.75rem">';
          grid.forEach(g => {
            html += '<div class="card" style="padding:.8rem"><div style="font-size:1.8rem;font-weight:700;color:'+colors[g.c]+'">'+g.v+'</div><div style="font-size:.7rem;color:var(--dim)">'+g.u+'</div><div style="font-size:.68rem;text-transform:uppercase;letter-spacing:.05em;color:var(--dim);margin-top:.25rem">'+g.l+'</div></div>';
          });
          html += '</div>';
          html += '<p style="font-size:.7rem;color:var(--dim);text-align:center">Tap a tab to view and edit data</p>';
          document.getElementById('content').innerHTML = html;
          document.getElementById('loc-sub').textContent = 'Updated ' + new Date().toLocaleTimeString();
        }

        // ─── Food ────────────────────────────────────────────────────────────────
        let foodItems = [];
        async function renderFood() {
          foodItems = await api('GET','food') || [];
          let html = '<div class="card">';
          if (!foodItems.length) { document.getElementById('content').innerHTML = '<div class="empty">No food items yet.<br>Tap + to add one.</div>'; addFab('food'); return; }
          foodItems.forEach((item, i) => {
            const days = daysUntil(item.expirationDate);
            html += '<div class="row" onclick="editFood('+i+')"><div class="row-body"><div class="row-title">'+esc(item.name)+'</div><div class="row-sub">'+esc(item.category)+' · '+item.quantity+' '+esc(item.unit)+'</div></div><div class="row-right">'+expiryBadge(days)+'</div></div>';
          });
          html += '</div>';
          document.getElementById('content').innerHTML = html;
          addFab('food');
        }
        function addFab(tab) {
          let fab = document.getElementById('fab'); if (fab) fab.remove();
          fab = document.createElement('button'); fab.className='fab'; fab.id='fab'; fab.innerHTML='＋';
          fab.onclick = tab==='food' ? () => editFood(-1) : tab==='supply' ? () => editSupply(-1) : tab==='meds' ? () => editMed(-1) : tab==='more' ? () => editDrill(-1) : null;
          document.getElementById('app').appendChild(fab);
        }
        function foodForm(item) {
          const cats = ['Canned','Dry Goods','Freeze-Dried','Frozen','Fresh','Beverages','Other'];
          const opts = cats.map(c => '<option'+(item&&item.category===c?' selected':'')+'>'+c+'</option>').join('');
          return `
            <div class="field"><label>Name</label><input id="f-name" value="${esc(item?.name||'')}" placeholder="e.g. Black Beans"></div>
            <div class="field"><label>Category</label><select id="f-cat">${opts}</select></div>
            <div class="field"><label>Quantity</label><input id="f-qty" type="number" min="0" step="0.1" value="${item?.quantity||1}"></div>
            <div class="field"><label>Unit</label><input id="f-unit" value="${esc(item?.unit||'cans')}" placeholder="cans, lbs, gallons…"></div>
            <div class="field"><label>Cal / unit</label><input id="f-cal" type="number" min="0" value="${item?.caloriesPerUnit||0}"></div>
            <div class="field"><label>Expiration date</label><input id="f-exp" type="date" value="${isoToInput(item?.expirationDate)}"></div>
            <div class="field"><label>Notes</label><textarea id="f-notes">${esc(item?.notes||'')}</textarea></div>`;
        }
        function editFood(idx) {
          const item = idx >= 0 ? foodItems[idx] : null;
          const title = item ? 'Edit ' + item.name : 'Add Food Item';
          let html = foodForm(item);
          html += '<div class="btn-row"><button class="btn btn-primary" onclick="saveFood('+(item?'"'+item.id+'"':'null')+')">Save</button>';
          if (item) html += '<button class="btn btn-danger" onclick="deleteFood(\\"'+item.id+'\\")">Delete</button>';
          html += '</div>';
          openSheet(title, html);
        }
        async function saveFood(id) {
          const body = {
            name: document.getElementById('f-name').value.trim(),
            category: document.getElementById('f-cat').value,
            quantity: parseFloat(document.getElementById('f-qty').value)||0,
            unit: document.getElementById('f-unit').value.trim(),
            caloriesPerUnit: parseFloat(document.getElementById('f-cal').value)||0,
            notes: document.getElementById('f-notes').value.trim(),
          };
          const exp = document.getElementById('f-exp').value;
          if (exp) body.expirationDate = new Date(exp + 'T12:00:00').toISOString();
          else body.expirationDate = null;
          if (!body.name) { toast('Name required','#f85149'); return; }
          if (id) await api('PATCH','food/'+id, body);
          else { body.id = crypto.randomUUID(); await api('POST','food', body); }
          closeSheet(); toast('Saved ✓'); renderFood();
        }
        async function deleteFood(id) {
          if (!confirm('Delete this item?')) return;
          await api('DELETE','food/'+id);
          closeSheet(); toast('Deleted'); renderFood();
        }

        // ─── Supply ──────────────────────────────────────────────────────────────
        let supplyItems = [];
        async function renderSupply() {
          supplyItems = await api('GET','supply') || [];
          const cats = [...new Set(supplyItems.map(i=>i.category))].sort();
          let html = '';
          if (!supplyItems.length) { document.getElementById('content').innerHTML = '<div class="empty">No supply items yet.<br>Add them in the Mac app first.</div>'; addFab('supply'); return; }
          cats.forEach(cat => {
            const group = supplyItems.filter(i=>i.category===cat);
            html += '<div class="section-header">'+esc(cat)+'</div><div class="card">';
            group.forEach((item,i) => {
              const idx = supplyItems.indexOf(item);
              const low = item.daysRemaining !== undefined && item.daysRemaining !== null && item.daysRemaining < 7;
              html += '<div class="row" onclick="editSupply('+idx+')"><div class="row-body"><div class="row-title">'+esc(item.name)+'</div><div class="row-sub">'+item.quantity+' '+esc(item.unit||'')+'</div></div>';
              if (low) html += '<span class="badge badge-red">Low</span>';
              html += '</div>';
            });
            html += '</div>';
          });
          document.getElementById('content').innerHTML = html;
          addFab('supply');
        }
        function editSupply(idx) {
          const item = idx >= 0 ? supplyItems[idx] : null;
          const cats = ['Water','Food','Medical','Fuel','Power','Communication','Other'];
          const opts = cats.map(c=>'<option'+(item&&item.category===c?' selected':'')+'>'+c+'</option>').join('');
          let html = `
            <div class="field"><label>Name</label><input id="s-name" value="${esc(item?.name||'')}" placeholder="Item name"></div>
            <div class="field"><label>Category</label><select id="s-cat">${opts}</select></div>
            <div class="field"><label>Quantity</label><input id="s-qty" type="number" min="0" step="0.1" value="${item?.quantity||0}"></div>
            <div class="field"><label>Unit</label><input id="s-unit" value="${esc(item?.unit||'')}" placeholder="gallons, lbs, units…"></div>
            <div class="field"><label>Notes</label><textarea id="s-notes">${esc(item?.notes||'')}</textarea></div>`;
          html += '<div class="btn-row"><button class="btn btn-primary" onclick="saveSupply('+(item?'"'+item.id+'"':'null')+')">Save</button></div>';
          openSheet(item ? 'Edit '+item.name : 'Add Supply Item', html);
        }
        async function saveSupply(id) {
          const body = {
            name: document.getElementById('s-name').value.trim(),
            category: document.getElementById('s-cat').value,
            quantity: parseFloat(document.getElementById('s-qty').value)||0,
            unit: document.getElementById('s-unit').value.trim(),
            notes: document.getElementById('s-notes').value.trim(),
          };
          if (!body.name) { toast('Name required','#f85149'); return; }
          if (id) await api('PATCH','supply/'+id, body);
          else { body.id = crypto.randomUUID(); await api('POST','supply', body); }
          closeSheet(); toast('Saved ✓'); renderSupply();
        }

        // ─── Meds ────────────────────────────────────────────────────────────────
        let meds = [];
        async function renderMeds() {
          meds = await api('GET','meds') || [];
          let html = '<div class="card">';
          if (!meds.length) { document.getElementById('content').innerHTML = '<div class="empty">No medications tracked yet.</div>'; addFab('meds'); return; }
          meds.forEach((m,i) => {
            const c = m.daysOnHand >= 30 ? 'green' : m.daysOnHand >= 14 ? 'yellow' : 'red';
            html += '<div class="row" onclick="editMed('+i+')"><div class="row-body"><div class="row-title">'+esc(m.name)+'</div><div class="row-sub">'+esc(m.dose||'')+(m.frequency?' · '+esc(m.frequency):'')+'</div></div><div class="row-right"><span class="badge badge-'+c+'">'+m.daysOnHand+'d</span></div></div>';
          });
          html += '</div>';
          document.getElementById('content').innerHTML = html;
          addFab('meds');
        }
        function editMed(idx) {
          const m = idx >= 0 ? meds[idx] : null;
          let html = `
            <div class="field"><label>Name</label><input id="m-name" value="${esc(m?.name||'')}" placeholder="e.g. Metformin"></div>
            <div class="field"><label>Dose</label><input id="m-dose" value="${esc(m?.dose||'')}" placeholder="e.g. 500mg"></div>
            <div class="field"><label>Frequency</label><input id="m-freq" value="${esc(m?.frequency||'')}" placeholder="e.g. Twice daily"></div>
            <div class="field"><label>Days on hand</label><input id="m-days" type="number" min="0" value="${m?.daysOnHand||0}"></div>
            <div class="field"><label>Refill date</label><input id="m-refill" type="date" value="${isoToInput(m?.refillDate)}"></div>
            <div class="field"><label>Notes</label><textarea id="m-notes">${esc(m?.notes||'')}</textarea></div>`;
          html += '<div class="btn-row"><button class="btn btn-primary" onclick="saveMed('+(m?'"'+m.id+'"':'null')+')">Save</button>';
          if (m) html += '<button class="btn btn-danger" onclick="deleteMed(\\"'+m.id+'\\")">Delete</button>';
          html += '</div>';
          openSheet(m ? 'Edit '+m.name : 'Add Medication', html);
        }
        async function saveMed(id) {
          const body = {
            name: document.getElementById('m-name').value.trim(),
            dose: document.getElementById('m-dose').value.trim(),
            frequency: document.getElementById('m-freq').value.trim(),
            daysOnHand: parseInt(document.getElementById('m-days').value)||0,
            notes: document.getElementById('m-notes').value.trim(),
          };
          const r = document.getElementById('m-refill').value;
          if (r) body.refillDate = new Date(r+'T12:00:00').toISOString(); else body.refillDate = null;
          if (!body.name) { toast('Name required','#f85149'); return; }
          if (id) await api('PATCH','meds/'+id, body);
          else { body.id = crypto.randomUUID(); await api('POST','meds', body); }
          closeSheet(); toast('Saved ✓'); renderMeds();
        }
        async function deleteMed(id) {
          if (!confirm('Delete this medication?')) return;
          await api('DELETE','meds/'+id);
          closeSheet(); toast('Deleted'); renderMeds();
        }

        // ─── More (Drills + Water Sources) ──────────────────────────────────────��
        let drillData = {sessions:[], overdue:[]};
        async function renderMore() {
          drillData = await api('GET','drills') || {sessions:[], overdue:[]};
          let html = '';
          if (drillData.overdue.length) {
            html += '<div class="section-header">Overdue Drills</div><div class="card">';
            drillData.overdue.forEach(d => {
              html += '<div class="row" onclick="logDrill(\\"'+d.type+'\\")"><div class="row-body"><div class="row-title">'+esc(d.type)+'</div><div class="row-sub">'+(d.lastDate?'Last: '+new Date(d.lastDate).toLocaleDateString():'Never practiced')+'</div></div><span class="badge badge-yellow">Overdue</span></div>';
            });
            html += '</div>';
          }
          if (drillData.sessions.length) {
            html += '<div class="section-header">Recent Drills</div><div class="card">';
            drillData.sessions.slice(0,5).forEach(s => {
              const oc = s.outcome==='Pass'?'green':s.outcome==='Fail'?'red':'yellow';
              html += '<div class="row"><div class="row-body"><div class="row-title">'+esc(s.type)+'</div><div class="row-sub">'+new Date(s.date).toLocaleDateString()+'</div></div><span class="badge badge-'+oc+'">'+esc(s.outcome)+'</span></div>';
            });
            html += '</div>';
          }
          html += '<button class="btn btn-primary" style="width:100%;margin-top:.75rem" onclick="logDrill(null)">+ Log New Drill</button>';
          document.getElementById('content').innerHTML = html;
        }
        function logDrill(type) {
          const types = ['Fire Evacuation','Earthquake (Drop/Cover/Hold)','Shelter-in-Place','Bug-Out Drill','Medical Response','Communications Check','Water Treatment','Power Outage Simulation','Generator Start & Transfer','Other'];
          const typeOpts = types.map(t=>'<option'+(t===type?' selected':'')+'>'+t+'</option>').join('');
          const outcomes = ['Pass','Needs Work','Fail','Practice Only'];
          const outOpts = outcomes.map(o=>'<option>'+o+'</option>').join('');
          const html = `
            <div class="field"><label>Type</label><select id="d-type">${typeOpts}</select></div>
            <div class="field"><label>Date</label><input id="d-date" type="date" value="${new Date().toISOString().substring(0,10)}"></div>
            <div class="field"><label>Participants</label><input id="d-part" type="number" min="1" value="1"></div>
            <div class="field"><label>Duration (min)</label><input id="d-dur" type="number" min="1" value="15"></div>
            <div class="field"><label>Outcome</label><select id="d-out">${outOpts}</select></div>
            <div class="field"><label>Lessons Learned</label><textarea id="d-notes" placeholder="What went well? What to improve?"></textarea></div>
            <div class="btn-row"><button class="btn btn-primary" onclick="saveDrill()">Save Drill</button></div>`;
          openSheet('Log Drill', html);
        }
        async function saveDrill() {
          const dateStr = document.getElementById('d-date').value;
          const body = {
            id: crypto.randomUUID(),
            type: document.getElementById('d-type').value,
            date: new Date(dateStr+'T12:00:00').toISOString(),
            participants: parseInt(document.getElementById('d-part').value)||1,
            durationMinutes: parseInt(document.getElementById('d-dur').value)||15,
            outcome: document.getElementById('d-out').value,
            lessonsLearned: document.getElementById('d-notes').value.trim(),
            notes: '',
          };
          await api('POST','drills', body);
          closeSheet(); toast('Drill logged ✓'); renderMore();
        }

        // ─── Utils ───────────────────────────────────────────────────────────────
        function esc(s) {
          return String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
        }

        // Boot
        renderHome();
        </script>
        </body>
        </html>
        """
    }

    // MARK: - Helpers

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func outageElapsed(_ start: Date) -> String {
        let mins = Int(Date().timeIntervalSince(start) / 60)
        let h = mins / 60, m = mins % 60
        return h == 0 ? "\(m)m elapsed" : "\(h)h \(m)m elapsed"
    }

    private func localIP() -> String {
        Host.current().addresses
            .first { !$0.contains(":") && $0 != "127.0.0.1" }
            ?? "localhost"
    }

    private func bonjourHostname() -> String {
        let host = ProcessInfo.processInfo.hostName
        if host.hasSuffix(".local") { return host }
        if !host.contains(".")     { return "\(host).local" }
        return host
    }
}

private extension String {
    var utf8data: Data { data(using: .utf8) ?? Data() }
}
