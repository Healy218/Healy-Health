import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager

    init() {
        // Font setup only — colors are applied dynamically via applyAppearance()
        let navFont = UIFont(name: "ChalkboardSE-Regular", size: 20) ?? .systemFont(ofSize: 20)
        let navLargeFont = UIFont(name: "ChalkboardSE-Regular", size: 34) ?? .systemFont(ofSize: 34)
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.titleTextAttributes = [.font: navFont]
        navAppearance.largeTitleTextAttributes = [.font: navLargeFont]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
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
        .accentColor(themeManager.current.onPrimaryText)
        .onAppear { applyAppearance(for: themeManager.current) }
        .onChange(of: themeManager.current) { _, newTheme in
            applyAppearance(for: newTheme)
        }
    }

    private func applyAppearance(for theme: AppTheme) {
        let uiColor = UIColor(theme.primaryColor)
        let textColor = UIColor(theme.onPrimaryText)
        let navFont = UIFont(name: "ChalkboardSE-Regular", size: 20) ?? .systemFont(ofSize: 20)
        let navLargeFont = UIFont(name: "ChalkboardSE-Regular", size: 34) ?? .systemFont(ofSize: 34)

        // Nav Bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = uiColor
        navAppearance.titleTextAttributes = [.font: navFont, .foregroundColor: textColor]
        navAppearance.largeTitleTextAttributes = [.font: navLargeFont, .foregroundColor: textColor]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = textColor

        // Tab Bar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = uiColor
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: textColor.withAlphaComponent(0.6)]
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: textColor]
        itemAppearance.normal.iconColor = textColor.withAlphaComponent(0.6)
        itemAppearance.selected.iconColor = textColor
        tabAppearance.stackedLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
