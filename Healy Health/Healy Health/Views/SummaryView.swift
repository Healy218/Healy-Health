import SwiftUI
import Charts

// MARK: - Supporting data types

struct ExerciseHistoryPoint: Identifiable {
    let id = UUID()
    let date: Date
    let maxWeight: Double
    let session: Int
}

struct ExerciseSummary: Identifiable {
    let id: String   // exercise name used as stable identifier
    let count: Int
}

struct ExerciseLogData: Identifiable {
    let id: UUID; let name: String; let date: Date; let maxWeight: Double; let totalVolume: Double
}

// MARK: - SummaryView

struct SummaryView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.current }

    private var lastWorkout: CompletedWorkout? { store.completedWorkouts.first }

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
    private var theme: AppTheme { themeManager.current }

    private var topData: (name: String, history: [ExerciseHistoryPoint])? {
        var counts: [String: Int] = [:]
        for workout in store.completedWorkouts {
            for exercise in workout.exercises where !exercise.logs.isEmpty {
                counts[exercise.name, default: 0] += 1
            }
        }
        guard let topName = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        return (topName, historyFor(topName))
    }

    var body: some View {
        if let top = topData {
            VStack(alignment: .leading, spacing: 10) {
                Text("Most Trained: \(top.name)")
                    .font(.custom("ChalkboardSE-Regular", size: 15))
                    .foregroundColor(theme.onPrimaryText.opacity(0.75))

                if top.history.count < 2 {
                    Text("Log more sessions to see progress")
                        .font(.caption)
                        .foregroundColor(theme.onPrimaryText.opacity(0.5))
                        .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
                } else {
                    ExerciseLineChart(history: top.history, theme: theme, height: 160)
                }
            }
            .padding()
            .background(theme == .light ? theme.onPrimaryText.opacity(0.08) : Color.clear)
            .cornerRadius(18)
        }
    }

    private func historyFor(_ name: String) -> [ExerciseHistoryPoint] {
        var points: [ExerciseHistoryPoint] = []
        let sorted = store.completedWorkouts.sorted { $0.date < $1.date }
        var session = 1
        for workout in sorted {
            for exercise in workout.exercises where exercise.name == name && !exercise.logs.isEmpty {
                let maxWeight = exercise.logs.map { $0.weight }.max() ?? 0
                points.append(ExerciseHistoryPoint(date: workout.date, maxWeight: maxWeight, session: session))
                session += 1
            }
        }
        return points
    }
}

// MARK: - Shared line chart component

struct ExerciseLineChart: View {
    let history: [ExerciseHistoryPoint]
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
                y: .value("Max Weight", point.maxWeight)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(lineColor)

            AreaMark(
                x: .value("Session", point.session),
                y: .value("Max Weight", point.maxWeight)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(fillColor)

            PointMark(
                x: .value("Session", point.session),
                y: .value("Max Weight", point.maxWeight)
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
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(isLight ? Color(white: 0.75) : Color(white: 0.3))
                AxisValueLabel().foregroundStyle(axisColor)
            }
        }
    }
}

// MARK: - Exercises list

struct ExercisesListView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.current }

    private var exercises: [ExerciseSummary] {
        var counts: [String: Int] = [:]
        for workout in store.completedWorkouts {
            for exercise in workout.exercises {
                counts[exercise.name, default: 0] += 1
            }
        }
        return counts.map { ExerciseSummary(id: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        ZStack {
            theme.primaryColor.ignoresSafeArea()
            List(exercises) { item in
                NavigationLink(destination: ExerciseProgressView(exerciseName: item.id)) {
                    HStack {
                        Text(item.id).foregroundColor(theme.rowText)
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
    let exerciseName: String
    private var theme: AppTheme { themeManager.current }

    private var history: [ExerciseHistoryPoint] {
        var points: [ExerciseHistoryPoint] = []
        let sorted = store.completedWorkouts.sorted { $0.date < $1.date }
        var session = 1
        for workout in sorted {
            for exercise in workout.exercises where exercise.name == exerciseName && !exercise.logs.isEmpty {
                let maxWeight = exercise.logs.map { $0.weight }.max() ?? 0
                points.append(ExerciseHistoryPoint(date: workout.date, maxWeight: maxWeight, session: session))
                session += 1
            }
        }
        return points
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
                            Text("Max Weight Over Time")
                                .font(.custom("ChalkboardSE-Regular", size: 14))
                                .foregroundColor(theme.onPrimaryText.opacity(0.7))
                            ExerciseLineChart(history: history, theme: theme, height: 220)
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
                                Text(String(format: "%.0f lbs", point.maxWeight))
                                    .foregroundColor(theme.rowText)
                                    .frame(width: 72, alignment: .trailing)
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
            List(store.completedWorkouts) { workout in
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
