---
name: logging-best-practices
description: Use when adding or reviewing logging in Swift code that uses the Logbook package — log calls, levels, metadata, redaction, bootstrap/flush wiring, or logging in tests. Symptoms: values interpolated into log messages, personal data (email, phone, token) reaching logs, metadata keys that hide what a value is, print() in app code.
license: MIT
metadata:
  author: Raul Riera
  version: "1.0"
---

# Logging Best Practices

## Overview

[Logbook](https://github.com/raulriera/Logbook) fans every entry out to the
unified log, an in-memory ring buffer, and rotating files — after a middleware
chain scrubs it. Middleware only sees `metadata`, so everything below exists to
keep sensitive values where middleware can catch them.

## The contract at every call site

1. **The message is a constant.** Every variable goes in `metadata`. A value
   interpolated into the message reaches Console and the exported file exactly
   as written — middleware never sees it.
2. **Keys name the value truthfully.** `SensitiveKeyRedactor` matches *keys*
   (`token`, `key`, `secret`, `password`, `credential`, `seed`, `mnemonic`,
   `phone`, `email`). `"email": user.email` is scrubbed; `"account":
   user.email` leaks to every sink. If the value is an email, the key says
   `email` — this is also what makes logs greppable.
3. **Log personal data only on the line that needs it.** A failure being
   investigated earns an identifier; a happy-path "sync succeeded" does not.
4. **One `private static let log = Log("CategoryName")` per type or feature
   area.** The name is the Console category filter. Never `print()`, never a
   bare `os.Logger` — neither reaches the ring buffer, the file, or middleware.

```swift
// ❌ message carries values; key hides that the value is an email; PII on the happy path
Self.log.info("Sync started for \(account.email)")
Self.log.error("Sync failed", metadata: ["account": account.email])

// ✅
Self.log.info("Sync started")
Self.log.error("Sync failed", metadata: [
    "email": account.email,          // key-matched, so the redactor scrubs it
    "endpoint": endpoint.absoluteString,
    "error": "\(error)",
])
```

## Levels

| Level | Records |
|---|---|
| `trace` | finest-grained control flow; off in release builds |
| `debug` | worth seeing while working on this code, and not after |
| `info` | worth knowing when reading a normal session back |
| `notice` | out of the ordinary, not yet wrong |
| `warning` | something wrong the app absorbed and carried on from |
| `error` | a failure the user can feel |
| `critical` | a failure the app cannot carry on past |

## App wiring

- `Logbook.bootstrap(subsystem:configuration:)` runs first thing in the app's
  init, before anything logs, with `SensitiveKeyRedactor()` in `middleware` —
  add `PatternRedactor()` where emails or phone numbers can appear under
  innocent keys. Before bootstrap, metadata is dropped rather than risked.
- `await Logbook.flush()` as the app leaves the foreground — lines batch
  before reaching disk, and a part-filled batch dies with the process.
- From an app extension, pass the host app's subsystem explicitly; the default
  would name the extension.

## Tests

Configuration sets `files: nil`, or points `directory` at a temporary one. A
test never writes the real `Caches/Logs`.

## Common mistakes

| Mistake | Fix |
|---|---|
| `log.error("Failed: \(error)")` | constant message; `"error": "\(error)"` in metadata |
| `"account": user.email` | the key is `email` — redaction matches keys |
| email or user id on success lines | identifiers only where an investigation needs them |
| `print()` or bare `os.Logger` | a `Log` — nothing else reaches every sink or middleware |
| tests writing real log files | `files: nil`, or a temporary `directory` |
