# Healy Health TODO

Last updated: 2026-08-12

This is the actionable backlog for `ROADMAP.md`. Work top-to-bottom within the active phase unless a user request changes the priority.

Priority legend:

- P0: crash, data loss, or state-corruption risk; address before broader feature work.
- P1: important correctness or core-flow gap; address before beta release.
- P2: usability, maintainability, or polish work.

## Phase 1 — Data safety and crash prevention

- [x] **HH-100 (P0) Add automated test targets and test seams.** Added the `Healy HealthTests` unit-test target, injected store storage/defaults dependencies, and covered temporary-directory persistence without touching live app data. The shared Xcode scheme now includes the test bundle; all 40 tests passed on the iPhone 17 Pro Max iOS 26.5 simulator. UI tests are deferred because no current critical flow requires UI-only coverage.
  - Acceptance: tests can create fresh stores, run mutations, verify encoded data deterministically, and execute from the shared scheme on the supported simulator runtime.

- [x] **HH-101 (P0) Make deletion safe and repair active state.** Replaced offset-by-offset deletion with store-owned ID deletion. Deleting an active routine clears both IDs; deleting the active workout clears its workout ID. Regression tests cover single and multi-routine deletion and active-workout deletion.
  - Acceptance: delete IDs or remove offsets in one mutation; deleting an active routine clears both IDs; deleting the active workout clears its ID; tests cover single and multi-delete.

- [x] **HH-102 (P0) Harden persistence.** Routine, history, and exercise-library writes now use atomic replacement; routine and history debounce independently; load/save failures publish user-visible state; and the app flushes routine/history data on backgrounding. Existing/corrupt files are left untouched rather than being replaced with defaults. Regression coverage verifies independent save intent, failed-write preservation, and corrupt-file handling.
  - Acceptance: atomic writes, explicit error propagation/state, separate intent where appropriate, and a scene background flush; failures are visible without destroying the last good file.

- [x] **HH-103 (P0) Validate and own the rest-timer lifecycle.** Rest durations now require a finite value greater than zero and no longer than 24 hours before a notification trigger is created. Notification permission is requested only when a user starts a rest timer; denied/failed scheduling is shown while the in-app countdown continues. Backgrounded countdowns keep their deadline and notification, and finishing or explicitly skipping an exercise's rest cancels its timer. Tests cover duration bounds, authorization/scheduling completion, and cancellation during an in-flight permission request.
  - Acceptance: bounded positive duration validation, scheduling completion handling, contextual permission flow, and documented/tested cancel-or-resume behavior for back navigation and relaunch.

- [x] **HH-104 (P0) Make imports validated and transactional.** Imports now decode into a candidate, reject unsupported schemas, duplicate IDs, blank required text, invalid numeric/log values, and dangling active IDs before state changes. A timestamped pre-import export is written to Documents/Import Backups; routine/history/library candidates are persisted before published state is committed, and a failed write attempts rollback while retaining the backup. History and library ordering are deterministic, and Settings shows the specific import error. Regression tests cover duplicate IDs, dangling active state, and history ordering.
  - Acceptance: decode into a candidate, validate the full graph, create a recoverable backup, commit all state or none, sort history, reject invalid active references, and show a specific error.

- [x] **HH-105 (P0) Make workout completion idempotent and current-state based.** `finishWorkout` now resolves the current routine and workout from IDs inside `RoutineStore`, returns a typed failure for missing or already-completed entries, and records history only once. The finish control disables once completion is reflected in store state, and a confirmation names every planned exercise with no logged sets before allowing completion. Regression tests cover current-state resolution, duplicate completion, and missing routine/workout rejection.
  - Acceptance: resolve by IDs inside the store, reject already-completed/missing workouts, disable repeated submission, and confirm or clearly explain skipped/unlogged work.

- [x] **HH-106 (P1) Apply consistent domain validation.** A shared model-level validator now trims exercise names and target reps, requires positive set counts and reps, and rejects negative/non-finite weights. Configure, edit, custom-exercise, set-logging, and import paths use it; inline feedback explains invalid form/set values, and boundary tests cover the rules.
  - Acceptance: shared validation rules require sensible set/repetition/weight values, trim names and reps, provide inline errors, and have boundary tests.

- [x] **HH-107 (P1) Repair state after load/migration.** Stored active references now normalize after every normal load, migration, and imported-state application: invalid routines clear both IDs, while a missing/cross-routine workout clears only the workout ID. Legacy reads now report a distinct migration error, retain their original files, and leave migration pending; successful migration persists first and only then records completion. Regression tests cover stale references and valid/corrupt legacy fixtures.
  - Acceptance: active references are normalized after every load/migration; migration outcome and errors are distinguishable and tested with legacy fixtures.

## Phase 2 — Core workout experience

- [x] **HH-201 (P1) Finish custom exercise library wiring.** “Custom” now means reusable: creating one normalizes and persists a library template, then adds the configured exercise to the current workout. The operation is atomic—save failure leaves both the library and workout unchanged and is shown inline. The library owns case/whitespace-insensitive duplicate protection, keeps templates deterministically sorted, and has temporary-directory persistence coverage.

- [x] **HH-202 (P1) Allow set correction.** Logged sets now expose edit/delete swipe actions. Edits are validated and persisted through ID-based store mutations; deletion requires confirmation, persists immediately, and clears an exercise's completion state when the remaining set count falls below its target. Regression tests cover scoped edits, invalid inputs, missing IDs, completion repair, and persistence.
  - Acceptance: set corrections are reversible; destructive deletion is confirmed; completion presentation remains accurate; and mutations persist immediately.

- [x] **HH-203 (P1) Persist active session/timer state.** Active workout start time and rest-timer identity/deadline now persist in the store and restore after navigation or relaunch. Expired, orphaned, deleted, completed, and imported-session timers are cleared with their notification; orphaned pending notifications are also removed on launch.
  - Acceptance: a resumed workout retains its original start time; a resumed exercise calculates rest time from its stored deadline; stale timer state and notifications are removed without disturbing a valid restored timer.

- [x] **HH-204 (P1) Add explicit abandon/reset flows.** Starting another routine or workout now refuses to replace a live session until the user explicitly chooses to keep or reset its progress. Workout and routine screens offer confirmed abandon actions; reset clears logs/completion state while both choices cancel the active rest timer. Store tests cover blocked implicit switching, partial-progress retention/reset, and routine-wide timer cleanup.

- [x] **HH-205 (P2) Add reordering.** Routines, workouts, and category-filtered exercises now support Edit-mode drag reordering through store-owned, validated moves that persist immediately. Active IDs remain stable; moving a category's exercises preserves all other category positions. Regression tests cover persistence, active IDs, nested workout moves, and filtered exercise ordering.

- [x] **HH-206 (P2) Improve editing consistency.** Exercise edits can now change category. Routine and workout names trim whitespace and cannot be blank; their alert actions disable until valid. Exercise names are unique within each workout, ignoring case/whitespace (but can be reused in other workouts), with inline custom-form prevention and an explanatory library-selection error. Store-owned mutations persist these edits, with regression coverage.

## Phase 3 — History, analytics, and data management

- [x] **HH-301 (P1) Make session counts consistent.** A trained session now means an exercise with one or more logged sets in a completed workout. The exercise list, top chart, and exercise-progress history all use the shared `ExerciseAnalytics` aggregation; unlogged planned exercises are excluded. Regression coverage verifies matching counts and history.

- [x] **HH-302 (P1) Add stable exercise identity.** Exercises now retain a durable tracking ID sourced from their library template, while completed snapshots preserve it independently of their snapshot IDs. Legacy routine/history/import data migrates by normalized name and persists immediately; analytics group by tracking ID so renames retain progress and same-name movements remain distinct.

- [x] **HH-303 (P1) Make history ordering deterministic.** Completed workout history now uses one newest-first comparator with UUID tie-breaks when importing, loading, completing, and presenting history. Exercise progress session ordering and summary ties are also stable.

- [x] **HH-304 (P1) Add safe history correction/deletion.** Completed-workout date, name, and focus can be corrected through store-owned validation and immediate persistence; whole records can be deleted only after confirmation. Failed writes restore the prior in-memory history, and every analytics view refreshes from the shared history collection. Exercise/log snapshots remain immutable.

- [x] **HH-305 (P1) Strengthen export compatibility.** Settings now documents and lists dated pre-import snapshots, with confirmed restore through the same validated transactional import path; restoring first retains the current state as another backup. Current-schema round-trip/validation, legacy-schema decoding, and backup discovery ordering/filtering are covered by tests.

- [x] **HH-306 (P2) Correct history metadata and version display.** Completed snapshots now persist routine and workout names separately, while legacy `dayName` history remains readable. History details and corrections present each field independently, and Settings reads marketing/build versions from `Bundle`.

- [x] **HH-307 (P2) Make chart behavior honest.** Analytics now consolidate duplicate entries with the same tracking ID into one workout session, summing volume and retaining the best top set/estimated 1RM; same-name exercises with different IDs remain separate. Both charts use linear interpolation so values never visually overshoot recorded points.

## Phase 4 — Accessibility and polish

- [ ] **HH-401 (P1) Audit Dynamic Type (in progress).** The app-wide Chalkboard font and every fixed-size custom text use semantic Dynamic Type scaling across core routine, workout, exercise, summary, settings, and planning views. Session actions now stack when horizontal space is insufficient, and the rest-timer readout scales with the preferred text size. Run the required accessibility-size device smoke test before marking complete.

- [ ] **HH-402 (P1) Add VoiceOver semantics (in progress).** Core routine/workout rows now expose state as a single focused element; set rows, timer presets/countdown actions, chart controls/charts, theme selection, and the history delete icon have explicit labels, values, and hints. Verify VoiceOver focus order and spoken output on device before closing.

- [x] **HH-403 (P1) Audit theme contrast.** Replaced ad hoc theme colors and opacity-based text with a testable sRGB palette. Every theme now meets WCAG AA 4.5:1 for primary/secondary text and chart labels, plus 3:1 for disabled controls, chart marks, and grids. The palette test covers row, status, and disabled-button states so future color changes cannot silently regress contrast.

- [ ] **HH-404 (P2) Test adaptive layouts.** The set-entry controls now fall back to a vertical layout, timer presets fall back to a two-column grid with 44-point targets, and exercise planning/category actions reflow at accessibility sizes. Verify small iPhone, iPad, landscape, keyboard presentation, and the preset row on device before closing.

- [x] **HH-405 (P2) Improve states and copy.** Empty workout and summary states now direct people to their routines, existing validation/save failures surface specific messages, and routine/workout/exercise deletions require an explicit destructive confirmation that explains the removed data.

- [x] **HH-406 (P2) Prepare localization and unit preferences.** Added an English `Localizable.xcstrings` catalog generated from the SwiftUI surface and extended to validation/persistence copy. Users can choose pounds or kilograms; values remain canonically stored in pounds while form input, set logs, history, accessibility values, charts, and volume labels convert only for display.

## Phase 5 — Release readiness

- [ ] **HH-501 (P1) Add CI build/test automation** for a clean checkout and a pinned supported Xcode/iOS environment. Added `.github/workflows/ios.yml`: pull requests and pushes to `main` run the shared `Healy Health` scheme on GitHub-hosted macOS 15 with Xcode 16.2 and iPhone 16 Pro (iOS 18.2), preserve the `.xcresult` bundle, and disable code signing. Confirm the first hosted run before closing.

- [x] **HH-502 (P1) Clean repository metadata.** Added root `.gitignore` rules for Finder metadata and per-user Xcode workspace state, then removed the four tracked `.DS_Store`/`xcuserdata` artifacts from Git's index without deleting local copies. The paths are ignored and no machine-specific files remain tracked.

- [ ] **HH-503 (P1) Run the release regression matrix.** Cover fresh install, upgrade/migration, import/export, interrupted saves, notification denied/allowed, background timer, device rotation, and supported iOS versions.

- [ ] **HH-504 (P1) Finalize shipping metadata.** Set marketing/build versions, verify icon light/dark/tinted variants, prepare screenshots/copy/support and privacy links, and validate signing/archive settings.

- [ ] **HH-505 (P2) Decide diagnostics strategy.** Prefer privacy-conscious first-party logging; obtain explicit approval before adding a third-party crash or analytics SDK.

## Current baseline notes

- The project contains the `Healy Health` application target and the `Healy HealthTests` XCTest target.
- `xcodebuild test` passed all 54 `Healy HealthTests` on 2026-08-06 using iPhone 17 Pro Max, iOS 26.5. CoreSimulatorService is currently unavailable in this environment, so tests cannot run again until that runtime service is restored.
- Active-session reload now restores all persisted fields as a unit before saving normalized state, preventing `activeWorkoutId`, start time, and timer state from being erased during load.
- The git root is the parent `Fitness App` directory; this app lives in its `Healy Health` subdirectory.
- Pre-existing tracked machine files were already dirty during the audit and were not modified by the audit.
