import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Healy Health")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Text("Your Hybrid Athlete Tracker")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    ContentView()
}
