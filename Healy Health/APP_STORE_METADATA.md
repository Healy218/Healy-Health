# App Store Metadata Draft

Last updated: 2026-09-16

This is the selected English (U.S.) release-candidate copy for the 1.0 listing. Bracketed fields require the account owner's final legal or public URL information.

## App information

- **Name:** Healy Health
- **Subtitle:** Plan. Log. Progress.
- **Primary category:** Health & Fitness
- **Secondary category:** Sports
- **Copyright:** 2026 [legal seller name]
- **Privacy Policy URL:** [public HTTPS URL required]
- **Support URL:** [public HTTPS URL required]
- **Marketing URL:** Optional; omit for 1.0 unless a product page is available.

The name and subtitle are each within Apple's 30-character limit. Health & Fitness is the recommended primary category because Apple explicitly includes workout tracking in that category.

## Version 1.0 copy

### Promotional text

Build flexible routines, log every set, time your rest, and review your progress—all with private, local-first workout data you can export and restore.

### Description

Healy Health is a focused workout tracker for planning routines, running training sessions, and understanding your progress without an account or subscription.

PLAN YOUR TRAINING
• Build multiple routines and workouts.
• Organize weightlifting, cardio, and stretching exercises.
• Set target sets, rep ranges, and starting weights.
• Reorder and edit your plan as your training changes.

LOG WITH CONFIDENCE
• Record weight and repetitions for every set.
• Correct or remove an accidental set safely.
• Use customizable rest timers with optional completion notifications.
• Resume an active workout and timer after navigating away or relaunching.

REVIEW YOUR PROGRESS
• Browse completed workout history.
• Review training volume, top sets, and estimated one-rep-max trends.
• Keep progress connected when an exercise is renamed.
• Display weights in pounds or kilograms without changing stored values.

KEEP CONTROL OF YOUR DATA
• Your workout data stays on your device by default.
• Export a portable JSON backup whenever you choose.
• Import compatible backups and restore retained pre-import snapshots.
• No account, advertising tracker, or third-party analytics SDK is required.

Healy Health supports Dynamic Type, VoiceOver-oriented labels and values, light and dark appearance, iPhone, and iPad.

### Keywords

workout,fitness,gym,routine,sets,reps,strength,weightlifting,training,progress,tracker

The keyword string is under Apple's 100-byte limit and does not repeat the app or company name.

## Age rating recommendation

Expected result: the lowest general-audience rating supported by the completed questionnaire (typically 4+ on earlier OS versions), with **Not Applicable** for Made for Kids and no higher override.

Expected questionnaire answers are none/no for violence, sexual content, profanity, drugs, gambling, loot boxes, horror, unrestricted web access, user-generated content, messaging, advertising, and contests. The account owner must confirm these answers against the final binary in App Store Connect; Apple calculates global and region-specific ratings from the submitted questionnaire.

## App Review notes draft

Healy Health does not require an account, login, subscription, network connection, or demo credentials. On first launch, the app creates a sample “Push Pull Legs” routine so the core flow can be reviewed immediately.

Suggested review path:

1. Open Push Pull Legs → Push Day → Weightlifting.
2. Return to the Workout tab and open an exercise.
3. Log a set and choose a rest-timer duration. Notification permission is requested only when a rest timer is first used; denying permission leaves the in-app countdown available.
4. Open Summary to review workout analytics and history.
5. Open Settings to change units or export/import a JSON backup.

All fitness information is entered by the user and stored locally. The app is a workout log and does not diagnose, treat, or provide medical advice.

Review contact name, email, and phone: [required owner contact]

## Screenshot plan

Capture clean data with no personal names or sensitive workout history. Use the same five-story sequence for each required device class:

1. Routines — “Build training around your goals”
2. Active workout — “Stay focused set by set”
3. Rest timer — “Keep every session moving”
4. Progress summary — “See strength and volume trends”
5. Data/settings — “Your data, your choice”

Required final assets:

- iPhone: 1–10 screenshots. Prefer a supported 6.9-inch portrait size such as 1260 × 2736; App Store Connect can scale highest-resolution assets to smaller iPhone classes.
- iPad: because the binary supports iPad, provide 13-inch portrait screenshots at 2064 × 2752 or 2048 × 2732.
- Screenshots must be JPEG/JPG/PNG and must not contain transparency.

The approved local environment only has an iPhone 17 Pro (6.3-inch) Simulator, so it cannot produce the required highest-resolution iPhone and iPad sets without an additional approved capture environment.

## Apple references

- [App information field limits](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [Platform version metadata limits](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [Screenshot upload requirements](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)
- [App Store categories](https://developer.apple.com/app-store/categories/)
- [Age-rating workflow](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating)
