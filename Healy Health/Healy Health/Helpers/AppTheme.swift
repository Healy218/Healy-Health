import SwiftUI
import Combine

// MARK: - Contrast-aware color primitives

/// An sRGB color that can be used both by SwiftUI and by unit tests. Keeping
/// the numeric values here makes contrast requirements enforceable instead of
/// relying on a visual review of `Color` values.
struct ThemeColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    init(_ red: Int, _ green: Int, _ blue: Int) {
        self.red = Double(red) / 255
        self.green = Double(green) / 255
        self.blue = Double(blue) / 255
    }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    /// WCAG 2 relative luminance for an opaque sRGB color.
    private var relativeLuminance: Double {
        func linearized(_ component: Double) -> Double {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        return (0.2126 * linearized(red))
            + (0.7152 * linearized(green))
            + (0.0722 * linearized(blue))
    }

    func contrastRatio(with background: ThemeColor) -> Double {
        let light = max(relativeLuminance, background.relativeLuminance)
        let dark = min(relativeLuminance, background.relativeLuminance)
        return (light + 0.05) / (dark + 0.05)
    }
}

extension ThemeColor {
    /// These status colors are shown on light surfaces, where their text and
    /// icon contrast remains at or above the 4.5:1 AA target.
    static let destructive = ThemeColor(180, 32, 32)
    static let success = ThemeColor(8, 122, 45)
}

struct ThemePalette {
    let primary: ThemeColor
    let onPrimary: ThemeColor
    let secondaryOnPrimary: ThemeColor
    let disabledOnPrimary: ThemeColor
    let rowBackground: ThemeColor
    let rowText: ThemeColor
    let secondaryRowText: ThemeColor
    let accent: ThemeColor
    let disabledButton: ThemeColor
    let chartSurface: ThemeColor
    let chartLine: ThemeColor
    let chartAxis: ThemeColor
    let chartGrid: ThemeColor
}

// MARK: - Typography

/// Keeps the app's display typeface while letting text respond to the user's
/// preferred Dynamic Type size. Always choose the closest semantic text style
/// for the content instead of using an unscaled fixed-size custom font.
enum AppTypography {
    static func chalkboard(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom("ChalkboardSE-Regular", size: size, relativeTo: style)
    }
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Codable {
    case systemBlue
    case light
    case dark
    case red
    case orange
    case yellow
    case green
    case indigo
    case violet
    case pink

    /// WCAG AA targets: 4.5:1 for text, 3:1 for disabled controls and chart
    /// marks, and 4.5:1 for chart axis labels. The darker blue, orange, green,
    /// and pink retain their original hue while making white text readable.
    var palette: ThemePalette {
        let white = ThemeColor(255, 255, 255)
        let nearWhite = ThemeColor(242, 247, 250)
        let black = ThemeColor(0, 0, 0)
        let nearBlack = ThemeColor(29, 29, 31)
        let secondaryDark = ThemeColor(89, 89, 89)
        let darkRow = ThemeColor(36, 36, 36)
        let disabledLight = ThemeColor(209, 216, 220)
        let disabledDark = ThemeColor(107, 107, 107)
        let disabledButton = ThemeColor(117, 117, 117)
        let chartAxis = ThemeColor(69, 69, 69)
        let chartGrid = ThemeColor(142, 142, 147)

        switch self {
        case .systemBlue:
            return ThemePalette(primary: ThemeColor(0, 105, 180), onPrimary: white, secondaryOnPrimary: nearWhite, disabledOnPrimary: disabledLight, rowBackground: white, rowText: black, secondaryRowText: secondaryDark, accent: ThemeColor(0, 105, 180), disabledButton: disabledButton, chartSurface: white, chartLine: ThemeColor(0, 105, 180), chartAxis: chartAxis, chartGrid: chartGrid)
        case .light:
            return ThemePalette(primary: white, onPrimary: black, secondaryOnPrimary: ThemeColor(48, 48, 48), disabledOnPrimary: disabledDark, rowBackground: ThemeColor(242, 242, 242), rowText: black, secondaryRowText: secondaryDark, accent: black, disabledButton: disabledButton, chartSurface: white, chartLine: nearBlack, chartAxis: chartAxis, chartGrid: chartGrid)
        case .dark:
            return ThemePalette(primary: black, onPrimary: white, secondaryOnPrimary: nearWhite, disabledOnPrimary: disabledLight, rowBackground: darkRow, rowText: white, secondaryRowText: ThemeColor(166, 166, 166), accent: ThemeColor(217, 217, 217), disabledButton: disabledButton, chartSurface: white, chartLine: nearBlack, chartAxis: chartAxis, chartGrid: chartGrid)
        case .red:
            return ThemePalette(primary: ThemeColor(217, 26, 26), onPrimary: white, secondaryOnPrimary: nearWhite, disabledOnPrimary: disabledLight, rowBackground: white, rowText: black, secondaryRowText: secondaryDark, accent: ThemeColor(217, 26, 26), disabledButton: disabledButton, chartSurface: white, chartLine: ThemeColor(217, 26, 26), chartAxis: chartAxis, chartGrid: chartGrid)
        case .orange:
            return ThemePalette(primary: ThemeColor(149, 67, 0), onPrimary: white, secondaryOnPrimary: nearWhite, disabledOnPrimary: disabledLight, rowBackground: white, rowText: black, secondaryRowText: secondaryDark, accent: ThemeColor(149, 67, 0), disabledButton: disabledButton, chartSurface: white, chartLine: ThemeColor(149, 67, 0), chartAxis: chartAxis, chartGrid: chartGrid)
        case .yellow:
            return ThemePalette(primary: ThemeColor(247, 217, 0), onPrimary: black, secondaryOnPrimary: ThemeColor(48, 48, 48), disabledOnPrimary: disabledDark, rowBackground: white, rowText: black, secondaryRowText: secondaryDark, accent: ThemeColor(115, 77, 0), disabledButton: disabledButton, chartSurface: white, chartLine: ThemeColor(115, 77, 0), chartAxis: chartAxis, chartGrid: chartGrid)
        case .green:
            return ThemePalette(primary: ThemeColor(8, 122, 45), onPrimary: white, secondaryOnPrimary: nearWhite, disabledOnPrimary: disabledLight, rowBackground: white, rowText: black, secondaryRowText: secondaryDark, accent: ThemeColor(8, 122, 45), disabledButton: disabledButton, chartSurface: white, chartLine: ThemeColor(8, 122, 45), chartAxis: chartAxis, chartGrid: chartGrid)
        case .indigo:
            return ThemePalette(primary: ThemeColor(74, 0, 130), onPrimary: white, secondaryOnPrimary: nearWhite, disabledOnPrimary: disabledLight, rowBackground: white, rowText: black, secondaryRowText: secondaryDark, accent: ThemeColor(74, 0, 130), disabledButton: disabledButton, chartSurface: white, chartLine: ThemeColor(74, 0, 130), chartAxis: chartAxis, chartGrid: chartGrid)
        case .violet:
            return ThemePalette(primary: ThemeColor(143, 0, 204), onPrimary: white, secondaryOnPrimary: nearWhite, disabledOnPrimary: disabledLight, rowBackground: white, rowText: black, secondaryRowText: secondaryDark, accent: ThemeColor(143, 0, 204), disabledButton: disabledButton, chartSurface: white, chartLine: ThemeColor(143, 0, 204), chartAxis: chartAxis, chartGrid: chartGrid)
        case .pink:
            return ThemePalette(primary: ThemeColor(185, 0, 92), onPrimary: white, secondaryOnPrimary: nearWhite, disabledOnPrimary: disabledLight, rowBackground: white, rowText: black, secondaryRowText: secondaryDark, accent: ThemeColor(185, 0, 92), disabledButton: disabledButton, chartSurface: white, chartLine: ThemeColor(185, 0, 92), chartAxis: chartAxis, chartGrid: chartGrid)
        }
    }

    // The full-screen background color
    var primaryColor: Color {
        palette.primary.color
    }

    // Text/icons that appear directly on the primary color
    var onPrimaryText: Color {
        palette.onPrimary.color
    }

    var secondaryOnPrimaryText: Color {
        palette.secondaryOnPrimary.color
    }

    var disabledOnPrimaryText: Color {
        palette.disabledOnPrimary.color
    }

    // List row background
    var rowBackground: Color {
        palette.rowBackground.color
    }

    // Primary text inside list rows
    var rowText: Color {
        palette.rowText.color
    }

    // Accent color used for buttons / interactive elements on row backgrounds
    var accentColor: Color {
        palette.accent.color
    }

    // Secondary / muted text inside rows
    var secondaryRowText: Color {
        palette.secondaryRowText.color
    }

    var disabledButtonColor: Color {
        palette.disabledButton.color
    }

    var destructiveColor: Color {
        destructiveThemeColor.color
    }

    var successColor: Color {
        ThemeColor.success.color
    }

    var successOnRowColor: Color {
        successRowThemeColor.color
    }

    var destructiveThemeColor: ThemeColor {
        self == .dark ? ThemeColor(255, 180, 171) : .destructive
    }

    var successRowThemeColor: ThemeColor {
        self == .dark ? ThemeColor(124, 227, 154) : .success
    }

    var chartSurfaceColor: Color {
        palette.chartSurface.color
    }

    var chartLineColor: Color {
        palette.chartLine.color
    }

    var chartAxisColor: Color {
        palette.chartAxis.color
    }

    var chartGridColor: Color {
        palette.chartGrid.color
    }

    var prefersDarkNavigationContent: Bool {
        switch self {
        case .yellow, .light:
            return false
        default:
            return true
        }
    }

    var displayName: String {
        switch self {
        case .systemBlue: return "Blue"
        case .light:      return "Light"
        case .dark:       return "Dark"
        case .red:        return "Red"
        case .orange:     return "Orange"
        case .yellow:     return "Yellow"
        case .green:      return "Green"
        case .indigo:     return "Indigo"
        case .violet:     return "Violet"
        case .pink:       return "Pink"
        }
    }

    // Whether this is a "style" theme (not a colour)
    var isStyle: Bool {
        switch self {
        case .light, .dark: return true
        default: return false
        }
    }
}

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let key = "selectedTheme"

    @Published var current: AppTheme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: Self.key) }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key) ?? ""
        self.current = AppTheme(rawValue: saved) ?? .light
    }
}
