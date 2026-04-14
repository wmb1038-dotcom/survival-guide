import SwiftUI
import WebKit

struct UnifiedMapView: View {
    @StateObject private var server = LocalWebServer.shared
    @StateObject private var awareness = MaritimeAwarenessEngine.shared
    @State private var reloadId = UUID()

    var body: some View {
        ZStack {
            if server.isRunning {
                ZStack(alignment: .topTrailing) {
                    WebView(url: URL(string: "\(server.localURL)/api/map")!)
                        .id(reloadId)
                        .ignoresSafeArea()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        if awareness.isGenerating {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.6)
                                Text("Generating Dashboard...")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        Button {
                            awareness.forceGenerate()
                        } label: {
                            Label("Refresh Now", systemImage: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(awareness.isGenerating)
                        
                        if !awareness.isOnline {
                            Label("Offline", systemImage: "wifi.slash")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(12)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Local Web Server is Offline")
                        .font(.headline)
                    Text("Enable the web server in Settings to view the unified map.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onReceive(awareness.dashboardUpdated) { _ in
            reloadId = UUID()
        }
        .navigationTitle("Unified Map")
    }
}

struct WebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        return wv
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        wv.load(request)
    }
}
