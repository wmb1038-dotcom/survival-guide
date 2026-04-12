import Foundation
import Network
import Combine

// MARK: - Local Web Server
//
// Serves a read-only status dashboard and JSON API to any browser on the
// local network. Start/stop from Settings → Web Server. Auto-starts on
// launch when enabled in AppSettings.

@MainActor
class LocalWebServer: ObservableObject {
    static let shared = LocalWebServer()

    @Published var isRunning = false
    @Published var localURL  = ""

    private var listener: NWListener?

    // MARK: - Control

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
                    self.isRunning = true
                    let ip = self.localIP()
                    self.localURL = "http://\(ip):\(port)"
                case .failed, .cancelled:
                    self.isRunning = false
                    self.localURL  = ""
                default: break
                }
            }
        }
        l.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel()
        listener  = nil
        isRunning = false
        localURL  = ""
    }

    // MARK: - Accept connection

    private func accept(_ conn: NWConnection) {
        conn.start(queue: .global(qos: .utility))
        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let data else { conn.cancel(); return }
            let reqStr = String(data: data, encoding: .utf8) ?? ""
            let path   = Self.parsePath(from: reqStr)
            Task { @MainActor [weak self] in
                guard let self else { return }
                let response = self.respond(to: path)
                conn.send(content: response,
                          completion: .contentProcessed { _ in conn.cancel() })
            }
        }
    }

    private static func parsePath(from request: String) -> String {
        let firstLine = request.components(separatedBy: "\r\n").first ?? ""
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return "/" }
        return parts[1].components(separatedBy: "?").first ?? "/"
    }

    // MARK: - Router

    private func respond(to path: String) -> Data {
        let (status, mime, body): (Int, String, Data) = {
            switch path {
            case "/", "/index.html":
                return (200, "text/html",
                        (dashboardHTML()).data(using: .utf8) ?? Data())
            case "/api/status":
                return (200, "application/json", statusJSON())
            default:
                return (404, "text/plain", "Not found".data(using: .utf8)!)
            }
        }()
        let statusText = status == 200 ? "OK" : "Not Found"
        let header = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: \(mime); charset=utf-8\r
        Content-Length: \(body.count)\r
        Connection: close\r
        Cache-Control: no-store\r
        \r

        """
        return (header.data(using: .utf8) ?? Data()) + body
    }

    // MARK: - JSON API  (/api/status)

    private func statusJSON() -> Data {
        let food     = FoodRotationEngine.shared
        let power    = PowerOutageEngine.shared
        let supply   = SupplyEngine()
        let skills   = SkillTreeStore.shared
        let drills   = DrillEngine.shared
        let seeds    = SeedBankEngine.shared
        let meds     = MedicationEngine.shared
        let sources  = WaterSourceEngine.shared
        let settings = AppSettingsStore.shared.settings
        let hh       = supply.household

        let dailyCal  = Double(hh.adults)   * settings.dailyCaloriesAdult
                      + Double(hh.children) * settings.dailyCaloriesChild
        let foodDays  = dailyCal > 0
            ? Int(food.totalCalories / dailyCal) : 0
        let waterGal  = supply.items
            .filter { $0.category == .water }
            .reduce(0.0) { $0 + $1.quantity }
        let waterDays = hh.waterNeededPerDay > 0
            ? Int(waterGal / hh.waterNeededPerDay) : 0

        var dict: [String: Any] = [
            "location":        LocationStore.shared.config.displayName,
            "water_days":      waterDays,
            "food_days":       foodDays,
            "food_calories":   Int(food.totalCalories),
            "food_expiring":   food.expiringSoon.count,
            "power_outage":    power.currentOutage != nil,
            "outages_year":    power.outagesThisYear.count,
            "medications":     meds.medications.count,
            "skills_done":     skills.completed.count,
            "skills_total":    allSkills.count,
            "drills_overdue":  drills.overdue.count,
            "water_sources":   sources.sources.count,
            "seed_varieties":  seeds.seeds.count,
            "generated_at":    ISO8601DateFormatter().string(from: Date()),
        ]

        if let outage = power.currentOutage {
            dict["outage_elapsed_min"] = Int(Date().timeIntervalSince(outage.startDate) / 60)
        }

        return (try? JSONSerialization.data(withJSONObject: dict,
                                            options: .prettyPrinted))
            ?? "{}".data(using: .utf8)!
    }

    // MARK: - HTML Dashboard  (/)

    private func dashboardHTML() -> String {
        let food     = FoodRotationEngine.shared
        let power    = PowerOutageEngine.shared
        let supply   = SupplyEngine()
        let skills   = SkillTreeStore.shared
        let drills   = DrillEngine.shared
        let seeds    = SeedBankEngine.shared
        let meds     = MedicationEngine.shared
        let sources  = WaterSourceEngine.shared
        let settings = AppSettingsStore.shared.settings
        let hh       = supply.household

        let dailyCal  = Double(hh.adults)   * settings.dailyCaloriesAdult
                      + Double(hh.children) * settings.dailyCaloriesChild
        let foodDays  = dailyCal > 0
            ? Int(food.totalCalories / dailyCal) : 0
        let waterGal  = supply.items
            .filter { $0.category == .water }
            .reduce(0.0) { $0 + $1.quantity }
        let waterDays = hh.waterNeededPerDay > 0
            ? Int(waterGal / hh.waterNeededPerDay) : 0

        let allSkillCount = allSkills.count
        let skillPct = allSkillCount > 0
            ? Int(Double(skills.completed.count) / Double(allSkillCount) * 100) : 0

        let outageActive  = power.currentOutage != nil
        let overdueCount  = drills.overdue.count
        let expiringCount = food.expiringSoon.count
        let locationName  = LocationStore.shared.config.displayName
        let displayName   = locationName.isEmpty ? "Home Base" : locationName

        // Status colors
        let waterCol = waterDays >= 14 ? "#3fb950" : waterDays >= 3 ? "#d29922" : "#f85149"
        let foodCol  = foodDays  >= 30 ? "#3fb950" : foodDays  >= 7 ? "#d29922" : "#f85149"
        let powerCol = outageActive ? "#f85149" : "#3fb950"
        let drillCol = overdueCount == 0 ? "#3fb950" : "#d29922"
        let skillCol = skillPct >= 50 ? "#3fb950" : skillPct >= 25 ? "#d29922" : "#e3b341"

        // Library link uses port 8000 (Python file server)
        let ip  = localIP()
        let libURL = "http://\(ip):8000"
        let now = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)

        // Alert banners
        var alerts = ""
        if outageActive {
            alerts += "<div class='alert'>⚡ POWER OUTAGE — \(escape(outageElapsed(power.currentOutage!.startDate)))</div>\n"
        }
        if expiringCount > 0 {
            alerts += "<div class='alert'>⚠ \(expiringCount) food item\(expiringCount == 1 ? "" : "s") expiring within 30 days</div>\n"
        }
        if overdueCount > 0 {
            alerts += "<div class='alert'>⚠ \(overdueCount) drill type\(overdueCount == 1 ? "" : "s") overdue</div>\n"
        }

        // Expiring food table rows
        var expiringRows = ""
        for item in food.expiringSoon.prefix(6) {
            let daysLeft = item.expirationDate.map {
                Calendar.current.dateComponents([.day], from: Date(), to: $0).day ?? 0
            } ?? 0
            let col = daysLeft < 7 ? "#f85149" : "#d29922"
            expiringRows += "<tr><td>\(escape(item.name))</td>"
                          + "<td style='color:\(col);text-align:right'>\(daysLeft) days</td></tr>\n"
        }

        // Overdue drill rows
        var drillRows = ""
        for (type, last) in drills.overdue.prefix(5) {
            let lastStr = last.map {
                DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .none)
            } ?? "Never"
            drillRows += "<tr><td>\(escape(type.rawValue))</td>"
                       + "<td style='color:#d29922;text-align:right'>\(lastStr)</td></tr>\n"
        }

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="refresh" content="60">
        <title>\(escape(displayName)) — Status</title>
        <style>
        *{box-sizing:border-box;margin:0;padding:0}
        body{background:#0d1117;color:#c9d1d9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;padding:1rem;max-width:680px;margin:0 auto}
        h1{font-size:1.35rem;color:#e6edf3;font-weight:700}
        .sub{font-size:.75rem;color:#8b949e;margin:.2rem 0 1rem}
        .alert{background:#161b22;border:1px solid #d29922;border-radius:8px;padding:.6rem .9rem;margin-bottom:.6rem;font-size:.85rem;color:#d29922;font-weight:600}
        .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(130px,1fr));gap:.65rem;margin-bottom:1rem}
        .card{background:#161b22;border-radius:10px;padding:.85rem .9rem;border:1px solid #21262d}
        .val{font-size:1.9rem;font-weight:700;line-height:1.1;font-variant-numeric:tabular-nums}
        .unit{font-size:.7rem;color:#8b949e;margin-top:.1rem}
        .lbl{font-size:.7rem;color:#8b949e;margin-top:.35rem;text-transform:uppercase;letter-spacing:.05em}
        .box{background:#161b22;border-radius:10px;padding:.9rem;border:1px solid #21262d;margin-bottom:.65rem}
        .box h2{font-size:.75rem;text-transform:uppercase;letter-spacing:.06em;color:#8b949e;margin-bottom:.6rem}
        table{width:100%;border-collapse:collapse;font-size:.85rem}
        td{padding:.3rem .1rem;border-bottom:1px solid #21262d}
        tr:last-child td{border:none}
        .lib{display:block;background:#161b22;border:1px solid #388bfd;border-radius:10px;padding:.9rem;text-align:center;color:#388bfd;text-decoration:none;font-size:.9rem;font-weight:600;margin-bottom:.65rem}
        .lib:active{opacity:.7}
        .footer{font-size:.65rem;color:#484f58;text-align:center;margin-top:.75rem;line-height:1.7}
        </style>
        </head>
        <body>
        <h1>\(escape(displayName))</h1>
        <p class="sub">Updated \(now) · Refreshes every 60 s</p>

        \(alerts)

        <div class="grid">
          <div class="card"><div class="val" style="color:\(waterCol)">\(waterDays)</div><div class="unit">days</div><div class="lbl">Water</div></div>
          <div class="card"><div class="val" style="color:\(foodCol)">\(foodDays)</div><div class="unit">days</div><div class="lbl">Food</div></div>
          <div class="card"><div class="val" style="color:\(powerCol)">\(outageActive ? "OUT" : "OK")</div><div class="unit">\(outageActive ? escape(outageElapsed(power.currentOutage!.startDate)) : "\(power.outagesThisYear.count) this yr")</div><div class="lbl">Power</div></div>
          <div class="card"><div class="val" style="color:\(drillCol)">\(overdueCount)</div><div class="unit">overdue</div><div class="lbl">Drills</div></div>
          <div class="card"><div class="val" style="color:\(skillCol)">\(skillPct)%</div><div class="unit">\(skills.completed.count)/\(allSkillCount)</div><div class="lbl">Skills</div></div>
          <div class="card"><div class="val" style="color:#c9d1d9">\(meds.medications.count)</div><div class="unit">tracked</div><div class="lbl">Meds</div></div>
          <div class="card"><div class="val" style="color:#c9d1d9">\(sources.sources.count)</div><div class="unit">mapped</div><div class="lbl">Water Src</div></div>
          <div class="card"><div class="val" style="color:#c9d1d9">\(seeds.seeds.count)</div><div class="unit">varieties</div><div class="lbl">Seeds</div></div>
        </div>

        \(!expiringRows.isEmpty ? """
        <div class="box"><h2>Expiring Soon</h2>
        <table><thead><tr><th style="text-align:left">Item</th><th style="text-align:right">Days Left</th></tr></thead>
        <tbody>\(expiringRows)</tbody></table></div>
        """ : "")

        \(!drillRows.isEmpty ? """
        <div class="box"><h2>Overdue Drills</h2>
        <table><thead><tr><th style="text-align:left">Type</th><th style="text-align:right">Last Practiced</th></tr></thead>
        <tbody>\(drillRows)</tbody></table></div>
        """ : "")

        <a class="lib" href="\(libURL)">📚 Open Offline Library →</a>

        <div class="footer">
          Survival Guide · Read-only · \(escape(localURL))<br>
          Open the Mac app to add or change data.
        </div>
        </body>
        </html>
        """
    }

    // MARK: - Helpers

    private func outageElapsed(_ start: Date) -> String {
        let mins = Int(Date().timeIntervalSince(start) / 60)
        let h = mins / 60, m = mins % 60
        return h == 0 ? "\(m)m elapsed" : "\(h)h \(m)m elapsed"
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&",  with: "&amp;")
         .replacingOccurrences(of: "<",  with: "&lt;")
         .replacingOccurrences(of: ">",  with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func localIP() -> String {
        Host.current().addresses
            .first { !$0.contains(":") && $0 != "127.0.0.1" }
            ?? "localhost"
    }
}
