import AppKit

final class FixedSpacer: NSView {
    init(width: CGFloat? = nil, height: CGFloat? = nil) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        if let width { widthAnchor.constraint(equalToConstant: width).isActive = true }
        if let height { heightAnchor.constraint(equalToConstant: height).isActive = true }
        // Unconstrained axes soak up ALL stack slack, so siblings keep their
        // designed sizes and pack to the edges.
        if width == nil {
            setContentHuggingPriority(.init(rawValue: 1), for: .horizontal)
            setContentCompressionResistancePriority(.init(rawValue: 1), for: .horizontal)
        }
        if height == nil {
            setContentHuggingPriority(.init(rawValue: 1), for: .vertical)
            setContentCompressionResistancePriority(.init(rawValue: 1), for: .vertical)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class DotView: NSView {
    init(color: NSColor) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = color.cgColor
        layer?.cornerRadius = 5
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 10).isActive = true
        heightAnchor.constraint(equalToConstant: 10).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class BadgeView: NSView {
    private let titleField: NSTextField
    private let foreground: NSColor

    init(text: String, foreground: NSColor, background: NSColor, radius: CGFloat = 4, horizontal: CGFloat = 6, vertical: CGFloat = 2) {
        self.foreground = foreground
        titleField = label(text, family: "Inter", size: 11, weight: .bold, color: foreground, align: .center)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = background.cgColor
        layer?.cornerRadius = radius

        titleField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleField)
        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontal),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontal),
            titleField.topAnchor.constraint(equalTo: topAnchor, constant: vertical),
            titleField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -vertical),
        ])
    }

    func setText(_ text: String) {
        titleField.attributedStringValue = NSAttributedString(string: text, attributes: [
            .font: tbFont("Inter", 11, .bold),
            .foregroundColor: foreground,
            .paragraphStyle: {
                let p = NSMutableParagraphStyle()
                p.alignment = .center
                return p
            }(),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class BadgeButton: NSButton {
    var onPress: (() -> Void)?

    init(title: String) {
        super.init(frame: .zero)
        self.title = title
        font = tbFont("Lato", 11, .medium)
        contentTintColor = TBColor.surface800
        isBordered = false
        bezelStyle = .regularSquare
        wantsLayer = true
        layer?.backgroundColor = TBColor.stroke.cgColor
        layer?.cornerRadius = 8
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 16).isActive = true // Figma: footer badge is 16pt
        target = self
        action = #selector(press)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    @objc private func press() { onPress?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class ActionAreaButton: NSButton {
    var onPress: (() -> Void)?

    init(content: NSView, height: CGFloat? = nil) {
        super.init(frame: .zero)
        title = ""
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)
        translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        if let height { heightAnchor.constraint(equalToConstant: height).isActive = true }
        target = self
        action = #selector(press)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    @objc private func press() { onPress?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class SymbolView: NSImageView {
    init(_ name: String, color: NSColor = TBColor.softText, size: CGFloat = 20) {
        super.init(frame: .zero)
        image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        symbolConfiguration = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
        contentTintColor = color
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: size).isActive = true
        heightAnchor.constraint(equalToConstant: size).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class DividerView: NSView {
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = TBColor.stroke.cgColor
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 1).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
