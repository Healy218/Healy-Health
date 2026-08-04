import Foundation

struct ExerciseHistoryPoint: Identifiable {
    let id: UUID
    let date: Date
    let totalVolume: Double
    let maxWeight: Double
    let estimatedOneRepMax: Double
    let session: Int
}

/// A logged exercise occurrence in a completed workout. An exercise is considered trained only
/// when the completed workout contains at least one logged set for it.
struct ExerciseTrainingSession: Identifiable {
    let id: UUID
    let trackingId: UUID
    let exerciseName: String
    let date: Date
    let totalVolume: Double
    let maxWeight: Double
    let estimatedOneRepMax: Double
}

struct ExerciseTrainingSummary: Identifiable, Equatable {
    let id: UUID
    let name: String
    let count: Int
}

/// Shared aggregation for exercise-history presentation. Keeping the trained-session definition
/// here prevents the summary chart and exercise list from drifting apart.
enum ExerciseAnalytics {
    static func trainedSessions(from completedWorkouts: [CompletedWorkout]) -> [ExerciseTrainingSession] {
        completedWorkouts.flatMap { workout in
            workout.exercises.compactMap { exercise in
                guard !exercise.logs.isEmpty else { return nil }

                return ExerciseTrainingSession(
                    id: workout.id,
                    trackingId: exercise.trackingId ?? exercise.id,
                    exerciseName: exercise.name,
                    date: workout.date,
                    totalVolume: exercise.totalVolume,
                    maxWeight: exercise.maxLoggedWeight,
                    estimatedOneRepMax: exercise.estimatedOneRepMax
                )
            }
        }
    }

    static func summaries(from sessions: [ExerciseTrainingSession]) -> [ExerciseTrainingSummary] {
        let grouped = Dictionary(grouping: sessions, by: \.trackingId)
        return grouped.map { trackingId, sessions in
            // Most-recent naming keeps the UI aligned when a library item has been renamed.
            let displayName = sessions.sorted {
                if $0.date != $1.date { return $0.date > $1.date }
                return $0.id.uuidString < $1.id.uuidString
            }.first?.exerciseName ?? "Exercise"
            return ExerciseTrainingSummary(id: trackingId, name: displayName, count: sessions.count)
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            return nameOrder == .orderedSame ? lhs.id.uuidString < rhs.id.uuidString : nameOrder == .orderedAscending
        }
    }

    static func history(
        for trackingId: UUID,
        from sessions: [ExerciseTrainingSession]
    ) -> [ExerciseHistoryPoint] {
        sessions
            .filter { $0.trackingId == trackingId }
            .sorted {
                if $0.date != $1.date { return $0.date < $1.date }
                return $0.id.uuidString < $1.id.uuidString
            }
            .enumerated()
            .map { index, session in
                ExerciseHistoryPoint(
                    id: session.id,
                    date: session.date,
                    totalVolume: session.totalVolume,
                    maxWeight: session.maxWeight,
                    estimatedOneRepMax: session.estimatedOneRepMax,
                    session: index + 1
                )
            }
    }
}

private extension Exercise {
    var totalVolume: Double {
        logs.reduce(0) { partialResult, log in
            partialResult + (log.weight * Double(log.reps))
        }
    }

    var maxLoggedWeight: Double {
        logs.map(\.weight).max() ?? 0
    }

    var estimatedOneRepMax: Double {
        logs.map { log in
            log.weight * (1 + (Double(log.reps) / 30.0))
        }
        .max() ?? 0
    }
}
