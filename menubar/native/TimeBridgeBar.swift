// TimeBridge Bar — a tiny native macOS menu bar app. No dependencies.
// Build with ./build.sh (uses Apple's own Swift compiler).
import AppKit

// ── Configuration ─────────────────────────────────────────────────────
struct ZoneChoice {
    let id: String
    let label: String
    let icon: String
}

let zoneChoices: [ZoneChoice] = [
    .init(id: "America/Denver", label: "Provo, Utah", icon: "🏔"),
    .init(id: "America/Phoenix", label: "Phoenix, Arizona", icon: "🌵"),
    .init(id: "America/Los_Angeles", label: "Los Angeles, California", icon: "🌴"),
    .init(id: "America/Chicago", label: "Chicago, Illinois", icon: "🌆"),
    .init(id: "America/New_York", label: "New York, New York", icon: "🗽"),
    .init(id: "Europe/London", label: "London, UK", icon: "🇬🇧"),
    .init(id: "Europe/Paris", label: "Paris, France", icon: "🥐"),
    .init(id: "Africa/Lagos", label: "Lagos, Nigeria", icon: "🇳🇬"),
    .init(id: "Africa/Johannesburg", label: "Johannesburg, South Africa", icon: "🇿🇦"),
    .init(id: "Asia/Kolkata", label: "Kolkata, India", icon: "🇮🇳"),
    .init(id: "Asia/Dubai", label: "Dubai, UAE", icon: "🇦🇪"),
    .init(id: "Asia/Tokyo", label: "Tokyo, Japan", icon: "🇯🇵"),
    .init(id: "UTC", label: "UTC", icon: "🌐"),
]

let defaultFromZoneID = "America/Denver"
let defaultToZoneID = "Africa/Lagos"
let appURL = "" // your deployed TimeBridge URL, e.g. "https://timebridge.vercel.app"
// ──────────────────────────────────────────────────────────────────────

func fmt(_ zone: TimeZone, _ pattern: String, _ date: Date = Date()) -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = zone
    df.dateFormat = pattern
    return df.string(from: date)
}

func zoneChoice(for id: String) -> ZoneChoice {
    zoneChoices.first(where: { $0.id == id }) ?? .init(id: id, label: id.replacingOccurrences(of: "_", with: " "), icon: "🕒")
}

func timeZoneFor(id: String) -> TimeZone {
    TimeZone(identifier: id) ?? .current
}

func parseTime(_ raw: String) -> (hour: Int, minute: Int)? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    for pattern in ["h:mm a", "hh:mm a", "H:mm", "HH:mm"] {
        formatter.dateFormat = pattern
        if let date = formatter.date(from: trimmed) {
            let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: date)
            return (components.hour ?? 0, components.minute ?? 0)
        }
    }
    return nil
}

func convertTimeString(_ input: String, fromZone: TimeZone, toZone: TimeZone, fromLabel: String, toLabel: String) -> String? {
    guard let parsed = parseTime(input) else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = fromZone
    let now = Date()
    guard let instant = calendar.date(bySettingHour: parsed.hour, minute: parsed.minute, second: 0, of: now) else { return nil }
    let fromText = fmt(fromZone, "EEE, MMM d · h:mm a zzz", instant)
    let toText = fmt(toZone, "EEE, MMM d · h:mm a zzz", instant)
    return "\(fromLabel): \(fromText)\n\(toLabel): \(toText)"
}

final class ConverterMenuView: NSView {
    let timeField = NSTextField(frame: .zero)
    let resultLabel = NSTextField(labelWithString: "")
    let convertButton = NSButton(title: "Convert", target: nil, action: nil)

    var onConvert: ((String) -> String?)?

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 128))
        wantsLayer = true

        let heading = NSTextField(labelWithString: "Convert a time in the selected from-zone")
        heading.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        heading.lineBreakMode = .byWordWrapping

        timeField.placeholderString = "9:00 AM"
        timeField.stringValue = "9:00 AM"
        timeField.bezelStyle = .roundedBezel
        timeField.target = self
        timeField.action = #selector(convertPressed)

        convertButton.bezelStyle = .rounded
        convertButton.target = self
        convertButton.action = #selector(convertPressed)

        resultLabel.stringValue = "Pick a time and press Convert."
        resultLabel.lineBreakMode = .byWordWrapping
        resultLabel.maximumNumberOfLines = 3

        let controls = NSStackView(views: [timeField, convertButton])
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.alignment = .centerY
        controls.distribution = .fill

        timeField.translatesAutoresizingMaskIntoConstraints = false
        convertButton.translatesAutoresizingMaskIntoConstraints = false
        timeField.widthAnchor.constraint(equalToConstant: 170).isActive = true
        convertButton.widthAnchor.constraint(equalToConstant: 78).isActive = true

        let stack = NSStackView(views: [heading, controls, resultLabel])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func convertPressed() {
        guard let onConvert else { return }
        resultLabel.stringValue = onConvert(timeField.stringValue) ?? "Use a time like 9:00 AM or 14:30."
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var fromZoneID = defaultFromZoneID
    private var toZoneID = defaultToZoneID

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refreshTitle()
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in self?.refreshTitle() }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func refreshTitle() {
        let fromZone = timeZoneFor(id: fromZoneID)
        let toZone = timeZoneFor(id: toZoneID)
        let from = zoneChoice(for: fromZoneID)
        let to = zoneChoice(for: toZoneID)
        let f = fmt(fromZone, "h:mma").lowercased()
        let t = fmt(toZone, "h:mma").lowercased()
        statusItem.button?.title = "\(from.icon) \(f) · \(to.icon) \(t)"
    }

    private func infoLine(_ menu: NSMenu, _ text: String) {
        let item = NSMenuItem()
        item.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
        ])
        item.isEnabled = false
        menu.addItem(item)
    }

    // Rebuilt each time the menu opens, so it's always current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let now = Date()
        let fromZone = timeZoneFor(id: fromZoneID)
        let toZone = timeZoneFor(id: toZoneID)
        let from = zoneChoice(for: fromZoneID)
        let to = zoneChoice(for: toZoneID)

        infoLine(menu, "\(from.label) — \(fmt(fromZone, "EEE, MMM d · h:mm a zzz", now))")
        infoLine(menu, "\(to.label) — \(fmt(toZone, "EEE, MMM d · h:mm a zzz", now))")
        menu.addItem(.separator())

        let diffMin = (toZone.secondsFromGMT(for: now) - fromZone.secondsFromGMT(for: now)) / 60
        let h = abs(diffMin) / 60, m = abs(diffMin) % 60
        let span = m == 0 ? "\(h)h" : "\(h)h \(m)m"
        let rel = diffMin > 0 ? "ahead of" : diffMin < 0 ? "behind" : "level with"
        infoLine(menu, diffMin == 0 ? "\(to.label) is level with \(from.label)" : "\(to.label) is \(span) \(rel) \(from.label)")
        menu.addItem(.separator())

        let fromItem = NSMenuItem(title: "Change from zone", action: nil, keyEquivalent: "")
        let fromMenu = NSMenu()
        for choice in zoneChoices {
            let row = NSMenuItem(title: "\(choice.icon) \(choice.label)", action: #selector(selectFromZone(_:)), keyEquivalent: "")
            row.target = self
            row.representedObject = choice.id as NSString
            row.state = choice.id == fromZoneID ? .on : .off
            fromMenu.addItem(row)
        }
        fromItem.submenu = fromMenu
        menu.addItem(fromItem)

        let toItem = NSMenuItem(title: "Change to zone", action: nil, keyEquivalent: "")
        let toMenu = NSMenu()
        for choice in zoneChoices {
            let row = NSMenuItem(title: "\(choice.icon) \(choice.label)", action: #selector(selectToZone(_:)), keyEquivalent: "")
            row.target = self
            row.representedObject = choice.id as NSString
            row.state = choice.id == toZoneID ? .on : .off
            toMenu.addItem(row)
        }
        toItem.submenu = toMenu
        menu.addItem(toItem)
        menu.addItem(.separator())

        let convertHeader = NSMenuItem(title: "Convert a time", action: nil, keyEquivalent: "")
        convertHeader.isEnabled = false
        menu.addItem(convertHeader)

        let converterItem = NSMenuItem()
        let converterView = ConverterMenuView()
        converterView.onConvert = { [weak self] raw in
            guard let self else { return nil }
            let fromZone = timeZoneFor(id: self.fromZoneID)
            let toZone = timeZoneFor(id: self.toZoneID)
            let from = zoneChoice(for: self.fromZoneID)
            let to = zoneChoice(for: self.toZoneID)
            return convertTimeString(raw, fromZone: fromZone, toZone: toZone, fromLabel: from.label, toLabel: to.label)
        }
        converterView.timeField.stringValue = fmt(fromZone, "h:mm a", now)
        converterView.resultLabel.stringValue = convertTimeString(converterView.timeField.stringValue, fromZone: fromZone, toZone: toZone, fromLabel: from.label, toLabel: to.label) ?? "Use a time like 9:00 AM or 14:30."
        converterItem.view = converterView
        menu.addItem(converterItem)

        // Quick reference: FROM-zone business hours today.
        let refItem = NSMenuItem(title: "Meeting quick reference", action: nil, keyEquivalent: "")
        let refMenu = NSMenu()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = fromZone
        for hour in 8...17 {
            guard let d = cal.date(bySettingHour: hour, minute: 0, second: 0, of: now) else { continue }
            let fromStr = fmt(fromZone, "h:mm a", d)
            let toStr = fmt(toZone, "h:mm a", d)
            let nextDay = fmt(fromZone, "yyyy-MM-dd", d) != fmt(toZone, "yyyy-MM-dd", d)
            let padded = String(repeating: " ", count: max(0, 8 - fromStr.count)) + fromStr
            let row = NSMenuItem()
            row.attributedTitle = NSAttributedString(
                string: "\(padded)  →  \(toStr)\(nextDay ? "  (+1d)" : "")",
                attributes: [.font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)]
            )
            row.isEnabled = false
            refMenu.addItem(row)
        }
        refItem.submenu = refMenu
        menu.addItem(refItem)
        menu.addItem(.separator())

        if !appURL.isEmpty {
            let open = NSMenuItem(title: "Open Converter", action: #selector(openConverter), keyEquivalent: "o")
            open.target = self
            menu.addItem(open)
        }
        let quit = NSMenuItem(title: "Quit TimeBridge Bar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func selectFromZone(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String {
            fromZoneID = id
            refreshTitle()
        }
    }

    @objc private func selectToZone(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String {
            toZoneID = id
            refreshTitle()
        }
    }

    @objc private func openConverter() {
        if let url = URL(string: appURL) { NSWorkspace.shared.open(url) }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu bar only — no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
