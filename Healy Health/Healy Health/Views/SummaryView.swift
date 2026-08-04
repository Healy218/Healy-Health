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

    func value(for point: ExerciseHistoryPoint) -> Double {
        switch self {
        case .volume:
            return point.totalVolume
        case .topSet:
            return point.maxWeight
        case .estimatedOneRepMax:
            return point.estimatedOneRepMax
        }
    }

    func formattedValue(for point: ExerciseHistoryPoint) -> String {
        switch self {
        case .volume:
            return "\(point.totalVolume.abbreviatedVolume) lb-reps"
        case .topSet:
            return "\(String(format: "%.0f", point.maxWeight)) lbs"
        case .estimatedOneRepMax:
            return "\(String(format: "%.0f", point.estimatedOneRepMax)) lbs"
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
                Text("No workouts completed yet.")
                    .foregroundColor(theme.onPrimaryText)
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
                                label: lastWorkout.map { "Last: \($0.dayName)" } ?? "Workout History",
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
            Text(label)
                .font(.custom("ChalkboardSE-Regular", size: 17))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .opacity(0.5)
        }
        .foregroundColor(theme.rowText)
        .padding()
        .background(theme.rowBackground)
        .cornerRadius(14)
    }
}

// MARK: - Top exercise chart card

struct TopExerciseChartCard: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("preferredExerciseChartMetric") private var selectedMetricRawValue = ExerciseChartMetric.volume.rawValue
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
                            .font(.custom("ChalkboardSE-Regular", size: 15))
                            .foregroundColor(theme.onPrimaryText.opacity(0.75))

                        Text(selectedMetric.subtitle)
                            .font(.caption)
                            .foregroundColor(theme.onPrimaryText.opacity(0.55))
                    }

                    Spacer()

                    ExerciseChartMetricMenu(selection: selectedMetricBinding, theme: theme)
                }

                if top.history.count < 2 {
                    Text("Log more sessions to see progress")
                        .font(.caption)
                        .foregroundColor(theme.onPrimaryText.opacity(0.5))
                        .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
                } else {
                    ExerciseLineChart(history: top.history, metric: selectedMetric, theme: theme, height: 160)
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
    let theme: AppTheme
    let height: CGFloat

    // Light theme keeps existing accent-on-card-background style; all others use primaryColor on white.
    private var isLight: Bool { theme == .light }
    private var lineColor: Color { isLight ? theme.accentColor : theme.primaryColor }
    private var fillColor: Color { isLight ? theme.accentColor.opacity(0.15) : theme.primaryColor.opacity(0.22) }
    private var axisColor: Color { isLight ? theme.onPrimaryText.opacity(0.6) : Color(white: 0.45) }

    var body: some View {
        Chart(history) { point in
            LineMark(
                x: .value("Session", point.session),
                y: .value(metric.axisLabel, metric.value(for: point))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(lineColor)

            AreaMark(
                x: .value("Session", point.session),
                y: .value(metric.axisLabel, metric.value(for: point))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(fillColor)

            PointMark(
                x: .value("Session", point.session),
                y: .value(metric.axisLabel, metric.value(for: point))
            )
            .foregroundStyle(lineColor)
        }
        .frame(height: height)
        .padding()
        .background(isLight ? Color.clear : Color.white)
        .cornerRadius(14)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel().foregroundStyle(axisColor)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(isLight ? Color(white: 0.75) : Color(white: 0.3))
                AxisValueLabel {
                    if let metricValue = value.as(Double.self) {
                        Text(formattedAxisValue(metricValue))
                    }
                }
                .foregroundStyle(axisColor)
            }
        }
    }

    private func formattedAxisValue(_ value: Double) -> String {
        switch metric {
        case .volume:
            return value.abbreviatedVolume
        case .topSet, .estimatedOneRepMax:
            return String(format: "%.0f", value)
        }
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
                            .foregroundColor(theme.onPrimaryText.opacity(0.6))
                            .padding()
                    } else {
                        // Chart card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(selectedMetric.title) Over Time")
                                        .font(.custom("ChalkboardSE-Regular", size: 14))
                                        .foregroundColor(theme.onPrimaryText.opacity(0.7))
                                    Text(selectedMetric.subtitle)
                                        .font(.caption)
                                        .foregroundColor(theme.onPrimaryText.opacity(0.55))
                                }

                                Spacer()

                                ExerciseChartMetricMenu(selection: selectedMetricBinding, theme: theme)
                            }
                            ExerciseLineChart(history: history, metric: selectedMetric, theme: theme, height: 220)
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
                                    Text(selectedMetric.formattedValue(for: point))
                                        .foregroundColor(theme.rowText)
                                    Text("Top set: \(String(format: "%.0f", point.maxWeight)) lbs")
                                        .font(.caption)
                                        .foregroundColor(theme.secondaryRowText)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .background(theme.rowBackground)

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

    var body: some View {
        ZStack {
            theme.primaryColor.ignoresSafeArea()
            List(store.completedWorkouts.sorted(by: CompletedWorkout.newestFirst)) { workout in
                NavigationLink(destination: SummaryDetailView(workout: workout)) {
                    VStack(alignment: .leading) {
                        Text(workout.date.formatted(date: .long, time: .shortened))
                            .font(.headline).foregroundColor(theme.rowText)
                        Text(workout.dayName)
                            .font(.subheadline).foregroundColor(theme.secondaryRowText)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(theme.rowBackground)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Workout History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Summary detail view

struct SummaryDetailView: View {
    let workout: CompletedWorkout
    @EnvironmentObject var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.current }

    var body: some View {
        ZStack {
            theme.primaryColor.ignoresSafeArea()
            List {
                Section(header: Text("Workout Info").foregroundColor(theme.onPrimaryText)) {
                    HStack { Text("Routine / Workout").foregroundColor(theme.rowText); Spacer(); Text(workout.dayName).foregroundColor(theme.secondaryRowText) }.listRowBackground(theme.rowBackground)
                    HStack { Text("Date").foregroundColor(theme.rowText); Spacer(); Text(workout.date.formatted(date: .long, time: .shortened)).foregroundColor(theme.secondaryRowText) }.listRowBackground(theme.rowBackground)
                }
                Section(header: Text("Exercises").foregroundColor(theme.onPrimaryText)) {
                    if workout.exercises.isEmpty {
                        Text("No exercises recorded.").listRowBackground(theme.rowBackground).foregroundColor(theme.secondaryRowText)
                    } else {
                        ForEach(workout.exercises) { exercise in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(exercise.name).font(.headline).foregroundColor(theme.rowText)
                                if exercise.logs.isEmpty {
                                    Text("No sets logged").font(.subheadline).foregroundColor(theme.secondaryRowText)
                                } else {
                                    ForEach(Array(exercise.logs.enumerated()), id: \.element.id) { index, log in
                                        HStack {
                                            Text("Set \(index + 1)").font(.subheadline).foregroundColor(theme.secondaryRowText)
                                            Spacer()
                                            Text("\(log.reps) reps @ \(String(format: "%.1f", log.weight)) lbs").font(.subheadline).foregroundColor(theme.rowText)
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
    }
}
