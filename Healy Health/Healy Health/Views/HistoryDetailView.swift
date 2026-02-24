import SwiftUI

struct HistoryDetailView: View {
    let workout: CompletedWorkout
    
    var body: some View {
        List {
            ForEach(workout.exercises) { exercise in
                ExerciseHistorySection(exercise: exercise)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.blue.ignoresSafeArea())
        .navigationTitle(workout.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ExerciseHistorySection: View {
    let exercise: Exercise
    
    var body: some View {
        Section(header: Text(exercise.name).foregroundColor(.white)) {
            if exercise.logs.isEmpty {
                Text("No logs recorded")
                    .italic()
                    .foregroundColor(.gray)
                    .listRowBackground(Color.white)
            } else {
                // improved enumeration to get index
                ForEach(Array(exercise.logs.enumerated()), id: \.element.id) { index, log in
                    HStack {
                        Text("Set \(index + 1)")
                            .foregroundColor(.black)
                        Spacer()
                        Text("\(log.reps) reps @ \(log.weightDisplay)")
                            .foregroundColor(.black)
                    }
                    .listRowBackground(Color.white)
                }
            }
        }
    }
}
