import XCTest
@testable import Healy_Health

final class ThemeContrastTests: XCTestCase {
    func testEveryThemeMeetsItsContrastTargets() {
        for theme in AppTheme.allCases {
            let palette = theme.palette

            assertContrast(
                palette.onPrimary,
                against: palette.primary,
                minimum: 4.5,
                role: "primary text",
                theme: theme
            )
            assertContrast(
                palette.secondaryOnPrimary,
                against: palette.primary,
                minimum: 4.5,
                role: "secondary text",
                theme: theme
            )
            assertContrast(
                palette.disabledOnPrimary,
                against: palette.primary,
                minimum: 3,
                role: "disabled controls",
                theme: theme
            )
            assertContrast(
                palette.rowText,
                against: palette.rowBackground,
                minimum: 4.5,
                role: "row text",
                theme: theme
            )
            assertContrast(
                palette.secondaryRowText,
                against: palette.rowBackground,
                minimum: 4.5,
                role: "secondary row text",
                theme: theme
            )
            assertContrast(
                palette.accent,
                against: palette.rowBackground,
                minimum: 3,
                role: "row controls",
                theme: theme
            )
            assertContrast(
                ThemeColor(255, 255, 255),
                against: palette.disabledButton,
                minimum: 4.5,
                role: "disabled button label",
                theme: theme
            )
            assertContrast(
                palette.onPrimary,
                against: palette.disabledButton,
                minimum: 4.5,
                role: "theme-aware disabled button label",
                theme: theme
            )
            assertContrast(
                theme.destructiveThemeColor,
                against: palette.rowBackground,
                minimum: 4.5,
                role: "destructive row action",
                theme: theme
            )
            assertContrast(
                theme.successRowThemeColor,
                against: palette.rowBackground,
                minimum: 3,
                role: "completed-workout icon",
                theme: theme
            )
            assertContrast(
                ThemeColor.success,
                against: palette.chartSurface,
                minimum: 4.5,
                role: "success action",
                theme: theme
            )
            assertContrast(
                palette.chartLine,
                against: palette.chartSurface,
                minimum: 3,
                role: "chart line",
                theme: theme
            )
            assertContrast(
                palette.chartAxis,
                against: palette.chartSurface,
                minimum: 4.5,
                role: "chart axis labels",
                theme: theme
            )
            assertContrast(
                palette.chartGrid,
                against: palette.chartSurface,
                minimum: 3,
                role: "chart grid",
                theme: theme
            )
        }
    }

    private func assertContrast(
        _ foreground: ThemeColor,
        against background: ThemeColor,
        minimum: Double,
        role: String,
        theme: AppTheme,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(
            foreground.contrastRatio(with: background),
            minimum,
            "\(theme.displayName) \(role) contrast is below \(minimum):1",
            file: file,
            line: line
        )
    }
}
