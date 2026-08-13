import SwiftUI
import Combine

struct ExerciseDetailView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage(WeightUnit.storageKey) private var weightUnit: WeightUnit = .pounds
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
    @State private var inputWeightUnit: WeightUnit = .pounds
    @State private var repsInput: String = ""
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Publishers.Autoconnect<Timer.TimerPublisher> = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var selectedDuration: Double = 120
    @State private var showCustomTimerAlert = false
    @State private var customTimerInput = ""
    @State private var timerErrorMessage: String?
    @State private var setLogErrorMessage: String?
    @State private var logBeingEdited: SetLog?
    @State private var logPendingDeletionID: UUID?
    @State private var setMutationErrorMessage: String?

    private var activeRestTimer: ActiveRestTimerState? {
        guard let timer = store.activeRestTimer,
              timer.routineId == routineId,
              timer.workoutId == workoutId,
              timer.exerciseId == exerciseId,
              timer.endTime > Date() else {
            return nil
        }
        return timer
    }

    private var timerActive: Bool { activeRestTimer != nil }

    var body: some View {
        ZStack {
            theme.primaryColor.ignoresSafeArea()
            if let exercise = exercise {
                ScrollView {
                    VStack {
                    Text(exercise.name).font(.title2).foregroundColor(theme.onPrimaryText).padding(.top)
                    Text("Target: \(exercise.targetSets) sets × \(exercise.targetReps) reps")
                        .font(.subheadline).foregroundColor(theme.secondaryOnPrimaryText)
                    List {
                        Section(header: Text("History").foregroundColor(theme.onPrimaryText)) {
                            if exercise.logs.isEmpty {
                                Text("No sets completed yet.").foregroundColor(theme.secondaryRowText)
                            } else {
                                ForEach(Array(exercise.logs.enumerated()), id: \.element.id) { index, log in
                                    HStack {
                                        Text("Set \(index + 1)").fontWeight(.bold)
                                        Spacer()
                                        Text("\(log.reps) reps @ \(WeightFormatter.string(fromPounds: log.weight, unit: weightUnit))")
                                    }
                                    .foregroundColor(theme.rowText)
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("Set \(index + 1)")
                                    .accessibilityValue("\(log.reps) reps at \(WeightFormatter.accessibilityString(fromPounds: log.weight, unit: weightUnit))")
                                    .accessibilityHint("Swipe up or down to edit or delete this set.")
                                    .listRowBackground(theme.rowBackground)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            logPendingDeletionID = log.id
                                        } label: {
                                            Label("Delete Set", systemImage: "trash")
                                        }
                                        Button {
                                            logBeingEdited = log
                                        } label: {
                                            Label("Edit Set", systemImage: "pencil")
                                        }
                                        .tint(theme.accentColor)
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden).frame(maxHeight: 200)

                    let maxSets = exercise.targetSets + 5
                    if exercise.logs.count >= maxSets {
                        Text("Maximum sets reached (\(maxSets))")
                            .font(.caption).foregroundColor(theme.secondaryOnPrimaryText)
                            .padding(.top, 8)
                    } else if !timerActive {
                        SetInputView(setNumber: exercise.logs.count + 1, weightInput: $weightInput, repsInput: $repsInput, selectedDuration: $selectedDuration, showCustomTimerAlert: $showCustomTimerAlert, isCustomDuration: isCustomDuration, validationMessage: setLogErrorMessage, onLogSet: logSet)
                    } else {
                        RestTimerDisplayView(timeRemaining: timeRemaining, nextSetNumber: exercise.logs.count + 1, onSkip: skipRest, onAddTime: {
                            addRestTime()
                        })
                    }
                    if exercise.logs.count >= exercise.targetSets {
                        Button(action: finishExercise) {
                            Text("Finish Exercise").font(.headline).foregroundColor(theme.successColor).padding().frame(maxWidth: .infinity).background(theme.chartSurfaceColor).cornerRadius(10)
                        }.padding(.horizontal)
                    }
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Text("Skip / Back").foregroundColor(theme.secondaryOnPrimaryText)
                    }.padding(.bottom)
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                VStack {
                    Text("Exercise Not Found").foregroundColor(theme.onPrimaryText)
                    Button("Back") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .onAppear {
            if let ex = exercise {
                weightInput = ex.logs.last.map {
                    WeightFormatter.inputString(fromPounds: $0.weight, unit: weightUnit, maximumFractionDigits: 0)
                } ?? WeightFormatter.inputString(fromPounds: ex.currentWeight, unit: weightUnit, maximumFractionDigits: 0)
                inputWeightUnit = weightUnit
                repsInput = ex.logs.last.map { String(format: "%d", $0.reps) } ?? ""
            }
            updateTimerDisplay()
        }
        .onChange(of: weightInput) { _ in setLogErrorMessage = nil }
        .onChange(of: weightUnit) { newUnit in
            reformatWeightInput(for: newUnit)
        }
        .onChange(of: repsInput) { _ in setLogErrorMessage = nil }
        .onReceive(timer) { _ in if timerActive { updateTimerDisplay() } }
        .onChange(of: scenePhase) { newPhase in if newPhase == .active { updateTimerDisplay() } }
        .alert("Custom Timer", isPresented: $showCustomTimerAlert, actions: {
            TextField("Seconds", text: $customTimerInput).keyboardType(.numberPad)
            Button("Set") { setCustomDuration() }
            Button("Cancel", role: .cancel, action: {})
        }, message: { Text("Enter rest duration in seconds.") })
        .alert("Rest Timer", isPresented: Binding(
            get: { timerErrorMessage != nil },
            set: { if !$0 { timerErrorMessage = nil } }
        ), actions: {
            Button("OK", role: .cancel) { timerErrorMessage = nil }
        }, message: {
            Text(timerErrorMessage ?? "")
        })
        .confirmationDialog(
            "Delete Logged Set?",
            isPresented: Binding(
                get: { logPendingDeletionID != nil },
                set: { if !$0 { logPendingDeletionID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Set", role: .destructive, action: deletePendingSet)
            Button("Cancel", role: .cancel) { logPendingDeletionID = nil }
        } message: {
            Text("This removes the set from this workout. You can’t undo it.")
        }
        .sheet(item: $logBeingEdited) { log in
            EditLoggedSetView(log: log) { weight, reps in
                store.updateLoggedSet(
                    routineId: routineId,
                    workoutId: workoutId,
                    exerciseId: exerciseId,
                    logId: log.id,
                    weight: weight,
                    reps: reps
                )
            }
            .environmentObject(themeManager)
        }
        .alert("Couldn’t Update Set", isPresented: Binding(
            get: { setMutationErrorMessage != nil },
            set: { if !$0 { setMutationErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { setMutationErrorMessage = nil }
        } message: {
            Text(setMutationErrorMessage ?? "")
        }
    }

    var isCustomDuration: Bool { ![120.0, 150.0, 180.0].contains(selectedDuration) }

    func logSet() {
        guard let weight = WeightFormatter.pounds(fromInput: weightInput, unit: weightUnit) else {
            setLogErrorMessage = "Enter a valid weight."
            return
        }
        guard let reps = Int(repsInput.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            setLogErrorMessage = "Enter reps as a whole number."
            return
        }
        guard let binding = exerciseBinding else { return }
        let validatedLog: ValidatedSetLog
        do {
            validatedLog = try ExerciseDomainValidation.setLog(weight: weight, reps: reps)
        } catch let error as ExerciseValidationError {
            setLogErrorMessage = error.localizedDescription
            return
        } catch {
            setLogErrorMessage = "Couldn’t validate this set."
            return
        }
        let maxSets = binding.wrappedValue.targetSets + 5
        guard binding.wrappedValue.logs.count < maxSets else { return }
        binding.wrappedValue.logs.append(SetLog(weight: validatedLog.weight, reps: validatedLog.reps, completedDate: Date()))
        binding.wrappedValue.currentWeight = validatedLog.weight
        store.saveRoutines()
        if binding.wrappedValue.logs.count < maxSets { startTimer() }
        repsInput = ""
    }

    func reformatWeightInput(for newUnit: WeightUnit) {
        defer { inputWeightUnit = newUnit }
        guard let pounds = WeightFormatter.pounds(fromInput: weightInput, unit: inputWeightUnit) else { return }
        weightInput = WeightFormatter.inputString(fromPounds: pounds, unit: newUnit, maximumFractionDigits: 0)
    }

    func startTimer() {
        guard case .success(let duration) = RestTimerDuration.validate(selectedDuration) else {
            showTimerDurationError(selectedDuration)
            return
        }

        guard let timer = store.startRestTimer(
            routineId: routineId,
            workoutId: workoutId,
            exerciseId: exerciseId,
            duration: duration
        ) else {
            timerErrorMessage = "Couldn’t start this rest timer."
            return
        }
        updateTimerDisplay()
        scheduleTimerNotification(for: timer)
    }

    func updateTimerDisplay() {
        guard let timer = activeRestTimer else {
            if store.clearExpiredRestTimer() {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            timeRemaining = 0
            return
        }
        let remaining = timer.endTime.timeIntervalSinceNow
        if remaining > 0 {
            timeRemaining = remaining
        } else {
            timeRemaining = 0
            store.clearExpiredRestTimer()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func setCustomDuration() {
        guard let seconds = Double(customTimerInput.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            timerErrorMessage = "Enter a rest duration greater than zero seconds."
            return
        }
        guard case .success(let duration) = RestTimerDuration.validate(seconds) else {
            showTimerDurationError(seconds)
            return
        }

        selectedDuration = duration
        customTimerInput = ""
    }

    func addRestTime() {
        guard let timer = store.addRestTime(
            routineId: routineId,
            workoutId: workoutId,
            exerciseId: exerciseId
        ) else { return }
        updateTimerDisplay()
        scheduleTimerNotification(for: timer)
    }

    func scheduleTimerNotification(for timer: ActiveRestTimerState) {
        NotificationManager.shared.scheduleTimer(
            seconds: max(timer.endTime.timeIntervalSinceNow, 1),
            identifier: timer.notificationId
        ) { result in
            if case .failure(let error) = result {
                timerErrorMessage = error.localizedDescription
            }
        }
    }

    func showTimerDurationError(_ seconds: TimeInterval) {
        if case .failure(let error) = RestTimerDuration.validate(seconds) {
            timerErrorMessage = error.localizedDescription
        }
    }

    func cancelRestTimer() {
        timeRemaining = 0
        store.cancelRestTimer(routineId: routineId, workoutId: workoutId, exerciseId: exerciseId)
    }

    func skipRest() { cancelRestTimer() }

    func deletePendingSet() {
        guard let logId = logPendingDeletionID else { return }
        logPendingDeletionID = nil
        if case .failure(let error) = store.deleteLoggedSet(
            routineId: routineId,
            workoutId: workoutId,
            exerciseId: exerciseId,
            logId: logId
        ) {
            setMutationErrorMessage = error.localizedDescription
        }
    }

    func finishExercise() {
        exerciseBinding?.wrappedValue.isCompleted = true
        store.saveRoutines()
        cancelRestTimer()
        presentationMode.wrappedValue.dismiss()
    }
}

private struct EditLoggedSetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @AppStorage(WeightUnit.storageKey) private var weightUnit: WeightUnit = .pounds

    let log: SetLog
    let onSave: (Double, Int) -> Result<Void, SetLogMutationError>

    @State private var weightInput: String
    @State private var inputWeightUnit: WeightUnit = .pounds
    @State private var repsInput: String
    @State private var errorMessage: String?

    private var theme: AppTheme { themeManager.current }

    init(
        log: SetLog,
        onSave: @escaping (Double, Int) -> Result<Void, SetLogMutationError>
    ) {
        self.log = log
        self.onSave = onSave
        _weightInput = State(initialValue: "")
        _repsInput = State(initialValue: String(log.reps))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Set Details") {
                    TextField("Weight (\(weightUnit.symbol))", text: $weightInput)
                        .keyboardType(.decimalPad)
                    TextField("Reps", text: $repsInput)
                        .keyboardType(.numberPad)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(theme.destructiveColor)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.primaryColor)
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
        .onChange(of: weightInput) { _ in errorMessage = nil }
        .onChange(of: repsInput) { _ in errorMessage = nil }
        .onAppear {
            weightInput = WeightFormatter.inputString(fromPounds: log.weight, unit: weightUnit)
            inputWeightUnit = weightUnit
        }
        .onChange(of: weightUnit) { newUnit in
            reformatWeightInput(for: newUnit)
        }
    }

    private func save() {
        guard let weight = WeightFormatter.pounds(fromInput: weightInput, unit: weightUnit) else {
            errorMessage = "Enter a valid weight."
            return
        }
        guard let reps = Int(repsInput.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Enter reps as a whole number."
            return
        }

        switch onSave(weight, reps) {
        case .success:
            dismiss()
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func reformatWeightInput(for newUnit: WeightUnit) {
        defer { inputWeightUnit = newUnit }
        guard let pounds = WeightFormatter.pounds(fromInput: weightInput, unit: inputWeightUnit) else { return }
        weightInput = WeightFormatter.inputString(fromPounds: pounds, unit: newUnit)
    }
}
