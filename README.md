# Offline Survival Guide

A macOS app for comprehensive offline emergency preparedness. Configure it for your location, track supplies and medications, run survival calculators, and generate AI-written HTML survival guides — all without an internet connection.

Built for Oahu, Hawaii (Island + Mountainous terrain), but fully configurable for any location via the built-in setup wizard.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

### Setup & Location
- **Location Wizard** — 5-step guided setup: city, multi-select terrain (Island + Mountainous simultaneously), hazards, household (adults, children, dogs, cats, small animals)
- **AI Guide Generation** — After setup, automatically generates location-specific HTML survival guides (one per hazard) via a local Ollama model and saves them to your offline library. Live terminal-style progress shown in the wizard.
- **Climate Database** — NOAA 1991–2020 normals for 30+ US cities; drives weather forecasts and frost date calculations

### Tools
| Tool | Description |
|---|---|
| **Quick Reference** | Fully editable cards (emergency contacts, radio frequencies, hospitals, shelters, facts) with per-entry notes |
| **Communications** | Morse code reference, radio frequency guide |
| **Checklists** | Preparedness checklists by scenario |
| **Supply Tracker** | Water/food/supply inventory with household-aware calculations; small animals supported |
| **Food Rotation** | Food inventory with expiration tracking, calorie totals, days-of-supply estimate, FIFO reminders, and local notifications 30/7/1 days before expiration |
| **Seed Bank** | Seed inventory with planting calendar (frost dates from climate data), garden bed tracker with harvest countdown |
| **Weather Forecast** | 5-day rolling forecast from NOAA climate normals, refined by your daily observations |
| **Emergency Plan** | Personal emergency plan editor |
| **Calculators** | Water, food, power, and solar power calculators. Solar defaults to Tesla Powerwall 2 + 18× Enphase IQ8H (fully editable). Appliance load selector with quantity steppers and up to 10 custom items. |
| **Medication Tracker** | Medication inventory with refill reminders |
| **Documents Vault** | Secure local document storage |
| **Skills Log** | Flat checklist of survival skills by category |
| **Skill Tree** | Visual tiered skill tree (Tier 1 Critical → Tier 3 Useful) with category progress rings; syncs with Skills Log |
| **Power Outage Log** | Live outage status, one-tap start/end, outage history, fuel log, battery level log with stats |
| **Resilience Dashboard** | Star Trek: SNW-themed situational awareness stoplights (Weather, Geological, Logistics, Resources) with automated background analysis and tooltips |
| **Unified Map** | Interactive multi-layer Folium map (Satellite/Light/Dark) combining mapped Water Sources and real-time Maritime Traffic |
| **Maritime Tracking** | Background AIS ingestion and vessel classification (Matson, Pasha, Tankers) with automated dashboard generation |

### Automation & Logic
The app includes a suite of background scripts for enhanced situational awareness:
- **Resilience Engine** — Automatically fetches and analyzes live data (NWS, USGS, HDOT, Gas Prices) on launch to update the dashboard.
- **Ghost Finder** — Cross-references port schedules with live AIS pings to identify vessels that have gone dark (overdue for a ping).
- **PortCall Scraper** — Automated extraction of Honolulu and Kalaeloa Barbers Point vessel schedules.
- **Watchdog Alert** — macOS system-level integration that triggers audio alerts and modal popups for critical (RED) status changes.
- **Resilience Wizard** — Interactive CLI for managing the downloading of multi-gigabyte offline data bundles (Wikipedia, WikiMed, OSM Maps) to external drives.

### Medical & Resources
- **Hawaii Medical Cheat Sheets** — Specially adapted from the Special Forces Medical Handbook for tropical bacteria, volcanic terrain, and local hazards (Leptospirosis, Rat Lungworm, Ciguatera).
- **Pocket Survival Booklet** — A high-readability, printable field manual designed to fit into a 4x6 waterproof pouch.
- **PDF Generator** — Built-in ReportLab script to generate durable, duplex-ready medical guides with crop marks.

### Library
- **Offline Document Library** — Browse PDFs, HTML guides, EPUBs, and ZIM archives organized by topic
- **Full-Text Search** — Keyword search across all indexed documents, expanded with AI-generated related terms
- **AI Survival Assistant** — Local LLM chat via [Ollama](https://ollama.com); location-aware system prompt built from your setup

---

## Requirements

| Requirement | Version |
|---|---|
| macOS | 13.0 Ventura or later |
| Xcode | 15 or later |
| Python | 3.11 or later |
| [Ollama](https://ollama.com) | Latest (optional — enables AI chat + guide generation) |
| Disk space | ~5 GB minimum for a useful library |

---

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/wmb1038-dotcom/survival-guide.git
cd survival-guide
```

### 2. Configure Maritime Awareness (Optional)

The app includes an automated AIS tracking and dashboard system.

1. **Create Python environment:**
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -e .
   ```

2. **Configure API Key:**
   Copy `config.example.toml` to `~/Library/Application Support/awareness/config.toml` and add your free API key from [aisstream.io](https://aisstream.io).

3. **Initialize Database:**
   ```bash
   awareness init
   ```

The Swift app will now automatically manage vessel tracking and dashboard generation whenever you are connected to WiFi.

### 3. Install Ollama (optional but recommended)

Download from [ollama.com](https://ollama.com) and pull a model:

```bash
# Recommended (16 GB RAM+)
ollama pull llama3.1:8b

# For 8 GB RAM Macs
ollama pull phi3:mini
```

To store models on an external drive:

```bash
OLLAMA_MODELS=/Volumes/YOUR_DRIVE/local-models ollama serve &
ollama pull llama3.1:8b
```

### 3. Build and run

Open `Survival Guide.xcodeproj` in Xcode and press **⌘R**, or:

```bash
xcodebuild -scheme "Survival Guide" -destination "platform=macOS" build
```

### 4. Run the setup wizard

On first launch, the setup wizard walks you through:
1. Welcome
2. Location (city, state/region)
3. Terrain type (multi-select: Island, Mountainous, Coastal, etc.)
4. Hazards (Hurricane, Earthquake, Wildfire, etc.)
5. Household (adults, children, dogs, cats, small animals)
6. **AI Guide Generation** — Ollama generates a full HTML survival guide for each selected hazard, saved to your offline library

### 5. Set up your document library

The app expects documents at `/Volumes/20TB_HDD/offline-library/` by default. You can change this in `OfflineLibraryApp.swift`.

See [DOCUMENTS.md](DOCUMENTS.md) for recommended free/public-domain documents to download.

### 6. Build the search index

```bash
bash build_offline_search_index_v2.sh
```

Walks your library folder, extracts text from PDFs/HTML/EPUBs, and writes `/Volumes/20TB_HDD/offline_search_index.json`.

---

## Document Library Structure

```
/Volumes/20TB_HDD/
├── offline-library/
│   ├── survival-guides/         ← AI-generated location-specific HTML guides
│   │   └── {city-state}/        ← One folder per configured location
│   │       ├── index.html
│   │       ├── hurricane.html
│   │       ├── earthquake.html
│   │       └── ...
│   ├── home repair/             ← FEMA, USDA, HUD home repair references
│   ├── trueprepper/             ← TruePrepper PDFs (download separately)
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
│   ├── nuclear-guides/
│   ├── books/
│   └── ...
├── offline-wikipedia/           ← Wikipedia ZIM (download from Kiwix)
└── local-models/                ← Ollama models (optional, for external drive)
```

---

## Notifications

The app uses local macOS notifications (no internet required) for:
- Food expiration warnings (30 days, 7 days, 1 day before)
- Water storage rotation reminders (every 6 months)
- Generator test reminders (monthly)
- Medication refill reminders

Grant notification permission when prompted on first launch.

---

## Contributing

Pull requests welcome. If you adapt this for your region, consider opening a PR to add your climate normals data or survival guide templates.

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes
4. Open a pull request

---

## Acknowledgments

- Document sources: [TruePrepper](https://trueprepper.com/survival-pdfs-downloads/), USDA, FEMA, HUD, DOE, US Army, US Navy, USMC (public domain)
- AI inference: [Ollama](https://ollama.com)
- Offline Wikipedia: [Kiwix](https://www.kiwix.org)
- Weather data: NOAA 1991–2020 Climate Normals

---

## License

MIT — see [LICENSE](LICENSE) for details.
