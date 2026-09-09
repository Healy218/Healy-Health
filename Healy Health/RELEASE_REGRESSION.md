# Release Regression Matrix

Last updated: 2026-09-09

Use this matrix for every TestFlight or App Store candidate. A row is complete only when its automated checks pass and any listed device check has been performed on the candidate build.

Status meanings:

- **Passed:** all currently required evidence is complete.
- **Partial:** automated or single-environment evidence passed, but a required device/environment check remains.
- **Blocked:** the required environment is unavailable.

## Current candidate evidence

| Area | Automated evidence | Device evidence | Status / remaining gate |
| --- | --- | --- | --- |
| Clean checkout, build, and tests | GitHub Actions `iOS` workflow; shared scheme includes the app and unit-test bundle | None required | Passed all 62 tests on run `33815905256` |
| Fresh install | `testFreshInstallCreatesAndPersistsTheDefaultRoutine` verifies first-launch bootstrap, migration marker, and persisted defaults | Delete/install the candidate, launch it, and confirm the default Push Pull Legs routine is usable | Partial — candidate install check pending |
| Upgrade and migration | Legacy routine/history identity migration, schema 0/1/2 decoding, corrupt-legacy retry, and active-ID repair tests | Install a prior public/beta build with representative data, upgrade in place, and verify routines, history, active state, and units | Blocked — prior-build upgrade environment unavailable |
| Import/export and recovery | Current export round trip, legacy export decoding, graph validation, deterministic ordering, backup discovery, and failed-write preservation tests | Export from one install, import into a separate clean install/device, then restore a pre-import backup | Blocked — separate install/device unavailable |
| Interrupted and failed saves | Independent save-intent, background flush, atomic failed-write preservation, corrupt-file retention, and rollback tests | Force background/termination immediately after an edit, relaunch, and verify the last confirmed data | Partial — automated coverage passed; candidate lifecycle check pending |
| Notifications allowed | Authorization-request and scheduling-success tests verify contextual permission and timer request creation | Grant permission, background the app, and confirm the rest-complete notification arrives once | Partial — system-delivery check pending |
| Notifications denied | `testRestTimerSchedulingReportsDeniedPermissionWithoutAddingNotification` verifies denial is reported without scheduling | Deny permission and verify the in-app countdown continues with actionable copy | Partial — system-permission UI check pending |
| Background/relaunch timer | Active start/deadline reload, expiry cleanup, cancellation, and orphan cleanup tests | Start a timer, background/relaunch before and after its deadline, and verify one consistent countdown/notification | Partial — candidate lifecycle check pending |
| Rotation and large text | Adaptive layout and theme contrast tests | Core workout flow passed portrait and landscape at maximum Dynamic Type on iPhone 17 Pro/iOS 26.5 | Passed for the available large-iPhone environment |
| Supported iOS versions/devices | Deployment target is iOS 16.0; CI passes on iOS 26.5 | Smoke test the minimum supported iOS, a compact iPhone, a large iPhone, and an iPad | Blocked — only iPhone 17 Pro/iOS 26.5 is available |
| VoiceOver | Explicit labels, values, hints, grouping, and control semantics are implemented | Verify focus order and spoken output through routine creation, workout execution, timer use, completion, history, and settings | Blocked — spoken VoiceOver environment unavailable |

## Candidate device checklist

Record the build number, device, OS, and result for each run.

- [ ] Fresh install opens with usable default data and no persistence alert.
- [ ] Prior-version data survives an in-place upgrade.
- [ ] Export from the populated install imports into a separate clean install.
- [ ] A retained pre-import backup restores successfully.
- [ ] An edit made immediately before background/termination is retained or produces an actionable failure.
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
| Local working tree | 2026-09-03 | Shell-side Xcode 26.6 | Blocked | CoreSimulatorService could not enumerate the established iPhone 17 Pro/iOS 26.5 destination |
