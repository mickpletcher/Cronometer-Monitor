# Cronometer Monitor Assessment

**Assessment date:** 2026-04-30  
**Repository:** `Cronometer-Monitor`

## Purpose

This project is a local-first PowerShell automation that reads nutrition totals from an authenticated Cronometer browser session and returns them as structured PowerShell output for downstream automation.

The current implementation does **not** log into Cronometer directly and does **not** use a stable public API. Instead, it connects to a Chrome instance running with remote debugging enabled, attaches to the open Cronometer tab through the Chrome DevTools Protocol (CDP), executes JavaScript in the page, reads the rendered nutrition tables from the DOM, and converts that data into a structured object with goals, remaining macros, alerts, and a nutrient list.

This is the key architectural truth a chatbot should preserve when working in this repo:

- The repo started with a credential-based / GraphQL-style approach.
- That earlier approach was abandoned.
- The current working design is **DOM extraction from a live Cronometer page via CDP**.

## Executive Summary

The repo is small, focused, and already usable for manual or scheduled local automation if Chrome is running in the expected debug mode and the Cronometer diary page is open. The main script is parse-valid and the README and changelog generally match the current implementation.

The most important maintenance risk is not PowerShell correctness. It is external UI dependency:

- The extractor depends on Cronometer DOM structure and CSS selectors.
- If Cronometer changes the diary page markup, extraction can break.
- There is currently no automated test harness or selector validation layer to detect that early.

The second major repo-level issue is documentation drift between current and historical files:

- `README.md` reflects the current DOM-based design.
- `CHANGELOG.md` clearly documents the migration history and is useful.
- `ANALYSIS.md` and parts of `PLAN.md` still describe the older GraphQL/network-injection path and should be treated as historical background, not current source of truth.

## Current State

## What is implemented

- Main script: `Invoke-CronometerMonitor.ps1`
- Chrome bootstrap helper: `Start-ChromeDebug.ps1`
- CMTrace-compatible logging
- Chrome remote debugging connection
- Cronometer tab discovery through `http://127.0.0.1:<port>/json`
- CDP `Runtime.evaluate` execution in the page
- DOM scraping of rendered nutrient tables
- Structured result object with macro goals, remaining values, alerts, and named micronutrients
- Optional raw response dump to `logs\CronometerDiaryRawResponse.json`

## What is not implemented

- Direct authenticated Cronometer API integration
- Stable network interception pipeline
- Automated tests
- Schema validation
- Retry logic around DOM extraction or delayed page readiness
- Historical storage
- Local API wrapper
- CLI packaging beyond direct script execution

## Recommended source-of-truth order

When a chatbot needs project context, it should trust files in this order:

1. `Invoke-CronometerMonitor.ps1`
2. `README.md`
3. `CHANGELOG.md`
4. `Start-ChromeDebug.ps1`
5. `future-upgrades.md`
6. `PLAN.md` and `ANALYSIS.md` only for historical context

## Architecture

## Runtime flow

1. Optional: launch Chrome with remote debugging enabled.
2. Query the Chrome tab list from `http://127.0.0.1:9222/json` by default.
3. Find the open tab whose URL matches `cronometer.com`.
4. Open the tab's `webSocketDebuggerUrl`.
5. Send a CDP `Runtime.evaluate` command containing a JavaScript DOM-scraping function.
6. Return JSON shaped like:

```json
{
  "date": "Apr 28",
  "nutrients": {
    "Energy": { "value": "1625.3", "unit": "kcal" }
  }
}
```

1. Parse that JSON in PowerShell.
2. Compute remaining calories, protein, carbs, and fat against configured goals.
3. Emit a `PSCustomObject`.
4. Log the run to `logs\CronometerMonitor.log`.

## Why this approach exists

This architecture exists because Cronometer does not expose a simple stable endpoint for daily totals in a way that was straightforward to reuse from native PowerShell. Earlier repo work tried to authenticate and call guessed backend endpoints. The project later pivoted to scraping the rendered client-side totals because the browser already has the authenticated session and the UI already contains the fully calculated values.

## Core Script Assessment

## Main script

`Invoke-CronometerMonitor.ps1` is the real heart of the repo. It is currently the strongest artifact in the project.

Strengths:

- Uses `CmdletBinding`, strict mode, and explicit error handling.
- Separates responsibilities into focused functions.
- Uses only native PowerShell and .NET types.
- Supports configurable goals and debug settings.
- Produces an automation-friendly output object.
- Writes operational logs in a format that is useful for troubleshooting.
- Parsed successfully with the PowerShell parser during this assessment.

Important functions:

- `Write-CMTraceLog`: writes structured operational log lines.
- `Clear-ChromeSessionRestore`: prevents Chrome's restore-tabs prompt after forced restarts.
- `Connect-ChromeForDebugging`: launches Chrome with the required debug flags.
- `Get-ChromeDebugEndpoint`: reads the list of open Chrome tabs.
- `Get-CronometerTab`: finds the Cronometer tab.
- `Invoke-ChromeDevToolsCommand`: sends a CDP command over WebSocket.
- `Get-NutritionDataViaDOM`: executes the DOM scraper in page context.
- `ConvertFrom-NutritionResponse`: converts raw extracted JSON into the final output object.
- `Save-RawResponse`: preserves raw extraction output for troubleshooting.
- `Start-CronometerMonitor`: orchestrates the whole run.

## Current selectors and assumptions

The current DOM extraction relies on these selectors and page assumptions:

- Date element: `.diary-date-btn`
- Nutrient tables: `table.targets-table`
- Nutrient names: `.nutrient-name`
- Nutrient values: `.targets-table-number .gwt-HTML`
- Units: `td:nth-child(3) .gwt-Label`

These are implementation-critical. If Cronometer changes these selectors or table structure, the script may return `NoDataFound` or silently degrade to zeros for missing nutrient names.

## Output schema

The current script returns a PowerShell object with:

- Diary metadata: `DiaryDate`, `QueryStatus`, `ExtractionMethod`
- Goal data: `CalorieGoal`, `ProteinGoalGrams`, `CarbohydrateGoalGrams`, `FatGoalGrams`
- Macro totals and remaining values
- A broad set of named micronutrient properties
- `Alerts` array

Notable current output fields include:

- `CaloriesConsumed`
- `CaloriesRemaining`
- `ProteinGrams`
- `ProteinRemainingGrams`
- `CarbsGrams`
- `NetCarbsGrams`
- `FatGrams`
- `FiberGrams`
- `SodiumMg`
- `PotassiumMg`
- `VitaminC_mg`
- `VitaminD_IU`
- `B12_Cobalamin_ug`

One important nuance: `ConvertFrom-NutritionResponse` builds an `allNutrients` array but does not currently place that array on the returned object. The README says a `Nutrients` property exists, but the current script does not include `Nutrients` in the final `PSCustomObject`. That is a real documentation/implementation mismatch.

## Supporting Files

## `README.md`

Status: mostly current and useful.

It accurately describes:

- Chrome-debugging-based architecture
- No credential storage
- Use of a dedicated Chrome debug profile
- Required flags and commands
- Main parameters and output intent

Mismatch noted:

- README documents a `Nutrients` property on output.
- Current script does not actually return `Nutrients`.

## `CHANGELOG.md`

Status: strong and useful.

It captures the project history well, especially:

- initial credential-based approach
- migration to Chrome/CDP
- removal of network injection
- move to DOM-only extraction
- switch to dedicated `CronometerDebug` Chrome profile
- IPv4 `127.0.0.1` usage instead of `localhost`

This file is very helpful for understanding why the repo looks the way it does today.

## `PLAN.md`

Status: partially stale.

Useful for:

- understanding the intended evolution of the project
- seeing the previous mental model and planned architecture

Not current for:

- network-first extraction assumptions
- placeholder GraphQL guidance
- fallback flow that still references network extraction

Treat this as a design-history file, not as an operational runbook.

## `ANALYSIS.md`

Status: historical and stale.

It documents the earlier credential/API attempt and correctly explains why that version failed, but it does not describe the current implementation anymore. A chatbot should not use this file as current repo truth except when explaining project history.

## `future-upgrades.md`

Status: local planning document, not tracked.

This file outlines a meaningful future direction:

- selector hardening
- session reliability
- schema validation
- local API
- automation integrations
- storage
- packaging

It is useful for roadmap context, but it is intentionally local-only via `.gitignore`.

## `Start-ChromeDebug.ps1`

Status: useful operational helper.

It mirrors the launch behavior from the main script and gives a simpler manual path to:

- stop Chrome
- clear restore state
- relaunch with the correct debug flags
- verify the debug endpoint

## Scratch / local utility artifacts

These appear to be temporary or exploratory rather than durable product assets:

- `debug.ps1`
- `newflags.ps1`
- `tempprofile.ps1`
- `error_output.txt`
- `prompt-browser-session-cronometer.md`
- `CronometerMonitorBuildPrompt.md`

They are useful for development history and local troubleshooting, but they are not core runtime entry points.

## Repo Layout

Current notable files at repo root:

- `Invoke-CronometerMonitor.ps1`: main extractor
- `Start-ChromeDebug.ps1`: Chrome launch helper
- `README.md`: usage and architecture
- `CHANGELOG.md`: change history
- `PLAN.md`: historical design plan
- `ANALYSIS.md`: historical analysis of abandoned API approach
- `future-upgrades.md`: local roadmap, ignored
- `logs\`: ignored runtime artifacts

## Behavior and Operational Model

## Preconditions for success

For the current script to work, all of these must be true:

- Chrome is installed at the expected path or `-ChromePath` is overridden.
- Chrome is running with the remote debug port enabled.
- A Cronometer tab is open.
- The user is already authenticated in that Chrome debug profile.
- The diary page is showing the date the user wants.
- The nutrition summary tables are rendered and visible enough for the DOM scraper to find them.

## Typical workflow

1. Run `Start-ChromeDebug.ps1` or `Invoke-CronometerMonitor.ps1 -LaunchChrome`.
2. Use the dedicated Chrome debug profile to log into Cronometer if needed.
3. Navigate to the target diary date.
4. Run `.\Invoke-CronometerMonitor.ps1`.
5. Consume the returned object or inspect logs/raw output.

## Main Risks and Weaknesses

## 1. DOM fragility

This is the primary technical risk. The extractor is tightly coupled to Cronometer's current page structure and class names.

Impact:

- A UI update can break extraction without any repo code changes.
- Failures may appear as missing values, zero values, or `NoDataFound`.

## 2. No automated tests

There are currently no unit, integration, or contract tests.

Impact:

- Regressions are likely to be detected only during manual use.
- Refactoring confidence is low.

## 3. Docs drift across historical files

The repo contains both current and old architectural narratives.

Impact:

- A chatbot that scans every Markdown file without prioritization could infer the wrong architecture.
- Contributors could spend time on outdated GraphQL assumptions.

## 4. README/output mismatch

`README.md` says the output includes `Nutrients`, but the current returned object does not expose it.

Impact:

- Downstream automation built from README expectations may fail.

## 5. Local-only maturity

This project is currently built around a single-user Windows workstation workflow.

Impact:

- It is usable as a personal automation tool.
- It is not yet a robust shared service or packaged application.

## Opportunities for Improvement

Highest-value next steps based on the current codebase:

1. Add `Nutrients` back to the returned object or remove it from the README.
2. Create selector validation and fallback handling around the DOM scraper.
3. Add lightweight test fixtures using saved raw responses and parser-only tests.
4. Separate durable docs from historical docs more clearly.
5. Add a stable machine-readable export shape, ideally with a schema version.
6. Add structured failure categories for debug endpoint failure, missing tab, selector miss, and parse miss.

## Assessment of Project Quality

## What is good

- Clear, narrow problem scope
- Practical pivot away from a failing design
- Low dependency surface
- Good logging discipline
- Thoughtful Windows-focused operational handling
- Useful changelog
- Strong enough documentation for manual usage

## What is immature

- Validation and tests
- Boundary between current docs and historical docs
- Production-hardening around page-load timing and UI drift
- Packaging for broader reuse

## Best description of maturity

This is a good personal automation tool with a sound current tactic, but it is still in an early reliability stage rather than a fully hardened reusable product.

## Guidance for Future Chatbot Sessions

If a chatbot uses this file instead of rescanning the repo, it should assume:

- The current implementation is PowerShell-only.
- The extraction path is DOM scraping through Chrome DevTools Protocol.
- No credentials should be reintroduced unless explicitly requested.
- `Invoke-CronometerMonitor.ps1` is the primary artifact to modify.
- `Start-ChromeDebug.ps1` is the main helper for Chrome startup issues.
- `README.md` and `CHANGELOG.md` are current enough to trust, with the single known mismatch around `Nutrients`.
- `ANALYSIS.md` and much of `PLAN.md` are historical context only.
- `future-upgrades.md` is a local roadmap and may not exist in a clean clone because it is gitignored.

When making future changes, prefer:

- preserving the current DOM/CDP design unless a clearly better stable extraction method is proven
- additive hardening over architectural rewrites
- updating this file when the repo meaningfully changes

## Snapshot Notes From This Assessment

As of 2026-04-30:

- `Invoke-CronometerMonitor.ps1` parsed successfully with the PowerShell parser.
- `.gitignore` excludes `logs/`, `*.credential.xml`, and `future-upgrades.md`.
- The git worktree was not completely clean during assessment:
  - `.gitignore` was modified
  - `Invoke-CronometerMonitor_OLD.ps1` was shown as deleted

Those git state details are just a point-in-time observation, not enduring project architecture.
