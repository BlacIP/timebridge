import AppKit

final class ConverterSectionView: NSView {
    var onSwap: (() -> Void)?

    init(from: ZoneChoice, to: ZoneChoice, fromZone: TimeZone, toZone: TimeZone, date: Date) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        // Height derives from header + card + button stack (Figma: 312 total).

        let swapLabel = NSStackView(views: [
            label(cityName(to), family: "Inter", size: 14, weight: .medium, lineHeight: 20, tracking: -0.084),
            SymbolView("arrow.clockwise", color: TBColor.sub, size: 16),
            label(cityName(from), family: "Inter", size: 14, weight: .medium, lineHeight: 20, tracking: -0.084),
        ])
        swapLabel.orientation = .horizontal
        swapLabel.alignment = .centerY
        swapLabel.spacing = 6
        let swap = ActionAreaButton(content: swapLabel, height: 20)
        swap.onPress = { [weak self] in self?.onSwap?() }

        let header = NSStackView(views: [swap, FixedSpacer()])
        header.orientation = .horizontal
        header.alignment = .top
        header.translatesAutoresizingMaskIntoConstraints = false
        header.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let card = ConverterCardView(from: from, to: to, fromZone: fromZone, toZone: toZone, date: date)
        // Conversion is live as the pickers change, so the primary action
        // copies the current conversion for pasting into chat.
        let button = PrimaryButton(title: "Copy conversion")
        button.onPress = { [weak card, weak button] in
            card?.copyConversion()
            button?.flash("Copied ✓")
        }

        let stack = NSStackView(views: [header, card, button])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 12
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
