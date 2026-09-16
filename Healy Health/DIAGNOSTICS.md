# Diagnostics Policy

Last updated: 2026-09-16

This is the shipping diagnostics decision for HH-505 and the 1.0 release.

## Decision

- Ship without a third-party crash-reporting, analytics, attribution, or telemetry SDK.
- Use Apple's Unified Logging only for narrow, actionable failures that are not already fully represented by user-visible error state.
- Do not automatically transmit logs or usage data. Diagnostic information remains on the device unless the user deliberately shares it through an Apple- or support-provided workflow.
- Revisit this decision only after real support evidence shows that on-device diagnostics are insufficient. Adding any third-party service requires explicit owner approval plus a new privacy, security, App Store disclosure, and privacy-manifest review.

## Logging rules

- Log failure categories and stable operation names, not routine names, workout names, exercise names, weights, repetitions, history, export contents, file URLs, UUIDs, notification identifiers, or other user-generated fitness data.
- Treat dynamic error descriptions as private. Never mark user-supplied values as public.
- Do not log successful user actions, screen views, engagement, or behavioral analytics.
- Keep user-facing recovery text in the app; logs supplement it and must not become the only explanation of a failure.
- Prefer typed errors and deterministic tests over additional logging when a failure can be reproduced locally.

## Current implementation

- The app has no external package dependencies and no analytics or crash-reporting SDK.
- Export encoding failures use `Logger` with a private error description.
- Persistence, import, timer, and notification failures remain visible in the UI and are covered by unit tests; they do not require background telemetry for the 1.0 candidate.

## Release review triggers

Repeat the privacy and diagnostics review before adding accounts, cloud sync, networking, remote configuration, analytics, crash upload, or a support-log export. Update `PrivacyInfo.xcprivacy` and App Store Connect privacy answers whenever a new implementation changes collected, linked, tracked, or transmitted data.
