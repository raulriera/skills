---
name: reflect
description: Write a reflection about a situation that got out of hand during this session
disable-model-invocation: true
argument-hint: "[short-topic-name]"
---

# Write a Reflection

Document a situation from this session where things went off track — a wrong turn, an over-engineered fix, a regression introduced — so the same mistake isn't repeated. Reflections are blameless and specific: the goal is a rule you'd follow next time, not a confession.

## Steps

1. **Get today's real date** — run `date +%F`. Don't guess it; the date is easy to get wrong from memory.

2. **Create the reflection file** at `.claude/reflections/<date>-$ARGUMENTS.md` (e.g. `2026-06-08-give-flow-currency-selection.md`), using this structure:

```
# <Descriptive Title>

**Date:** YYYY-MM-DD

## The Bug / Task

What was the original problem or request?

## Root Cause

What was actually causing the issue — the real cause, not the symptom.

## What Went Wrong

### Attempt 1: <short label>
What was tried, *why it seemed reasonable at the time*, and what actually broke.

Repeat `### Attempt N` for each misstep. The value is in showing why each plausible-looking path failed — that's what stops it being retried.

## Lessons

Numbered, actionable rules to apply next time (e.g. "Reuse the state already resolved upstream instead of re-fetching from cache"), not vague regrets ("be more careful").
```

3. **Update the index** at `.claude/reflections/index.md` — append one line at the bottom (entries run oldest → newest):

```
- [YYYY-MM-DD - <Title>](<date>-$ARGUMENTS.md): one-sentence summary of the misstep.
```

4. **If `index.md` doesn't exist**, create it with this header first, then add the entry:

```
# Reflections

A log of situations where things got out of hand. Each entry documents the issue, missteps, and how it was resolved.
```
