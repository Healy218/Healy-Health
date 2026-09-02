import SwiftUI

enum AppChrome {
    static func applyGlobalAppearance(for theme: AppTheme) {
        let navBgColor = UIColor(theme.primaryColor)
        let navTextColor = UIColor(theme.onPrimaryText)
        let tabBgColor = UIColor(theme.primaryColor)
        let tabTextColor = UIColor(theme.onPrimaryText)
        let navFont = scaledFont(
            named: "ChalkboardSE-Regular",
            size: 20,
            textStyle: .headline
        )
        let navLargeFont = scaledFont(
            named: "ChalkboardSE-Regular",
            size: 34,
            textStyle: .largeTitle
        )

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = navBgColor
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [.font: navFont, .foregroundColor: navTextColor]
        navAppearance.largeTitleTextAttributes = [.font: navLargeFont, .foregroundColor: navTextColor]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = navTextColor

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = tabBgColor
        let itemAppearance = UITabBarItemAppearance()
        let secondaryTabTextColor = UIColor(theme.secondaryOnPrimaryText)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: secondaryTabTextColor]
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: tabTextColor]
        itemAppearance.normal.iconColor = secondaryTabTextColor
        itemAppearance.selected.iconColor = tabTextColor
        tabAppearance.stackedLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    private static func scaledFont(
        named name: String,
        size: CGFloat,
        textStyle: UIFont.TextStyle
    ) -> UIFont {
        let baseFont = UIFont(name: name, size: size) ?? .systemFont(ofSize: size)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: baseFont)
    }
}

struct ThemedNavigationChrome: ViewModifier {
    let theme: AppTheme

    func body(content: Content) -> some View {
        content
            .toolbarBackground(theme.primaryColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(theme.prefersDarkNavigationContent ? .dark : .light, for: .navigationBar)
    }
}

struct ThemedTabChrome: ViewModifier {
    let theme: AppTheme

    func body(content: Content) -> some View {
        content
            .toolbarBackground(theme.primaryColor, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(theme.prefersDarkNavigationContent ? .dark : .light, for: .tabBar)
    }
}
