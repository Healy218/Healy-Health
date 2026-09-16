# Release Regression Matrix

Last updated: 2026-09-16

Use this matrix for every TestFlight or App Store candidate. A row is complete only when its automated checks pass and any listed device check has been performed on the candidate build.

Status meanings:

- **Passed:** all currently required evidence is complete.
- **Partial:** automated or single-environment evidence passed, but a required device/environment check remains.
- **Blocked:** the required environment is unavailable.

## Current candidate evidence

| Area | Automated evidence | Device evidence | Status / remaining gate |
| --- | --- | --- | --- |
| Clean checkout, build, and tests | GitHub Actions `iOS` workflow; shared scheme includes the app and unit-test bundle | Current working tree ran all tests on the approved Simulator | Partial — all 62 tests passed locally on the current candidate with Xcode 26.6; all 62 hosted tests passed on older commit `3df13e9` in run `33815905256`, but the current PR-head run is not inspectable through the available private-repository access |
| Fresh install | `testFreshInstallCreatesAndPersistsTheDefaultRoutine` verifies first-launch bootstrap, migration marker, and persisted defaults | Uninstalled the app, installed the current build, launched it, and inspected both UI and persisted files | Passed — one usable Push Pull Legs routine, three workouts, zero logs, and the migration marker persisted |
| Upgrade and migration | Legacy routine/history identity migration, schema 0/1/2 decoding, corrupt-legacy retry, and active-ID repair tests | Built commit `a14d676`, seeded the retained schema-1 export, installed the current build over it without uninstalling, launched, and inspected migrated persistence | Passed — 5 routines, 15 workouts, 68 planned exercises, 33 logs, 52 completed workouts, and 18 library entries survived; no routine/history exercise lacked a tracking ID |
| Import/export and recovery | Current export round trip, legacy export decoding, graph validation, deterministic ordering, backup discovery, and failed-write preservation tests | Export from one install, import into a separate clean install/device, then restore a pre-import backup | Partial — clean reinstall and retained schema-1 fixture are available; file-import and backup-restore UI checks remain |
| Interrupted and failed saves | Independent save-intent, background flush, atomic failed-write preservation, corrupt-file retention, and rollback tests | Logged a third 135 lb × 8 set, immediately terminated the app, and inspected/relaunched the persisted state | Passed — the set and active timer record were saved before termination |
| Notifications allowed | Authorization-request and scheduling-success tests verify contextual permission and timer request creation | Grant permission, background the app, and confirm the rest-complete notification arrives once | Partial — system-delivery check pending |
| Notifications denied | `testRestTimerSchedulingReportsDeniedPermissionWithoutAddingNotification` verifies denial is reported without scheduling | Deny permission and verify the in-app countdown continues with actionable copy | Partial — system-permission UI check pending |
| Background/relaunch timer | Active start/deadline reload, expiry cleanup, cancellation, and orphan cleanup tests | Terminated with an active timer, then relaunched after its deadline and inspected state | Partial — active timer persisted and expired state was removed on relaunch; before-deadline relaunch and direct delivery observation remain |
| Rotation and large text | Adaptive layout and theme contrast tests | Core workout flow passed portrait and landscape at maximum Dynamic Type on iPhone 17 Pro/iOS 26.5 | Passed for the available large-iPhone environment |
| Supported iOS versions/devices | Deployment target is iOS 16.0; CI passes on iOS 26.5 | Smoke test the minimum supported iOS, a compact iPhone, a large iPhone, and an iPad | Blocked — only iPhone 17 Pro/iOS 26.5 is available |
| VoiceOver | Explicit labels, values, hints, grouping, and control semantics are implemented | Verify focus order and spoken output through routine creation, workout execution, timer use, completion, history, and settings | Partial — the Simulator is available, but enabling the system accessibility setting awaits explicit user confirmation |

## Candidate device checklist

Record the build number, device, OS, and result for each run.

- [x] Fresh install opens with usable default data and no persistence alert.
- [x] Prior-version data survives an in-place upgrade.
- [ ] Export from the populated install imports into a separate clean install.
- [ ] A retained pre-import backup restores successfully.
- [x] An edit made immediately before background/termination is retained or produces an actionable failure.
- [ ] Notification-allowed timer fires once after backgrounding.
- [ ] Notification-denied timer keeps counting in-app and explains how to enable notifications.
- [ ] Timer state is correct after backgrounding, relaunching before expiry, and relaunching after expiry.
- [x] Core flow fits portrait and landscape on iPhone 17 Pro/iOS 26.5 at maximum Dynamic Type.
- [ ] Core flow passes on the minimum supported iOS version.
- [ ] Core flow passes on compact iPhone and iPad layouts.
- [ ] VoiceOver focus order and spoken output are correct for the core flow.

## Sign-off record

| Build | Date | Environment | Result | Notes |
| --- | --- | --- | --- | --- |
| Branch `3df13e9` | 2026-09-03 | GitHub-hosted macOS 26, Xcode 26.5, iPhone 17 Pro/iOS 26.5 | Passed | Workflow run `33815905256`; all 62 tests and result-bundle upload passed |
| Local working tree | 2026-09-16 | Xcode 26.6 (`17F113`), iPhone 17 Pro/iOS 26.5 | Passed | All 62 tests passed; fresh install, schema-1 prior-build upgrade, immediate-termination persistence, and expired-timer cleanup passed |
