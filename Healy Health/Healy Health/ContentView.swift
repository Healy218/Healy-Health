//
//  ContentView.swift
//  Healy Health
//
//  Created by Matthew Healy on 2/4/26.
//

import SwiftUI

struct ContentView: View {
    init() {
        // Fix #9: Safe font unwrapping
        let navFont = UIFont(name: "ChalkboardSE-Regular", size: 20) ?? .systemFont(ofSize: 20)
        let navLargeFont = UIFont(name: "ChalkboardSE-Regular", size: 34) ?? .systemFont(ofSize: 34)
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.font: navFont, .foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.font: navLargeFont, .foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = .white
        
        // Tab Bar Appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = .systemBlue
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.6)]
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
        itemAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.6)
        itemAppearance.selected.iconColor = UIColor.white
        tabAppearance.stackedLayoutAppearance = itemAppearance
        
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    // Fix #4: Use @EnvironmentObject instead of @ObservedObject
    @EnvironmentObject var store: RoutineStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack {
                RoutinesView()
            }
            .tabItem {
                Label("Routines", systemImage: "list.bullet.clipboard")
            }
            .tag(0)
            
            NavigationStack {
                ActiveWorkoutView()
            }
            .tabItem {
                Label("Workout", systemImage: "dumbbell.fill")
            }
            .tag(1)
            
            NavigationStack {
                SummaryView()
            }
            .tabItem {
                Label("Summary", systemImage: "chart.bar.fill")
            }
            .tag(2)
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(3)
        }
        .environment(\.font, Font.custom("ChalkboardSE-Regular", size: 17))
        .accentColor(.white)
    }
}
