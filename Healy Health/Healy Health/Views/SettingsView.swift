import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            Color.blue.ignoresSafeArea()
            
            VStack {
                Text("Settings")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                
                Text("Settings coming soon...")
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
}
