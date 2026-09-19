import Foundation

/// The display unit for weights. Persisted workout data remains in pounds so
/// existing routines, history records, and exports stay backward compatible.
enum WeightUnit: String, CaseIterable, Codable, Identifiable {
    case pounds
    case kilograms

    static let storageKey = "preferredWeightUnit"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pounds: return String(localized: "Pounds (lb)")
        case .kilograms: return String(localized: "Kilograms (kg)")
        }
    }

    var symbol: String {
        switch self {
        case .pounds: return "lb"
        case .kilograms: return "kg"
        }
    }

    var spokenName: String {
        switch self {
        case .pounds: return String(localized: "pounds")
        case .kilograms: return String(localized: "kilograms")
        }
    }

    var volumeSymbol: String { "\(symbol)-reps" }
}

enum WeightFormatter {
    private static let kilogramsPerPound = 0.45359237

    static func displayedValue(fromPounds pounds: Double, unit: WeightUnit) -> Double {
        unit == .pounds ? pounds : pounds * kilogramsPerPound
    }

    static func pounds(fromDisplayedValue value: Double, unit: WeightUnit) -> Double {
        unit == .pounds ? value : value / kilogramsPerPound
    }

    static func pounds(fromInput input: String, unit: WeightUnit) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        let displayedValue = formatter.number(from: trimmed)?.doubleValue ?? Double(trimmed)
        guard let displayedValue else { return nil }
        return pounds(fromDisplayedValue: displayedValue, unit: unit)
    }

    static func inputString(
        fromPounds pounds: Double,
        unit: WeightUnit,
        maximumFractionDigits: Int = 1
    ) -> String {
        numberString(
            displayedValue(fromPounds: pounds, unit: unit),
            maximumFractionDigits: maximumFractionDigits
        )
    }

    static func string(
        fromPounds pounds: Double,
        unit: WeightUnit,
        maximumFractionDigits: Int = 1
    ) -> String {
        "\(inputString(fromPounds: pounds, unit: unit, maximumFractionDigits: maximumFractionDigits)) \(unit.symbol)"
    }

    static func accessibilityString(
        fromPounds pounds: Double,
        unit: WeightUnit,
        maximumFractionDigits: Int = 1
    ) -> String {
        "\(inputString(fromPounds: pounds, unit: unit, maximumFractionDigits: maximumFractionDigits)) \(unit.spokenName)"
    }

    static func numberString(_ value: Double, maximumFractionDigits: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}
