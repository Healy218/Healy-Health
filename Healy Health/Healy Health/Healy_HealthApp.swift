//
//  Healy_HealthApp.swift
//  Healy Health
//
//  Created by Matthew Healy on 2/4/26.
//

import SwiftUI

@main
struct HealyHealthApp: App {
    init() {
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
