import SwiftUI

struct ExerciseLibraryView: View {
    @State private var showCreateWorkout = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                
                Text("Build Your Routine")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
                
                Text("Create a custom workout and pick from our extensive library of exercises.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                
                Button(action: {
                    showCreateWorkout = true
                }) {
                    Text("Create Workout")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.blue.ignoresSafeArea())
            .navigationTitle("Exercises")
            // Navigation destination handles the push transition
            .navigationDestination(isPresented: $showCreateWorkout) {
                CreateWorkoutView()
            }
        }
    }
}

#Preview {
    ExerciseLibraryView()
}
