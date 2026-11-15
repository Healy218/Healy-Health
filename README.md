<p align="center">
  <img src="Healy%20Health/Healy%20Health/Assets.xcassets/AppIcon.appiconset/HealyHealthAppIcon.png" alt="DERD Health app icon" width="120">
</p>

<h1 align="center">DERD Health</h1>

<p align="center"><strong>Do Everything Right Daily</strong><br>A local-first workout tracker for iPhone and iPad.</p>

DERD Health lets you plan routines, log every set, time your rest, and see your progress over time. It needs no account, subscription, or network connection, and your workout data stays on your device unless you export it.

> **Status:** Pre-release. The app isn't on the App Store or TestFlight yet, so for now you'll need to build it from source with Xcode.

## Features

**Plan**
- Build multiple routines, each made up of workouts
- Organize weightlifting, cardio, and stretching exercises
- Set target sets, rep ranges, and starting weights
- Pick from a built-in exercise library or add your own reusable exercises
- Drag to reorder routines, workouts, and exercises

**Train**
- Log weight and reps for each set, and edit or delete a set if you make a mistake
- Use a 2:00, 2:30, or 3:00 rest timer or set your own, with an optional notification when it ends
- Leave or relaunch the app mid-workout and pick up where you left off, including the timer
- Get a warning before finishing a workout with exercises you haven't logged

**Review**
- Browse completed workouts, and correct or delete past entries
- Chart volume, top set, and estimated one-rep max for each exercise
- Keep an exercise's progress when you rename it

**Your data**
- Export everything to a JSON file and import it on another device
- Undo an import from the backup that's saved automatically beforehand
- Switch between pounds and kilograms without changing your stored data

**Accessibility and appearance**
- Dynamic Type, VoiceOver labels, and contrast-tested colors
- Ten color themes, including light and dark

## Getting started

### Requirements

- macOS with Xcode 26 (CI uses Xcode 26.5)
- iOS 16.0 or later on the device or simulator you run it on

The project has no third-party dependencies, so there are no packages to install.

### Build and run

```bash
git clone https://github.com/Healy218/Healy-Health.git
```

```bash
open "Healy-Health/Healy Health/Healy Health.xcodeproj"
```

In Xcode, select the **Healy Health** scheme and a simulator, then press **⌘R**. The first launch creates a sample "Push Pull Legs" routine so you have something to try right away.

To run on a physical device, go to **Signing & Capabilities** and choose your own team. You'll probably need to change the bundle identifier too, because `Healy-Labs.Healy-Health` is registered to the project owner's team.

### Run the tests

From the `Healy Health` folder that contains the `.xcodeproj`:

```bash
xcodebuild test -project 'Healy Health.xcodeproj' -scheme 'Healy Health' -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=NO
```

If you don't have that simulator, change the `-destination` to one you do have. To list them:

```bash
xcrun simctl list devices available
```

The unit tests cover persistence, migration, import and export, set logging, rest timers, weight conversion, and theme contrast. There are no UI tests yet.

GitHub Actions runs the same tests on every pull request and on every push to `main` (see [`ios.yml`](.github/workflows/ios.yml)).

## Project structure

```text
.
├── .github/workflows/ios.yml     # CI build and test
├── AGimports/                    # Earlier prototype sources, not part of the Xcode project
└── Healy Health/
    ├── Healy Health.xcodeproj
    ├── Healy Health/             # App target
    │   ├── Healy_HealthApp.swift # App entry point
    │   ├── ContentView.swift     # Tab bar: Routines, Workout, Summary, Settings
    │   ├── Models/               # Domain types, validation, analytics, RoutineStore
    │   ├── Views/                # SwiftUI screens
    │   ├── Helpers/              # Themes, export/import, notifications
    │   ├── Localizable.xcstrings # String catalog (English)
    │   └── PrivacyInfo.xcprivacy # Privacy manifest
    └── Healy HealthTests/        # Unit tests
```

The app is built with SwiftUI, Swift Charts, and Combine. `RoutineStore` is the main source of truth: views read its published state and make changes through its methods.

### Naming

The app was renamed from Healy Health to **DERD Health**. Only the display name and user-facing text changed. The repository, Xcode target and scheme, and bundle identifier keep the old name so existing installs and their data continue to work.

## How data is stored

All data lives in the app's sandbox on the device.

| Data | Location |
| --- | --- |
| Routines and in-progress logs | `Documents/routines.json` |
| Completed workouts | `Documents/workout_history.json` |
| Exercise library | `Documents/exercise_library.json` |
| Backups made before each import | `Documents/Import Backups/` |
| Active session, rest timer, and preferences | `UserDefaults` |

A few rules keep this data safe, and any change to it should follow them:

- **Writes are atomic.** A failed save keeps the last good file and shows an error in the app. Corrupt files are kept rather than overwritten.
- **Imports are all-or-nothing.** A file is fully validated before anything changes, and the current data is backed up first.
- **Old exports keep working.** The current export format is schema version 2, and versions 0 and 1 can still be imported.
- **Weights are stored in pounds.** Kilograms only affect how weights are displayed and entered.

## Privacy

The app has no analytics, advertising, crash-reporting, or other third-party SDKs, and it makes no network requests. The privacy manifest declares no tracking and no collected data. Notification permission is requested only when you first use a rest timer, and the countdown still works if you decline.

DERD Health is a workout log. It doesn't provide medical advice.

## Roadmap

Before the first public release, the plan is to add:

- An in-app assistant that creates workouts to fit your routine. Building routines by hand will stay available. The approach hasn't been chosen yet, and Apple's on-device Foundation Models framework is the first option to try.
- Optional sync of completed workouts to Apple Health.
- Testing across more devices and iOS versions, including VoiceOver, followed by a TestFlight beta.

Neither the assistant nor Apple Health sync exists in the app yet.

## License

No license has been chosen yet, so all rights are reserved by default.
