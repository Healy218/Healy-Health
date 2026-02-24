import SwiftUI
import Combine

struct RestTimerView: View {
    @State private var timeRemaining = 120 // 2 minutes default
    @State private var timerActive = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Rest Timer")
                .font(.headline)
            
            Text(timeString(time: timeRemaining))
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            
            HStack(spacing: 20) {
                Button(action: { startTimer(seconds: 120) }) {
                    Text("2:00")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                
                Button(action: { startTimer(seconds: 180) }) {
                    Text("3:00")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                
                Button(action: stopTimer) {
                    Text("Reset")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(15)
        .shadow(radius: 5)
        .onReceive(timer) { _ in
            if timerActive {
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    timerActive = false
                    // Optional: Haptic feedback here
                }
            }
        }
    }
    
    func startTimer(seconds: Int) {
        timeRemaining = seconds
        timerActive = true
    }
    
    func stopTimer() {
        timerActive = false
        timeRemaining = 120
    }
    
    func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    RestTimerView()
        .padding()
}
