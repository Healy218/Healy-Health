import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager

    init() {
        // Apply saved theme before any views render so titles are colored immediately
        let saved = UserDefaults.standard.string(forKey: "selectedTheme") ?? ""
        let theme = AppTheme(rawValue: saved) ?? .light
        AppChrome.applyGlobalAppearance(for: theme)
    }

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack { RoutinesView() }
                .modifier(ThemedNavigationChrome(theme: themeManager.current))
                .tabItem { Label("Routines", systemImage: "list.bullet.clipboard") }
                .tag(0)

            NavigationStack { ActiveWorkoutView() }
                .modifier(ThemedNavigationChrome(theme: themeManager.current))
                .tabItem { Label("Workout", systemImage: "dumbbell.fill") }
                .tag(1)

            NavigationStack { SummaryView() }
                .modifier(ThemedNavigationChrome(theme: themeManager.current))
                .tabItem { Label("Summary", systemImage: "chart.bar.fill") }
                .tag(2)

            NavigationStack { SettingsView() }
                .modifier(ThemedNavigationChrome(theme: themeManager.current))
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .environment(\.font, Font.custom("ChalkboardSE-Regular", size: 17))
        .modifier(ThemedTabChrome(theme: themeManager.current))
        .tint(themeManager.current.onPrimaryText)
        .onAppear { AppChrome.applyGlobalAppearance(for: themeManager.current) }
        .onChange(of: themeManager.current) { newTheme in
            AppChrome.applyGlobalAppearance(for: newTheme)
        }
    }
}
