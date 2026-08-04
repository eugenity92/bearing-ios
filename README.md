# Bearing

A small iOS app that reads heart-rate variability, resting heart rate and sleep from HealthKit and turns them into a daily readiness score — measured against your own baseline, not a population average. It also pulls air quality and weather so the answer to "should I train today?" accounts for the conditions outside as well as the state you're in.

Built as a study in modern iOS architecture: Swift 6 with complete strict concurrency, SwiftUI, `@Observable`, protocol-based dependency injection, and a pure domain layer isolated from every Apple framework.

> **Not a medical device.** The readiness score is a documented heuristic comparing today's values to your own recent averages. It has not been validated against any clinical or performance outcome, and it cannot diagnose or predict anything. See [`docs/readiness-score.md`](docs/readiness-score.md) for the algorithm and its limitations, stated plainly.

---

## Status

| Milestone | State |
|---|---|
| M0 — project scaffolding, CI, lint | ✅ |
| M1 — networking layer + Open-Meteo slice | 🚧 |
| M2 — HealthKit + readiness score | ⬜ |
| M3 — docs and screenshots | ⬜ |

## Architecture

```
┌──────────────────────────────────────────────┐
│ Scenes        SwiftUI views + @Observable    │
│               @MainActor scene models        │
├──────────────────────────────────────────────┤
│ Services      Sendable protocols, live impls │
│               as actors, injected via        │
│               swift-dependencies             │
├──────────────────────────────────────────────┤
│ Networking    Resource<T> + NetworkService   │
├──────────────────────────────────────────────┤
│ ReadinessCore Pure domain — no HealthKit,    │
│  (SPM)        no SwiftUI, no I/O             │
└──────────────────────────────────────────────┘
```

**`Packages/ReadinessCore` is a separate local Swift package on purpose.** The scoring algorithm, sleep aggregation and baseline statistics live there and cannot import HealthKit, SwiftUI or Foundation's clock even by accident — the package simply doesn't depend on them. That makes the interesting logic testable in about a second with no simulator, and it's enforced by the compiler rather than by convention.

Every service follows one shape:

```swift
protocol OutdoorConditionsService: Sendable { ... }

private actor LiveOutdoorConditionsService: OutdoorConditionsService { ... }

private enum OutdoorConditionsServiceKey: DependencyKey {
    static let liveValue: any OutdoorConditionsService = LiveOutdoorConditionsService()
}

extension DependencyValues {
    var outdoorConditionsService: any OutdoorConditionsService { ... }
}
```

Scene models are `@Observable @MainActor final class` with a nested `enum State { case loading, loadFailed, loaded(T) }`. Views own them with `@State`. There are no computed `some View` properties anywhere — every subview is a `private struct` in the same file.

## Running it

```bash
git clone https://github.com/eugenity92/bearing-ios.git
cd bearing-ios
open Bearing.xcodeproj
```

No project generation step is required — `Bearing.xcodeproj` is committed. `project.yml` is committed too, because a reviewable YAML file beats an unreadable `pbxproj` diff; regenerate with `xcodegen generate` only if you change the project structure.

HealthKit returns no data in the simulator, so launch with `-useSampleHealthData` to run against a seeded synthetic dataset.

```bash
swift test --package-path Packages/ReadinessCore   # pure domain, ~1s, no simulator
bundle exec fastlane test                          # full suite, simulator
bundle exec fastlane lint                          # SwiftLint, strict
```

`fastlane` needs a modern Ruby; macOS system Ruby 2.6 will not do. `Gemfile.lock` is committed so CI installs a pinned set.

## CI

Three jobs on every pull request: the domain package, SwiftLint in `--strict` mode, and a simulator build-and-test through Fastlane.

Everything is **simulator-only, so no code signing, no secrets, and no Apple Developer account** — clone it, and CI goes green on your fork too. Two details that are easy to get wrong:

- **`-skipMacroValidation` is load-bearing.** swift-dependencies ships `DependenciesMacrosPlugin`, and without that flag a headless build fails with an untrusted-macro error — the CI equivalent of Xcode's "trust this macro?" prompt.
- **No simulator name is hard-coded.** The Fastfile queries `simctl` and picks the highest-numbered iPhone available. Pinning a device name is one of the most common ways an iOS pipeline breaks after a runner image update.

## Things I deliberately did not do

- **Background delivery of HealthKit updates.** Needs an extra entitlement and a paid developer account, and cannot be exercised in CI. The app refreshes on appear and on scene activation instead.
- **Workouts in the score.** Available and read, but adding a training-load term without validation would be unfalsifiable complexity. Workouts appear as context only.
- **Tests for SwiftUI view bodies, the real `HKHealthStore`, or live network calls.** The first is brittle, the latter two are integration concerns that would make the suite slow and flaky. Everything crosses a protocol seam instead.

## Notes on HealthKit that cost me time

- **Read authorization is unreadable by design.** `authorizationStatus(for:)` is meaningful only for *share* types, and `getRequestStatusForAuthorization` returning `.unnecessary` does **not** mean access was granted — it means no prompt is needed. Apple does this so an app cannot infer, from a denial, that you have a condition you didn't want to disclose. So the UI can never say "you denied HRV access"; it says "no data available — either no access, or your devices haven't recorded any," and offers a route to Settings.
- **Partial grants are normal, not an edge case.** The permission sheet has a per-type toggle, so HRV granted and sleep denied is a common state. The score redistributes component weights rather than failing.
- **Sleep samples overlap.** With an Apple Watch and a third-party sleep app both writing to HealthKit, naively summing `sleepAnalysis` durations can produce a fourteen-hour night. Intervals are merged before being summed.
- **Nights cross midnight**, so sleep is bucketed 18:00 the previous day to 12:00 the current one, using `Calendar` arithmetic rather than adding 86,400 seconds — otherwise daylight-saving transitions are silently wrong.
- **HealthKit's `heartRateVariabilitySDNN` is not overnight HRV.** The Watch samples it opportunistically through the day, so a daily mean is not comparable to the overnight-window figure Whoop and Oura report. The score uses it anyway, and says so.

## Privacy

No health data leaves the device. The only outbound request is to Open-Meteo for weather and air quality, and the coordinate sent with it is rounded to two decimal places — roughly a kilometre — because the forecast does not need to know which building you are in.

## License

MIT
