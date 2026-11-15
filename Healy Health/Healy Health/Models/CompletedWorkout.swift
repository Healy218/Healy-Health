import Foundation

struct CompletedWorkout: Identifiable, Codable {
    var id = UUID()
    var date: Date
    /// The routine name at the time this workout was completed. Older history files did not
    /// retain this value, so it remains optional for a truthful legacy display.
    var routineName: String?
    var workoutName: String
    var focus: String
    var exercises: [Exercise]
    var routineId: UUID?
    var workoutId: UUID?

    /// Compatibility accessor for callers and legacy fixtures that used the old name for the
    /// workout portion of a completed-history record.
    var dayName: String { workoutName }

    enum CodingKeys: String, CodingKey {
        case id, date, routineName, workoutName, dayName, focus, exercises, routineId, workoutId
    }

    init(
        id: UUID = UUID(),
        date: Date,
        routineName: String? = nil,
        workoutName: String,
        focus: String,
        exercises: [Exercise],
        routineId: UUID?,
        workoutId: UUID?
    ) {
        self.id = id
        self.date = date
        self.routineName = routineName
        self.workoutName = workoutName
        self.focus = focus
        self.exercises = exercises
        self.routineId = routineId
        self.workoutId = workoutId
    }

    /// Preserves source compatibility while history created before HH-306 is upgraded on its
    /// next save. New production code should use `routineName` and `workoutName`.
    init(
        id: UUID = UUID(),
        date: Date,
        dayName: String,
        focus: String,
        exercises: [Exercise],
        routineId: UUID?,
        workoutId: UUID?
    ) {
        self.init(
            id: id,
            date: date,
            workoutName: dayName,
            focus: focus,
            exercises: exercises,
            routineId: routineId,
            workoutId: workoutId
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        routineName = try container.decodeIfPresent(String.self, forKey: .routineName)
        workoutName = try container.decodeIfPresent(String.self, forKey: .workoutName)
            ?? container.decode(String.self, forKey: .dayName)
        focus = try container.decode(String.self, forKey: .focus)
        exercises = try container.decode([Exercise].self, forKey: .exercises)
        routineId = try container.decodeIfPresent(UUID.self, forKey: .routineId)
        workoutId = try container.decodeIfPresent(UUID.self, forKey: .workoutId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(routineName, forKey: .routineName)
        try container.encode(workoutName, forKey: .workoutName)
        try container.encode(focus, forKey: .focus)
        try container.encode(exercises, forKey: .exercises)
        try container.encodeIfPresent(routineId, forKey: .routineId)
        try container.encodeIfPresent(workoutId, forKey: .workoutId)
    }

    /// Date ties are resolved by UUID so persisted and presented history order never depends on
    /// JSON array order or dictionary iteration.
    nonisolated static func newestFirst(_ lhs: CompletedWorkout, _ rhs: CompletedWorkout) -> Bool {
        if lhs.date != rhs.date { return lhs.date > rhs.date }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
