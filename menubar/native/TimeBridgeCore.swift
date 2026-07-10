import AppKit

struct ZoneChoice {
    let id: String
    let label: String
    let code: String
    let icon: String
}

let zoneChoices: [ZoneChoice] = [
    .init(id: "America/Denver", label: "Provo, Utah", code: "PRO", icon: "🏔"),
    .init(id: "America/Phoenix", label: "Phoenix, Arizona", code: "PHX", icon: "🌵"),
    .init(id: "America/Los_Angeles", label: "Los Angeles, California", code: "LA", icon: "🌴"),
    .init(id: "America/Chicago", label: "Chicago, Illinois", code: "CHI", icon: "🌆"),
    .init(id: "America/New_York", label: "New York, New York", code: "NYC", icon: "🗽"),
    .init(id: "Europe/London", label: "London, UK", code: "LON", icon: "🇬🇧"),
    .init(id: "Europe/Paris", label: "Paris, France", code: "PAR", icon: "🥐"),
    .init(id: "Africa/Lagos", label: "Lagos, Nigeria", code: "LOS", icon: "🇳🇬"),
    .init(id: "Africa/Johannesburg", label: "Johannesburg, South Africa", code: "JNB", icon: "🇿🇦"),
    .init(id: "Asia/Kolkata", label: "Kolkata, India", code: "CCU", icon: "🇮🇳"),
    .init(id: "Asia/Dubai", label: "Dubai, UAE", code: "DXB", icon: "🇦🇪"),
    .init(id: "Asia/Manila", label: "Manila, Philippines", code: "MNL", icon: "🇵🇭"),
    .init(id: "Asia/Tokyo", label: "Tokyo, Japan", code: "TYO", icon: "🇯🇵"),
    .init(id: "UTC", label: "UTC", code: "UTC", icon: "🌐"),
]

let defaultFromZoneID = "America/Denver"
let defaultToZoneID = "Africa/Lagos"
let fromDefaultsKey = "timebridge.fromZoneID"
let toDefaultsKey = "timebridge.toZoneID"
let appURL = "" // your deployed TimeBridge URL, e.g. "https://timebridge.vercel.app"

func fmt(_ zone: TimeZone, _ pattern: String, _ date: Date = Date()) -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = zone
    df.dateFormat = pattern
    return df.string(from: date)
}

func zoneChoice(for id: String) -> ZoneChoice {
    let fallback = id.split(separator: "/").last.map(String.init) ?? id
    return zoneChoices.first(where: { $0.id == id }) ?? .init(
        id: id,
        label: id.replacingOccurrences(of: "_", with: " "),
        code: String(fallback.prefix(3)).uppercased(),
        icon: "🕒"
    )
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

func compactTime(_ zone: TimeZone, _ date: Date = Date()) -> String {
    fmt(zone, "h:mma", date).lowercased().replacingOccurrences(of: "m", with: "")
}

func offsetSummary(from fromZone: TimeZone, to toZone: TimeZone, fromLabel: String, toLabel: String, at date: Date = Date()) -> String {
    let diffMin = (toZone.secondsFromGMT(for: date) - fromZone.secondsFromGMT(for: date)) / 60
    if diffMin == 0 { return "\(toLabel) is level with \(fromLabel)" }
    let h = abs(diffMin) / 60
    let m = abs(diffMin) % 60
    let span = m == 0 ? "\(h)h" : "\(h)h \(m)m"
    return "\(toLabel) is \(span) \(diffMin > 0 ? "ahead of" : "behind") \(fromLabel)"
}

func calendarDayDiff(from fromZone: TimeZone, to toZone: TimeZone, at date: Date) -> Int {
    var fromCalendar = Calendar(identifier: .gregorian)
    fromCalendar.timeZone = fromZone
    var toCalendar = Calendar(identifier: .gregorian)
    toCalendar.timeZone = toZone
    var neutralCalendar = Calendar(identifier: .gregorian)
    neutralCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let fromParts = fromCalendar.dateComponents([.year, .month, .day], from: date)
    let toParts = toCalendar.dateComponents([.year, .month, .day], from: date)
    guard
        let fromDay = neutralCalendar.date(from: fromParts),
        let toDay = neutralCalendar.date(from: toParts)
    else { return 0 }
    return neutralCalendar.dateComponents([.day], from: fromDay, to: toDay).day ?? 0
}

// Set by the app delegate so dropdown menus opened from inside the popover
// don't dismiss it (a transient popover closes on outside-window clicks).
var presentMenuGuard: ((NSMenu, NSView) -> Void)?

func presentDropdownMenu(_ menu: NSMenu, from anchor: NSView) {
    if let present = presentMenuGuard {
        present(menu, anchor)
    } else {
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: anchor.bounds.height + 4), in: anchor)
    }
}

// Wall-clock fields in a specific zone — the converter's source of truth.
struct WallClock {
    var year: Int, month: Int, day: Int, hour: Int, minute: Int
}

func wallClock(of date: Date, in zone: TimeZone) -> WallClock {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = zone
    let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    return WallClock(year: c.year ?? 2026, month: c.month ?? 1, day: c.day ?? 1,
                     hour: c.hour ?? 0, minute: c.minute ?? 0)
}

func instant(of wall: WallClock, in zone: TimeZone) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = zone
    let c = DateComponents(year: wall.year, month: wall.month, day: wall.day,
                           hour: wall.hour, minute: wall.minute)
    return cal.date(from: c) ?? Date()
}

// Sensible meeting-time default, mirroring the web app.
func roundedUpToHalfHour(_ date: Date, in zone: TimeZone) -> WallClock {
    var w = wallClock(of: date, in: zone)
    let total = min(((w.hour * 60 + w.minute + 29) / 30) * 30, 23 * 60 + 30)
    w.hour = total / 60
    w.minute = total % 60
    return w
}

func parseDateText(_ raw: String) -> (year: Int, month: Int, day: Int)? {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    for pattern in ["MM/dd/yyyy", "M/d/yyyy", "yyyy-MM-dd"] {
        f.dateFormat = pattern
        if let d = f.date(from: raw.trimmingCharacters(in: .whitespaces)) {
            let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: d)
            if let y = c.year, let m = c.month, let day = c.day { return (y, m, day) }
        }
    }
    return nil
}

// Chat-pasteable conversion line, same shape as the web app's copy button.
func copyLine(fromZone: TimeZone, toZone: TimeZone, fromLabel: String, toLabel: String, at date: Date) -> String {
    "\(fmt(fromZone, "h:mm a zzz", date)) (\(fromLabel), \(fmt(fromZone, "EEE, MMM d", date)))"
        + " → \(fmt(toZone, "h:mm a zzz", date)) (\(toLabel), \(fmt(toZone, "EEE, MMM d", date)))"
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
