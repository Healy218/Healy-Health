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

struct ImportBackup: Identifiable, Equatable {
    let url: URL
    let createdAt: Date

    var id: URL { url }
    var filename: String { url.deletingPathExtension().lastPathComponent }
}

enum ImportError: LocalizedError, Equatable {
    case unreadableFile
    case unsupportedSchema(Int)
    case invalidData(String)
    case backupFailed
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "The selected file could not be read or is not a Healy Health export."
        case .unsupportedSchema(let version):
            return "This export uses unsupported data version \(version)."
        case .invalidData(let reason):
            return "This export contains invalid data: \(reason)"
        case .backupFailed:
            return "Your current data could not be backed up, so nothing was imported."
        case .persistenceFailed:
            return "The import could not be saved. Your previous data remains available in the pre-import backup."
        }
    }
}

enum AppImportValidator {
    static let currentSchemaVersion = 2

    static func normalizedCandidate(from export: AppExportData) throws -> AppExportData {
        guard (0...currentSchemaVersion).contains(export.schemaVersion) else {
            throw ImportError.unsupportedSchema(export.schemaVersion)
        }
        let migration = ExerciseIdentityMigration.migrated(
            routines: export.routines,
            completedWorkouts: export.completedWorkouts,
            templates: export.exerciseLibrary
        )
        try validateRoutines(migration.routines)
        try validateCompletedWorkouts(migration.completedWorkouts)
        try validateTemplates(export.exerciseLibrary)
        try validateActiveReferences(
            routines: export.routines,
            activeRoutineId: export.activeRoutineId,
            activeWorkoutId: export.activeWorkoutId
        )

        return AppExportData(
            schemaVersion: export.schemaVersion,
            exportedAt: export.exportedAt,
            routines: migration.routines,
            completedWorkouts: migration.completedWorkouts.sorted(by: CompletedWorkout.newestFirst),
            exerciseLibrary: export.exerciseLibrary.sorted(by: templateNameAscending),
            selectedTheme: export.selectedTheme,
            activeRoutineId: export.activeRoutineId,
            activeWorkoutId: export.activeWorkoutId
        )
    }

    private static func validateRoutines(_ routines: [Routine]) throws {
        try requireUnique(routines.map(\.id), named: "routine")
        var workoutIDs: [UUID] = []
        var exerciseIDs: [UUID] = []
        var logIDs: [UUID] = []
        for routine in routines {
            try requireText(routine.name, named: "routine name")
            guard routine.dateCreated.timeIntervalSinceReferenceDate.isFinite else {
                throw ImportError.invalidData("a routine has an invalid creation date")
            }
            for workout in routine.workouts {
                workoutIDs.append(workout.id)
                try requireText(workout.name, named: "workout name")
                try requireText(workout.focus, named: "workout focus")
                for exercise in workout.exercises {
                    exerciseIDs.append(exercise.id)
                    try validate(exercise)
                    logIDs.append(contentsOf: exercise.logs.map(\.id))
                }
            }
        }
        try requireUnique(workoutIDs, named: "workout")
        try requireUnique(exerciseIDs, named: "exercise")
        try requireUnique(logIDs, named: "set log")
    }

    private static func validateCompletedWorkouts(_ workouts: [CompletedWorkout]) throws {
        try requireUnique(workouts.map(\.id), named: "completed workout")
        for workout in workouts {
            guard workout.date.timeIntervalSinceReferenceDate.isFinite else {
                throw ImportError.invalidData("a completed workout has an invalid date")
            }
            try requireText(workout.dayName, named: "completed workout name")
            try requireText(workout.focus, named: "completed workout focus")
            // Completed workouts are immutable snapshots. A planned exercise can legitimately
            // appear in multiple completed sessions with the same original ID, so uniqueness is
            // required within one snapshot—not across the entire history collection.
            try requireUnique(workout.exercises.map(\.id), named: "history exercise")
            for exercise in workout.exercises {
                try validate(exercise)
                try requireUnique(exercise.logs.map(\.id), named: "history set log")
            }
        }
    }

    private static func validateTemplates(_ templates: [ExerciseTemplate]) throws {
        try requireUnique(templates.map(\.id), named: "exercise library item")
        for template in templates {
            try requireText(template.name, named: "exercise library item name")
            try requireText(template.primaryMuscleGroup, named: "exercise library muscle group")
            try requireText(template.equipmentType, named: "exercise library equipment")
        }
    }

    private static func validateActiveReferences(routines: [Routine], activeRoutineId: UUID?, activeWorkoutId: UUID?) throws {
        guard let activeRoutineId else {
            guard activeWorkoutId == nil else {
                throw ImportError.invalidData("an active workout is missing its active routine")
            }
            return
        }
        guard let routine = routines.first(where: { $0.id == activeRoutineId }) else {
            throw ImportError.invalidData("the active routine does not exist")
        }
        if let activeWorkoutId, !routine.workouts.contains(where: { $0.id == activeWorkoutId }) {
            throw ImportError.invalidData("the active workout does not belong to the active routine")
        }
    }

    private static func validate(_ exercise: Exercise) throws {
        do {
            _ = try ExerciseDomainValidation.configuration(
                name: exercise.name,
                targetSets: exercise.targetSets,
                targetReps: exercise.targetReps,
                currentWeight: exercise.currentWeight
            )
        } catch let error as ExerciseValidationError {
            throw ImportError.invalidData(importErrorDescription(for: error, isSetLog: false))
        }

        for log in exercise.logs {
            do {
                _ = try ExerciseDomainValidation.setLog(weight: log.weight, reps: log.reps)
            } catch let error as ExerciseValidationError {
                throw ImportError.invalidData(importErrorDescription(for: error, isSetLog: true))
            }
            guard log.completedDate.timeIntervalSinceReferenceDate.isFinite else {
                throw ImportError.invalidData("a set log has an invalid date")
            }
        }
    }

    private static func importErrorDescription(for error: ExerciseValidationError, isSetLog: Bool) -> String {
        switch error {
        case .emptyName:
            return "an exercise name is empty"
        case .invalidTargetSets:
            return "an exercise has zero or negative target sets"
        case .emptyTargetReps:
            return "an exercise target reps is empty"
        case .invalidWeight:
            return isSetLog ? "a set log has an invalid weight" : "an exercise has an invalid weight"
        case .invalidLogReps:
            return "a set log has zero or negative reps"
        }
    }

    private static func requireText(_ value: String, named name: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.invalidData("a \(name) is empty")
        }
    }

    private static func requireUnique(_ ids: [UUID], named name: String) throws {
        guard Set(ids).count == ids.count else {
            throw ImportError.invalidData("duplicate \(name) identifiers")
        }
    }

    private static func templateNameAscending(_ lhs: ExerciseTemplate, _ rhs: ExerciseTemplate) -> Bool {
        let result = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        return result == .orderedSame ? lhs.id.uuidString < rhs.id.uuidString : result == .orderedAscending
    }
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
            schemaVersion: AppImportValidator.currentSchemaVersion,
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

    func importJSONData(from url: URL) -> Result<Void, ImportError> {
        guard let data = try? Data(contentsOf: url) else { return .failure(.unreadableFile) }
        return importJSONData(from: data)
    }

    /// Restores a retained pre-import backup through the same validation and transactional write
    /// path as a user-selected export. The current app state is backed up first, so a restore can
    /// itself be recovered if the wrong snapshot is chosen.
    func restoreImportBackup(_ backup: ImportBackup) -> Result<Void, ImportError> {
        importJSONData(from: backup.url)
    }

    /// Returns only app-created pre-import snapshots, newest first. Discovery is deliberately
    /// read-only; no backup is deleted or changed merely by opening the recovery screen.
    func importBackups(in directory: URL) -> [ImportBackup] {
        let backupsDirectory = directory.appendingPathComponent("Import Backups", isDirectory: true)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: backupsDirectory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.compactMap { url in
            guard url.pathExtension.lowercased() == "json",
                  url.lastPathComponent.hasPrefix("HealyHealth_PreImport_") else {
                return nil
            }
            let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            return ImportBackup(
                url: url,
                createdAt: values?.creationDate ?? values?.contentModificationDate ?? .distantPast
            )
        }
        .sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            return lhs.filename > rhs.filename
        }
    }

    func importJSONData(from data: Data) -> Result<Void, ImportError> {
        guard let decoded = decodedExportData(from: data) else { return .failure(.unreadableFile) }

        let candidate: AppExportData
        do {
            candidate = try AppImportValidator.normalizedCandidate(from: decoded)
        } catch let error as ImportError {
            return .failure(error)
        } catch {
            return .failure(.invalidData("validation could not be completed"))
        }

        let store = RoutineStore.shared
        let library = ExerciseManager.shared
        let previous = AppExportData(
            schemaVersion: AppImportValidator.currentSchemaVersion,
            exportedAt: Date(),
            routines: store.routines,
            completedWorkouts: store.completedWorkouts,
            exerciseLibrary: library.exercises,
            selectedTheme: ThemeManager.shared.current,
            activeRoutineId: store.activeRoutineId,
            activeWorkoutId: store.activeWorkoutId
        )

        guard createBackup(previous, in: store.persistenceDirectory) else {
            return .failure(.backupFailed)
        }

        do {
            try store.persistImportCandidate(
                routines: candidate.routines,
                completedWorkouts: candidate.completedWorkouts
            )
            try library.persistImportCandidate(candidate.exerciseLibrary)
        } catch {
            // Each write is atomic. Restore any earlier candidate files before returning, and
            // retain the pre-import snapshot for recovery if a restore write also fails.
            try? store.persistImportCandidate(
                routines: previous.routines,
                completedWorkouts: previous.completedWorkouts
            )
            try? library.persistImportCandidate(previous.exerciseLibrary)
            return .failure(.persistenceFailed)
        }

        store.applyImportedState(
            routines: candidate.routines,
            completedWorkouts: candidate.completedWorkouts,
            activeRoutineId: candidate.activeRoutineId,
            activeWorkoutId: candidate.activeWorkoutId
        )
        library.applyImportedLibrary(candidate.exerciseLibrary)
        ThemeManager.shared.current = candidate.selectedTheme
        return .success(())
    }

    private func createBackup(_ export: AppExportData, in directory: URL) -> Bool {
        let backupsDirectory = directory.appendingPathComponent("Import Backups", isDirectory: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmmss_SSS"
        let filename = "HealyHealth_PreImport_\(formatter.string(from: Date())).json"

        do {
            try FileManager.default.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(export)
            try data.write(to: backupsDirectory.appendingPathComponent(filename), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    func decodedExportData(from data: Data) -> AppExportData? {
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
