import SwiftUI
import Charts

// MARK: - Supporting data types

struct ExerciseLogData: Identifiable {
    let id: UUID; let name: String; let date: Date; let maxWeight: Double; let totalVolume: Double
}

enum ExerciseChartMetric: String, CaseIterable, Identifiable {
    case volume
    case topSet
    case estimatedOneRepMax

    var id: String { rawValue }

    var title: String {
        switch self {
        case .volume:
            return "Volume"
        case .topSet:
            return "Top Set"
        case .estimatedOneRepMax:
            return "Estimated 1RM"
        }
    }

    var subtitle: String {
        switch self {
        case .volume:
            return "Volume = weight x reps across all logged sets"
        case .topSet:
            return "Top set = heaviest weight logged in a session"
        case .estimatedOneRepMax:
            return "Estimated 1RM uses the best set from the session"
        }
    }

    var axisLabel: String {
        switch self {
        case .volume:
            return "Volume"
        case .topSet:
            return "Top Set"
        case .estimatedOneRepMax:
            return "Estimated 1RM"
        }
    }

    func value(for point: ExerciseHistoryPoint, unit: WeightUnit) -> Double {
        switch self {
        case .volume:
            return WeightFormatter.displayedValue(fromPounds: point.totalVolume, unit: unit)
        case .topSet:
            return WeightFormatter.displayedValue(fromPounds: point.maxWeight, unit: unit)
        case .estimatedOneRepMax:
            return WeightFormatter.displayedValue(fromPounds: point.estimatedOneRepMax, unit: unit)
        }
    }

    func formattedValue(for point: ExerciseHistoryPoint, unit: WeightUnit) -> String {
        switch self {
        case .volume:
            let displayedVolume = value(for: point, unit: unit)
            return "\(WeightFormatter.numberString(displayedVolume, maximumFractionDigits: displayedVolume >= 1000 ? 0 : 1)) \(unit.volumeSymbol)"
        case .topSet:
            return WeightFormatter.string(fromPounds: point.maxWeight, unit: unit, maximumFractionDigits: 0)
        case .estimatedOneRepMax:
            return WeightFormatter.string(fromPounds: point.estimatedOneRepMax, unit: unit, maximumFractionDigits: 0)
        }
    }
}

private extension Double {
    var abbreviatedVolume: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = self >= 1000 ? 0 : 1
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "%.0f", self)
    }
}

// MARK: - SummaryView

struct SummaryView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.current }

    private var lastWorkout: CompletedWorkout? {
        store.completedWorkouts.sorted(by: CompletedWorkout.newestFirst).first
    }

    var body: some View {
        ZStack {
            theme.primaryColor.ignoresSafeArea()

            if store.completedWorkouts.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(theme.disabledOnPrimaryText)
                        .accessibilityHidden(true)
                    Text("No workouts completed yet.")
                        .font(AppTypography.chalkboard(20, relativeTo: .title3))
                        .foregroundColor(theme.onPrimaryText)
                    Text("Complete a workout to see your history and progress here.")
                        .font(AppTypography.chalkboard(16, relativeTo: .body))
                        .foregroundColor(theme.secondaryOnPrimaryText)
                        .multilineTextAlignment(.center)
                    Button("Browse Routines") {
                        store.selectedTab = 0
                    }
                    .font(AppTypography.chalkboard(17, relativeTo: .body))
                    .foregroundColor(theme.accentColor)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(theme.rowBackground)
                    .cornerRadius(12)
                    .accessibilityHint("Opens the Routines tab so you can start a workout.")
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 16) {

                        // Top chart: most trained exercise
                        TopExerciseChartCard()

                        // Exercises button
                        NavigationLink(destination: ExercisesListView()) {
                            SummaryNavButton(label: "Exercises", icon: "dumbbell.fill", theme: theme)
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Last workout / history button
                        NavigationLink(destination: WorkoutHistoryView()) {
                            SummaryNavButton(
                                label: lastWorkout.map { "Last: \($0.workoutName)" } ?? "Workout History",
                                icon: "calendar",
                                theme: theme
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Reusable nav button

struct SummaryNavButton: View {
    let label: String
    let icon: String
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(label)
                .font(AppTypography.chalkboard(17, relativeTo: .body))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .opacity(0.5)
                .accessibilityHidden(true)
        }
        .foregroundColor(theme.rowText)
        .padding()
        .background(theme.rowBackground)
        .cornerRadius(14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityHint("Opens \(label).")
    }
}

// MARK: - Top exercise chart card

struct TopExerciseChartCard: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("preferredExerciseChartMetric") private var selectedMetricRawValue = ExerciseChartMetric.volume.rawValue
    @AppStorage(WeightUnit.storageKey) private var weightUnit: WeightUnit = .pounds
    private var theme: AppTheme { themeManager.current }

    private var topData: (name: String, history: [ExerciseHistoryPoint])? {
        let sessions = ExerciseAnalytics.trainedSessions(from: store.completedWorkouts)
        guard let topExercise = ExerciseAnalytics.summaries(from: sessions).first else {
            return nil
        }
        return (topExercise.name, ExerciseAnalytics.history(for: topExercise.id, from: sessions))
    }

    private var selectedMetric: ExerciseChartMetric {
        get { ExerciseChartMetric(rawValue: selectedMetricRawValue) ?? .volume }
        nonmutating set { selectedMetricRawValue = newValue.rawValue }
    }

    private var selectedMetricBinding: Binding<ExerciseChartMetric> {
        Binding(
            get: { selectedMetric },
            set: { selectedMetric = $0 }
        )
    }

    var body: some View {
        if let top = topData {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Most Trained: \(top.name)")
                            .font(AppTypography.chalkboard(15, relativeTo: .subheadline))
                            .foregroundColor(theme.secondaryOnPrimaryText)

                        Text(selectedMetric.subtitle)
                            .font(.caption)
                            .foregroundColor(theme.secondaryOnPrimaryText)
                    }

                    Spacer()

                    ExerciseChartMetricMenu(selection: selectedMetricBinding, theme: theme)
                }

                if top.history.count < 2 {
                    Text("Log more sessions to see progress")
                        .font(.caption)
                        .foregroundColor(theme.disabledOnPrimaryText)
                        .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
                } else {
                    ExerciseLineChart(history: top.history, metric: selectedMetric, unit: weightUnit, theme: theme, height: 160)
                }
            }
            .padding()
            .background(theme == .light ? theme.onPrimaryText.opacity(0.08) : Color.clear)
            .cornerRadius(18)
        }
    }

}

// MARK: - Shared line chart component

struct ExerciseLineChart: View {
    let history: [ExerciseHistoryPoint]
    let metric: ExerciseChartMetric
    let unit: WeightUnit
    let theme: AppTheme
    let height: CGFloat

    private var lineColor: Color { theme.chartLineColor }
    private var fillColor: Color { theme.chartLineColor.opacity(0.2) }
    private var axisColor: Color { theme.chartAxisColor }

    var body: some View {
        Chart(history) { point in
            LineMark(
                x: .value("Session", point.session),
                y: .value(metric.axisLabel, metric.value(for: point, unit: unit))
            )
            .interpolationMethod(.linear)
            .foregroundStyle(lineColor)

            AreaMark(
                x: .value("Session", point.session),
                y: .value(metric.axisLabel, metric.value(for: point, unit: unit))
            )
            .interpolationMethod(.linear)
            .foregroundStyle(fillColor)

            PointMark(
                x: .value("Session", point.session),
                y: .value(metric.axisLabel, metric.value(for: point, unit: unit))
            )
            .foregroundStyle(lineColor)
        }
        .frame(height: height)
        .padding()
        .background(theme.chartSurfaceColor)
        .cornerRadius(14)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel().foregroundStyle(axisColor)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(theme.chartGridColor)
                AxisValueLabel {
                    if let metricValue = value.as(Double.self) {
                        Text(formattedAxisValue(metricValue))
                    }
                }
                .foregroundStyle(axisColor)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.title) progress chart")
        .accessibilityValue(chartAccessibilityValue)
        .accessibilityHint("The individual session results are listed below the chart.")
    }

    private func formattedAxisValue(_ value: Double) -> String {
        switch metric {
        case .volume:
            return "\(value.abbreviatedVolume) \(unit.volumeSymbol)"
        case .topSet, .estimatedOneRepMax:
            return "\(WeightFormatter.numberString(value, maximumFractionDigits: 0)) \(unit.symbol)"
        }
    }

    private var chartAccessibilityValue: String {
        guard let latest = history.last else { return "No sessions recorded." }
        return "\(history.count) sessions. Latest session: \(metric.formattedValue(for: latest, unit: unit)) on \(latest.date.formatted(date: .abbreviated, time: .omitted))."
    }
}

struct ExerciseChartMetricMenu: View {
    @Binding var selection: ExerciseChartMetric
    let theme: AppTheme

    var body: some View {
        Menu {
            Picker("Metric", selection: $selection) {
                ForEach(ExerciseChartMetric.allCases) { metric in
                    Text(metric.title).tag(metric)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selection.title)
                    .font(.caption.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundColor(theme.rowText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(theme.rowBackground)
            .cornerRadius(10)
        }
        .accessibilityLabel("Chart metric")
        .accessibilityValue(selection.title)
        .accessibilityHint("Choose the metric shown in the progress chart.")
    }
}

// MARK: - Exercises list

struct ExercisesListView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.current }

    private var exercises: [ExerciseTrainingSummary] {
        ExerciseAnalytics.summaries(
            from: ExerciseAnalytics.trainedSessions(from: store.completedWorkouts)
        )
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                return nameOrder == .orderedSame ? lhs.id.uuidString < rhs.id.uuidString : nameOrder == .orderedAscending
            }
    }

    var body: some View {
        ZStack {
            theme.primaryColor.ignoresSafeArea()
            List(exercises) { item in
                NavigationLink(destination: ExerciseProgressView(exerciseId: item.id, exerciseName: item.name)) {
                    HStack {
                        Text(item.name).foregroundColor(theme.rowText)
                        Spacer()
                        Text("\(item.count) session\(item.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(theme.secondaryRowText)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(item.name)
                    .accessibilityValue("\(item.count) session\(item.count == 1 ? "" : "s")")
                    .accessibilityHint("Opens progress for \(item.name).")
                }
                .listRowBackground(theme.rowBackground)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Exercise progress view

struct ExerciseProgressView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("preferredExerciseChartMetric") private var selectedMetricRawValue = ExerciseChartMetric.volume.rawValue
    @AppStorage(WeightUnit.storageKey) private var weightUnit: WeightUnit = .pounds
    let exerciseId: UUID
    let exerciseName: String
    private var theme: AppTheme { themeManager.current }

    private var selectedMetric: ExerciseChartMetric {
        get { ExerciseChartMetric(rawValue: selectedMetricRawValue) ?? .volume }
        nonmutating set { selectedMetricRawValue = newValue.rawValue }
    }

    private var selectedMetricBinding: Binding<ExerciseChartMetric> {
        Binding(
            get: { selectedMetric },
            set: { selectedMetric = $0 }
        )
    }

    private var history: [ExerciseHistoryPoint] {
        ExerciseAnalytics.history(
            for: exerciseId,
            from: ExerciseAnalytics.trainedSessions(from: store.completedWorkouts)
        )
    }

    var body: some View {
        ZStack {
            theme.primaryColor.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if history.count < 2 {
                        Text("Log more sessions to see a progress chart.")
                            .foregroundColor(theme.secondaryOnPrimaryText)
                            .padding()
                    } else {
                        // Chart card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(selectedMetric.title) Over Time")
                                        .font(AppTypography.chalkboard(14, relativeTo: .subheadline))
                                        .foregroundColor(theme.secondaryOnPrimaryText)
                                    Text(selectedMetric.subtitle)
                                        .font(.caption)
                                        .foregroundColor(theme.secondaryOnPrimaryText)
                                }

                                Spacer()

                                ExerciseChartMetricMenu(selection: selectedMetricBinding, theme: theme)
                            }
                            ExerciseLineChart(history: history, metric: selectedMetric, unit: weightUnit, theme: theme, height: 220)
                        }
                        .padding()
                        .background(theme == .light ? theme.onPrimaryText.opacity(0.08) : Color.clear)
                        .cornerRadius(18)
                        .padding(.horizontal)
                    }

                    // Session log list (most recent first)
                    VStack(spacing: 0) {
                        ForEach(history.reversed()) { point in
                            HStack {
                                Text("Session \(point.session)")
                                    .foregroundColor(theme.rowText)
                                Spacer()
                                Text(point.date.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(theme.secondaryRowText)
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(selectedMetric.formattedValue(for: point, unit: weightUnit))
                                        .foregroundColor(theme.rowText)
                                    Text("Top set: \(WeightFormatter.string(fromPounds: point.maxWeight, unit: weightUnit, maximumFractionDigits: 0))")
                                        .font(.caption)
                                        .foregroundColor(theme.secondaryRowText)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .background(theme.rowBackground)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Session \(point.session), \(point.date.formatted(date: .abbreviated, time: .omitted))")
                            .accessibilityValue("\(selectedMetric.formattedValue(for: point, unit: weightUnit)). Top set \(WeightFormatter.accessibilityString(fromPounds: point.maxWeight, unit: weightUnit, maximumFractionDigits: 0)).")

                            if point.id != history.reversed().last?.id {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                    .cornerRadius(14)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Workout history list

struct WorkoutHistoryView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.current }
    @State private var pendingDeletion: CompletedWorkout?
    @State private var mutationErrorMessage: String?

    var body: some View {
        ZStack {
            theme.primaryColor.ignoresSafeArea()
            List(store.completedWorkouts.sorted(by: CompletedWorkout.newestFirst)) { workout in
                NavigationLink(destination: SummaryDetailView(workout: workout)) {
                    VStack(alignment: .leading) {
                        Text(workout.date.formatted(date: .long, time: .shortened))
                            .font(.headline).foregroundColor(theme.rowText)
                        Text(workout.workoutName)
                            .font(.subheadline).foregroundColor(theme.secondaryRowText)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(workout.workoutName)
                    .accessibilityValue("Completed \(workout.date.formatted(date: .long, time: .shortened)).")
                    .accessibilityHint("Opens completed workout details. Swipe up or down to delete.")
                }
                .listRowBackground(theme.rowBackground)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingDeletion = workout
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .confirmationDialog(
            "Delete Completed Workout?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Workout", role: .destructive, action: deletePendingWorkout)
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("This permanently removes this workout and its analytics contribution. It can’t be undone.")
        }
        .alert("Couldn’t Delete Workout", isPresented: Binding(
            get: { mutationErrorMessage != nil },
            set: { if !$0 { mutationErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { mutationErrorMessage = nil }
        } message: {
            Text(mutationErrorMessage ?? "")
        }
        .navigationTitle("Workout History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func deletePendingWorkout() {
        guard let workout = pendingDeletion else { return }
        pendingDeletion = nil
        if case .failure(let error) = store.deleteCompletedWorkout(id: workout.id) {
            mutationErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Summary detail view

struct SummaryDetailView: View {
    let workout: CompletedWorkout
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage(WeightUnit.storageKey) private var weightUnit: WeightUnit = .pounds
    @Environment(\.dismiss) private var dismiss
    private var theme: AppTheme { themeManager.current }
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var mutationErrorMessage: String?

    private var currentWorkout: CompletedWorkout {
        store.completedWorkouts.first(where: { $0.id == workout.id }) ?? workout
    }

    var body: some View {
        ZStack {
            theme.primaryColor.ignoresSafeArea()
            List {
                Section(header: Text("Workout Info").foregroundColor(theme.onPrimaryText)) {
                    HStack { Text("Routine").foregroundColor(theme.rowText); Spacer(); Text(currentWorkout.routineName ?? "Not recorded").foregroundColor(theme.secondaryRowText) }.listRowBackground(theme.rowBackground)
                    HStack { Text("Workout").foregroundColor(theme.rowText); Spacer(); Text(currentWorkout.workoutName).foregroundColor(theme.secondaryRowText) }.listRowBackground(theme.rowBackground)
                    HStack { Text("Date").foregroundColor(theme.rowText); Spacer(); Text(currentWorkout.date.formatted(date: .long, time: .shortened)).foregroundColor(theme.secondaryRowText) }.listRowBackground(theme.rowBackground)
                }
                Section(header: Text("Exercises").foregroundColor(theme.onPrimaryText)) {
                    if currentWorkout.exercises.isEmpty {
                        Text("No exercises recorded.").listRowBackground(theme.rowBackground).foregroundColor(theme.secondaryRowText)
                    } else {
                        ForEach(currentWorkout.exercises) { exercise in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(exercise.name).font(.headline).foregroundColor(theme.rowText)
                                if exercise.logs.isEmpty {
                                    Text("No sets logged").font(.subheadline).foregroundColor(theme.secondaryRowText)
                                } else {
                                    ForEach(Array(exercise.logs.enumerated()), id: \.element.id) { index, log in
                                        HStack {
                                            Text("Set \(index + 1)").font(.subheadline).foregroundColor(theme.secondaryRowText)
                                            Spacer()
                                            Text("\(log.reps) reps @ \(WeightFormatter.string(fromPounds: log.weight, unit: weightUnit))").font(.subheadline).foregroundColor(theme.rowText)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4).listRowBackground(theme.rowBackground)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Edit") { isEditing = true }
                Button(role: .destructive) { showDeleteConfirmation = true } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete completed workout")
                .accessibilityHint("Permanently deletes this workout and its analytics contribution.")
            }
        }
        .sheet(isPresented: $isEditing) {
            EditCompletedWorkoutView(workout: currentWorkout)
                .environmentObject(store)
                .environmentObject(themeManager)
        }
        .confirmationDialog(
            "Delete Completed Workout?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Workout", role: .destructive, action: deleteWorkout)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes this workout and its analytics contribution. It can’t be undone.")
        }
        .alert("Couldn’t Delete Workout", isPresented: Binding(
            get: { mutationErrorMessage != nil },
            set: { if !$0 { mutationErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { mutationErrorMessage = nil }
        } message: {
            Text(mutationErrorMessage ?? "")
        }
    }

    private func deleteWorkout() {
        switch store.deleteCompletedWorkout(id: currentWorkout.id) {
        case .success:
            dismiss()
        case .failure(let error):
            mutationErrorMessage = error.localizedDescription
        }
    }
}

struct EditCompletedWorkoutView: View {
    let workout: CompletedWorkout
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var date: Date
    @State private var routineName: String
    @State private var workoutName: String
    @State private var focus: String
    @State private var mutationErrorMessage: String?

    init(workout: CompletedWorkout) {
        self.workout = workout
        _date = State(initialValue: workout.date)
        _routineName = State(initialValue: workout.routineName ?? "")
        _workoutName = State(initialValue: workout.workoutName)
        _focus = State(initialValue: workout.focus)
    }

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Details") {
                    TextField("Routine name", text: $routineName)
                    TextField("Workout name", text: $workoutName)
                    TextField("Focus", text: $focus)
                    DatePicker("Completed", selection: $date)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.primaryColor.ignoresSafeArea())
            .navigationTitle("Edit History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: save)
                }
            }
            .alert("Couldn’t Save History", isPresented: Binding(
                get: { mutationErrorMessage != nil },
                set: { if !$0 { mutationErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { mutationErrorMessage = nil }
            } message: {
                Text(mutationErrorMessage ?? "")
            }
        }
    }

    private func save() {
        switch store.updateCompletedWorkout(
            id: workout.id,
            date: date,
            routineName: routineName,
            workoutName: workoutName,
            focus: focus
        ) {
        case .success:
            dismiss()
        case .failure(let error):
            mutationErrorMessage = error.localizedDescription
        }
    }
}
