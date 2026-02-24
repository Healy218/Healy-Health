//
//  ContentView.swift
//  Healy Health
//
//  Created by Matthew Healy on 2/4/26.
//

import SwiftUI

struct ContentView: View {
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.font: UIFont(name: "ChalkboardSE-Regular", size: 20)!, .foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.font: UIFont(name: "ChalkboardSE-Regular", size: 34)!, .foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = .white
        
        // Tab Bar Appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        // Use systemBlue so it exactly matches the SwiftUI `Color.blue`
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

    var body: some View {
        TabView {
            ExerciseLibraryView()
                .tabItem {
                    Label("Exercises", systemImage: "list.bullet.clipboard")
                }
            
            NavigationStack {
                MainScheduleView()
            }
            .tabItem {
                Label("Workout", systemImage: "dumbbell.fill")
            }
            
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.fill")
            }
        }
        .environment(\.font, Font.custom("ChalkboardSE-Regular", size: 17))
        .accentColor(.white)
    }
}
