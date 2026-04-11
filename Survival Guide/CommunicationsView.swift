import SwiftUI

// MARK: - Communications View

struct CommunicationsView: View {
    @State private var selectedTab = "Phonetic"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Communications Reference")
                            .font(.title2.bold())
                        Text("Offline · NATO · Morse · Flags · Radio · Knots")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label("Always available", systemImage: "checkmark.shield.fill")
                        .font(.caption).foregroundStyle(.green)
                }

                Picker("Tab", selection: $selectedTab) {
                    Text("Phonetic").tag("Phonetic")
                    Text("Morse").tag("Morse")
                    Text("Signals").tag("Signals")
                    Text("Radio").tag("Radio")
                    Text("Knots").tag("Knots")
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case "Phonetic": PhoneticTab()
                case "Morse":    MorseTab()
                case "Signals":  SignalFlagsTab()
                case "Radio":    RadioChannelsTab()
                default:         KnotsTab()
                }
            }
            .padding(20)
        }
    }
}

// MARK: - NATO Phonetic Alphabet

private struct PhoneticEntry {
    let letter: String
    let word: String
    let pronounce: String
    let morse: String
}

private let phoneticData: [PhoneticEntry] = [
    .init(letter: "A", word: "Alfa",     pronounce: "AL-fah",      morse: "·–"),
    .init(letter: "B", word: "Bravo",    pronounce: "BRAH-voh",    morse: "–···"),
    .init(letter: "C", word: "Charlie",  pronounce: "CHAR-lee",    morse: "–·–·"),
    .init(letter: "D", word: "Delta",    pronounce: "DELL-tah",    morse: "–··"),
    .init(letter: "E", word: "Echo",     pronounce: "ECK-oh",      morse: "·"),
    .init(letter: "F", word: "Foxtrot",  pronounce: "FOKS-trot",   morse: "··–·"),
    .init(letter: "G", word: "Golf",     pronounce: "GOLF",        morse: "––·"),
    .init(letter: "H", word: "Hotel",    pronounce: "hoh-TEL",     morse: "····"),
    .init(letter: "I", word: "India",    pronounce: "IN-dee-ah",   morse: "··"),
    .init(letter: "J", word: "Juliet",   pronounce: "JEW-lee-et",  morse: "·–––"),
    .init(letter: "K", word: "Kilo",     pronounce: "KEY-loh",     morse: "–·–"),
    .init(letter: "L", word: "Lima",     pronounce: "LEE-mah",     morse: "·–··"),
    .init(letter: "M", word: "Mike",     pronounce: "MIKE",        morse: "––"),
    .init(letter: "N", word: "November", pronounce: "no-VEM-ber",  morse: "–·"),
    .init(letter: "O", word: "Oscar",    pronounce: "OSS-car",     morse: "–––"),
    .init(letter: "P", word: "Papa",     pronounce: "pah-PAH",     morse: "·––·"),
    .init(letter: "Q", word: "Quebec",   pronounce: "keh-BECK",    morse: "––·–"),
    .init(letter: "R", word: "Romeo",    pronounce: "ROW-me-oh",   morse: "·–·"),
    .init(letter: "S", word: "Sierra",   pronounce: "see-AIR-ah",  morse: "···"),
    .init(letter: "T", word: "Tango",    pronounce: "TANG-go",     morse: "–"),
    .init(letter: "U", word: "Uniform",  pronounce: "YOU-nee-form", morse: "··–"),
    .init(letter: "V", word: "Victor",   pronounce: "VIK-tah",     morse: "···–"),
    .init(letter: "W", word: "Whiskey",  pronounce: "WISS-key",    morse: "·––"),
    .init(letter: "X", word: "X-ray",    pronounce: "ECKS-ray",    morse: "–··–"),
    .init(letter: "Y", word: "Yankee",   pronounce: "YANG-key",    morse: "–·––"),
    .init(letter: "Z", word: "Zulu",     pronounce: "ZOO-loo",     morse: "––··"),
]

private let digitPhonetic: [(String, String, String)] = [
    ("0","Zero",   "ZE-ro"),   ("1","One",   "WUN"),
    ("2","Two",    "TOO"),     ("3","Three", "TREE"),
    ("4","Four",   "FOW-er"),  ("5","Five",  "FIFE"),
    ("6","Six",    "SIX"),     ("7","Seven", "SEV-en"),
    ("8","Eight",  "AIT"),     ("9","Nine",  "NIN-er"),
]

private struct PhoneticTab: View {
    @State private var encoder = ""
    @State private var encoded = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Encoder
            CommCard(title: "Message Encoder", symbol: "mic.fill", color: .blue) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Type a word or phrase…", text: $encoder)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(8)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                        .onChange(of: encoder) { _, v in
                            encoded = v.uppercased().compactMap { c -> String? in
                                guard let entry = phoneticData.first(where: { $0.letter == String(c) }) else {
                                    return c == " " ? "/ " : nil
                                }
                                return entry.word
                            }.joined(separator: " · ")
                        }
                    if !encoded.isEmpty {
                        Text(encoded)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.blue)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // Alphabet grid
            CommCard(title: "NATO Phonetic Alphabet", symbol: "character.textbox", color: .orange) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(phoneticData, id: \.letter) { e in
                        HStack(spacing: 6) {
                            Text(e.letter)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.word)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(e.pronounce)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            // Digits
            CommCard(title: "NATO Digits", symbol: "number", color: .purple) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()),
                                    GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(digitPhonetic, id: \.0) { d, word, pron in
                        VStack(spacing: 2) {
                            Text(d)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                            Text(word)
                                .font(.system(size: 10, weight: .semibold))
                            Text(pron)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }
}

// MARK: - Morse Code

private let morseData: [(String, String)] = [
    ("A","·–"), ("B","–···"), ("C","–·–·"), ("D","–··"),  ("E","·"),
    ("F","··–·"),("G","––·"), ("H","····"), ("I","··"),   ("J","·–––"),
    ("K","–·–"), ("L","·–··"),("M","––"),   ("N","–·"),   ("O","–––"),
    ("P","·––·"),("Q","––·–"),("R","·–·"),  ("S","···"),  ("T","–"),
    ("U","··–"), ("V","···–"),("W","·––"),  ("X","–··–"), ("Y","–·––"),
    ("Z","––··"),
    ("0","–––––"),("1","·––––"),("2","··–––"),("3","···––"),("4","····–"),
    ("5","·····"),("6","–····"),("7","––···"),("8","–––··"),("9","––––·"),
]

private let morseSpecial: [(String, String, String)] = [
    ("SOS",     "··· ––– ···",     "Universal distress signal"),
    ("AR",      "·–·–·",           "End of message"),
    ("SK",      "···–·–",          "End of contact / silence"),
    ("BT",      "–···–",           "Break / paragraph"),
    ("KN",      "–·––·",           "Invite specific station only"),
    ("CQ",      "–·–· ––·–",       "General call to all stations"),
    ("DE",      "–·· ·",           "This is / from [callsign]"),
    ("73",      "––··· –––··",     "Best regards"),
    ("88",      "–––·· –––··",     "Love and kisses"),
]

private struct MorseTab: View {
    @State private var morseInput = ""
    @State private var morseOutput = ""

    private func encode(_ text: String) -> String {
        let dict = Dictionary(uniqueKeysWithValues: morseData)
        return text.uppercased().compactMap { c -> String? in
            if c == " " { return "/" }
            return dict[String(c)]
        }.joined(separator: "  ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            CommCard(title: "Morse Encoder", symbol: "dot.radiowaves.left.and.right", color: .orange) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Type text to convert…", text: $morseInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(8)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                        .onChange(of: morseInput) { _, v in morseOutput = encode(v) }
                    if !morseOutput.isEmpty {
                        Text(morseOutput)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("· = dot (short)  – = dash (long)  space between letters  / between words")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            CommCard(title: "Timing Guide", symbol: "clock.fill", color: .blue) {
                VStack(alignment: .leading, spacing: 6) {
                    MorseTimingRow(label: "Dot (·)",              value: "1 unit")
                    MorseTimingRow(label: "Dash (–)",             value: "3 units")
                    MorseTimingRow(label: "Between symbols",      value: "1 unit silence")
                    MorseTimingRow(label: "Between letters",      value: "3 units silence")
                    MorseTimingRow(label: "Between words",        value: "7 units silence")
                    MorseTimingRow(label: "Standard speed",       value: "5 WPM = ~1 sec/word")
                    MorseTimingRow(label: "Emergency speed",      value: "5–10 WPM recommended")
                }
            }

            CommCard(title: "Special Signals", symbol: "exclamationmark.bubble.fill", color: .red) {
                VStack(spacing: 0) {
                    ForEach(Array(morseSpecial.enumerated()), id: \.offset) { i, row in
                        HStack(spacing: 10) {
                            Text(row.0)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .frame(width: 38, alignment: .leading)
                            Text(row.1)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.orange)
                                .frame(width: 110, alignment: .leading)
                            Text(row.2)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 5)
                        if i < morseSpecial.count - 1 { Divider() }
                    }
                }
            }

            CommCard(title: "Code Chart", symbol: "table.fill", color: .green) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                    GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                    ForEach(morseData, id: \.0) { letter, code in
                        HStack(spacing: 5) {
                            Text(letter)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .frame(width: 16)
                            Text(code)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 5).padding(.vertical, 3)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
                    }
                }
            }
        }
    }
}

private struct MorseTimingRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
    }
}

// MARK: - Signal Flags

private struct FlagEntry {
    let letter: String; let word: String
    let pattern: String   // text description of flag appearance
    let meaning: String   // single-letter meaning at sea
}

private let flagData: [FlagEntry] = [
    .init(letter: "A", word: "Alfa",     pattern: "White & blue swallowtail",              meaning: "Diver down — keep clear at slow speed"),
    .init(letter: "B", word: "Bravo",    pattern: "Red swallowtail",                        meaning: "Carrying dangerous cargo (explosives/fuel)"),
    .init(letter: "C", word: "Charlie",  pattern: "5 horizontal: blue/white/red/white/blue",meaning: "Yes / Affirmative"),
    .init(letter: "D", word: "Delta",    pattern: "3 vertical: yellow/blue/yellow",         meaning: "Keep clear — maneuvering with difficulty"),
    .init(letter: "E", word: "Echo",     pattern: "2 diagonal: blue (top) / red (bottom)",  meaning: "Altering course to starboard"),
    .init(letter: "F", word: "Foxtrot",  pattern: "Diamond: white center, red corners",     meaning: "I am disabled — communicate with me"),
    .init(letter: "G", word: "Golf",     pattern: "6 vertical stripes: yellow/blue (×3)",   meaning: "I require a pilot"),
    .init(letter: "H", word: "Hotel",    pattern: "2 vertical: white (left) / red (right)", meaning: "Pilot is on board"),
    .init(letter: "I", word: "India",    pattern: "Yellow with black circle center",         meaning: "Altering course to port"),
    .init(letter: "J", word: "Juliet",   pattern: "3 horizontal: blue/white/blue",           meaning: "On fire / dangerous cargo — keep clear"),
    .init(letter: "K", word: "Kilo",     pattern: "2 vertical: yellow (left) / blue (right)",meaning: "I wish to communicate"),
    .init(letter: "L", word: "Lima",     pattern: "4 squares: yellow/black/black/yellow",    meaning: "Stop your vessel instantly"),
    .init(letter: "M", word: "Mike",     pattern: "White X on blue",                         meaning: "My vessel is stopped — making no way"),
    .init(letter: "N", word: "November", pattern: "4×4 blue/white checkerboard",             meaning: "No / Negative"),
    .init(letter: "O", word: "Oscar",    pattern: "2 diagonal: red (top-left) / yellow",     meaning: "Man overboard"),
    .init(letter: "P", word: "Papa",     pattern: "Blue border, white center",               meaning: "In port: departing soon. At sea: nets fouled"),
    .init(letter: "Q", word: "Quebec",   pattern: "Solid yellow",                            meaning: "All well — request clearance (pratique)"),
    .init(letter: "R", word: "Romeo",    pattern: "Red cross on yellow, with red border",    meaning: "(No standard single-letter meaning)"),
    .init(letter: "S", word: "Sierra",   pattern: "White square on blue",                    meaning: "Engines going astern"),
    .init(letter: "T", word: "Tango",    pattern: "3 vertical: red/white/red",               meaning: "Keep clear — trawling / fishing"),
    .init(letter: "U", word: "Uniform",  pattern: "2 diagonal: white (top-left) / red",      meaning: "You are running into danger"),
    .init(letter: "V", word: "Victor",   pattern: "Red X on white",                          meaning: "I require assistance"),
    .init(letter: "W", word: "Whiskey",  pattern: "Blue border, red/white squares center",   meaning: "I require MEDICAL assistance"),
    .init(letter: "X", word: "X-ray",    pattern: "Blue cross on white",                     meaning: "Stop your intentions — watch my signals"),
    .init(letter: "Y", word: "Yankee",   pattern: "6 diagonal: red/yellow stripes",          meaning: "I am dragging anchor"),
    .init(letter: "Z", word: "Zulu",     pattern: "4 triangles: black(top)/blue(right)/red(bottom)/yellow(left)", meaning: "I require a tug"),
]

private let distressSignals: [(String, String)] = [
    ("NC",         "International distress signal (2 flags)"),
    ("SOS",        "Morse code: ··· ––– ···  (any medium)"),
    ("MAYDAY",     "Voice: spoken 3× on Ch 16 (156.800 MHz)"),
    ("Orange smoke","Daytime visual distress signal"),
    ("Red flare",  "Pyrotechnic distress signal (night or day)"),
    ("Mirror flash","Signal mirror — aim at aircraft/ships"),
    ("Dye marker", "Bright orange/yellow sea dye — aerial visibility"),
    ("Arms",       "Raise/lower outstretched arms repeatedly"),
    ("Code flag V","Victor flag — I require assistance"),
    ("Code flag W","Whiskey flag — I require MEDICAL assistance"),
]

private struct SignalFlagsTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            CommCard(title: "Distress Signals", symbol: "exclamationmark.triangle.fill", color: .red) {
                VStack(spacing: 0) {
                    ForEach(Array(distressSignals.enumerated()), id: \.offset) { i, row in
                        HStack(spacing: 10) {
                            Text(row.0)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .frame(width: 90, alignment: .leading)
                            Text(row.1)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        if i < distressSignals.count - 1 { Divider() }
                    }
                }
            }

            CommCard(title: "Signal Flag Alphabet (A–Z)", symbol: "flag.fill", color: .blue) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Flag").font(.system(size: 10, weight: .bold)).frame(width: 38, alignment: .leading)
                        Text("Pattern").font(.system(size: 10, weight: .bold)).frame(width: 170, alignment: .leading)
                        Text("Single-flag meaning").font(.system(size: 10, weight: .bold))
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 5)
                    Divider()
                    ForEach(flagData, id: \.letter) { f in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(f.letter) \(f.word)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .frame(width: 90, alignment: .leading)
                            Text(f.pattern)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .frame(width: 170, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(f.meaning)
                                .font(.system(size: 10))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
            }
        }
    }
}

// MARK: - Emergency Radio Channels

private struct RadioSection {
    let name: String
    let color: Color
    let channels: [(String, String, String)]  // freq, name, purpose
}

private let radioSections: [RadioSection] = [
    RadioSection(name: "NOAA Weather Radio", color: .blue, channels: [
        ("162.550", "WX1", "Primary — most populated areas"),
        ("162.400", "WX2", "Secondary"),
        ("162.475", "WX3", "Secondary"),
        ("162.425", "WX4", "Secondary"),
        ("162.450", "WX5", "Secondary"),
        ("162.500", "WX6", "Secondary"),
        ("162.525", "WX7", "Secondary"),
    ]),
    RadioSection(name: "Marine VHF", color: Color(red: 0.0, green: 0.4, blue: 0.8), channels: [
        ("156.800 (Ch 16)", "International Distress",  "PRIMARY distress, safety, and calling — always monitor"),
        ("157.100 (Ch 22A)","US Coast Guard",          "USCG working channel after contact on 16"),
        ("156.525 (Ch 70)", "DSC Distress",            "Digital Selective Calling — automated distress only"),
        ("156.600 (Ch 12)", "Port Operations",         "Vessel traffic — large ports"),
        ("156.650 (Ch 13)", "Bridge-to-Bridge",        "Ship navigation — 1W only"),
        ("156.450 (Ch 9)",  "Recreational Calling",    "Pleasure vessel hailing channel"),
        ("156.300 (Ch 6)",  "Intership Safety",        "Search and rescue coordination"),
    ]),
    RadioSection(name: "Amateur / Ham Radio", color: .green, channels: [
        ("146.520",         "2m National Simplex",     "National FM calling frequency — no repeater needed"),
        ("52.525",          "6m National Simplex",     "6-meter national simplex calling"),
        ("7.290",           "40m HF Regional",         "Regional emergency / Skywarn nets"),
        ("14.300",          "20m HF Maritime",         "Maritime Mobile Service Net — worldwide"),
        ("5330.5 kHz",      "60m Ch 1 (USB)",          "Federal interoperability — emergency use"),
        ("5346.5 kHz",      "60m Ch 2 (USB)",          "Federal interoperability"),
        ("5357.0 kHz",      "60m Ch 3 (USB)",          "Federal interoperability"),
        ("5371.5 kHz",      "60m Ch 4 (USB)",          "Federal interoperability"),
        ("5403.5 kHz",      "60m Ch 5 (USB)",          "Federal interoperability"),
    ]),
    RadioSection(name: "CB Radio", color: .orange, channels: [
        ("Ch 9  (27.065 MHz)", "Emergency",            "Official CB emergency channel — monitored by REACT"),
        ("Ch 19 (27.185 MHz)", "Highway / Truckers",   "Trucker information — road hazards, traffic"),
    ]),
    RadioSection(name: "FRS / GMRS", color: .yellow, channels: [
        ("462.5625 (Ch 1)",  "FRS/GMRS",              "General calling — no license for FRS power"),
        ("462.5875 (Ch 2)",  "FRS/GMRS",              "General use"),
        ("462.6125 (Ch 3)",  "FRS/GMRS",              "General use"),
        ("467.5625 (Ch 8)",  "FRS only (0.5W)",       "FRS low-power simplex"),
        ("462.675  (Ch 20)", "GMRS Simplex",           "Common GMRS simplex calling"),
    ]),
    RadioSection(name: "Aviation", color: Color(red: 0.0, green: 0.5, blue: 0.5), channels: [
        ("121.500 MHz",      "Guard / Distress",       "INTERNATIONAL aeronautical emergency — always monitored"),
        ("243.000 MHz",      "Military UHF Guard",     "Military aircraft distress — AM mode"),
        ("122.800 MHz",      "UNICOM",                 "Uncontrolled airport advisory"),
        ("122.900 MHz",      "MULTICOM",               "Uncontrolled airport common traffic"),
    ]),
    RadioSection(name: "Law Enforcement / EMS", color: .red, channels: [
        ("155.340 MHz",      "Nat'l Interop Calling",  "Federal/state/local law enforcement coordination"),
        ("155.475 MHz",      "Police/Fire Mutual Aid", "Interoperability — mutual aid events"),
        ("154.280 MHz",      "Fire Dispatch (common)", "Varies by region — check local plan"),
        ("155.910 MHz",      "Police Dispatch (common)","Varies by region — check local plan"),
        ("866.0125 MHz",     "700 MHz Interop",        "FirstNet/LTE interoperability band"),
    ]),
    RadioSection(name: "HF International Distress", color: .purple, channels: [
        ("2182 kHz (USB)",   "Maritime HF Distress",   "Primary MF maritime distress — 3-min silence each hour"),
        ("4125 kHz (USB)",   "Maritime HF",            "Secondary MF/HF maritime"),
        ("8291 kHz (USB)",   "Maritime HF",            "Primary HF maritime distress"),
        ("12290 kHz (USB)",  "Maritime HF",            "HF maritime working"),
        ("16420 kHz (USB)",  "Maritime HF",            "HF maritime working"),
    ]),
]

private struct RadioChannelsTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            InfoBannerComm(
                symbol: "exclamationmark.circle.fill", color: .red,
                text: "ALWAYS monitor Marine Ch 16 (156.800 MHz) and Aviation 121.500 MHz if near water or airports. These are never used for routine traffic."
            )
            ForEach(radioSections, id: \.name) { section in
                CommCard(title: section.name, symbol: "antenna.radiowaves.left.and.right", color: section.color) {
                    VStack(spacing: 0) {
                        ForEach(Array(section.channels.enumerated()), id: \.offset) { i, ch in
                            HStack(alignment: .top, spacing: 8) {
                                Text(ch.0)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .frame(width: 140, alignment: .leading)
                                Text(ch.1)
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(width: 130, alignment: .leading)
                                Text(ch.2)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            if i < section.channels.count - 1 { Divider() }
                        }
                    }
                }
            }
        }
    }
}

private struct InfoBannerComm: View {
    let symbol: String; let color: Color; let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color).font(.system(size: 14, weight: .semibold))
            Text(text).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Knots Reference

private struct KnotEntry {
    let name: String
    let use: String
    let strength: String   // Relative knot strength vs. rope
    let steps: [String]
    let tips: String
}

private let knotData: [KnotEntry] = [
    KnotEntry(
        name: "Bowline",
        use: "Fixed loop that will not slip — rescue, tying off to anchor",
        strength: "~70% rope strength",
        steps: [
            "Make a small loop in the standing line (the 'rabbit hole')",
            "Pass the working end up through the hole from below",
            "Go around the standing part (the 'tree')",
            "Come back down through the hole",
            "Pull tight — loop size is set when you tighten"
        ],
        tips: "Remember: rabbit comes UP through the hole, AROUND the tree, then back DOWN. Never use as a climbing knot without a backup."
    ),
    KnotEntry(
        name: "Clove Hitch",
        use: "Securing rope to a post, railing, or tree — quick and adjustable",
        strength: "~60–75% rope strength",
        steps: [
            "Pass rope over the post and cross over itself",
            "Pass rope over post again, tucking end under the second wrap",
            "Pull both ends to tighten"
        ],
        tips: "Fast to tie but can slip under load if not backed up. Best for starting lashings. Add a half hitch for security."
    ),
    KnotEntry(
        name: "Square Knot (Reef Knot)",
        use: "Joining two ropes of equal diameter — first aid bandages, packages",
        strength: "~45% rope strength",
        steps: [
            "Cross right over left, then under",
            "Cross left over right, then under",
            "Pull both ends — the knot should lie flat"
        ],
        tips: "Only for ropes of the same diameter under low load. Can spill to a lark's head if uneven pull. NEVER use for life safety."
    ),
    KnotEntry(
        name: "Sheet Bend",
        use: "Joining two ropes of DIFFERENT sizes — most reliable joining knot",
        strength: "~50% of weaker rope strength",
        steps: [
            "Form a bight (loop) in the thicker rope",
            "Pass the thinner rope up through the bight from below",
            "Go around both sides of the bight",
            "Tuck thinner rope under itself (not under the bight)",
            "Both tails should exit on the same side — if not, redo"
        ],
        tips: "Both free ends must be on the same side. Double sheet bend for slippery ropes: wrap the thin line twice."
    ),
    KnotEntry(
        name: "Taut-Line Hitch",
        use: "Adjustable loop — tent guylines, adjustable tie-downs",
        strength: "~70% rope strength",
        steps: [
            "Wrap the working end around the standing line twice (toward anchor)",
            "Make one more wrap on the outside of those two",
            "Pull to set — slide knot to adjust tension"
        ],
        tips: "Slides under light tension but grips under load. Use on nylon/synthetic — may slip on slick cord."
    ),
    KnotEntry(
        name: "Figure-Eight",
        use: "Stopper knot — prevents rope from pulling through blocks, guides",
        strength: "~75–80% rope strength",
        steps: [
            "Make a loop",
            "Pass working end over standing part",
            "Bring working end under and up through the loop",
            "Pull tight"
        ],
        tips: "Easier to untie than an overhand knot after loading. Also used as a climbing attachment knot (Figure-8 Follow-Through)."
    ),
    KnotEntry(
        name: "Trucker's Hitch",
        use: "3:1 mechanical advantage — lashing loads, tensioning ridgelines",
        strength: "3× hauling force (be careful of overloading rope)",
        steps: [
            "Tie a slipped loop in the middle of the line (using a figure-eight or slip knot)",
            "Pass the working end around the anchor (tree, rack, etc.)",
            "Thread it UP through your loop — this is your pulley",
            "Pull down to tension — can achieve 3:1 mechanical advantage",
            "Secure with two half hitches to the standing line"
        ],
        tips: "The most useful load-securing knot. Critical for securing vehicle loads or tensioning tarps. Release the slip loop by pulling the tag end."
    ),
    KnotEntry(
        name: "Prusik Hitch",
        use: "Friction hitch — emergency rope ascender, load release control",
        strength: "Depends on loop cord vs. main rope diameter",
        steps: [
            "Make a small loop (sling) from 5–7mm cord",
            "Wrap the sling around the main rope 3 times through its own loop",
            "Dress the wraps neatly and push together",
            "Slides freely when unweighted; grips when loaded"
        ],
        tips: "Sling cord must be 60–80% of main rope diameter. Doesn't work well on wet/icy rope. Use a Klemheist or Bachmann in those conditions."
    ),
]

private struct KnotsTab: View {
    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            InfoBannerComm(symbol: "info.circle", color: .blue,
                           text: "Practice each knot until you can tie it in the dark with cold hands. Tap a knot to see tying steps.")

            ForEach(knotData, id: \.name) { knot in
                KnotCard(knot: knot, isExpanded: expanded.contains(knot.name)) {
                    if expanded.contains(knot.name) { expanded.remove(knot.name) }
                    else { expanded.insert(knot.name) }
                }
            }
        }
    }
}

private struct KnotCard: View {
    let knot: KnotEntry
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.brown)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(knot.name)
                            .font(.system(size: 13, weight: .semibold))
                        Text(knot.use)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(isExpanded ? nil : 1)
                    }
                    Spacer()
                    Text(knot.strength)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to tie:")
                        .font(.system(size: 11, weight: .semibold))
                    ForEach(Array(knot.steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(i + 1).")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.brown)
                                .frame(width: 18)
                            Text(step)
                                .font(.system(size: 11))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                        Text(knot.tips)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                    .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
                }
                .padding([.horizontal, .bottom], 12)
            }
        }
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1))
    }
}

// MARK: - Shared Card Component

struct CommCard<Content: View>: View {
    let title: String
    let symbol: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            Divider()
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
    }
}
