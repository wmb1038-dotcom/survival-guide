# Offline Survival Guide

A macOS app for offline emergency preparedness. Browse a local library of survival documents, search across them with AI-assisted query expansion, chat with a local AI assistant, and track historical weather patterns — all without an internet connection.

Built for Oahu, Hawaii, but designed to be adapted for any location.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

- **Offline Document Library** — Browse PDFs, HTML guides, EPUBs, and ZIM archives organized by topic (Survival Guides, Medical, Military Manuals, Preparedness, and more)
- **Full-Text Search** — Keyword search across all indexed documents, expanded with AI-generated related terms
- **AI Survival Assistant** — Local LLM chat via [Ollama](https://ollama.com) — no internet, no API keys, no data sent anywhere
- **Historical Weather Forecast** — 5-day rolling forecast based on NOAA 1991–2020 climate normals, refined by your own daily observations
- **Section Browser** — Visual card grid for topics and documents; full-screen document preview

---

## Requirements

| Requirement | Version |
|---|---|
| macOS | 13.0 Ventura or later |
| Xcode | 15 or later |
| [Ollama](https://ollama.com) | Latest |
| Disk space | ~5 GB minimum for a useful library |

---

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/survival-guide.git
cd survival-guide
```

### 2. Install Ollama

Download from [ollama.com](https://ollama.com) and pull a model:

```bash
# Recommended (16 GB RAM+)
ollama pull llama3.1:8b

# For 8 GB RAM Macs
ollama pull llama3.2:3b
```

To store models on an external drive:

```bash
OLLAMA_MODELS=/Volumes/YOUR_DRIVE/local-models ollama pull llama3.1:8b
```

### 3. Build the app

Open `Survival Guide.xcodeproj` in Xcode and press **⌘R**, or build from the command line:

```bash
xcodebuild -scheme "Survival Guide" -destination "platform=macOS" build
```

### 4. Set up your document library

The app expects documents at `/Volumes/20TB_HDD/offline-library/` by default. You can change this path in `OfflineLibraryApp.swift` (the `base` constant in `ContentView`).

Recommended free/public-domain documents to download — see [DOCUMENTS.md](DOCUMENTS.md).

### 5. Build the search index

Run the included indexing script to enable full-text search:

```bash
bash build_offline_search_index_v2.sh
```

This walks your library folder, extracts text from PDFs/HTML/EPUBs, and writes an index to `/Volumes/20TB_HDD/offline_search_index.json`.

---

## Document Library Structure

```
/Volumes/20TB_HDD/
├── offline-library/
│   ├── survival-guides/       ← Oahu-specific HTML guides (included in repo)
│   ├── trueprepper/           ← TruePrepper PDFs (download separately)
│   │   ├── military-manuals/
│   │   ├── survival-manuals/
│   │   ├── preparedness/
│   │   ├── first-aid/
│   │   ├── nuclear-radiation/
│   │   ├── checklists/
│   │   └── reference/
│   ├── medical-human/
│   ├── medical-pets/
│   ├── cooking/
│   ├── gardening-water/
│   ├── radio/
│   └── books/
├── offline-wikipedia/         ← Wikipedia ZIM (download from Kiwix)
└── local-models/              ← Ollama models (optional, for external drive)
```

---

## Customizing for Your Location

The app is currently configured for Oahu, Hawaii. To adapt it:

1. **AI assistant** — Edit the `systemPrompt` in `AgentViewModel` (`OfflineLibraryApp.swift`) with local hazards, infrastructure, frequencies, and geography
2. **Weather** — The `oahuNormals` array in `WeatherView.swift` uses NOAA data for Honolulu. Replace with normals for your nearest city ([NOAA Climate Normals](https://www.ncei.noaa.gov/products/land-based-station/us-climate-normals))
3. **Survival guides** — Replace the HTML files in `offline-library/survival-guides/` with guides relevant to your area
4. **Document catalog** — Edit the `items` array in `ContentView` to point to your local files

A location-aware setup wizard is planned for a future release.

---

## Contributing

Pull requests welcome. If you adapt this for your region, consider opening a PR to add your climate normals data or survival guide templates.

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes
4. Open a pull request

---

## Acknowledgments

- Document sources: [TruePrepper](https://trueprepper.com/survival-pdfs-downloads/), USDA, FEMA, US Army, US Navy, USMC (public domain)
- AI inference: [Ollama](https://ollama.com)
- Offline Wikipedia: [Kiwix](https://www.kiwix.org)
- Weather data: NOAA 1991–2020 Climate Normals

---

## License

MIT — see [LICENSE](LICENSE) for details.
