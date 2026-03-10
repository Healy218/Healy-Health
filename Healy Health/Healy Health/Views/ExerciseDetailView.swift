import SwiftUI
import Combine

struct ExerciseDetailView: View {
    @EnvironmentObject var store: RoutineStore
    let routineId: UUID
    let workoutId: UUID
    let exerciseId: UUID
    
    private var exerciseBinding: Binding<Exercise>? {
        guard let rIndex = store.routines.firstIndex(where: { $0.id == routineId }),
              let wIndex = store.routines[rIndex].workouts.firstIndex(where: { $0.id == workoutId }),
              let eIndex = store.routines[rIndex].workouts[wIndex].exercises.firstIndex(where: { $0.id == exerciseId }) else {
            return nil
        }
        return Binding(
            get: { store.routines[rIndex].workouts[wIndex].exercises[eIndex] },
            set: {
                store.routines[rIndex].workouts[wIndex].exercises[eIndex] = $0
                store.saveRoutines()
            }
        )
    }
    
    // We'll use a local copy for the UI to prevent constant binding lookups if needed, or just unwrap it
    // Let's create a computed property for safety
    private var exercise: Exercise? {
        exerciseBinding?.wrappedValue
    }
    
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
            
            if let exercise = exercise {
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
                    
                    // Fix #5: Use extracted subviews
                    if !timerActive {
                        SetInputView(
                            setNumber: exercise.logs.count + 1,
                            weightInput: $weightInput,
                            repsInput: $repsInput,
                            selectedDuration: $selectedDuration,
                            showCustomTimerAlert: $showCustomTimerAlert,
                            isCustomDuration: isCustomDuration,
                            onLogSet: logSet
                        )
                    } else {
                        RestTimerDisplayView(
                            timeRemaining: timeRemaining,
                            nextSetNumber: exercise.logs.count + 1,
                            onSkip: skipRest,
                            onAddTime: {
                                if let endTime = timerEndTime {
                                    timerEndTime = endTime.addingTimeInterval(30)
                                    NotificationManager.shared.cancelTimer()
                                    updateTimerDisplay()
                                    NotificationManager.shared.scheduleTimer(seconds: timeRemaining)
                                }
                            }
                        )
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
            } else {
                VStack {
                    Text("Exercise Not Found")
                        .foregroundColor(.white)
                    Button("Back") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let exercise = self.exercise {
                if let lastLog = exercise.logs.last {
                    weightInput = String(format: "%.0f", lastLog.weight)
                    repsInput = String(format: "%d", lastLog.reps)
                } else {
                    weightInput = String(format: "%.0f", exercise.currentWeight)
                    repsInput = ""
                }
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
        guard let binding = exerciseBinding else { return }
        
        let newLog = SetLog(weight: weight, reps: reps, completedDate: Date())
        binding.wrappedValue.logs.append(newLog)
        
        binding.wrappedValue.currentWeight = weight
        store.saveRoutines()
        
        // Start Timer if not finished 5 sets (adjustable)
        if binding.wrappedValue.logs.count < 5 {
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
            // Fix #12: Haptic feedback on timer completion
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    func skipRest() {
        timerActive = false
        timerEndTime = nil
        NotificationManager.shared.cancelTimer()
    }
    
    func finishExercise() {
        exerciseBinding?.wrappedValue.isCompleted = true
        store.saveRoutines()
        NotificationManager.shared.cancelTimer() // Ensure no lingering timer
        presentationMode.wrappedValue.dismiss()
    }
    
}
