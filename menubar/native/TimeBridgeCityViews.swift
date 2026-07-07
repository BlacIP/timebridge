import AppKit

final class ClockRowView: NSView {
    init(choice: ZoneChoice, zone: TimeZone, date: Date, dotColor: NSColor, badgeTextColor: NSColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 56).isActive = true // Figma: city rows are 56pt

        let title = label(cityName(choice), size: 18, weight: .medium, lineHeight: 24, tracking: -0.27)
        let badge = BadgeView(text: fmt(zone, "zzz", date), foreground: badgeTextColor, background: TBColor.strong)
        let titleRow = NSStackView(views: [title, badge])
        titleRow.orientation = .horizontal
        titleRow.spacing = 6
        titleRow.alignment = .centerY

        let regionText = regionName(choice).isEmpty ? choice.label : regionName(choice)
        let region = label(regionText, size: 12, color: TBColor.sub, lineHeight: 16)
        let meta = NSStackView(views: [titleRow, region])
        meta.orientation = .vertical
        meta.spacing = 2
        meta.alignment = .leading

        let time = label(fmt(zone, "h:mm a", date), size: 32, weight: .medium, align: .right)
        let day = label(fmt(zone, "EEE, MMM d", date), size: 12, color: TBColor.softText, lineHeight: 16, align: .right)
        let right = NSStackView(views: [time, day])
        right.orientation = .vertical
        right.spacing = 2
        right.alignment = .trailing

        let row = NSStackView(views: [DotView(color: dotColor), meta, FixedSpacer(), right])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class UpperTimeBlockView: NSView {
    var onPrimaryPick: ((NSButton) -> Void)?
    var onSecondaryPick: ((NSButton) -> Void)?

    init(primary: ZoneChoice, secondary: ZoneChoice, primaryZone: TimeZone, secondaryZone: TimeZone, date: Date) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        // Height derives from the rows/summary stack (Figma: 188 total).

        let summary = NSView()
        summary.wantsLayer = true
        summary.layer?.backgroundColor = TBColor.stroke.cgColor
        summary.translatesAutoresizingMaskIntoConstraints = false
        summary.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let summaryText = label(
            offsetSummary(from: primaryZone, to: secondaryZone, fromLabel: primary.label, toLabel: secondary.label, at: date),
            size: 14,
            color: TBColor.sub,
            lineHeight: 20,
            tracking: -0.084,
            align: .center
        )
        summaryText.translatesAutoresizingMaskIntoConstraints = false
        summary.addSubview(summaryText)

        let primaryRow = ActionAreaButton(content: ClockRowView(choice: primary, zone: primaryZone, date: date, dotColor: TBColor.lagosDot, badgeTextColor: TBColor.primaryLight), height: 56)
        primaryRow.onPress = { [weak self, weak primaryRow] in
            if let primaryRow { self?.onPrimaryPick?(primaryRow) }
        }
        let secondaryRow = ActionAreaButton(content: ClockRowView(choice: secondary, zone: secondaryZone, date: date, dotColor: TBColor.provoDot, badgeTextColor: TBColor.verified), height: 56)
        secondaryRow.onPress = { [weak self, weak secondaryRow] in
            if let secondaryRow { self?.onSecondaryPick?(secondaryRow) }
        }

        let stack = NSStackView(views: [primaryRow, DividerView(), secondaryRow, summary])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            summaryText.centerXAnchor.constraint(equalTo: summary.centerXAnchor),
            summaryText.centerYAnchor.constraint(equalTo: summary.centerYAnchor),
            summaryText.leadingAnchor.constraint(greaterThanOrEqualTo: summary.leadingAnchor, constant: 22),
            summaryText.trailingAnchor.constraint(lessThanOrEqualTo: summary.trailingAnchor, constant: -22),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        for child in stack.arrangedSubviews {
            child.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
