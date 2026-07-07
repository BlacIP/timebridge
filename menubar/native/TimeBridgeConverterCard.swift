import AppKit

// The functional converter. All three pickers hold the SAME instant, each
// rendered in its own zone — so editing any one of them (date, from-time,
// to-time) updates the others immediately. No text parsing involved.
final class ConverterCardView: NSView {
    private let from: ZoneChoice
    private let to: ZoneChoice
    private let fromZone: TimeZone
    private let toZone: TimeZone
    private let dateBox: PickerBoxView
    private let fromBox: PickerBoxView
    private let toBox: PickerBoxView
    private let summary: SummaryRowView
    private var instantValue: Date

    init(from: ZoneChoice, to: ZoneChoice, fromZone: TimeZone, toZone: TimeZone, date: Date) {
        self.from = from
        self.to = to
        self.fromZone = fromZone
        self.toZone = toZone
        instantValue = instant(of: roundedUpToHalfHour(date, in: fromZone), in: fromZone)
        dateBox = PickerBoxView(elements: .yearMonthDay, zone: fromZone, icon: "calendar")
        fromBox = PickerBoxView(elements: .hourMinute, zone: fromZone, icon: "clock", use24Hour: true)
        toBox = PickerBoxView(elements: .hourMinute, zone: toZone, icon: "clock", use24Hour: true)
        summary = SummaryRowView(text: "", dayDiff: 0)

        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = TBColor.strong.cgColor
        layer?.borderColor = TBColor.stroke.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = 12
        translatesAutoresizingMaskIntoConstraints = false

        let dateGroup = InputGroupView(title: "Date in \(cityName(from))", content: dateBox)
        let fromGroup = InputGroupView(title: "Time in \(cityName(from))", content: fromBox)
        let toGroup = InputGroupView(title: "Time in \(cityName(to))", content: toBox)

        let equals = label("=", family: "Inter", size: 16, weight: .medium, color: TBColor.softText, lineHeight: 24, tracking: -0.176, align: .center)
        equals.widthAnchor.constraint(equalToConstant: 24).isActive = true
        equals.heightAnchor.constraint(equalToConstant: 40).isActive = true
        let timeRow = NSStackView(views: [fromGroup, equals, toGroup])
        NSLayoutConstraint.activate([
            fromGroup.widthAnchor.constraint(equalToConstant: 137),
            toGroup.widthAnchor.constraint(equalTo: fromGroup.widthAnchor),
        ])
        timeRow.orientation = .horizontal
        timeRow.alignment = .bottom
        timeRow.spacing = 12

        let stack = NSStackView(views: [dateGroup, timeRow, summary])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
        for child in [dateGroup, timeRow, summary] {
            child.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        dateBox.onChange = { [weak self] d in self?.setInstant(d, from: self?.dateBox) }
        fromBox.onChange = { [weak self] d in self?.setInstant(d, from: self?.fromBox) }
        toBox.onChange = { [weak self] d in self?.setInstant(d, from: self?.toBox) }
        dateBox.onIconTap = { [weak self] in self?.showDateMenu() }
        fromBox.onIconTap = { [weak self] in self?.showTimeMenu(isFrom: true) }
        toBox.onIconTap = { [weak self] in self?.showTimeMenu(isFrom: false) }
        summary.onCopy = { [weak self] in self?.copyConversion() }

        setInstant(instantValue)
    }

    // Single source of truth: push the instant into every picker except the
    // one being edited (rewriting it mid-edit would drop segment focus).
    private func setInstant(_ d: Date, from sender: PickerBoxView? = nil) {
        instantValue = d
        for box in [dateBox, fromBox, toBox] where box !== sender {
            box.picker.dateValue = d
        }
        summary.update(
            text: "\(fmt(toZone, "EEE, MMM d", d)) · \(fmt(toZone, "zzz", d)) in \(cityName(to))",
            dayDiff: calendarDayDiff(from: fromZone, to: toZone, at: d)
        )
    }

    /* ---------- Dropdown menus ---------- */

    private func showDateMenu() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = fromZone
        let todayStart = cal.startOfDay(for: Date())
        let menu = NSMenu()
        for offset in 0..<14 {
            guard let day = cal.date(byAdding: .day, value: offset, to: todayStart) else { continue }
            let title = offset == 0 ? "Today" : offset == 1 ? "Tomorrow" : fmt(fromZone, "EEE, MMM d", day)
            let item = NSMenuItem(title: title, action: #selector(pickDate(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = day
            item.state = cal.isDate(day, inSameDayAs: instantValue) ? .on : .off
            menu.addItem(item)
        }
        presentDropdownMenu(menu, from: dateBox)
    }

    @objc private func pickDate(_ sender: NSMenuItem) {
        guard let day = sender.representedObject as? Date else { return }
        var wall = wallClock(of: instantValue, in: fromZone)
        let d = wallClock(of: day, in: fromZone)
        wall.year = d.year
        wall.month = d.month
        wall.day = d.day
        setInstant(instant(of: wall, in: fromZone))
    }

    private func showTimeMenu(isFrom: Bool) {
        let zone = isFrom ? fromZone : toZone
        let current = wallClock(of: instantValue, in: zone)
        let menu = NSMenu()
        for mins in stride(from: 0, to: 24 * 60, by: 30) {
            var wall = current
            wall.hour = mins / 60
            wall.minute = mins % 60
            let item = NSMenuItem(title: fmt(zone, "h:mm a", instant(of: wall, in: zone)),
                                  action: #selector(pickTime(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ["mins": mins, "from": isFrom]
            item.state = (current.hour * 60 + current.minute) == mins ? .on : .off
            menu.addItem(item)
        }
        presentDropdownMenu(menu, from: isFrom ? fromBox : toBox)
    }

    @objc private func pickTime(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let mins = info["mins"] as? Int,
              let isFrom = info["from"] as? Bool else { return }
        let zone = isFrom ? fromZone : toZone
        var wall = wallClock(of: instantValue, in: zone)
        wall.hour = mins / 60
        wall.minute = mins % 60
        setInstant(instant(of: wall, in: zone))
    }

    /* ---------- Copy ---------- */

    func copyConversion() {
        let line = copyLine(fromZone: fromZone, toZone: toZone,
                            fromLabel: cityName(from), toLabel: cityName(to),
                            at: instantValue)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(line, forType: .string)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
