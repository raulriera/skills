# Diagnosing failures

## Find the simulator the run used

With parallel testing on, `xcodebuild` boots `Clone N of <device>` and deletes it after the run.
The base simulator's Keychain, permissions database, containers, and logs then say nothing
about the failure.

- Look for "Clone" in the `xcodebuild` log and in `~/Library/Logs/CoreSimulator/CoreSimulator.log`.
- Collect evidence from inside the run: the result bundle, or a log stream on the device the run
  used.

## Read the result bundle

```sh
xcrun xcresulttool get test-results tests --path <bundle>.xcresult
xcrun xcresulttool get test-results activities --test-id '<Class>/<method>' --path <bundle>.xcresult
```

Activities give each query, tap, and its time. Screenshots attached on failure show the screen.

## Make failure messages useful

- Name the element and the expectation: "Expected the Details screen (title 'Details')".
- When a wait fails, include the visible static texts (first 15 labels) so the message shows
  which screen was really there.
- Pass `file` and `line` from the test so the failure points at the test step.

## Flaky test procedure

1. Run the test alone several times, then in the full plan. Note which one fails.
2. Check the start state: did the reset run before services started?
3. Check readiness: did the action wait for `isHittable`, `isEnabled`, and the data?
4. Check moving content: did a scroll or a late load move the element?
5. Check external state: network, provider limits, remote items from an earlier run.
6. Fix the cause. Do not raise a timeout or add a retry as the fix.

## Regression tests

- See the new test fail on the code without the fix before you trust it.
- Test the path the user hit (the screen and the action), not only the layer the fix changed.
  A test built from the fix's own reasoning proves the reasoning, not that the bug is gone.
