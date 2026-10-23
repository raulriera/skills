# State and idempotency

A test is idempotent when it gives the same result on every run, in any order, alone or in a
full plan, on a fresh or a used simulator.

## `launch()` restarts the process, not the data

`XCUIApplication.launch()` ends the running app and starts it again. Keychain items, files,
and `UserDefaults` stay. Each test must clear the state it depends on.

## Reset inside the app, before services exist

Swift property initializers and `App.init` run before any view appears. If a service starts
async work in its initializer (restore a session, load accounts, open a socket), a reset that
runs later cannot stop that work.

```swift
// BAD: the container already restored the saved session
let services = AppServices()
init() {
    if isUITesting { services.reset() }
}

// GOOD: reset first, then construct services
init() {
    #if DEBUG && targetEnvironment(simulator)
    try UITestReset.runIfRequested()
    #endif
    services = AppServices()
}
```

Rules for the reset hook:

- Compile it only in `DEBUG && targetEnvironment(simulator)`.
- Run it only when the launch sets an explicit flag, such as `UI_TEST_RESET=1` in `launchEnvironment`.
- Clear the real stores: the same Keychain services, directories, and preference domain that
  production uses. A separate test namespace is a design choice; agree on it first, because it
  stops the tests from covering the real storage paths.
- Throw on a reset error. A partial reset gives a wrong start state that is hard to diagnose.
- Clear every store that holds user data, including caches that restore a screen or a tab.

## Relaunch to check persistence

Set the flag for the first launch only, then remove it. A later `relaunch()` must run the real
startup restore.

```swift
func launch() throws {
    app.launchEnvironment["UI_TEST_RESET"] = "1"
    app.launch()
    app.launchEnvironment.removeValue(forKey: "UI_TEST_RESET")
    try expectWelcome()
}

func relaunch() {
    app.terminate()
    app.launch()
}
```

A foreground `terminate()` discards saved scene state. UI tests therefore do not cover scene
restoration; check it by hand (background the app, then stop it).

## End every test cleanly

- `defer { app.terminate() }` so a failed test does not leave the app running for the next one.
- Set `continueAfterFailure = false` in a base class, or throw from every failed wait. Dependent
  steps after a failure only add noise.
- Do not share an `XCUIApplication` or page-object state between tests through `static` storage.

## Remote and shared state

The reset clears only the device. State on a server or chain stays.

- Read-only tests: use public fixtures and compare values from the same response.
- Tests that create remote state: use a value unique to the run, or remove the state in the same
  test (for example, create a link, then cancel it). Do not depend on a count of remote items.
- Tests that spend money or quota: use a test environment and dedicated test accounts, and
  follow the project's spending rules.
- Clipboard: the simulator clipboard can sync with the Mac. Say in the test's doc comment what it
  leaves there.

## Fixtures and generated data

- Sign-in and import flows use public test fixtures or dedicated test accounts.
- Create flows may generate real, disposable data when it is acceptable for that data to appear
  in screenshots and logs.
- Never type, log, attach, or record real credentials, recovery material, or personal data.
- Generate unique names (for example with a UUID suffix) when a test saves a named item, so a
  second run does not collide with the first.

## Permissions

Reset protected resources at the start of the test that needs a fresh prompt. Terminate first:
a reset against a running app is not reliable.

```swift
app.terminate()
app.resetAuthorizationStatus(for: .photos)
app.launch()
```
