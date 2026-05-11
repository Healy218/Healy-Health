import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct AppExportData: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let routines: [Routine]
    let completedWorkouts: [CompletedWorkout]
    let exerciseLibrary: [ExerciseTemplate]
    let selectedTheme: AppTheme
    let activeRoutineId: UUID?
    let activeWorkoutId: UUID?
}

struct AppExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

final class ExportManager {
    static let shared = ExportManager()

    private init() {}

    func makeExportDocument() -> AppExportDocument? {
        guard let data = generateJSONData() else { return nil }
        return AppExportDocument(data: data)
    }

    func defaultExportFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return "HealyHealth_Export_\(formatter.string(from: Date()))"
    }

    func generateJSONData() -> Data? {
        let exportData = AppExportData(
            schemaVersion: 1,
            exportedAt: Date(),
            routines: RoutineStore.shared.routines,
            completedWorkouts: RoutineStore.shared.completedWorkouts,
            exerciseLibrary: ExerciseManager.shared.exercises,
            selectedTheme: ThemeManager.shared.current,
            activeRoutineId: RoutineStore.shared.activeRoutineId,
            activeWorkoutId: RoutineStore.shared.activeWorkoutId
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            return try encoder.encode(exportData)
        } catch {
            print("Failed to export data: \(error)")
            return nil
        }
    }

    func importJSONData(from url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        return importJSONData(from: data)
    }

    func importJSONData(from data: Data) -> Bool {
        guard let decoded = decodeExportData(from: data) else { return false }

        RoutineStore.shared.routines = decoded.routines
        RoutineStore.shared.completedWorkouts = decoded.completedWorkouts
        RoutineStore.shared.activeRoutineId = decoded.activeRoutineId
        RoutineStore.shared.activeWorkoutId = decoded.activeWorkoutId
        RoutineStore.shared.performSaveHistory()
        RoutineStore.shared.saveRoutines()

        ExerciseManager.shared.exercises = decoded.exerciseLibrary.sorted { $0.name < $1.name }
        ExerciseManager.shared.saveLibrary()

        ThemeManager.shared.current = decoded.selectedTheme

        return true
    }

    private func decodeExportData(from data: Data) -> AppExportData? {
        let iso8601Decoder = JSONDecoder()
        iso8601Decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? iso8601Decoder.decode(AppExportData.self, from: data) {
            return decoded
        }

        struct LegacyAppExportData: Codable {
            let routines: [Routine]
            let completedWorkouts: [CompletedWorkout]
        }

        if let decoded = try? iso8601Decoder.decode(LegacyAppExportData.self, from: data) {
            return AppExportData(
                schemaVersion: 0,
                exportedAt: Date(),
                routines: decoded.routines,
                completedWorkouts: decoded.completedWorkouts,
                exerciseLibrary: ExerciseManager.shared.exercises,
                selectedTheme: ThemeManager.shared.current,
                activeRoutineId: nil,
                activeWorkoutId: nil
            )
        }

        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode(AppExportData.self, from: data) {
            return decoded
        }
        if let decoded = try? decoder.decode(LegacyAppExportData.self, from: data) {
            return AppExportData(
                schemaVersion: 0,
                exportedAt: Date(),
                routines: decoded.routines,
                completedWorkouts: decoded.completedWorkouts,
                exerciseLibrary: ExerciseManager.shared.exercises,
                selectedTheme: ThemeManager.shared.current,
                activeRoutineId: nil,
                activeWorkoutId: nil
            )
        }

        return nil
    }
}
