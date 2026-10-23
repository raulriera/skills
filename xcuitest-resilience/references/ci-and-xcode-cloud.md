# Local runs and Xcode Cloud

The same test code must run from Xcode, from `xcodebuild`, and on Xcode Cloud.

## Test code

The UI test runner is an iOS process. It cannot run host commands.

- Do not use `Process`, `xcrun simctl`, `devicectl`, or host file paths in tests.
- Use `XCUIApplication`, `XCUIElement`, `XCUIDevice`, `UIPasteboard`, `resetAuthorizationStatus(for:)`,
  launch arguments, and launch environment.
- Read configuration with `ProcessInfo.processInfo.environment`.

## Host preparation

Put host-only setup (for example simulator biometric enrollment) in the scheme's Test pre-action.

- Use the destination Xcode selected (`TARGET_DEVICE_IDENTIFIER`). Never use `booted`, a fixed
  device, or every device.
- Make the script safe to run again: it sets a state, it does not toggle one.
- Exit with an error and a clear message when the destination is not a simulator.
- A whole-simulator erase during a run also ends the test runner. Reset app state per test instead.

Xcode Cloud runs custom scripts from `ci_scripts/` (`ci_post_clone.sh`, `ci_pre_xcodebuild.sh`,
`ci_post_xcodebuild.sh`). Apple's custom-script documentation does not say if scheme pre-actions
run there. Verify a pre-action on Xcode Cloud before you depend on it, or make the tests pass
without it.

## Secrets

- Never commit keys. Locally, keep them in ignored configuration (for example `Local.xcconfig`)
  and pass them to the runner through the test plan's environment (`"value": "$(TEST_API_KEY)"`).
- An unset build setting can arrive as an empty string or as the literal `$(NAME)`. Treat both
  as missing.
- On Xcode Cloud, store the key as a secret custom environment variable on the workflow. A
  `ci_pre_xcodebuild.sh` can write it into the ignored xcconfig so the test plan expands it the
  same way as locally. Never print the value.
- Decide per project what a missing secret means: `XCTSkip` (the test cannot run in this
  environment) or `XCTFail` (the environment is broken). Use one rule for all tests.
- Never type a real key in a way that a screenshot or log keeps in full. UI test logs record
  typed text.

## Test plans

- Keep UI tests in their own test plan, apart from offline unit tests.
- Turn off parallel execution for UI tests. Parallel runs boot simulator clones, and the clones
  share nothing with the base simulator (Keychain, permissions, logs).
- Set the app language and region at launch (`-AppleLanguages (en)`, `-AppleLocale en_US`) so
  label queries do not depend on the host's settings.
- Use the same simulator models locally and on CI, one per device class you support.

## Network

UI tests that read live data depend on the provider. Make them fail fast with the provider's own
error alert (rate limit, offline), not a generic timeout, so a CI failure says which service failed.
