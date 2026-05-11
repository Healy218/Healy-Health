import SwiftUI
import Combine

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

    // The full-screen background color
    var primaryColor: Color {
        switch self {
        case .systemBlue: return .blue
        case .light:      return .white
        case .dark:       return .black
        case .red:        return Color(red: 0.85, green: 0.1, blue: 0.1)
        case .orange:     return Color(red: 0.95, green: 0.5, blue: 0.05)
        case .yellow:     return Color(red: 0.97, green: 0.85, blue: 0.0)
        case .green:      return Color(red: 0.1, green: 0.68, blue: 0.25)
        case .indigo:     return Color(red: 0.29, green: 0.0, blue: 0.51)
        case .violet:     return Color(red: 0.56, green: 0.0, blue: 0.8)
        case .pink:       return Color(red: 0.98, green: 0.13, blue: 0.53)
        }
    }

    // Text/icons that appear directly on the primary color
    var onPrimaryText: Color {
        switch self {
        case .yellow, .light: return .black
        default:              return .white
        }
    }

    // List row background
    var rowBackground: Color {
        switch self {
        case .dark:  return Color(white: 0.14)
        case .light: return Color(white: 0.95)
        default:     return .white
        }
    }

    // Primary text inside list rows
    var rowText: Color {
        switch self {
        case .dark: return .white
        default:    return .black
        }
    }

    // Accent color used for buttons / interactive elements on row backgrounds
    var accentColor: Color {
        switch self {
        case .light:  return .black
        case .dark:   return Color(white: 0.85)
        case .yellow: return Color(red: 0.45, green: 0.3, blue: 0.0)
        default:      return primaryColor
        }
    }

    // Secondary / muted text inside rows
    var secondaryRowText: Color {
        switch self {
        case .dark: return Color(white: 0.65)
        default:    return Color(white: 0.35)
        }
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
