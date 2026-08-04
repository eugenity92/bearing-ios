# Decisions

Short records of choices that a reader might otherwise assume were accidental.

## 1. Commit the `.xcodeproj` and the `project.yml`

**Context.** Generated project files (XcodeGen, Tuist) give reviewable configuration and clean diffs. Committed `.xcodeproj` files give a clone-and-open experience with zero tooling.

**Decision.** Commit both. `Bearing.xcodeproj` is the source of truth for building; `project.yml` exists so the configuration is readable in a pull request instead of buried in a `pbxproj`.

**Why.** For a portfolio repository, someone opening it should not have to install anything first. The cost is remembering to run `xcodegen generate` after structural changes, which is acceptable on a solo project.

## 2. A separate SPM package for the domain

**Context.** The scoring logic could live in the app target next to everything else.

**Decision.** `Packages/ReadinessCore` is a local package with no dependency on HealthKit, SwiftUI, or swift-dependencies.

**Why.** It makes the boundary a compiler-enforced fact rather than a promise, and it means the logic that actually matters is tested in about a second with no simulator — a separate, fast CI job.

## 3. Hosts in xcconfig without a URL scheme

**Context.** Base URLs are injected through xcconfig into `Info.plist` and read via `Configuration`.

**Decision.** Store `api.open-meteo.com`, not `https://api.open-meteo.com`. The scheme is prepended in code.

**Why.** xcconfig treats `//` as the start of a comment, so a value containing `https://` is silently truncated at build time with no error. This is a well-known trap and the cause is invisible at the call site.

## 4. CoreLocation via a delegate wrapper, not `CLLocationUpdate.liveUpdates()`

**Context.** iOS 17 is the deployment target.

**Decision.** Wrap `CLLocationManager` and its delegate in an actor exposing `async` methods.

**Why.** `CLServiceSession`, which makes the modern async API's authorization behaviour predictable, is iOS 18+. On an iOS 17 baseline a plain delegate wrapper is boring and correct.

## 5. No code signing anywhere in CI

**Context.** The pipeline could archive and upload to TestFlight.

**Decision.** CI builds and tests for the simulator only. The `beta` lane exists and is documented but is never run by CI.

**Why.** Simulator builds need no signing, so the pipeline needs no secrets and no Apple Developer account. Anyone who forks the repository gets a green build. Release automation is documented rather than half-working.
