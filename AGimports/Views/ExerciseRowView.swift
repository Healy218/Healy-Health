import SwiftUI

struct ExerciseRowView: View {
    @Binding var exercise: Exercise
    
    var body: some View {
        HStack {
            Button(action: {
                exercise.isCompleted.toggle()
            }) {
                Image(systemName: exercise.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(exercise.isCompleted ? .green : .gray)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle()) // Keeps the row clickable separately if needed
            
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.headline)
                    .strikethrough(exercise.isCompleted)
                    .foregroundColor(exercise.isCompleted ? .secondary : .primary)
                
                HStack {
                    Label("\(exercise.targetSets) sets", systemImage: "number")
                    Label(exercise.targetReps, systemImage: "repeat")
                    Label(exercise.weightDisplay, systemImage: "scalemass")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ExerciseRowView(exercise: .constant(Exercise(name: "Bench Press", targetSets: 4, targetReps: "8-10", currentWeight: 135.0)))
        .padding()
}
