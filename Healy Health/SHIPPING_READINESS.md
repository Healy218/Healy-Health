# Shipping Readiness

Last updated: 2026-09-09

This checklist records release-owned configuration and App Store deliverables for HH-504. Values requiring an owner decision remain intentionally unset.

## Build configuration

| Item | Current state | Release action |
| --- | --- | --- |
| Marketing version | `1.0` in Debug and Release | Confirm this is the intended first public version |
| Build number | `1` in Debug and Release | Increment for every uploaded archive |
| Bundle identifier | `Healy-Labs.Healy-Health` | Confirm it matches the App Store Connect record |
| Signing | Automatic, team `3T3UWJTM4R` | Validate the Distribution certificate/profile during archive upload |
| Deployment target | iOS 16.0 | Confirm support policy and complete minimum-OS regression |
| Device families | iPhone and iPad | Complete compact-iPhone and iPad validation |
| Orientations | iPhone portrait/landscape; iPad all orientations | Complete the outstanding device matrix |
| Archive action | Shared scheme archives the Release configuration | Create and validate a signed archive after the version decisions |
| Launch screen | Generated launch screen | Verify on the final candidate in light and dark appearance |

## Icon and appearance

- [x] The primary icon is present at 1024×1024.
- [x] Every pixel in the current PNG is opaque (`minAlpha = 255`), although the PNG retains an alpha channel.
- [x] The asset catalog compiles in the hosted CI build.
- [ ] Decide whether to ship dedicated dark and tinted artwork. The asset slots exist but currently fall back to the primary icon.
- [ ] Inspect the icon on the Home Screen in default, dark, and tinted appearances before archive sign-off.

## Privacy and support

- [x] `PrivacyInfo.xcprivacy` declares first-party `UserDefaults` access (`CA92.1`) and app-container file timestamp access (`C617.1`).
- [x] The manifest declares no tracking and no data collected by the app. Revisit this if any diagnostics, analytics, accounts, cloud sync, or network service is added.
- [ ] Provide the public privacy-policy URL for App Store Connect.
- [ ] Provide the public support URL and support contact workflow.
- [ ] Complete App Store Connect privacy answers against the final binary and manifest.

## Store listing

- [ ] Final app name and subtitle.
- [ ] Promotional text, description, and keywords.
- [ ] Primary and secondary categories.
- [ ] Copyright and age-rating questionnaire.
- [ ] Review contact, notes, and any demo instructions.
- [ ] Final screenshots for every required iPhone and iPad display class.

## Archive and distribution gate

- [ ] Confirm marketing version and select the next build number.
- [ ] Build an Archive using the shared `Healy Health` scheme and Release configuration.
- [ ] Run Xcode Organizer validation and resolve signing, entitlement, icon, and privacy diagnostics.
- [ ] Upload to App Store Connect and confirm processing completes without warnings.
- [ ] Distribute to TestFlight, execute `RELEASE_REGRESSION.md`, and record sign-off.

## Apple references

- [Describing use of required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Required-reason values for file timestamps and UserDefaults](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)
- [Adding a privacy manifest](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk)
