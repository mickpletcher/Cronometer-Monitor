# Cronometer Monitor Copilot Instructions

## Scope

This repository is an existing PowerShell automation that extracts Cronometer diary data from a live Chrome session through Chrome DevTools Protocol. Treat it as a retrofit first repo, not a greenfield app.

## Core Rules

1. Preserve the current DOM extraction architecture unless a spec explicitly replaces it.
2. Favor additive changes over rewrites.
3. Do not reintroduce credential based login or guessed API calls as the default path.
4. Keep the main entry point at `Invoke-CronometerMonitor.ps1`.
5. Keep support scripts focused on local browser startup and diagnostics.

## Architecture Rules

1. The current source of truth is the PowerShell script plus the live Cronometer page DOM.
2. Browser session reuse is intentional. Do not add secret storage or cookie replay unless the spec requires it.
3. If selectors or timing logic change, update the README and spec package in the same change.
4. Prefer native PowerShell and .NET types. Avoid third party module dependencies unless a spec justifies them.

## Naming Conventions

1. PowerShell functions use approved verbs and `Verb-Noun`.
2. New specs live under `specs/NNN-short-kebab-name/`.
3. Repo docs should describe the current behavior first and proposed behavior second.

## Testing Expectations

1. Parse validation is the minimum gate for PowerShell edits.
2. Changes that affect DOM extraction should include at least one local smoke test against a live Cronometer page when feasible.
3. Keep CI safe for machines without Cronometer access. No live authenticated checks in default automation.

## Documentation Rules

1. Keep `README.md` aligned with the current script behavior.
2. Treat `PLAN.md` and `ANALYSIS.md` as historical context unless they are deliberately refreshed.
3. Record non trivial repo shaping work under `specs/`.

## Spec Driven Delivery Requirement

All future non trivial work should align to a spec package:

1. Create or update `requirements.md`
2. Create or update `spec.md`
3. Create or update `plan.md`
4. Create or update `tasks.md`
5. Implement only what the spec covers
6. Audit the implementation against the spec
7. Run regression checks before merge

If code and spec disagree, update one of them deliberately.
