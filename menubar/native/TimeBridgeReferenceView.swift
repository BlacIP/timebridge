import AppKit

final class ReferenceTableView: NSView {
    init(fromZone: TimeZone, toZone: TimeZone, date: Date) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        // Height derives from 5 rows of 28 + 8pt gaps (Figma: 172 total).

        var rows: [NSView] = []
        for hour in 8...12 {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = fromZone
            let source = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
            rows.append(Self.row(
                left: fmt(fromZone, "h:mm a", source),
                middle: fmt(fromZone, "h:mm a", source),
                right: fmt(toZone, "h:mm a", source)
            ))
        }
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private static func row(left: String, middle: String, right: String) -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let row = NSStackView(views: [
            col(left, width: 110, color: TBColor.strong, family: "Inter"),
            col(middle, width: 110, color: TBColor.sub, family: "Lato"),
            SymbolView("arrow.right", color: TBColor.softText, size: 14),
            col(right, width: 110, color: TBColor.strong, family: "Inter", align: .right),
        ])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .equalSpacing
        row.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            row.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
        ])
        return view
    }

    private static func col(_ text: String, width: CGFloat, color: NSColor, family: String, align: NSTextAlignment = .left) -> NSView {
        let box = NSView()
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: width).isActive = true
        let textView = label(text, family: family, size: 14, weight: family == "Inter" ? .medium : .regular, color: color, lineHeight: 20, tracking: -0.084, align: align)
        textView.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            textView.centerYAnchor.constraint(equalTo: box.centerYAnchor),
        ])
        return box
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
