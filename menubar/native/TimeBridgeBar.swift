// TimeBridge Bar — a tiny native macOS menu bar app. No dependencies.
// Build with ./build.sh (uses Apple's own Swift compiler).
import AppKit

// ── Configuration ─────────────────────────────────────────────────────
let fromZone = TimeZone(identifier: "America/Denver")!
let toZone = TimeZone(identifier: "Africa/Lagos")!
let fromIcon = "🏔", fromLabel = "Provo"
let toIcon = "🇳🇬", toLabel = "Lagos"
let appURL = "" // your deployed TimeBridge URL, e.g. "https://timebridge.vercel.app"
// ──────────────────────────────────────────────────────────────────────

func fmt(_ zone: TimeZone, _ pattern: String, _ date: Date = Date()) -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = zone
    df.dateFormat = pattern
    return df.string(from: date)
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

func convertTimeString(_ input: String) -> String? {
    guard let parsed = parseTime(input) else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = fromZone
    let now = Date()
    guard let instant = calendar.date(bySettingHour: parsed.hour, minute: parsed.minute, second: 0, of: now) else { return nil }
    let fromText = fmt(fromZone, "EEE, MMM d · h:mm a zzz", instant)
    let toText = fmt(toZone, "EEE, MMM d · h:mm a zzz", instant)
    return "\(fromLabel): \(fromText)\n\(toLabel): \(toText)"
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!

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
        let f = fmt(fromZone, "h:mma").lowercased()
        let t = fmt(toZone, "h:mma").lowercased()
        statusItem.button?.title = "\(fromIcon) \(f) · \(toIcon) \(t)"
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

        infoLine(menu, "\(fromLabel) — \(fmt(fromZone, "EEE, MMM d · h:mm a zzz", now))")
        infoLine(menu, "\(toLabel) — \(fmt(toZone, "EEE, MMM d · h:mm a zzz", now))")
        menu.addItem(.separator())

        let diffMin = (toZone.secondsFromGMT(for: now) - fromZone.secondsFromGMT(for: now)) / 60
        let h = abs(diffMin) / 60, m = abs(diffMin) % 60
        let span = m == 0 ? "\(h)h" : "\(h)h \(m)m"
        let rel = diffMin > 0 ? "ahead of" : diffMin < 0 ? "behind" : "level with"
        infoLine(menu, diffMin == 0 ? "\(toLabel) is level with \(fromLabel)" : "\(toLabel) is \(span) \(rel) \(fromLabel)")
        menu.addItem(.separator())

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
        let convert = NSMenuItem(title: "Convert a Time…", action: #selector(promptForConversion), keyEquivalent: "")
        convert.target = self
        menu.addItem(convert)
        let quit = NSMenuItem(title: "Quit TimeBridge Bar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func openConverter() {
        if let url = URL(string: appURL) { NSWorkspace.shared.open(url) }
    }

    @objc private func promptForConversion() {
        let alert = NSAlert()
        alert.messageText = "Convert a Time"
        alert.informativeText = "Enter a time in Provo (for example, 9:00 AM)."
        alert.alertStyle = .informational

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        input.stringValue = "9:00 AM"
        alert.accessoryView = input
        alert.addButton(withTitle: "Convert")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let result = convertTimeString(input.stringValue) else {
            let error = NSAlert()
            error.messageText = "Invalid Time"
            error.informativeText = "Use a time like 9:00 AM or 14:30."
            error.runModal()
            return
        }

        let resultAlert = NSAlert()
        resultAlert.messageText = "Conversion Result"
        resultAlert.informativeText = result
        resultAlert.alertStyle = .informational
        resultAlert.addButton(withTitle: "OK")
        resultAlert.runModal()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu bar only — no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
