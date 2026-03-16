import Foundation

struct Workout: Identifiable, Codable {
    var id = UUID()
    var name: String
    var focus: String
    var exercises: [Exercise]
    var isCompleted: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, focus, exercises, isCompleted
    }

    init(id: UUID = UUID(), name: String, focus: String, exercises: [Exercise], isCompleted: Bool = false) {
        self.id = id; self.name = name; self.focus = focus
        self.exercises = exercises; self.isCompleted = isCompleted
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self,       forKey: .id)
        name        = try c.decode(String.self,     forKey: .name)
        focus       = try c.decode(String.self,     forKey: .focus)
        exercises   = try c.decode([Exercise].self, forKey: .exercises)
        isCompleted = (try? c.decode(Bool.self,     forKey: .isCompleted)) ?? false
    }
}
