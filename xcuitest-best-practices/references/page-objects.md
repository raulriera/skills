# Page objects

A page object holds what one screen knows: how to find its elements, the actions a person can
take on it, and how to tell that it is on screen. Tests then read as user steps.

## Layout

```
<App>UITests/
  Support/
    UITestApp.swift          // launch, relaunch, tap, waitFor, waitForAbsence, expectOutcome
    UITestError.swift        // errors that stop a test after a failed wait
  Screens/
    WelcomeScreen.swift
    SignInScreen.swift
    HomeScreen.swift
  Onboarding/
    SignInUITests.swift
```

- One page object per screen or sheet, in its own file.
- One shared driver owns the `XCUIApplication`, launch and relaunch, and the wait and tap helpers.
  Page objects use the driver; they do not copy its helpers.
- Group test files by feature, as the app groups its sources.

## Shape

```swift
/// The sign-in screen, where a person enters an email address and a password.
@MainActor
struct SignInScreen {
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
    func expectShown(file: StaticString = #filePath, line: UInt = #line) throws {
        try driver.waitFor(email, file: file, line: line)
        try driver.waitFor(password, file: file, line: line)
    }
}
```

Rules:

- Use a `struct` that is `@MainActor`. It stores no state except the driver.
- Elements are computed properties, so each read queries the current tree.
- Actions that move to another screen return that screen's page object when it helps the test
  read as a flow. Mark the return `@discardableResult`.
- `expectShown()` uses an element only that screen has. A shared navigation title is not enough
  when two screens use it.
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

        let signIn = try WelcomeScreen(driver: app).openSignIn()
        try signIn.signIn(email: "test@example.com", password: "wrong-password")

        try app.waitFor(signIn.invalidCredentialsError)
        app.relaunch()
        try WelcomeScreen(driver: app).expectShown()
    }
}
```

- One behavior per test; the name says the outcome.
- XCTest finds test methods by their Objective-C selector, which must start with `test`. A
  method with a raw identifier name (`` func `test Sign in fails` `` ) needs an explicit
  `@objc(test…)` selector.
- Helpers throw. A test function is `throws` and uses `try` for each step.
- Put a shared flow that most tests need (sign in, finish onboarding) in the driver or in a
  small flow type, not in a base class with many flags that subclasses override.

## When to add a page object

Add one when a second test uses the same screen, or when a test's queries need comments to
explain them. A single test that only checks one label can query the screen directly.
