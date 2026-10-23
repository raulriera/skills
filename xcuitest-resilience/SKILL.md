---
name: xcuitest-resilience
description: 'Use when writing, reviewing, or debugging XCUITest UI tests for iOS apps. Makes tests idempotent, free of manual setup, and portable between local runs and Xcode Cloud. Covers app-state reset before service construction, page objects, readiness waits, system alerts and permissions, custom gestures, relaunch and persistence checks, secrets, and flaky-test diagnosis. Symptoms: a test passes alone but fails in a full run or on CI, taps miss, waits time out, the app starts in the wrong state.'
license: MIT
metadata:
  author: Raul Riera
  version: "1.0"
---

# XCUITest Resilience

## Overview

A UI test drives the real app as a person would. It must prepare its own state, prove each
screen is ready before it acts, act once, and fail at the first unexpected result. Investigate
timing, data readiness, and setup ownership before you add a retry.

Project rules (for example in `AGENTS.md`, `CLAUDE.md`, or a testing guide) take priority over
this skill.

## Agent behavior contract

1. Every test is self-contained. It resets the state it needs at launch, does not depend on test
   order, and leaves nothing that changes the next run.
2. Tests need no manual step: no reset command, no simulator setting, no specific test order.
   Host-only preparation goes in the scheme's Test pre-action, never in the test process.
3. Reset app state inside the app, before services are constructed, behind an explicit launch flag
   that only Debug simulator builds read. Remove the flag before a relaunch that checks persistence.
4. Do not replace the behavior under test with a fake. End-to-end tests use production
   implementations and normal storage unless the project defines another boundary.
5. Query by visible text and accessibility labels first. They test what people see and hear.
   Use accessibility identifiers only where a label is not unique or not stable, and only if the
   project allows them.
6. Wait for readiness (`exists`, `isHittable`, `isEnabled`, or a proven data-ready state) before every
   action. Never use `sleep` as a wait.
7. A timed-out wait throws and ends the test. Do not continue with dependent steps.
8. Do not retry committed actions (create, save, send, pay) and do not dismiss alerts automatically.
   An unexpected alert fails the test at once.
9. Put screen knowledge in page objects. Tests read as a list of user steps and outcomes.
10. Use only standard XCUITest APIs in test code: no `Process`, `xcrun simctl`, or host file access.
11. Never type, log, or attach real credentials or personal data. UI test logs record typed text.
12. If the project says only a person runs UI tests, build them but do not run them, and say
    clearly that a build is not a run.

## First 60 seconds (triage)

- Find the goal: a new test, a review, a flaky failure, or CI preparation.
- Find the facts:
  - Which screens and services the flow touches, and which persistent state it reads or writes.
  - If the flow needs network data, credentials, or system permissions.
  - If it fails always, only in a full run, only on CI, or only on one device type.
- Branch:
  - wrong start state or a test that depends on test order → `references/state-and-idempotency.md`
  - taps that miss, waits that time out, data not loaded → `references/waiting-and-interaction.md`
  - repeated queries or long tests → `references/page-objects.md`
  - permission alerts, share sheets, background, deep links → `references/system-ui.md`
  - secrets, pre-actions, Xcode Cloud → `references/ci-and-xcode-cloud.md`
  - a failure you cannot explain → `references/diagnosing-failures.md`

## Routing map

- Reset hooks, launch and relaunch, remote state, fixtures → `references/state-and-idempotency.md`
- Readiness predicates, scrolling, moving content, gestures → `references/waiting-and-interaction.md`
- Page objects, the shared app driver, test layout and naming → `references/page-objects.md`
- SpringBoard alerts, permission resets, share sheets, backgrounding, URLs → `references/system-ui.md`
- Local and Xcode Cloud configuration, secrets, test plans → `references/ci-and-xcode-cloud.md`
- Simulator clones, result bundles, regression tests → `references/diagnosing-failures.md`

## Common pitfalls → next best move

| Symptom | Cause | Fix |
|---|---|---|
| Wrong start state on launch | Reset runs after services start work | Reset before service construction |
| Passes alone, fails in a full run | Leftover state, or a parallel clone | Reset per launch; read logs from the simulator the run used |
| Tap misses a dialog button | The dialog is still animating | Wait for `isHittable` |
| "Expected X to exist" after an action | Data not loaded yet | Wait for a proven ready state, then act once |
| `app.open(url)` starts in the wrong state | `open` does not apply `launchArguments` | `launch()` first, then `open(url)` |
| System alert not found | It belongs to SpringBoard | Query `XCUIApplication(bundleIdentifier: "com.apple.springboard")` |
| Share sheet action not found | Actions are cells | Query `app.cells["Copy"]` |
| Slide control does nothing | `tap()` is a touch, not activation | Drag with `press(forDuration:thenDragTo:)` |
| Tap lands on the wrong row | Content moved after the scroll | Swipe slowly, then wait for a stable frame |
| Two buttons share one label | A sheet covers the screen behind it | Scope by container, or take the hittable match |
| Passes locally, fails on CI | Host command or a missing secret | Standard APIs only; supply secrets through CI configuration |

## Verification checklist

- Each test launches with the reset flag and passes when run alone, twice in a row, and in the full plan.
- No test depends on another test's result or on state from an earlier run.
- Each action waits for readiness; each wait throws on timeout.
- No `sleep`, no generic alert dismissal, no retry of a committed action.
- Queries use user-facing text where it is unique and stable.
- Relaunches that check persistence omit the reset flag.
- Remote state that a test creates is unique to the run or removed by the test.
- Test code uses no `Process`, `simctl`, or host paths; secrets come from configuration.
- Page objects own queries; tests read as user steps.

## References

- `references/state-and-idempotency.md`
- `references/waiting-and-interaction.md`
- `references/page-objects.md`
- `references/system-ui.md`
- `references/ci-and-xcode-cloud.md`
- `references/diagnosing-failures.md`
