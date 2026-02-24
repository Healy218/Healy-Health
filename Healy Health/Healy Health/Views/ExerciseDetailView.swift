import SwiftUI
import Combine

struct ExerciseDetailView: View {
    @Binding var exercise: Exercise
    var onSave: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.scenePhase) var scenePhase
    
    @State private var weightInput: String = ""
    @State private var repsInput: String = ""
    
    // Timer State
    @State private var timerActive = false
    @State private var timerEndTime: Date?
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Publishers.Autoconnect<Timer.TimerPublisher> = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Timer Settings
    @State private var selectedDuration: Double = 120 // Default 2:00
    @State private var showCustomTimerAlert = false
    @State private var customTimerInput = ""
    
    var body: some View {
        ZStack {
            // Background
            Color.blue.ignoresSafeArea()
            
            VStack {
                // Header
                Text(exercise.name)
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.top)
                
                // Set History List
                List {
                    Section(header: Text("History").foregroundColor(.white)) {
                        if exercise.logs.isEmpty {
                            Text("No sets completed yet.")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(exercise.logs) { log in
                                HStack {
                                    Text("Set \(exercise.logs.firstIndex(where: { $0.id == log.id })! + 1)")
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text("\(log.reps) reps @ \(String(format: "%.1f", log.weight)) lbs")
                                }
                                .foregroundColor(.black)
                                .listRowBackground(Color.white)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .frame(maxHeight: 200)
                
                // Current Set Input
                if !timerActive {
                    VStack(spacing: 20) {
                        Text("Set \(exercise.logs.count + 1)")
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
                        
                        // Timer Settings (Only show when not active)
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

                        
                        Button(action: logSet) {
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
                } else {
                    // Rest Timer View
                    VStack(spacing: 20) {
                        Text("Rest Timer")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(timeString(time: timeRemaining))
                            .font(.system(size: 60, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Button(action: skipRest) {
                            Text("Skip Rest & Start Set \(exercise.logs.count + 1)")
                                .foregroundColor(.blue)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            // Add 30 seconds
                            if let endTime = timerEndTime {
                                timerEndTime = endTime.addingTimeInterval(30)
                                NotificationManager.shared.cancelTimer()
                                updateTimerDisplay() // Recalculate remaining
                                NotificationManager.shared.scheduleTimer(seconds: timeRemaining)
                            }
                        }) {
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
                
                Spacer()
                
                // Footer Actions
                if exercise.logs.count >= 3 {
                    Button(action: finishExercise) {
                        Text("Finish Exercise")
                            .font(.headline)
                            .foregroundColor(.green)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Skip / Back")
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.bottom)
            }
        }
        .onAppear {
            if let lastLog = exercise.logs.last {
                weightInput = String(format: "%.0f", lastLog.weight)
                repsInput = String(format: "%d", lastLog.reps)
            } else {
                weightInput = String(format: "%.0f", exercise.currentWeight)
                repsInput = ""
            }
        }
        .onReceive(timer) { _ in
            if timerActive {
                updateTimerDisplay()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && timerActive {
                updateTimerDisplay()
            }
        }
        .alert("Custom Timer", isPresented: $showCustomTimerAlert, actions: {
            TextField("Seconds", text: $customTimerInput)
                .keyboardType(.numberPad)
            Button("Set", action: {
                if let seconds = Double(customTimerInput) {
                    selectedDuration = seconds
                }
                customTimerInput = ""
            })
            Button("Cancel", role: .cancel, action: {})
        }, message: {
            Text("Enter rest duration in seconds.")
        })
    }
    
    var isCustomDuration: Bool {
        return ![120.0, 150.0, 180.0].contains(selectedDuration)
    }

    func logSet() {
        guard let weight = Double(weightInput), let reps = Int(repsInput) else { return }
        
        let newLog = SetLog(weight: weight, reps: reps, completedDate: Date())
        exercise.logs.append(newLog)
        
        exercise.currentWeight = weight
        
        onSave()
        
        // Start Timer if not finished 5 sets (adjustable)
        if exercise.logs.count < 5 {
            startTimer()
        }
        
        repsInput = ""
    }
    
    func startTimer() {
        timerEndTime = Date().addingTimeInterval(selectedDuration)
        timerActive = true
        updateTimerDisplay()
        
        // Schedule Notification
        NotificationManager.shared.scheduleTimer(seconds: selectedDuration)
    }
    
    func updateTimerDisplay() {
        guard let endTime = timerEndTime else { return }
        let remaining = endTime.timeIntervalSinceNow
        
        if remaining > 0 {
            timeRemaining = remaining
        } else {
            timeRemaining = 0
            timerActive = false
            timerEndTime = nil
            // Haptics or sound could go here
        }
    }
    
    func skipRest() {
        timerActive = false
        timerEndTime = nil
        NotificationManager.shared.cancelTimer()
    }
    
    func finishExercise() {
        exercise.isCompleted = true
        NotificationManager.shared.cancelTimer() // Ensure no lingering timer
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
    
    func timeString(time: TimeInterval) -> String {
        let totalSeconds = Int(ceil(time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

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
