# Page objects

A page object holds what one feature knows: how to find the elements of its screens and sheets,
the actions a person can take in it, and how to tell that it is on screen. Tests then read as user
steps.

## Layout

```
<App>UITests/
  Support/
    UITestApp.swift          // launch, relaunch, tab bar, tap, waitFor, waitForAbsence, expectOutcome
    UITestError.swift        // errors that stop a test after a failed wait
  Onboarding/
    OnboardingPage.swift     // the welcome and sign-in screens
    SignInUITests.swift
  Settings/
    SettingsPage.swift
    NotificationSettingsUITests.swift
```

- One page object per feature, such as Onboarding, Settings, or Contacts, in its own file in that
  feature's test folder.
- One shared driver owns the `XCUIApplication`, launch and relaunch, app-wide navigation such as
  the tab bar, and the wait and tap helpers. It knows no feature's screens. Page objects use the
  driver; they do not copy its helpers.
- A page never holds another feature's steps. A test that crosses features uses each feature's
  page.
- Group test files by feature, as the app groups its sources.

## Shape

```swift
/// The onboarding feature: the welcome screen and the sign-in screen.
@MainActor
struct OnboardingPage {
    let driver: UITestApp

    // MARK: Elements

    var email: XCUIElement { driver.app.textFields["Email"] }
    var password: XCUIElement { driver.app.secureTextFields["Password"] }
    var submit: XCUIElement { driver.app.buttons["Sign In"] }
    var invalidCredentialsError: XCUIElement { driver.app.staticTexts["Check your email and password."] }

    // MARK: Actions

    /// Enters credentials and submits them once.
    /// - Parameters:
    ///   - email: A test account's email address.
    ///   - password: The test account's password, never a real one.
    /// - Throws: A missing or unavailable control.
    func signIn(email: String, password: String) throws {
        try driver.tap(self.email)
        self.email.typeText(email)
        try driver.tap(self.password)
        self.password.typeText(password)
        try driver.tap(submit)
    }

    // MARK: Expectations

    /// Confirms the sign-in screen is on screen.
    /// - Throws: A missing field.
    func expectSignIn(file: StaticString = #filePath, line: UInt = #line) throws {
        try driver.waitFor(email, file: file, line: line)
        try driver.waitFor(password, file: file, line: line)
    }
}
```

Rules:

- Use a `struct` that is `@MainActor`. It stores no state except the driver.
- Elements are computed properties, so each read queries the current tree.
- Actions that move to another feature return that feature's page when it helps the test read
  as a flow. Mark the return `@discardableResult`.
- Each expectation such as `expectSignIn()` uses an element only that screen has. A shared
  navigation title is not enough when two screens use it.
- Document why a query has its shape (a container scope, a predicate, a normalized tap point).
  The next person who changes the UI needs that reason.
- Keep assertions about the behavior under test in the test, not in the page object.
  Page objects assert only that a screen is shown.

## Tests

```swift
@MainActor
final class SignInUITests: XCTestCase {
    /// Wrong credentials show an error and do not save a session that a relaunch restores.
    func testInvalidCredentialsShowAnErrorWithoutSigningIn() throws {
        let app = UITestApp()
        defer { app.terminate() }
        try app.launch()

        let onboarding = OnboardingPage(driver: app)
        try onboarding.openSignIn()
        try onboarding.signIn(email: "test@example.com", password: "wrong-password")

        try app.waitFor(onboarding.invalidCredentialsError)
        app.relaunch()
        try onboarding.expectWelcome()
    }
}
```

- One behavior per test; the name says the outcome.
- XCTest finds test methods by their Objective-C selector, which must start with `test`. A
  method with a raw identifier name (`` func `test Sign in fails` `` ) needs an explicit
  `@objc(test…)` selector.
- Helpers throw. A test function is `throws` and uses `try` for each step.
- Put a flow on the page of the feature that owns it, such as signing in on the Onboarding page.
  Never put it in the driver or in a base class with many flags that subclasses override.
- A test that only needs to start signed in launches in a prepared state instead of driving
  another feature's screens (see `state-and-idempotency.md`).

## When to add a page object

Each feature that the tests use has a page. Add it with the feature's first test that needs more
than one query. A single test that only checks one label can query the screen directly.
