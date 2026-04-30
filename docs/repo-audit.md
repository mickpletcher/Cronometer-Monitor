<!-- markdownlint-disable MD013 -->

# Repository Audit

## Summary

This repository is a local first PowerShell automation for extracting Cronometer diary nutrition data from an already authenticated Chrome session. It is not a packaged service and it is not currently an API client. The live architecture is Chrome remote debugging plus DOM extraction through Chrome DevTools Protocol.

## Folder Structure

| Path | Purpose |
| --- | --- |
| `Invoke-CronometerMonitor.ps1` | Main entry point that connects to Chrome, reads the page, and returns structured nutrition output |
| `Start-ChromeDebug.ps1` | Helper that launches Chrome with remote debugging enabled |
| `logs/` | Local runtime logs and optional raw response dumps |
| `README.md` | Current usage and workflow guide |
| `CHANGELOG.md` | Historical change record |
| `PLAN.md` | Historical build plan from the earlier network based direction |
| `ANALYSIS.md` | Historical analysis from the earlier network based direction |
| `specs/` | Spec packages for future non trivial work |
| `docs/` | Repo level audit and support docs |

## Current Entry Points

| Entry Point | Purpose |
| --- | --- |
| `Invoke-CronometerMonitor.ps1` | Run extraction against the currently open Cronometer diary page |
| `Start-ChromeDebug.ps1` | Start Chrome in the required debug mode for the main script |

## Languages And Runtime

1. PowerShell 5.1 and 7.x
2. Native .NET types for WebSocket and HTTP interaction
3. Google Chrome with remote debugging enabled

## Current Architecture

1. Query Chrome tabs from `http://127.0.0.1:<port>/json`.
2. Find the open Cronometer tab.
3. Connect to the tab `webSocketDebuggerUrl`.
4. Run JavaScript in page context with CDP `Runtime.evaluate`.
5. Read rendered diary totals from the DOM.
6. Convert the response into PowerShell output with goals, remaining values, and alerts.

## Documentation State

Strengths:

1. `README.md` reflects the current DOM based design.
2. `CHANGELOG.md` explains the pivot from older ideas to the current implementation.
3. `assessment.md` captures the repo status accurately and should help future maintenance.

Gaps:

1. `PLAN.md` and `ANALYSIS.md` still describe an older network request direction and should be treated as historical background.
2. There was no repo specific GitHub Spec scaffold before this retrofit.
3. There is still no automated live smoke test for selector drift, which is the biggest functional risk.

## Main Risks

1. Cronometer DOM selector drift can break extraction without warning.
2. Page readiness timing can produce empty results if the nutrient tables are not fully loaded.
3. Local only runtime assumptions make CI limited to parse and static analysis checks.

## Retrofit Outcome

This retrofit adds:

1. Repo specific Copilot instructions
2. Reusable GitHub prompt files for spec driven work
3. A baseline numbered spec package
4. A safe CI workflow for PowerShell parse and analyzer checks

## Recommended Next Technical Follow Up

1. Build a selector readiness layer with clearer failure modes.
2. Add a fixture driven parser test path for `ConvertFrom-NutritionResponse`.
3. Refresh or archive the outdated historical plan files once the current direction settles.

<!-- markdownlint-enable MD013 -->
