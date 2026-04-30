# 001 DOM Extraction Hardening Requirements

## Change Summary

Create the first formal spec package for this repo and use it to define the next meaningful improvement area: making the current Chrome plus DOM extraction workflow more reliable without changing the architecture.

## Current Baseline

1. `Invoke-CronometerMonitor.ps1` connects to a live Chrome debug session and reads Cronometer diary totals from the rendered page DOM.
2. The repo is usable for manual local automation today.
3. Selector drift and page readiness are the main known risks.
4. There are no automated tests and no prior spec package.

## Functional Requirements

1. The repo must keep `Invoke-CronometerMonitor.ps1` as the main entry point.
2. The repo must keep DOM extraction from a live Cronometer page as the default data acquisition path.
3. Future hardening work must improve failure handling when the diary page is open but required DOM elements are missing or not ready.
4. Future hardening work must make it easier to diagnose selector drift or partial page load issues from logs or output status.
5. Documentation for future hardening work must describe how to reproduce the target scenario with a live Chrome debug session.

## Non Functional Requirements

1. Changes must remain compatible with PowerShell 5.1 and 7.x.
2. Default automation must remain local only and must not depend on Cronometer credentials stored in the repo.
3. CI must stay safe for GitHub hosted runners and avoid authenticated live Cronometer checks.
4. Spec driven workflow files must be understandable without scanning the full repo history.

## Non Goals

1. Replacing DOM extraction with direct API integration.
2. Packaging the repo as a module or installer.
3. Building cloud hosted execution.
4. Solving every future upgrade item in this spec package.

## Acceptance Signals

1. The repo contains a reusable GitHub Spec scaffold under `.github/`, `docs/`, and `specs/`.
2. Future contributors can start from `specs/001-dom-extraction-hardening/` and understand the next intended work area.
3. The README points readers at the spec driven workflow.
