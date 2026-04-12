import SwiftUI

// MARK: - Home Intranet Setup Guide

struct HomeNetworkView: View {

    @State private var expandedSection: String? = "overview"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                Divider().opacity(0.3)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sections) { sec in
                        NetSection(
                            item: sec,
                            isExpanded: expandedSection == sec.id,
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedSection = expandedSection == sec.id ? nil : sec.id
                                }
                            }
                        )
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: "wifi.router.fill")
                .font(.system(size: 36))
                .foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 4) {
                Text("Home Intranet Setup")
                    .font(.system(size: 22, weight: .bold))
                Text("Serve your offline library to every device in the house — no internet required")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Section data

    private let sections: [NetSectionItem] = [
        NetSectionItem(
            id: "overview",
            symbol: "lightbulb.fill",
            color: .yellow,
            title: "How It Works",
            body: """
            During a power outage or internet disruption your household needs access to the \
            offline library on this Mac. Google Wifi points can form a local mesh network \
            completely independent of the internet. This Mac then acts as a web server, and \
            every phone, tablet, or laptop on the mesh can browse the offline library at a \
            simple local address like http://192.168.86.100:8000.

            No internet connection is required at any point after the initial setup.
            """,
            steps: []
        ),
        NetSectionItem(
            id: "hardware",
            symbol: "checklist",
            color: .blue,
            title: "What You Need",
            body: nil,
            steps: [
                Step(n: nil, title: "Google Wifi or Nest Wifi points", detail: "2–4 points recommended for whole-home coverage. These are the white puck-shaped routers."),
                Step(n: nil, title: "Ethernet cable (optional but recommended)", detail: "One short cable to connect a Wifi point directly to this Mac for the fastest server connection."),
                Step(n: nil, title: "Power for the Wifi points", detail: "Each point needs its own outlet. During an outage, connect them to a UPS or generator circuit."),
                Step(n: nil, title: "This Mac with the 20TB drive attached", detail: "The Mac will run the file server. The drive must be mounted at /Volumes/20TB_HDD."),
            ]
        ),
        NetSectionItem(
            id: "google-wifi",
            symbol: "wifi.router.fill",
            color: .teal,
            title: "Step 1 — Configure Google Wifi Points",
            body: nil,
            steps: [
                Step(n: "1", title: "Download the Google Home app on your phone", detail: "Available on iPhone and Android. You only need this during initial setup — not during emergencies."),
                Step(n: "2", title: "Set up the primary (main) Wifi point", detail: "Plug the primary point into power and connect it to your existing router via Ethernet. Open Google Home → Add → Set up device → New device. Follow the in-app steps."),
                Step(n: "3", title: "Add remaining points as mesh nodes", detail: "Plug each additional point into power anywhere in the house. In Google Home → Add → Set up device → New device → choose 'Add to existing mesh.' Place them to maximize coverage."),
                Step(n: "4", title: "Name your network", detail: "Give it a memorable name (e.g. HomeBase or SurvivalNet). The password is only needed for Wi-Fi clients — wired clients connect automatically."),
                Step(n: "5", title: "Connect the Mac via Ethernet to any Wifi point", detail: "Plug one end of an Ethernet cable into the LAN port on a Wifi point and the other into the Mac (via USB-C to Ethernet adapter if needed). The Mac will receive a local IP address like 192.168.86.x."),
                Step(n: "6", title: "Note the Mac's local IP address", detail: "On the Mac: System Settings → Network → Ethernet (or Wi-Fi) → IP Address. Write this down — household members will type it into their browser. Example: 192.168.86.100"),
            ]
        ),
        NetSectionItem(
            id: "server",
            symbol: "server.rack",
            color: .purple,
            title: "Step 2 — Start the File Server on the Mac",
            body: "Open Terminal (Applications → Utilities → Terminal) and run one of the following commands. The server stays running until you quit Terminal or press Control-C.",
            steps: [
                Step(n: "Option A", title: "Python 3 (built-in on macOS)", detail: "cd /Volumes/20TB_HDD/offline-library\npython3 -m http.server 8000\n\nAccess from any device: http://192.168.86.100:8000"),
                Step(n: "Option B", title: "Python 3 — serve entire drive", detail: "cd /Volumes/20TB_HDD\npython3 -m http.server 8000\n\nServes the full drive including offline-library, offline-maps, and survival-guides."),
                Step(n: "Option C", title: "Run on startup automatically", detail: "To have the server start when you log in, paste this into Terminal:\n\nmkdir -p ~/Library/LaunchAgents\ncat > ~/Library/LaunchAgents/com.survivalguide.httpserver.plist << 'EOF'\n<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\"><dict>\n  <key>Label</key><string>com.survivalguide.httpserver</string>\n  <key>ProgramArguments</key><array>\n    <string>/usr/bin/python3</string>\n    <string>-m</string><string>http.server</string><string>8000</string>\n  </array>\n  <key>WorkingDirectory</key><string>/Volumes/20TB_HDD/offline-library</string>\n  <key>RunAtLoad</key><true/>\n  <key>KeepAlive</key><true/>\n</dict></plist>\nEOF\nlaunchctl load ~/Library/LaunchAgents/com.survivalguide.httpserver.plist"),
            ]
        ),
        NetSectionItem(
            id: "access",
            symbol: "iphone",
            color: .green,
            title: "Step 3 — Access from Any Device",
            body: "Once the server is running and devices are connected to the Google Wifi network:",
            steps: [
                Step(n: "1", title: "Connect the device to your Google Wifi network", detail: "Join the Wi-Fi network you named in Step 1. No internet required — the mesh is self-contained."),
                Step(n: "2", title: "Open any web browser", detail: "Safari, Chrome, Firefox — any browser works. On phones, tablets, and computers."),
                Step(n: "3", title: "Navigate to the Mac's address", detail: "Type: http://192.168.86.100:8000\n(Replace 192.168.86.100 with your Mac's actual IP from Step 1.)\n\nYou will see a file listing of the offline library. Tap any folder to browse, tap any file to open it."),
                Step(n: "4", title: "Bookmark it on every device now", detail: "Before an emergency, add this address as a bookmark or home screen shortcut on every household device. Label it 'Offline Library.'"),
            ]
        ),
        NetSectionItem(
            id: "power",
            symbol: "bolt.fill",
            color: .orange,
            title: "Power Outage Checklist",
            body: "When the grid goes down, do these in order:",
            steps: [
                Step(n: "1", title: "Switch Google Wifi points to backup power", detail: "Connect each Wifi point to a UPS (uninterruptible power supply) or a power strip on your generator circuit. Each point draws about 12–15 watts."),
                Step(n: "2", title: "Switch this Mac and the 20TB drive to backup power", detail: "Connect the Mac and the external drive enclosure to the same UPS or generator circuit. Verify the drive is mounted: open Finder and confirm 20TB_HDD appears in the sidebar."),
                Step(n: "3", title: "Start the file server if not running automatically", detail: "Open Terminal and run:\ncd /Volumes/20TB_HDD/offline-library && python3 -m http.server 8000"),
                Step(n: "4", title: "Announce the address to household members", detail: "Tell everyone to open their browser and go to http://192.168.86.100:8000 (or whatever IP the Mac shows). All offline books, manuals, medical references, and survival guides are accessible."),
                Step(n: "5", title: "Confirm the AI chat works locally", detail: "If Ollama is running on this Mac, the AI chat in the Survival Guide app also works offline for anyone using this Mac directly."),
            ]
        ),
        NetSectionItem(
            id: "tips",
            symbol: "info.circle.fill",
            color: .secondary,
            title: "Tips & Troubleshooting",
            body: nil,
            steps: [
                Step(n: nil, title: "Mac's IP address changed?", detail: "Google Wifi usually assigns stable IPs via DHCP reservation. To make it permanent: open the Google Home app → your device → Reserve IP. This ensures the address never changes."),
                Step(n: nil, title: "Can't reach the server from another device?", detail: "On the Mac, go to System Settings → Network → Firewall → Firewall Options and ensure incoming connections on port 8000 are allowed. Or temporarily turn the firewall off while on the private network."),
                Step(n: nil, title: "Google Wifi points without internet?", detail: "The mesh works fine with no internet uplink. Devices connected to it get local IPs and can reach each other and the Mac server. Only internet-bound requests will fail — which is expected."),
                Step(n: nil, title: "Slower speeds on Wi-Fi vs Ethernet?", detail: "Wi-Fi speeds are more than sufficient for reading documents. Even at 10 Mbps a PDF loads in under a second. The bottleneck is the 20TB drive read speed, not the network."),
                Step(n: nil, title: "Adding the offline map tiles to the browser?", detail: "The offline map tiles (downloaded via Settings → Offline Maps) are stored at /Volumes/20TB_HDD/offline-library/offline-maps/. They are visible in the browser directory listing but are designed for use within this app, not directly in a browser."),
            ]
        ),
    ]
}

// MARK: - Data Models

private struct NetSectionItem: Identifiable {
    let id     : String
    let symbol : String
    let color  : Color
    let title  : String
    let body   : String?
    let steps  : [Step]
}

private struct Step: Identifiable {
    let id     = UUID()
    let n      : String?   // step number label, nil = bullet
    let title  : String
    let detail : String
}

// MARK: - Section View

private struct NetSection: View {
    let item      : NetSectionItem
    let isExpanded: Bool
    let onToggle  : () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 15))
                        .foregroundStyle(item.color)
                        .frame(width: 24)
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    // Intro body text
                    if let body = item.body {
                        Text(body)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Steps
                    if !item.steps.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(item.steps) { step in
                                StepRow(step: step, accentColor: item.color)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
                .padding(.top, 2)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isExpanded ? item.color.opacity(0.05) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isExpanded ? item.color.opacity(0.2) : Color.white.opacity(0.07))
        )
    }
}

// MARK: - Step Row

private struct StepRow: View {
    let step       : Step
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Number badge or bullet
            if let n = step.n {
                Text(n)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
            } else {
                Circle()
                    .fill(accentColor.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .padding(.top, 5)
                    .padding(.leading, 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.system(size: 12, weight: .semibold))
                Text(step.detail)
                    .font(.system(size: 11, design: step.detail.contains("\n") ? .monospaced : .default))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
