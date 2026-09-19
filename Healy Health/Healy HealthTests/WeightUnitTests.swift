import XCTest
@testable import Healy_Health

final class WeightUnitTests: XCTestCase {
    func testKilogramDisplayConvertsCanonicalPounds() {
        XCTAssertEqual(
            WeightFormatter.displayedValue(fromPounds: 135, unit: .kilograms),
            61.23496995,
            accuracy: 0.000_001
        )
    }

    func testConvertingDisplayedKilogramsBackPreservesCanonicalPounds() {
        let displayedKilograms = WeightFormatter.displayedValue(fromPounds: 225, unit: .kilograms)

        XCTAssertEqual(
            WeightFormatter.pounds(fromDisplayedValue: displayedKilograms, unit: .kilograms),
            225,
            accuracy: 0.000_001
        )
    }

    func testPoundDisplayDoesNotChangeStoredValues() {
        XCTAssertEqual(WeightFormatter.displayedValue(fromPounds: 185, unit: .pounds), 185)
        XCTAssertEqual(WeightFormatter.pounds(fromDisplayedValue: 185, unit: .pounds), 185)
    }

    func testKilogramInputConvertsBackToCanonicalPounds() throws {
        let storedPounds = try XCTUnwrap(
            WeightFormatter.pounds(fromInput: "61.23496995", unit: .kilograms)
        )

        XCTAssertEqual(storedPounds, 135, accuracy: 0.000_001)
    }

    func testChartMetricsUseTheSelectedDisplayUnit() {
        let point = ExerciseHistoryPoint(
            id: UUID(),
            date: Date(),
            totalVolume: 1_000,
            maxWeight: 100,
            estimatedOneRepMax: 110,
            session: 1
        )

        XCTAssertEqual(
            ExerciseChartMetric.topSet.value(for: point, unit: .kilograms),
            45.359237,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            ExerciseChartMetric.volume.value(for: point, unit: .kilograms),
            453.59237,
            accuracy: 0.000_001
        )
    }
}
