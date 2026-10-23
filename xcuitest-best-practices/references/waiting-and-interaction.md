# Waiting and interaction

## Stop the test on a failed wait

Helpers record the failure, then throw, so no dependent step runs:

```swift
/// Errors that stop a UI test after a failed wait has been recorded.
enum UITestError: Error {
    case missingElement, unexpectedElement, unavailableControl, unexpectedState, reportedError
}
```

`continueAfterFailure = false` also stops the test, but only for failures XCTest records itself.

## Existence is not readiness

`waitForExistence` checks the accessibility tree only. An element can exist while it animates,
sits behind a sheet, or is disabled. Wait for all three conditions, then tap once.

```swift
func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) throws {
    let ready = NSPredicate(format: "exists == true AND isHittable == true AND isEnabled == true")
    let expectation = XCTNSPredicateExpectation(predicate: ready, object: element)
    guard XCTWaiter.wait(for: [expectation], timeout: 10) == .completed else {
        XCTFail("\(element) did not become ready", file: file, line: line)
        throw UITestError.unavailableControl
    }
    element.tap()
}
```

Pass `file` and `line` through every helper so Xcode shows the failure on the test's line.

## Absence is a result too

Wait for an outgoing element to leave with `waitForNonExistence(timeout:)`. Use it to prove a
push finished, a sheet closed, or a deleted row is gone.

## UI ready is not data ready

A button can appear before its data loads. On CI the gap is larger. Wait for a state that proves
the data is there (a balance, a row, a title), not only for the button.

## Expected result or reported error

When an action can end in a result or an error alert, wait for either one. Fail at once when the
alert appears, instead of waiting for the full timeout.

```swift
let errorTitles = ["Couldn't Connect", "Too Many Requests"]
let outcome = NSPredicate(format: "label == %@", "Home")
let errors = errorTitles.map { NSPredicate(format: "label == %@", $0) }
let either = NSCompoundPredicate(orPredicateWithSubpredicates: [outcome] + errors)
try waitFor(app.descendants(matching: .any).matching(either).firstMatch)
if let title = errorTitles.first(where: { app.alerts[$0].exists }) {
    XCTFail("The app showed \(title) instead of Home")
    throw UITestError.reportedError
}
```

## Optional screens

Some screens appear only in some states (a permission prompt that was already answered). Do not
wait the full timeout for them. Poll for either the optional screen or the next required screen,
and act on the one that appears.

```swift
let deadline = Date.now.addingTimeInterval(30)
while !allow.waitForExistence(timeout: 1) {
    if nextScreen.exists { return }
    guard Date.now < deadline else {
        XCTFail("Neither the permission prompt nor the next screen appeared")
        throw UITestError.missingElement
    }
}
try tap(allow)
```

## Retries

Retry only a read-only action, or an action whose idempotency you can prove. After a timeout,
check if the action already took effect before you try again. Never repeat create, save, send,
or pay. A test that checks a retry must assert that the app reused the same identity.

## Scrolling to an element

An element below the fold exists but is never hittable. Waiting for `isHittable` does not scroll.

- Swipe the container with `swipeUp(velocity: .slow)`. A fast swipe still moves after the call
  returns, so the tap lands on another element.
- Limit the number of swipes and fail with a clear message.
- After the scroll, wait until the element's frame stops changing when content loads async
  (balances, recent activity).

```swift
var swipes = 0
while !element.isHittable, swipes < 8 {
    container.swipeUp(velocity: .slow)
    swipes += 1
}
guard element.isHittable else {
    XCTFail("\(element) stayed off screen after 8 swipes")
    throw UITestError.unavailableControl
}
```

## Duplicate labels

A sheet's button and the button behind it can share a label. Scope the query by container
(`app.sheets`, `app.alerts["Title"]`, `app.navigationBars["Title"]`), or take the first hittable
match. Try these before you add an identifier.

## Custom gestures

`tap()` sends a touch at the element's center. It does not trigger an accessibility activation.
A slide-to-confirm control with `.accessibilityRepresentation { Button … }` looks like a button
but ignores a tap. Drag it:

```swift
let track = app.buttons["Swipe to Send"]
let start = track.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5))
let end = track.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
start.press(forDuration: 0.1, thenDragTo: end)
```

Make sure the control is enabled first. A disabled view ignores the drag too.

## Stacked or overlapping elements

When views overlap (a fanned card stack), the frame center can belong to the element on top.
Tap a normalized offset that only the target covers, and say why in a doc comment.

## Text entry

- Tap the field and wait for it before `typeText`.
- End with `"\n"` only when the return key's action is part of the flow under test.
- Secure fields expose a placeholder as `value` until text is entered; assert on that, not on
  the typed text.

## Timeouts

- Use one default timeout (10 s) for local UI changes.
- Use a longer, named timeout only for network work, and document why.
- Do not raise a timeout to fix a flaky test before you find the cause.
