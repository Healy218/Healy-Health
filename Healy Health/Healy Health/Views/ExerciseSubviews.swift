import SwiftUI

// Fix #5: Extracted from ExerciseDetailView

struct TimerPresetButton: View {
    let duration: Double
    let label: String
    @Binding var selectedDuration: Double
    
    var isSelected: Bool {
        return selectedDuration == duration
    }
    
    var body: some View {
        Button(action: { selectedDuration = duration }) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.white : Color.blue.opacity(0.5))
                .foregroundColor(isSelected ? .blue : .white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 1)
                )
        }
    }
}
struct SetInputView: View {
    let setNumber: Int
    @Binding var weightInput: String
    @Binding var repsInput: String
    @Binding var selectedDuration: Double
    @Binding var showCustomTimerAlert: Bool
    var isCustomDuration: Bool
    var onLogSet: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Set \(setNumber)")
                .font(.title)
                .foregroundColor(.white)
            
            HStack(spacing: 20) {
                VStack {
                    Text("Weight (lbs)")
                        .foregroundColor(.white)
                    TextField("0", text: $weightInput)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
                
                VStack {
                    Text("Reps")
                        .foregroundColor(.white)
                    TextField("0", text: $repsInput)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            
            // Timer Settings
            VStack(alignment: .leading, spacing: 10) {
                Text("Auto-Start Timer Duration:")
                    .foregroundColor(.white)
                    .font(.caption)
                
                HStack(spacing: 12) {
                    TimerPresetButton(duration: 120, label: "2:00", selectedDuration: $selectedDuration)
                    TimerPresetButton(duration: 150, label: "2:30", selectedDuration: $selectedDuration)
                    TimerPresetButton(duration: 180, label: "3:00", selectedDuration: $selectedDuration)
                    
                    Button(action: { showCustomTimerAlert = true }) {
                        Text("Custom")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(isCustomDuration ? Color.white : Color.blue.opacity(0.5))
                            .foregroundColor(isCustomDuration ? .blue : .white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal)
            
            Button(action: onLogSet) {
                Text("Log Set")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

struct RestTimerDisplayView: View {
    let timeRemaining: TimeInterval
    let nextSetNumber: Int
    var onSkip: () -> Void
    var onAddTime: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rest Timer")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(timeString(time: timeRemaining))
                .font(.system(size: 60, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Button(action: onSkip) {
                Text("Skip Rest & Start Set \(nextSetNumber)")
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
            }
            
            Button(action: onAddTime) {
                Text("+30s")
                    .foregroundColor(.white)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white, lineWidth: 1)
                    )
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .padding()
    }
    
    private func timeString(time: TimeInterval) -> String {
        let totalSeconds = Int(ceil(time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
