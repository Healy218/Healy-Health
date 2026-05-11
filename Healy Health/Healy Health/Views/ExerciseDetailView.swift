import SwiftUI
import Combine

struct ExerciseDetailView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    let routineId: UUID
    let workoutId: UUID
    let exerciseId: UUID

    private var theme: AppTheme { themeManager.current }

    private var exerciseBinding: Binding<Exercise>? {
        guard let rIndex = store.routines.firstIndex(where: { $0.id == routineId }),
              let wIndex = store.routines[rIndex].workouts.firstIndex(where: { $0.id == workoutId }),
              let eIndex = store.routines[rIndex].workouts[wIndex].exercises.firstIndex(where: { $0.id == exerciseId }) else { return nil }
        return Binding(
            get: { store.routines[rIndex].workouts[wIndex].exercises[eIndex] },
            set: { store.routines[rIndex].workouts[wIndex].exercises[eIndex] = $0; store.saveRoutines() }
        )
    }
    private var exercise: Exercise? { exerciseBinding?.wrappedValue }

    @Environment(\.presentationMode) var presentationMode
    @Environment(\.scenePhase) var scenePhase
    @State private var weightInput: String = ""
    @State private var repsInput: String = ""
    @State private var timerActive = false
    @State private var timerEndTime: Date?
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Publishers.Autoconnect<Timer.TimerPublisher> = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var selectedDuration: Double = 120
    @State private var showCustomTimerAlert = false
    @State private var customTimerInput = ""

    var body: some View {
        ZStack {
            theme.primaryColor.ignoresSafeArea()
            if let exercise = exercise {
                VStack {
                    Text(exercise.name).font(.title2).foregroundColor(theme.onPrimaryText).padding(.top)
                    Text("Target: \(exercise.targetSets) sets × \(exercise.targetReps) reps")
                        .font(.subheadline).foregroundColor(theme.onPrimaryText.opacity(0.7))
                    List {
                        Section(header: Text("History").foregroundColor(theme.onPrimaryText)) {
                            if exercise.logs.isEmpty {
                                Text("No sets completed yet.").foregroundColor(theme.secondaryRowText)
                            } else {
                                ForEach(exercise.logs) { log in
                                    HStack {
                                        Text("Set \(exercise.logs.firstIndex(where: { $0.id == log.id })! + 1)").fontWeight(.bold)
                                        Spacer()
                                        Text("\(log.reps) reps @ \(String(format: "%.1f", log.weight)) lbs")
                                    }
                                    .foregroundColor(theme.rowText)
                                    .listRowBackground(theme.rowBackground)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden).frame(maxHeight: 200)

                    let maxSets = exercise.targetSets + 5
                    if exercise.logs.count >= maxSets {
                        Text("Maximum sets reached (\(maxSets))")
                            .font(.caption).foregroundColor(theme.onPrimaryText.opacity(0.6))
                            .padding(.top, 8)
                    } else if !timerActive {
                        SetInputView(setNumber: exercise.logs.count + 1, weightInput: $weightInput, repsInput: $repsInput, selectedDuration: $selectedDuration, showCustomTimerAlert: $showCustomTimerAlert, isCustomDuration: isCustomDuration, onLogSet: logSet)
                    } else {
                        RestTimerDisplayView(timeRemaining: timeRemaining, nextSetNumber: exercise.logs.count + 1, onSkip: skipRest, onAddTime: {
                            if let endTime = timerEndTime {
                                timerEndTime = endTime.addingTimeInterval(30)
                                NotificationManager.shared.cancelTimer()
                                updateTimerDisplay()
                                NotificationManager.shared.scheduleTimer(seconds: timeRemaining)
                            }
                        })
                    }
                    Spacer()
                    if exercise.logs.count >= exercise.targetSets {
                        Button(action: finishExercise) {
                            Text("Finish Exercise").font(.headline).foregroundColor(.green).padding().frame(maxWidth: .infinity).background(theme.onPrimaryText).cornerRadius(10)
                        }.padding(.horizontal)
                    }
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Text("Skip / Back").foregroundColor(theme.onPrimaryText.opacity(0.8))
                    }.padding(.bottom)
                }
            } else {
                VStack {
                    Text("Exercise Not Found").foregroundColor(theme.onPrimaryText)
                    Button("Back") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .onAppear {
            if let ex = exercise {
                weightInput = ex.logs.last.map { String(format: "%.0f", $0.weight) } ?? String(format: "%.0f", ex.currentWeight)
                repsInput = ex.logs.last.map { String(format: "%d", $0.reps) } ?? ""
            }
        }
        .onReceive(timer) { _ in if timerActive { updateTimerDisplay() } }
        .onChange(of: scenePhase) { newPhase in if newPhase == .active && timerActive { updateTimerDisplay() } }
        .alert("Custom Timer", isPresented: $showCustomTimerAlert, actions: {
            TextField("Seconds", text: $customTimerInput).keyboardType(.numberPad)
            Button("Set") { if let s = Double(customTimerInput) { selectedDuration = s }; customTimerInput = "" }
            Button("Cancel", role: .cancel, action: {})
        }, message: { Text("Enter rest duration in seconds.") })
    }

    var isCustomDuration: Bool { ![120.0, 150.0, 180.0].contains(selectedDuration) }

    func logSet() {
        guard let weight = Double(weightInput), let reps = Int(repsInput), let binding = exerciseBinding else { return }
        let maxSets = binding.wrappedValue.targetSets + 5
        guard binding.wrappedValue.logs.count < maxSets else { return }
        binding.wrappedValue.logs.append(SetLog(weight: weight, reps: reps, completedDate: Date()))
        binding.wrappedValue.currentWeight = weight
        store.saveRoutines()
        if binding.wrappedValue.logs.count < maxSets { startTimer() }
        repsInput = ""
    }

    func startTimer() {
        timerEndTime = Date().addingTimeInterval(selectedDuration)
        timerActive = true; updateTimerDisplay()
        NotificationManager.shared.scheduleTimer(seconds: selectedDuration)
    }

    func updateTimerDisplay() {
        guard let endTime = timerEndTime else { return }
        let remaining = endTime.timeIntervalSinceNow
        if remaining > 0 { timeRemaining = remaining } else {
            timeRemaining = 0; timerActive = false; timerEndTime = nil
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func skipRest() { timerActive = false; timerEndTime = nil; NotificationManager.shared.cancelTimer() }
    func finishExercise() { exerciseBinding?.wrappedValue.isCompleted = true; store.saveRoutines(); NotificationManager.shared.cancelTimer(); presentationMode.wrappedValue.dismiss() }
}
