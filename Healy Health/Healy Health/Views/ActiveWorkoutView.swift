import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject var store: RoutineStore
    
    var body: some View {
        ZStack {
            Color.blue.edgesIgnoringSafeArea(.all)
            
            if let activeRoutine = store.activeRoutine {
                // A routine is selected
                if let activeWorkout = store.activeWorkout {
                    // A specific workout is active — show exercise mode
                    WorkoutSessionView(routine: activeRoutine, workout: activeWorkout)
                } else {
                    // Show the routine's list of workouts to pick from
                    RoutineWorkoutListView(routine: activeRoutine)
                }
            } else {
                // No routine selected at all
                VStack {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.5))
                        .padding()
                    
                    Text("No Active Routine")
                        .font(.custom("ChalkboardSE-Regular", size: 24))
                        .bold()
                        .foregroundColor(.white)
                    
                    Text("Swipe right on a routine in the Routines tab to start it here.")
                        .font(.custom("ChalkboardSE-Regular", size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Shows the list of workouts within the active routine
struct RoutineWorkoutListView: View {
    let routine: Routine
    @EnvironmentObject var store: RoutineStore
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text(routine.name)
                    .font(.custom("ChalkboardSE-Regular", size: 24))
                    .bold()
                    .foregroundColor(.white)
                
                Text("Select a workout to begin")
                    .font(.custom("ChalkboardSE-Regular", size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.2))
            
            if routine.workouts.isEmpty {
                Spacer()
                Text("This routine has no workouts yet.\nAdd some in the Routines tab.")
                    .font(.custom("ChalkboardSE-Regular", size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                List {
                    ForEach(routine.workouts) { workout in
                        Button {
                            store.activeWorkoutId = workout.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workout.name)
                                        .font(.custom("ChalkboardSE-Regular", size: 20))
                                        .foregroundColor(.black)
                                    Text(workout.focus)
                                        .font(.custom("ChalkboardSE-Regular", size: 14))
                                        .foregroundColor(Color(white: 0.3))
                                    Text("\(workout.exercises.count) exercises")
                                        .font(.custom("ChalkboardSE-Regular", size: 12))
                                        .foregroundColor(Color(white: 0.3))
                                }
                                Spacer()
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.white)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}

// MARK: - The active exercise session for a specific workout
struct WorkoutSessionView: View {
    let routine: Routine
    let workout: Workout
    @EnvironmentObject var store: RoutineStore
    
    // Get fresh data from the store
    private var currentWorkout: Workout? {
        store.activeRoutine?.workouts.first { $0.id == workout.id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Status
            VStack(spacing: 4) {
                Text(routine.name)
                    .font(.custom("ChalkboardSE-Regular", size: 16))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(workout.name)
                    .font(.custom("ChalkboardSE-Regular", size: 24))
                    .bold()
                    .foregroundColor(.white)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.2))
            
            if let currentWorkout = currentWorkout {
                if currentWorkout.exercises.isEmpty {
                    Spacer()
                    Text("No exercises added yet.")
                        .font(.custom("ChalkboardSE-Regular", size: 18))
                        .foregroundColor(.white)
                    Spacer()
                } else {
                    List {
                        ForEach(currentWorkout.exercises) { exercise in
                            NavigationLink(destination: ExerciseDetailView(
                                routineId: routine.id,
                                workoutId: currentWorkout.id,
                                exerciseId: exercise.id)) {
                                ActiveExerciseRowView(exercise: exercise)
                            }
                            .listRowBackground(Color.white)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            
            HStack(spacing: 12) {
                // Back to routine workout list
                Button(action: {
                    store.activeWorkoutId = nil
                }) {
                    Text("Back to Routine")
                        .font(.custom("ChalkboardSE-Regular", size: 16))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                }
                
                // Finish workout
                Button(action: {
                    store.finishWorkout(routine: routine, workout: workout)
                }) {
                    Text("Finish Workout")
                        .font(.custom("ChalkboardSE-Regular", size: 16))
                        .bold()
                        .foregroundColor(.blue)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

// A view for the row within the workout session
struct ActiveExerciseRowView: View {
    let exercise: Exercise
    
    var setsCompleted: Int {
        exercise.logs.count
    }
    
    var isFullyCompleted: Bool {
        exercise.isCompleted || (setsCompleted >= exercise.targetSets)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.custom("ChalkboardSE-Regular", size: 18))
                    .foregroundColor(.black)
                
                Text("\(setsCompleted)/\(exercise.targetSets) sets completed")
                    .font(.custom("ChalkboardSE-Regular", size: 14))
                    .foregroundColor(Color(white: 0.3))
            }
            Spacer()
            
            if isFullyCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
                    .font(.title2)
            }
        }
        .padding(.vertical, 8)
    }
}
