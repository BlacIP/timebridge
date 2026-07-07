import AppKit

private final class FlippedContentView: NSView {
    override var isFlipped: Bool { true }
}

final class TimeBridgeMenuView: NSView {
    var onSwap: (() -> Void)?
    var onPickFrom: ((NSButton) -> Void)?
    var onPickTo: ((NSButton) -> Void)?
    var onQuit: (() -> Void)?

    init(from: ZoneChoice, to: ZoneChoice, fromZone: TimeZone, toZone: TimeZone, date: Date, canOpenApp: Bool) {
        super.init(frame: NSRect(x: 0, y: 0, width: 402, height: 856))
        translatesAutoresizingMaskIntoConstraints = false

        let primaryIsTo = to.id == "Africa/Lagos"
        let primary = primaryIsTo ? to : from
        let secondary = primaryIsTo ? from : to
        let primaryZone = primaryIsTo ? toZone : fromZone
        let secondaryZone = primaryIsTo ? fromZone : toZone

        let content = makeContent(
            primary: primary,
            secondary: secondary,
            primaryZone: primaryZone,
            secondaryZone: secondaryZone,
            primaryIsTo: primaryIsTo,
            date: date
        )
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.documentView = content
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        NSLayoutConstraint.activate([
            content.widthAnchor.constraint(equalToConstant: 402),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Design height is 856; only shrink (and scroll) when the screen is
        // too short for the full dropdown.
        let contentHeight = content.fittingSize.height
        let maxHeight = (NSScreen.main?.visibleFrame.height ?? 900) - 30
        widthAnchor.constraint(equalToConstant: 402).isActive = true
        heightAnchor.constraint(equalToConstant: min(contentHeight, maxHeight)).isActive = true
    }

    private func makeContent(primary: ZoneChoice, secondary: ZoneChoice, primaryZone: TimeZone, secondaryZone: TimeZone, primaryIsTo: Bool, date: Date) -> NSView {
        // Height comes from the stack + 24pt insets, so the sections can't
        // drift out of sync with a hard-coded total.
        let content = FlippedContentView(frame: NSRect(x: 0, y: 0, width: 402, height: 856))
        content.translatesAutoresizingMaskIntoConstraints = false
        content.wantsLayer = true
        content.layer?.backgroundColor = TBColor.panel.cgColor
        content.layer?.borderColor = TBColor.stroke.cgColor
        content.layer?.borderWidth = 1
        content.layer?.cornerRadius = 12

        let upper = UpperTimeBlockView(primary: primary, secondary: secondary, primaryZone: primaryZone, secondaryZone: secondaryZone, date: date)
        upper.onPrimaryPick = { [weak self] button in primaryIsTo ? self?.onPickTo?(button) : self?.onPickFrom?(button) }
        upper.onSecondaryPick = { [weak self] button in primaryIsTo ? self?.onPickFrom?(button) : self?.onPickTo?(button) }

        let converter = ConverterSectionView(from: secondary, to: primary, fromZone: secondaryZone, toZone: primaryZone, date: date)
        converter.onSwap = { [weak self] in self?.onSwap?() }

        let quit = BadgeButton(title: "QUIT")
        quit.onPress = { [weak self] in self?.onQuit?() }
        let footer = NSStackView(views: [FixedSpacer(), quit])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let stack = NSStackView(views: [
            upper,
            DividerView(),
            converter,
            DividerView(),
            // Same direction as the converter card: FROM-zone business hours.
            ReferenceTableView(fromZone: secondaryZone, toZone: primaryZone, date: date),
            DividerView(),
            footer,
        ])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
        ])
        // .width alignment can yield to child hugging; pin widths so every
        // section spans the full 354pt column like the design.
        for child in stack.arrangedSubviews {
            child.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return content
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
