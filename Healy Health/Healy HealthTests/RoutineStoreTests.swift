import XCTest
@testable import Healy_Health

@MainActor
final class RoutineStoreTests: XCTestCase {
    private var storageDirectory: URL!
    private var defaults: UserDefaults!
    private var defaultsSuiteName = ""

    override func setUpWithError() throws {
        storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoutineStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)

        defaultsSuiteName = "RoutineStoreTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    override func tearDownWithError() throws {
        if let storageDirectory {
            try? FileManager.default.removeItem(at: storageDirectory)
        }
        if let defaults {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        storageDirectory = nil
        defaults = nil
        defaultsSuiteName = ""
    }

    func testFlushSavesRoutineDataToInjectedDirectory() throws {
        let routine = makeRoutine(name: "Strength")
        let store = makeEmptyStore()

        store.addRoutine(routine)
        store.flushSaves()

        let data = try Data(contentsOf: storageDirectory.appendingPathComponent("routines.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let savedRoutines = try decoder.decode([Routine].self, from: data)

        XCTAssertEqual(savedRoutines.map(\.id), [routine.id])
        XCTAssertEqual(savedRoutines.first?.name, "Strength")
    }

    func testNewStoreLoadsDataFromItsInjectedDirectory() {
        let routine = makeRoutine(name: "Strength")
        let store = makeEmptyStore()
        store.addRoutine(routine)
        store.flushSaves()
        defaults.set(true, forKey: "hasMigratedToRoutines")

        let reloadedStore = RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .normal
        )

        XCTAssertEqual(reloadedStore.routines.map(\.id), [routine.id])
    }

    func testRoutineSaveDoesNotWriteHistory() {
        var writtenFileNames: [String] = []
        let store = RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .empty,
            saveDebounceInterval: 0,
            dataWriter: { data, url in
                writtenFileNames.append(url.lastPathComponent)
                try data.write(to: url, options: .atomic)
            }
        )

        store.routines = [makeRoutine(name: "Strength")]
        store.saveRoutines()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        XCTAssertEqual(writtenFileNames, ["routines.json"])
    }

    func testFailedRoutineSavePreservesTheLastGoodFileAndPublishesAnError() throws {
        let original = makeRoutine(name: "Original")
        let initialStore = makeEmptyStore()
        initialStore.routines = [original]
        XCTAssertTrue(initialStore.flushSaves())
        let originalData = try Data(contentsOf: storageDirectory.appendingPathComponent("routines.json"))

        let failedStore = RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .empty,
            dataWriter: { data, url in
                if url.lastPathComponent == "routines.json" {
                    throw CocoaError(.fileWriteNoPermission)
                }
                try data.write(to: url, options: .atomic)
            }
        )
        failedStore.routines = [makeRoutine(name: "Replacement")]

        XCTAssertFalse(failedStore.flushSaves())
        XCTAssertEqual(
            try Data(contentsOf: storageDirectory.appendingPathComponent("routines.json")),
            originalData
        )
        XCTAssertEqual(failedStore.persistenceError?.resource, .routines)
        XCTAssertEqual(failedStore.persistenceError?.operation, .save)
    }

    func testCorruptRoutineFileIsReportedAndNeverReplacedWithDefaults() throws {
        defaults.set(true, forKey: "hasMigratedToRoutines")
        let routinesURL = storageDirectory.appendingPathComponent("routines.json")
        try Data("not valid JSON".utf8).write(to: routinesURL, options: .atomic)

        let store = RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .normal
        )

        XCTAssertTrue(store.routines.isEmpty)
        XCTAssertEqual(store.persistenceError?.resource, .routines)
        XCTAssertEqual(store.persistenceError?.operation, .load)
        XCTAssertEqual(try Data(contentsOf: routinesURL), Data("not valid JSON".utf8))
    }

    func testDeletingOneRoutinePreservesAnUnrelatedActiveRoutine() {
        let first = makeRoutine(name: "First")
        let second = makeRoutine(name: "Second")
        let store = makeEmptyStore()
        store.routines = [first, second]
        store.activeRoutineId = second.id
        store.activeWorkoutId = second.workouts[0].id

        store.deleteRoutines(ids: [first.id])

        XCTAssertEqual(store.routines.map(\.id), [second.id])
        XCTAssertEqual(store.activeRoutineId, second.id)
        XCTAssertEqual(store.activeWorkoutId, second.workouts[0].id)
    }

    func testMultipleRoutineDeletionUsesStableIDsAndClearsActiveState() {
        let first = makeRoutine(name: "First")
        let second = makeRoutine(name: "Second")
        let third = makeRoutine(name: "Third")
        let store = makeEmptyStore()
        store.routines = [first, second, third]
        store.activeRoutineId = second.id
        store.activeWorkoutId = second.workouts[0].id

        store.deleteRoutines(ids: [first.id, second.id])

        XCTAssertEqual(store.routines.map(\.id), [third.id])
        XCTAssertNil(store.activeRoutineId)
        XCTAssertNil(store.activeWorkoutId)
    }

    func testDeletingActiveWorkoutKeepsItsRoutineAndClearsOnlyWorkoutState() {
        let routine = makeRoutine(name: "Strength")
        let secondWorkout = Workout(name: "Cardio", focus: "Conditioning", exercises: [])
        let store = makeEmptyStore()
        store.routines = [routine]
        store.routines[0].workouts.append(secondWorkout)
        store.activeRoutineId = routine.id
        store.activeWorkoutId = secondWorkout.id

        store.deleteWorkouts(routineId: routine.id, ids: [secondWorkout.id])

        XCTAssertEqual(store.routines[0].workouts.map(\.id), [routine.workouts[0].id])
        XCTAssertEqual(store.activeRoutineId, routine.id)
        XCTAssertNil(store.activeWorkoutId)
    }

    private func makeEmptyStore() -> RoutineStore {
        RoutineStore(
            documentsDirectory: storageDirectory,
            userDefaults: defaults,
            initialLoadBehavior: .empty
        )
    }

    private func makeRoutine(name: String) -> Routine {
        Routine(
            name: name,
            workouts: [Workout(name: "Workout", focus: "Focus", exercises: [])]
        )
    }
}
