# Shipping Readiness

Last updated: 2026-09-16

This checklist records release-owned configuration and App Store deliverables for HH-504. Values requiring an owner decision remain intentionally unset.

## Build configuration

| Item | Current state | Release action |
| --- | --- | --- |
| Marketing version | `1.0` in Debug and Release; selected for the first public candidate | Change only if the App Store Connect record requires a different version |
| Build number | `1` in Debug and Release; selected for the first upload | Increment if build 1 has already been uploaded or for every later archive |
| Bundle identifier | `Healy-Labs.Healy-Health` | Confirm it matches the App Store Connect record |
| Signing | Automatic, team `3T3UWJTM4R`; no valid local code-signing identity is installed | Install/select a valid Apple Distribution identity and profile, then validate during archive upload |
| Deployment target | iOS 16.0 | Confirm support policy and complete minimum-OS regression |
| Device families | iPhone and iPad | Complete compact-iPhone and iPad validation |
| Orientations | iPhone portrait/landscape; iPad all orientations | Complete the outstanding device matrix |
| Archive action | Shared scheme archives the Release configuration; unsigned Release archive succeeded on 2026-09-16 | Repeat with distribution signing after the version decisions |
| Launch screen | Generated launch screen | Verify on the final candidate in light and dark appearance |

## Icon and appearance

- [x] The primary icon is present at 1024×1024.
- [x] Every pixel in the current PNG is opaque (`minAlpha = 255`), although the PNG retains an alpha channel.
- [x] The asset catalog compiles in the hosted CI build.
- [x] Ship 1.0 using the opaque primary icon as the system fallback for dark and tinted appearances; dedicated variants are deferred until purpose-built artwork is available.
- [ ] Inspect the icon on the Home Screen in default, dark, and tinted appearances before archive sign-off. Default and dark system appearances were visually verified on iPhone 17 Pro/iOS 26.5 on 2026-09-16; tinted appearance remains.

## Privacy and support

- [x] `PrivacyInfo.xcprivacy` declares first-party `UserDefaults` access (`CA92.1`) and app-container file timestamp access (`C617.1`).
- [x] The manifest declares no tracking and no data collected by the app. Revisit this if any diagnostics, analytics, accounts, cloud sync, or network service is added.
- [x] `DIAGNOSTICS.md` records the 1.0 decision to use private, on-device Apple Unified Logging without third-party SDKs or automatic telemetry upload.
- [ ] Provide the public privacy-policy URL for App Store Connect.
- [ ] Provide the public support URL and support contact workflow.
- [ ] Complete App Store Connect privacy answers against the final binary and manifest.

## Store listing

- [x] `APP_STORE_METADATA.md` provides a field-limit-checked English (U.S.) draft, recommended categories, age-rating assumptions, review notes, and a five-screen screenshot plan.
- [x] Release-candidate name `Healy Health` and subtitle `Plan. Log. Progress.` selected.
- [x] Release-candidate promotional text, description, and keywords are in `APP_STORE_METADATA.md` and fit Apple's field limits.
- [x] Health & Fitness selected as primary category; Sports selected as secondary.
- [ ] Copyright and age-rating questionnaire.
- [ ] Review contact, notes, and any demo instructions.
- [ ] Final screenshots for every required iPhone and iPad display class.

## Archive and distribution gate

- [x] Select marketing version `1.0` and build `1` for the first upload; bump the build if App Store Connect already contains build 1.
- [x] Build and structurally validate an unsigned Archive using the shared `Healy Health` scheme and Release configuration.
- [x] Confirm the archive contains an arm64 app and dSYM, version `1.0` build `1`, iOS 16.0 minimum, bundle ID `Healy-Labs.Healy-Health`, and a valid embedded `PrivacyInfo.xcprivacy`.
- [ ] Repeat the archive with a valid Apple Distribution identity and provisioning profile.
- [ ] Run Xcode Organizer validation and resolve signing, entitlement, icon, and privacy diagnostics.
- [ ] Upload to App Store Connect and confirm processing completes without warnings.
- [ ] Distribute to TestFlight, execute `RELEASE_REGRESSION.md`, and record sign-off.

Unsigned archive evidence: `/tmp/HealyHealth-1.0-1-unsigned.xcarchive`. It passed Xcode's store-oriented bundle validation with signing disabled. Because the machine reports zero valid code-signing identities, this artifact cannot be uploaded or treated as the signed release candidate.

## Apple references

- [Describing use of required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Required-reason values for file timestamps and UserDefaults](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)
- [Adding a privacy manifest](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk)
