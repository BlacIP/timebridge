import AppKit

// Input box styled like the design's date/time fields, hosting a native
// NSDatePicker (segmented editing — click a segment, type or use arrow keys)
// plus an icon button that opens a dropdown menu of values.
final class PickerBoxView: NSView {
    let picker = NSDatePicker()
    var onChange: ((Date) -> Void)?
    var onIconTap: (() -> Void)?

    init(elements: NSDatePicker.ElementFlags, zone: TimeZone, icon: String, use24Hour: Bool = false) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = TBColor.surface800.cgColor
        layer?.borderColor = TBColor.stroke.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = 10
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 40).isActive = true

        picker.datePickerStyle = .textField
        picker.datePickerElements = elements
        picker.isBezeled = false
        picker.isBordered = false
        picker.drawsBackground = false
        picker.focusRingType = .none
        picker.font = tbFont("Inter", 16, .medium)
        picker.appearance = NSAppearance(named: .darkAqua) // white text on the dark box
        picker.timeZone = zone
        picker.locale = Locale(identifier: use24Hour ? "en_GB" : "en_US") // 22:30 vs 07/07/2026
        picker.target = self
        picker.action = #selector(changed)
        picker.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let iconButton = ActionAreaButton(content: SymbolView(icon, size: 20), height: 20)
        iconButton.onPress = { [weak self] in self?.onIconTap?() }

        let row = NSStackView(views: [picker, FixedSpacer(), iconButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @objc private func changed() {
        onChange?(picker.dateValue)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class PrimaryButton: NSButton {
    var onPress: (() -> Void)?
    private var flashResetTitle: String?

    init(title: String) {
        super.init(frame: .zero)
        self.title = title
        font = tbFont("Lato", 14, .medium)
        contentTintColor = .white
        isBordered = false
        bezelStyle = .regularSquare
        wantsLayer = true
        layer?.backgroundColor = TBColor.primary.cgColor
        layer?.cornerRadius = 10
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 40).isActive = true
        target = self
        action = #selector(press)
    }

    func flash(_ text: String) {
        if flashResetTitle == nil { flashResetTitle = title }
        title = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, let original = self.flashResetTitle else { return }
            self.title = original
            self.flashResetTitle = nil
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    @objc private func press() { onPress?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
