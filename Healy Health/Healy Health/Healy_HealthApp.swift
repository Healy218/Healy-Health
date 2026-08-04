//
//  Healy_HealthApp.swift
//  Healy Health
//
//  Created by Matthew Healy on 2/4/26.
//

import SwiftUI

@main
struct HealyHealthApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = RoutineStore.shared
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(themeManager)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                store.flushSaves()
            }
        }
    }
}
