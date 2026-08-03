# Healy Health TODO

Last updated: 2026-08-02

This is the actionable backlog for `ROADMAP.md`. Work top-to-bottom within the active phase unless a user request changes the priority.

Priority legend:

- P0: crash, data loss, or state-corruption risk; address before broader feature work.
- P1: important correctness or core-flow gap; address before beta release.
- P2: usability, maintainability, or polish work.

## Phase 1 — Data safety and crash prevention

- [x] **HH-100 (P0) Add automated test targets and test seams.** Added the `Healy HealthTests` unit-test target, injected store storage/defaults dependencies, and covered temporary-directory persistence without touching live app data. UI tests are deferred because no current critical flow requires UI-only coverage.
  - Acceptance: tests can create fresh stores, run mutations, and verify encoded data deterministically.

- [x] **HH-101 (P0) Make deletion safe and repair active state.** Replaced offset-by-offset deletion with store-owned ID deletion. Deleting an active routine clears both IDs; deleting the active workout clears its workout ID. Regression tests cover single and multi-routine deletion and active-workout deletion.
  - Acceptance: delete IDs or remove offsets in one mutation; deleting an active routine clears both IDs; deleting the active workout clears its ID; tests cover single and multi-delete.

- [ ] **HH-102 (P0) Harden persistence.** `RoutineStore` and `ExerciseManager` suppress encode/write/read errors with `try?`; routine/history saves share one debounce, noncritical mutations rely on a one-second delayed save, and writes are not atomic.
  - Acceptance: atomic writes, explicit error propagation/state, separate intent where appropriate, and a scene background/termination flush; failures are visible without destroying the last good file.

- [ ] **HH-103 (P0) Validate and own the rest-timer lifecycle.** Custom duration accepts zero, negative, non-finite, and impractically large values before creating `UNTimeIntervalNotificationTrigger`. Scheduling errors are ignored, notification permission is requested at launch without context, and leaving via the navigation bar can orphan a pending timer while the view state is discarded.
  - Acceptance: bounded positive duration validation, scheduling completion handling, contextual permission flow, and documented/tested cancel-or-resume behavior for back navigation and relaunch.

- [ ] **HH-104 (P0) Make imports validated and transactional.** Imports do not reject unsupported schema versions, duplicate identifiers, invalid values, or active IDs that do not exist in imported routines. Multiple singleton states are mutated before persistence success is known.
  - Acceptance: decode into a candidate, validate the full graph, create a recoverable backup, commit all state or none, sort history, repair references, and show a specific error.

- [ ] **HH-105 (P0) Make workout completion idempotent and current-state based.** `finishWorkout` accepts value snapshots rather than resolving the current routine/workout by ID, can create another history item if invoked twice, and allows completion with no confirmation when planned exercises have no logs.
  - Acceptance: resolve by IDs inside the store, reject already-completed/missing workouts, disable repeated submission, and confirm or clearly explain skipped/unlogged work.

- [ ] **HH-106 (P1) Apply consistent domain validation.** Configure/edit/custom forms accept zero or negative set counts, negative/non-finite weights, and whitespace-only or untrimmed values in some paths. Set logging accepts negative weight and zero/negative reps.
  - Acceptance: shared validation rules require sensible set/repetition/weight values, trim names and reps, provide inline errors, and have boundary tests.

- [ ] **HH-107 (P1) Repair state after load/migration.** `loadActiveState` trusts stored UUIDs without checking that the routine contains the workout. Migration is marked complete even when legacy reads fail silently.
  - Acceptance: active references are normalized after every load/migration; migration outcome and errors are distinguishable and tested with legacy fixtures.

## Phase 2 — Core workout experience

- [ ] **HH-201 (P1) Finish custom exercise library wiring.** `ExerciseManager.addExercise` is unused; the custom-exercise UI checks library duplicates but adds only to one workout, so a new custom exercise is not available for reuse. Decide whether “Custom” means reusable or one-off and make the UI/data behavior match.

- [ ] **HH-202 (P1) Allow set correction.** Add edit/delete controls for logged sets, recalculate completion presentation, and persist changes immediately. Confirm destructive history edits where appropriate.

- [ ] **HH-203 (P1) Persist active session/timer state.** Store workout start time and rest-timer end time outside view-local `@State`, then restore or explicitly cancel them after navigation/relaunch.

- [ ] **HH-204 (P1) Add explicit abandon/reset flows.** Let users abandon a workout or routine with clear choices about partial logs. Do not rely on starting another routine to implicitly replace the active context.

- [ ] **HH-205 (P2) Add reordering.** Support stable reordering of routines, workouts, and exercises and persist the new order.

- [ ] **HH-206 (P2) Improve editing consistency.** Allow exercise category changes, define duplicate-name behavior, trim routine/workout names, and disable invalid alert actions before submission.

## Phase 3 — History, analytics, and data management

- [ ] **HH-301 (P1) Make session counts consistent.** `ExercisesListView` counts every planned exercise in a completed workout, including exercises with no logs, while the top chart counts only logged exercises. Define “trained/session” once and share the aggregation logic.

- [ ] **HH-302 (P1) Add stable exercise identity.** Analytics currently group by exact display name; renames split progress and unrelated same-name movements merge. Add a stable template/exercise identity with a backward-compatible migration.

- [ ] **HH-303 (P1) Make history ordering deterministic.** The UI assumes `completedWorkouts.first` is latest and renders stored order directly. Sort on load/import and use explicit sorted views as a defensive measure.

- [ ] **HH-304 (P1) Add safe history correction/deletion.** Include confirmations, immediate persistence, and analytics refresh.

- [ ] **HH-305 (P1) Strengthen export compatibility.** Reject future unsupported schemas, document supported versions, add round-trip and legacy fixture tests, and include any newly persisted session/preferences data.

- [ ] **HH-306 (P2) Correct history metadata and version display.** Store/show routine name separately from workout name, and read marketing/build versions from `Bundle` instead of hard-coding `1.0 (Beta)`.

- [ ] **HH-307 (P2) Make chart behavior deterministic and honest.** Add tie-breaking for “Most Trained,” consolidate duplicate exercise entries within one workout session, and consider linear interpolation to avoid Catmull-Rom visual overshoot.

## Phase 4 — Accessibility and polish

- [ ] **HH-401 (P1) Audit Dynamic Type.** Replace fixed-size typography where it clips and test all core screens at accessibility sizes.

- [ ] **HH-402 (P1) Add VoiceOver semantics.** Label chart controls, workout state, icon-only status, timer controls, and grouped rows; verify logical focus order.

- [ ] **HH-403 (P1) Audit theme contrast.** Measure primary, secondary, disabled, and chart colors across every theme rather than relying on visual inspection.

- [ ] **HH-404 (P2) Test adaptive layouts.** Check small iPhone, iPad, landscape, keyboard presentation, and the four-button timer preset row for clipping or crowded targets.

- [ ] **HH-405 (P2) Improve states and copy.** Add useful actions to empty states, surface validation/save errors, and make destructive actions visually explicit.

- [ ] **HH-406 (P2) Prepare localization and unit preferences.** Move user-facing strings to a string catalog and plan lb/kg formatting without storing formatted strings.

## Phase 5 — Release readiness

- [ ] **HH-501 (P1) Add CI build/test automation** for a clean checkout and a pinned supported Xcode/iOS environment.

- [ ] **HH-502 (P1) Clean repository metadata.** Add an appropriate `.gitignore` and stop tracking `.DS_Store`, `xcuserdata`, and `UserInterfaceState.xcuserstate` without touching user source changes.

- [ ] **HH-503 (P1) Run the release regression matrix.** Cover fresh install, upgrade/migration, import/export, interrupted saves, notification denied/allowed, background timer, device rotation, and supported iOS versions.

- [ ] **HH-504 (P1) Finalize shipping metadata.** Set marketing/build versions, verify icon light/dark/tinted variants, prepare screenshots/copy/support and privacy links, and validate signing/archive settings.

- [ ] **HH-505 (P2) Decide diagnostics strategy.** Prefer privacy-conscious first-party logging; obtain explicit approval before adding a third-party crash or analytics SDK.

## Current baseline notes

- The project contains the `Healy Health` application target and the `Healy HealthTests` XCTest target.
- App and test sources type-check passed on 2026-08-02; XCTest execution remains unverified in the terminal environment.
- Terminal `xcodebuild build-for-testing` could not finish because its CoreSimulator service reported no available simulator runtimes during asset compilation. The user reports that their interactive Xcode instance successfully built and installed the app in an iPhone simulator.
- The git root is the parent `Fitness App` directory; this app lives in its `Healy Health` subdirectory.
- Pre-existing tracked machine files were already dirty during the audit and were not modified by the audit.
