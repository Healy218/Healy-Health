# Healy Health Roadmap

Last updated: 2026-08-03

## Product goal

Ship a reliable iOS workout-tracking app that lets users build routines, run and resume workouts, log sets and rest periods, review progress, and safely move or restore their data.

## Status legend

- Complete: exit criteria have been met.
- In progress: this is the active phase.
- Planned: work has not started or is not yet the focus.

## Phase 0 — Baseline and planning

Status: Complete

Outcome: Establish the current app baseline and a repeatable session workflow.

Completed:

- Reviewed the SwiftUI views, data models, persistence, import/export, notifications, themes, and analytics.
- Confirmed that all Swift sources type-check against the iOS SDK.
- Identified the absence of unit-test and UI-test targets.
- Created `codex.md`, `TODO.md`, `ROADMAP.md`, and `handoff.md`.

Exit criteria:

- [x] Current-state risks are documented and prioritized.
- [x] A phased path to release exists.
- [x] Every future session has start/end and handoff rules.

## Phase 1 — Data safety and crash prevention

Status: In progress

Outcome: Routine, workout, history, timer, and imported data remain internally consistent and recoverable across all normal app lifecycle events.

Scope:

- Add a test target and cover store mutations, persistence, decoding, import validation, and workout completion.
- Repair active routine/workout references after deletion, loading, and import.
- Make multi-item deletion safe.
- Replace silent, delayed-only persistence with atomic writes, surfaced errors, and lifecycle flushing.
- Validate all numeric and text inputs using domain rules, not only parseability.
- Make rest-timer scheduling safe for invalid input and clear across navigation/background transitions.
- Validate import schema and relationships before committing any imported state.
- Resolve the current workout from IDs when finishing and prevent duplicate or accidental completions.

Completed in this phase:

- Added the `Healy HealthTests` unit-test target and a `RoutineStore` test seam that uses injected temporary storage and `UserDefaults`.
- Made routine and workout deletion ID-based, preventing multi-row index shifts and clearing invalid active state; covered single/multi-routine and active-workout deletion.
- Hardened routine, history, and exercise-library persistence with atomic writes and visible failure state. Routine/history save requests are now independent, backgrounding flushes pending store data, and failed/corrupt files are retained rather than silently replaced.
- Hardened the rest timer: durations are finite, positive, and capped at 24 hours; notification permission is requested at timer use; and authorization/scheduling failures reach the user without stopping the visible countdown. A backgrounded timer continues, while leaving/completing its exercise or launching a new app process clears its pending notification.

Verification note: app and XCTest sources type-check in the terminal environment. The user has also built and installed the app in an interactive iPhone simulator, while terminal `xcodebuild` remains blocked by a separate CoreSimulator-runtime issue. XCTest execution has not yet been recorded.

Exit criteria:

- [ ] No known user-entered value can create an invalid notification trigger or impossible workout configuration.
- [ ] Deleting or importing data cannot leave dangling active IDs.
- [ ] Critical persistence and mutation paths have automated tests.
- [ ] Save/import failures reach the UI with an actionable message.
- [ ] The app passes a clean build and the Phase 1 regression checklist.

## Phase 2 — Complete the core workout experience

Status: Planned

Outcome: Users can confidently plan, start, correct, resume, abandon, and complete workouts without losing context.

Scope:

- Make custom exercise library behavior explicit and persist reusable custom exercises.
- Allow logged sets to be edited or deleted.
- Preserve or intentionally cancel rest-timer state when navigating away and returning.
- Add explicit resume, abandon, and reset flows with confirmations.
- Add routine, workout, and exercise reordering.
- Improve workout-completion validation and skipped-exercise messaging.
- Review category editing and duplicate exercise handling.

Exit criteria:

- [ ] Accidental set entries are reversible.
- [ ] Active workout and timer state behave predictably after navigation and app relaunch.
- [ ] Destructive workout actions require confirmation.
- [ ] Routine and workout organization can be changed without rebuilding content.

## Phase 3 — Accurate history, analytics, and data management

Status: Planned

Outcome: History and charts consistently reflect completed work and remain compatible as the data model evolves.

Scope:

- Introduce stable exercise identity so renames and same-name exercises do not split or merge analytics incorrectly.
- Define a single meaning of “session” and use it consistently in summary counts and charts.
- Sort imported and loaded history deterministically.
- Add history deletion/correction with confirmation.
- Version and validate exports; document backward-compatibility guarantees.
- Display the app version from the bundle rather than hard-coded copy.
- Clarify routine versus workout metadata in history details.

Exit criteria:

- [ ] Summary counts, charts, and history agree for the same dataset.
- [ ] Export/import round-trip tests pass for current and supported legacy schemas.
- [ ] Users can correct erroneous history safely.
- [ ] Analytics remain stable when an exercise is renamed.

## Phase 4 — Accessibility and product polish

Status: Planned

Outcome: The app is readable, navigable, and visually consistent across supported devices, themes, and accessibility settings.

Scope:

- Adopt Dynamic Type-friendly typography and reduce dependence on fixed custom-font sizes.
- Add VoiceOver labels, values, hints, and appropriate accessibility grouping.
- Audit contrast for every theme and state.
- Test compact iPhone, large iPhone, iPad, portrait, landscape, and large accessibility text.
- Improve empty states, validation messages, keyboard behavior, and destructive-action affordances.
- Prepare strings for localization and make units/preferences extensible.

Exit criteria:

- [ ] Core flows work at accessibility text sizes without clipping.
- [ ] Core flows are usable with VoiceOver.
- [ ] Theme colors meet the chosen contrast target.
- [ ] Supported device/orientation smoke tests pass.

## Phase 5 — Release readiness and deployment

Status: Planned

Outcome: Produce a tested, supportable App Store/TestFlight candidate.

Scope:

- Add continuous integration for build and tests.
- Remove tracked machine-specific files and add repository ignore rules.
- Run regression, migration, interruption, and device testing on supported iOS versions.
- Finalize version/build numbers, icons and appearance variants, launch experience, App Store metadata, privacy disclosures, and support links.
- Decide on privacy-conscious crash reporting/diagnostics before adding any third-party service.
- Archive, distribute to TestFlight, resolve beta findings, and prepare the App Store submission.

Exit criteria:

- [ ] CI is green from a clean checkout.
- [ ] No open P0 or P1 defects remain.
- [ ] Exported data has been restored successfully on a separate install/device.
- [ ] TestFlight regression sign-off is complete.
- [ ] Store listing, privacy information, signing, and archive validation are complete.
