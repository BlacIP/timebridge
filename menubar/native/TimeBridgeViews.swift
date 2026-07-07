import AppKit

enum TBColor {
    static let panel = NSColor(calibratedRed: 0.961, green: 0.969, blue: 0.980, alpha: 1)
    static let stroke = NSColor(calibratedRed: 0.918, green: 0.925, blue: 0.941, alpha: 1)
    static let strong = NSColor(calibratedRed: 0.055, green: 0.071, blue: 0.106, alpha: 1)
    static let surface800 = NSColor(calibratedRed: 0.133, green: 0.145, blue: 0.188, alpha: 1)
    static let sub = NSColor(calibratedRed: 0.322, green: 0.345, blue: 0.400, alpha: 1)
    static let softText = NSColor(calibratedRed: 0.600, green: 0.627, blue: 0.682, alpha: 1)
    static let primary = NSColor(calibratedRed: 0.200, green: 0.361, blue: 1.000, alpha: 1)
    static let lagosDot = NSColor(calibratedRed: 0.200, green: 0.361, blue: 1.000, alpha: 1)
    static let provoDot = NSColor(calibratedRed: 0.137, green: 0.749, blue: 0.369, alpha: 1)
    static let primaryLight = NSColor(calibratedRed: 0.835, green: 0.886, blue: 1.000, alpha: 1)
    static let verified = NSColor(calibratedRed: 0.278, green: 0.761, blue: 1.000, alpha: 1)
    static let successBg = NSColor(calibratedRed: 0.761, green: 0.961, blue: 0.855, alpha: 1)
    static let successText = NSColor(calibratedRed: 0.043, green: 0.275, blue: 0.153, alpha: 1)
}

func tbFont(_ family: String, _ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let style: String
    switch weight {
    case .bold: style = "Bold"
    case .medium: style = "Medium"
    default: style = "Regular"
    }
    return NSFont(name: "\(family)-\(style)", size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
}

func label(
    _ value: String,
    family: String = "Lato",
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor = TBColor.strong,
    lineHeight: CGFloat? = nil,
    tracking: CGFloat = 0,
    align: NSTextAlignment = .left
) -> NSTextField {
    let field = NSTextField(labelWithString: "")
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = align
    if let lineHeight {
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
    }
    field.attributedStringValue = NSAttributedString(
        string: value,
        attributes: [
            .font: tbFont(family, size, weight),
            .foregroundColor: color,
            .kern: tracking,
            .paragraphStyle: paragraph,
        ]
    )
    field.lineBreakMode = .byTruncatingTail
    field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    field.setContentHuggingPriority(.defaultHigh, for: .horizontal) // never absorb stack slack
    return field
}

func cityName(_ choice: ZoneChoice) -> String {
    choice.label.split(separator: ",").first.map(String.init) ?? choice.label
}

func regionName(_ choice: ZoneChoice) -> String {
    choice.label.split(separator: ",").dropFirst().joined(separator: ",").trimmingCharacters(in: .whitespaces)
}
