import Foundation
import SwiftUI
import Combine

// MARK: - Survival Guide Generator

@MainActor
class SurvivalGuideGenerator: ObservableObject {

    @Published var isGenerating  = false
    @Published var progress: Double = 0       // 0.0 → 1.0
    @Published var currentTask   = ""
    @Published var log: [LogLine] = []
    @Published var isComplete    = false
    @Published var outputDirectory: URL? = nil

    // MARK: - Log

    struct LogLine: Identifiable {
        let id = UUID()
        let text: String
        enum Kind { case info, success, warning, error, progress }
        let kind: Kind
    }

    private func emit(_ text: String, _ kind: LogLine.Kind = .info) {
        log.append(LogLine(text: text, kind: kind))
    }

    // MARK: - Entry Point

    func generate(config: LocationConfig) async {
        isGenerating   = true
        isComplete     = false
        progress       = 0
        log            = []
        outputDirectory = nil

        emit("Checking Ollama…")

        guard await OllamaClient.isAvailable() else {
            emit("⚠︎ Ollama not reachable at localhost:11434", .warning)
            emit("  Install Ollama and run `ollama serve` to enable AI guide generation.", .warning)
            emit("  You can regenerate guides later from the Settings tab.", .info)
            isGenerating = false
            isComplete   = true
            return
        }

        let models = await OllamaClient.availableModels()
        let preferred = ["llama3.1:8b", "llama3:8b", "llama3.2:latest", "llama3.2",
                         "mistral", "phi3:mini", "phi3:medium"]
        guard let model = preferred.first(where: { models.contains($0) }) ?? models.first else {
            emit("⚠︎ No models found. Run `ollama pull llama3.1:8b` first.", .warning)
            isGenerating = false
            isComplete   = true
            return
        }
        emit("✓ Using model: \(model)", .success)

        // Output directory
        let outDir = outputDir(for: config)
        do {
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            outputDirectory = outDir
            emit("✓ Output: \(outDir.path)", .success)
        } catch {
            emit("✗ Cannot create output directory: \(error.localizedDescription)", .error)
            isGenerating = false
            isComplete   = true
            return
        }

        let hazards = config.hazards.isEmpty ? Array(HazardType.allCases) : config.hazards
        let total   = Double(hazards.count + 1)
        var done    = 0

        for hazard in hazards {
            currentTask = "Generating: \(hazard.rawValue)…"
            emit("→ \(hazard.rawValue)", .progress)

            do {
                let content = try await OllamaClient.generate(
                    model:  model,
                    system: systemPrompt(config),
                    prompt: hazardPrompt(hazard, config)
                )
                let html = wrapHTML(title: "\(hazard.rawValue) — \(config.displayName)",
                                    content: sanitizeLLMHTML(content), hazard: hazard)
                let fname = safeFilename(hazard.rawValue) + ".html"
                try html.write(to: outDir.appendingPathComponent(fname),
                               atomically: true, encoding: .utf8)
                emit("  ✓ \(fname)", .success)
            } catch {
                emit("  ✗ \(error.localizedDescription)", .error)
            }

            done   += 1
            progress = Double(done) / total
        }

        // Index
        currentTask = "Building index…"
        emit("→ index.html", .progress)
        let idx = buildIndex(config: config, hazards: hazards)
        do {
            try idx.write(to: outDir.appendingPathComponent("index.html"),
                          atomically: true, encoding: .utf8)
            emit("  ✓ index.html", .success)
        } catch {
            emit("  ✗ \(error.localizedDescription)", .error)
        }

        progress    = 1.0
        currentTask = "Complete"
        isGenerating = false
        isComplete   = true
        emit("✓ Done — \(hazards.count) guides for \(config.displayName)", .success)
    }

    // MARK: - Prompts

    private func systemPrompt(_ c: LocationConfig) -> String {
        c.systemPromptContext + """

        You are generating emergency preparedness survival guides formatted as HTML body content.
        Rules:
        - Write practical, actionable guidance with specific numbers (gallons, days, temperatures, distances).
        - Use ONLY these HTML tags: <h2> <h3> <p> <ul> <ol> <li> <strong> <em>.
        - Do NOT output <html> <head> <body> <style> <script> or markdown.
        - Each section starts with an <h2> tag. Sub-points use <h3> or <ul><li>.
        - Be specific to the user's location and region type.
        """
    }

    private func hazardPrompt(_ hazard: HazardType, _ c: LocationConfig) -> String {
        let region = c.regionTypes.map(\.rawValue).joined(separator: " + ")
        return """
        Write a detailed \(hazard.rawValue) survival guide for \(c.displayName) (\(region) region).

        Key fact: \(hazard.promptFact)

        Include all eight sections as <h2> headings:
        1. Risk Assessment for \(c.displayName)
        2. Warning Signs & Alerts
        3. Immediate Actions — First 72 Hours
        4. Shelter-in-Place vs Evacuation Decision
        5. Water, Food & Medical
        6. Communications & Power
        7. Week-Long & Extended Survival
        8. Recovery & After-Action

        End with a complete <h2>Supplies Checklist</h2> as a <ul> of specific items with quantities.
        """
    }

    // MARK: - HTML Templates

    private func wrapHTML(title: String, content: String, hazard: HazardType) -> String {
        let hex = hazardHex(hazard)
        let date = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>\(escapeHTML(title))</title>
        <style>
        :root{--a:\(hex)}
        *{box-sizing:border-box;margin:0;padding:0}
        body{background:#0d1117;color:#c9d1d9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;line-height:1.75;padding:2.5rem 2rem;max-width:860px;margin:0 auto}
        h1{font-size:1.9rem;color:var(--a);border-bottom:2px solid var(--a);padding-bottom:.5rem;margin-bottom:1.75rem}
        h2{font-size:1.15rem;color:var(--a);margin:2rem 0 .6rem;padding:.3rem .75rem;border-left:3px solid var(--a);background:rgba(255,255,255,.03);border-radius:0 4px 4px 0}
        h3{font-size:.95rem;color:#8b949e;margin:1rem 0 .4rem}
        p{margin-bottom:.9rem}
        ul,ol{margin:.4rem 0 .9rem 1.6rem}
        li{margin-bottom:.3rem}
        strong{color:#e6edf3}
        a{color:var(--a);text-decoration:none}
        a:hover{text-decoration:underline}
        .back{display:inline-block;margin-bottom:1.5rem;font-size:.85rem;opacity:.75}
        .footer{margin-top:3rem;padding-top:1rem;border-top:1px solid #21262d;font-size:.75rem;color:#484f58}
        </style>
        </head>
        <body>
        <a href="index.html" class="back">← All Guides</a>
        <h1>\(escapeHTML(title))</h1>
        \(content)
        <div class="footer">Generated offline · Survival Guide app · \(date)</div>
        </body>
        </html>
        """
    }

    private func buildIndex(config: LocationConfig, hazards: [HazardType]) -> String {
        let region = config.regionTypes.map(\.rawValue).joined(separator: " + ")
        let items  = hazards.map { h -> String in
            let fname = safeFilename(h.rawValue) + ".html"
            return """
            <li><a href="\(fname)" style="border-color:\(hazardHex(h));color:\(hazardHex(h))">\(escapeHTML(h.rawValue))</a></li>
            """
        }.joined(separator: "\n")

        let date = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Survival Guides — \(escapeHTML(config.displayName))</title>
        <style>
        *{box-sizing:border-box;margin:0;padding:0}
        body{background:#0d1117;color:#e6edf3;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;padding:3rem 2rem;max-width:680px;margin:0 auto}
        h1{font-size:1.75rem;margin-bottom:.4rem}
        .sub{color:#8b949e;margin-bottom:2rem;font-size:.9rem}
        ul{list-style:none;display:grid;gap:.65rem}
        li a{display:block;padding:.75rem 1rem;background:#161b22;border-radius:8px;text-decoration:none;font-size:.95rem;border:1px solid #21262d;transition:border-color .2s,background .2s}
        li a:hover{background:#1c2128}
        .footer{margin-top:3rem;font-size:.75rem;color:#484f58}
        </style>
        </head>
        <body>
        <h1>Survival Guides</h1>
        <p class="sub">\(escapeHTML(config.displayName)) · \(escapeHTML(region))</p>
        <ul>
        \(items)
        </ul>
        <div class="footer">Generated offline · Survival Guide app · \(date)</div>
        </body>
        </html>
        """
    }

    // MARK: - Helpers

    private func outputDir(for config: LocationConfig) -> URL {
        let base = URL(fileURLWithPath: "/Volumes/20TB_HDD/offline-library/survival-guides")
        let city  = config.city.isEmpty ? "unknown" : config.city
        let state = config.stateOrRegion.isEmpty ? "" : "-\(config.stateOrRegion)"
        let name  = "\(city)\(state)"
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return base.appendingPathComponent(name.isEmpty ? "location" : name)
    }

    private func safeFilename(_ s: String) -> String {
        s.lowercased()
         .replacingOccurrences(of: " / ", with: "-")
         .replacingOccurrences(of: "/", with: "-")
         .replacingOccurrences(of: " ", with: "-")
    }

    /// Strips dangerous HTML tags from raw LLM output before embedding in a page.
    /// The LLM is instructed not to emit these, but we sanitize defensively.
    private func sanitizeLLMHTML(_ raw: String) -> String {
        let dangerous = ["script", "style", "link", "iframe", "object",
                         "embed", "form", "input", "meta", "base", "noscript"]
        var s = raw
        for tag in dangerous {
            // Both opening tags (with optional attributes) and closing tags
            if let re = try? NSRegularExpression(
                pattern: "</?\\s*\(tag)(\\s[^>]*)?>",
                options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                s = re.stringByReplacingMatches(
                    in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
            }
        }
        return s
    }

    private func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func hazardHex(_ h: HazardType) -> String {
        switch h {
        case .hurricane:   return "#4d80e6"
        case .tornado:     return "#a855f7"
        case .earthquake:  return "#92400e"
        case .tsunami:     return "#3b82f6"
        case .flood:       return "#1d5fc8"
        case .wildfire:    return "#f97316"
        case .winter:      return "#93c5fd"
        case .nuclear:     return "#eab308"
        case .volcano:     return "#cc3300"
        case .heatwave:    return "#e86400"
        case .drought:     return "#b5a033"
        case .supplyChain: return "#6b7280"
        }
    }
}
