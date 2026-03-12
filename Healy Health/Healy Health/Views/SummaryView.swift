import SwiftUI
import Charts

struct SummaryView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager

    @State private var recentExercises: [ExerciseLogData] = []
    private var theme: AppTheme { themeManager.current }

    var body: some View {
        ZStack {
            theme.primaryColor.edgesIgnoringSafeArea(.all)
            VStack {
                if store.completedWorkouts.isEmpty {
                    Text("No workouts completed yet.")
                        .foregroundColor(theme.onPrimaryText).padding()
                } else {
                    List {
                        if !recentExercises.isEmpty {
                            Section(header: Text("Recent Highlights").foregroundColor(theme.onPrimaryText)) {
                                VStack(alignment: .leading) {
                                    Text("Max Weight - Last 3 Exercises")
                                        .font(.caption).foregroundColor(theme.secondaryRowText).padding(.bottom, 4)
                                    Chart(recentExercises) { data in
                                        BarMark(x: .value("Exercise", data.name), y: .value("Weight (lbs)", data.maxWeight))
                                            .foregroundStyle(theme.accentColor.gradient)
                                            .annotation(position: .top) {
                                                Text(String(format: "%.0f", data.maxWeight))
                                                    .font(.caption2).foregroundColor(theme.rowText)
                                            }
                                    }
                                    .frame(height: 150)
                                    .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(theme.accentColor) } }
                                    .chartYAxis { AxisMarks { _ in AxisGridLine(); AxisValueLabel().foregroundStyle(theme.accentColor) } }
                                }
                                .padding()
                                .listRowBackground(theme.rowBackground)
                            }
                        }
                        Section(header: Text("Workout History").foregroundColor(theme.onPrimaryText)) {
                            ForEach(store.completedWorkouts) { workout in
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
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Summary")
        }
        .onAppear { recentExercises = computeRecentExercises() }
    }

    private func computeRecentExercises() -> [ExerciseLogData] {
        var results: [ExerciseLogData] = []
        var count = 0
        for workout in store.completedWorkouts {
            for exercise in workout.exercises where !exercise.logs.isEmpty {
                let maxWeight = exercise.logs.map { $0.weight }.max() ?? 0
                let totalVolume = exercise.logs.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
                results.append(ExerciseLogData(id: UUID(), name: exercise.name, date: workout.date, maxWeight: maxWeight, totalVolume: totalVolume))
                count += 1
                if count >= 3 { return results.reversed() }
            }
        }
        return results.reversed()
    }
}

struct ExerciseLogData: Identifiable {
    let id: UUID; let name: String; let date: Date; let maxWeight: Double; let totalVolume: Double
}

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
