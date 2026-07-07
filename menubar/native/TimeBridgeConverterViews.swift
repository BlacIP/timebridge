import AppKit

final class InputGroupView: NSView {
    init(title: String, content: NSView) {
        super.init(frame: .zero)
        let stack = NSStackView(views: [
            label(title, family: "Inter", size: 14, weight: .medium, color: .white, lineHeight: 20, tracking: -0.084),
            content,
        ])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
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

final class SummaryRowView: NSView {
    var onCopy: (() -> Void)?

    private let textField: NSTextField
    private let badge: BadgeView
    private let copySymbol = SymbolView("doc.on.doc", size: 20)

    init(text: String, dayDiff: Int) {
        textField = label(text, size: 12, color: .white, lineHeight: 16)
        // Pill = half the 18pt badge height; radii beyond bounds/2 make
        // CoreAnimation paint the layer wrong (it flooded the whole row).
        badge = BadgeView(text: "+1 DAY", foreground: TBColor.successText, background: TBColor.successBg, radius: 9, horizontal: 8, vertical: 2)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = TBColor.surface800.cgColor
        layer?.cornerRadius = 10
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 40).isActive = true // Figma: summary row is 40pt

        let left = NSStackView(views: [textField, badge])
        left.orientation = .horizontal
        left.alignment = .centerY
        left.spacing = 8

        let copyButton = ActionAreaButton(content: copySymbol, height: 20)
        copyButton.onPress = { [weak self] in
            self?.onCopy?()
            self?.flashCopied()
        }

        let row = NSStackView(views: [left, FixedSpacer(), copyButton])
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
        update(text: text, dayDiff: dayDiff)
    }

    func update(text: String, dayDiff: Int) {
        textField.attributedStringValue = NSAttributedString(string: text, attributes: [
            .font: tbFont("Lato", 12, .regular),
            .foregroundColor: NSColor.white,
        ])
        badge.isHidden = dayDiff == 0
        if dayDiff != 0 { badge.setText(dayDiff > 0 ? "+1 DAY" : "-1 DAY") }
    }

    private func flashCopied() {
        copySymbol.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Copied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.copySymbol.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
