import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager

    init() {
        // Apply saved theme before any views render so titles are colored immediately
        let saved = UserDefaults.standard.string(forKey: "selectedTheme") ?? ""
        let theme = AppTheme(rawValue: saved) ?? .light
        ContentView.applyAppearanceStatic(for: theme)
    }

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack { RoutinesView() }
                .tabItem { Label("Routines", systemImage: "list.bullet.clipboard") }
                .tag(0)

            NavigationStack { ActiveWorkoutView() }
                .tabItem { Label("Workout", systemImage: "dumbbell.fill") }
                .tag(1)

            NavigationStack { SummaryView() }
                .tabItem { Label("Summary", systemImage: "chart.bar.fill") }
                .tag(2)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .environment(\.font, Font.custom("ChalkboardSE-Regular", size: 17))
        .accentColor(themeManager.current.rowText)
        .onAppear { ContentView.applyAppearanceStatic(for: themeManager.current) }
        .onChange(of: themeManager.current) { _, newTheme in
            ContentView.applyAppearanceStatic(for: newTheme)
        }
    }

    static func applyAppearanceStatic(for theme: AppTheme) {
        let navBgColor = UIColor(theme.primaryColor)
        let navTextColor = UIColor(theme.onPrimaryText)
        let tabBgColor = UIColor(theme.primaryColor)
        let tabTextColor = UIColor(theme.onPrimaryText)
        let navFont = UIFont(name: "ChalkboardSE-Regular", size: 20) ?? .systemFont(ofSize: 20)
        let navLargeFont = UIFont(name: "ChalkboardSE-Regular", size: 34) ?? .systemFont(ofSize: 34)

        // Nav Bar — neutral background, content-matching text
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = navBgColor
        navAppearance.titleTextAttributes = [.font: navFont, .foregroundColor: navTextColor]
        navAppearance.largeTitleTextAttributes = [.font: navLargeFont, .foregroundColor: navTextColor]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = navTextColor

        // Tab Bar — keeps theme primary color
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = tabBgColor
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: tabTextColor.withAlphaComponent(0.6)]
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: tabTextColor]
        itemAppearance.normal.iconColor = tabTextColor.withAlphaComponent(0.6)
        itemAppearance.selected.iconColor = tabTextColor
        tabAppearance.stackedLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
