import SwiftUI
import Charts

struct SummaryView: View {
    @EnvironmentObject var store: RoutineStore
    
    // Fix #6: Cached recent exercises instead of computed on every render
    @State private var recentExercises: [ExerciseLogData] = []
    
    private func computeRecentExercises() -> [ExerciseLogData] {
        var results: [ExerciseLogData] = []
        var count = 0
        
        for workout in store.completedWorkouts {
            for exercise in workout.exercises where !exercise.logs.isEmpty {
                let maxWeight = exercise.logs.map { $0.weight }.max() ?? 0
                let totalVolume = exercise.logs.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
                
                results.append(ExerciseLogData(
                    id: UUID(),
                    name: exercise.name,
                    date: workout.date,
                    maxWeight: maxWeight,
                    totalVolume: totalVolume
                ))
                
                count += 1
                if count >= 3 { return results.reversed() }
            }
        }
        return results.reversed()
    }
    
    var body: some View {
        ZStack {
            Color.blue.edgesIgnoringSafeArea(.all)
            
            VStack {
                if store.completedWorkouts.isEmpty {
                    Text("No workouts completed yet.")
                        .foregroundColor(.white)
                        .padding()
                } else {
                    List {
                        if !recentExercises.isEmpty {
                            Section(header: Text("Recent Highlights").foregroundColor(.white)) {
                                VStack(alignment: .leading) {
                                    Text("Max Weight - Last 3 Exercises")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .padding(.bottom, 4)
                                    
                                    Chart(recentExercises) { data in
                                        BarMark(
                                            x: .value("Exercise", data.name),
                                            y: .value("Weight (lbs)", data.maxWeight)
                                        )
                                        .foregroundStyle(Color.blue.gradient)
                                        .annotation(position: .top) {
                                            Text(String(format: "%.0f", data.maxWeight))
                                                .font(.caption2)
                                                .foregroundColor(.black)
                                        }
                                    }
                                    .frame(height: 150)
                                    .chartXAxis {
                                        AxisMarks { _ in
                                            AxisValueLabel()
                                                .foregroundStyle(Color.black)
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks { _ in
                                            AxisGridLine()
                                            AxisValueLabel()
                                                .foregroundStyle(Color.black)
                                        }
                                    }
                                }
                                .padding()
                                .listRowBackground(Color.white)
                            }
                        }
                        
                        Section(header: Text("Workout History").foregroundColor(.white)) {
                            ForEach(store.completedWorkouts) { workout in
                                NavigationLink(destination: SummaryDetailView(workout: workout)) {
                                    VStack(alignment: .leading) {
                                        Text(workout.date.formatted(date: .long, time: .shortened))
                                            .font(.headline)
                                            .foregroundColor(.black)
                                        Text(workout.dayName)
                                            .font(.subheadline)
                                            .foregroundColor(Color(white: 0.3))
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(Color.white)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Summary")
        }
        .onAppear {
            recentExercises = computeRecentExercises()
        }
    }
}

struct ExerciseLogData: Identifiable {
    let id: UUID
    let name: String
    let date: Date
    let maxWeight: Double
    let totalVolume: Double
}

struct SummaryDetailView: View {
    let workout: CompletedWorkout
    
    var body: some View {
        ZStack {
            Color.blue.ignoresSafeArea()
            
            List {
                Section(header: Text("Workout Info").foregroundColor(.white)) {
                    HStack {
                        Text("Routine / Workout")
                        Spacer()
                        Text(workout.dayName)
                            .foregroundColor(.gray)
                    }
                    .listRowBackground(Color.white)
                    
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(workout.date.formatted(date: .long, time: .shortened))
                            .foregroundColor(.gray)
                    }
                    .listRowBackground(Color.white)
                }
                
                Section(header: Text("Exercises").foregroundColor(.white)) {
                    if workout.exercises.isEmpty {
                        Text("No exercises recorded.")
                            .listRowBackground(Color.white)
                            .foregroundColor(.gray)
                    } else {
                        ForEach(workout.exercises) { exercise in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(exercise.name)
                                    .font(.headline)
                                    .foregroundColor(.black)
                                
                                if exercise.logs.isEmpty {
                                    Text("No sets logged")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                } else {
                                    ForEach(Array(exercise.logs.enumerated()), id: \.element.id) { index, log in
                                        HStack {
                                            Text("Set \(index + 1)")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text("\(log.reps) reps @ \(String(format: "%.1f", log.weight)) lbs")
                                                .font(.subheadline)
                                                .foregroundColor(.black)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color.white)
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
