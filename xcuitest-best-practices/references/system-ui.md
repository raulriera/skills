# System UI

## Permission alerts

Permission alerts run in SpringBoard, not in the app.

```swift
let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
try tap(springboard.buttons["Allow"])   // wait for isHittable: the alert animates in
```

- A prompt shows only while the status is undetermined. To test it, reset the resource before
  launch: `app.terminate()`, then `app.resetAuthorizationStatus(for:)`, then `app.launch()`.
- The alert can take longer to appear on a loaded CI host. Poll for either the alert or the next
  app screen; fail only when neither appears.
- Some system pickers run in their own process. Query that process by bundle identifier. A query
  against a process that is not running returns an empty tree, so polling several hosts is safe.
  Do not call `activate()` on them; it moves them to the foreground.
- Do not use `addUIInterruptionMonitor` to dismiss alerts in general. An unexpected alert must fail.

## Share sheets

Share sheet actions run in the app's process and are `cells`, not `buttons`:

```swift
try tap(app.cells["Copy"])
```

File preview labels in the sheet may not be in the tree. Check the action cells instead.

## App alerts and confirmation dialogs

Scope the button to its alert: `app.alerts["Delete Draft?"].buttons["Delete"]`. Button labels
like "OK", "Cancel", and "Continue" repeat across screens.

## Background and foreground

The Home button does not send the app to the background on every device (for example on a
foldable inner display). Open SpringBoard instead, then check the app's state:

```swift
XCUIApplication(bundleIdentifier: "com.apple.springboard").activate()
guard app.wait(for: .runningBackground, timeout: 10) else {
    XCTFail("The app did not enter the background")
    throw UITestError.unexpectedState
}
app.activate()
guard app.wait(for: .runningForeground, timeout: 10) else {
    XCTFail("The app did not return to the foreground")
    throw UITestError.unexpectedState
}
```

## URLs and deep links

`app.open(url)` delivers a URL through the system. It does **not** apply `launchArguments` or
`launchEnvironment`. If the app is not running, it starts without the reset flag.

1. Call `launch()` first, with the reset flag, and wait for the start screen.
2. Then call `app.open(url)`.
3. Wait for an element that proves the URL was handled. The app can show its default screen
   before the handler runs.

## Clipboard

`UIPasteboard.general` in the test process writes the simulator clipboard. A system paste
prompt can appear when the app reads it; a SwiftUI `PasteButton` avoids the prompt. The
simulator clipboard can sync with the Mac.

## Keyboard

The Simulator and CI hosts can attach a hardware keyboard, so the software keyboard may not appear.
Do not tap software keyboard keys. Use `typeText`, including `"\n"` for the return key.
