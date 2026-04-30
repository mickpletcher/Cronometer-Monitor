# Changelog

All notable changes to this project are documented here.

Format: `[version] - YYYY-MM-DD` followed by change categories. Versions follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

Changes staged but not yet assigned a version.

---

## [0.2.0] - 2026-04-29

### Changed

- Rewrote `Invoke-CronometerMonitor.ps1` from credential-based authentication to Chrome DevTools Protocol (CDP) session attachment. The script no longer stores or prompts for Cronometer credentials.
- Replaced the `Invoke-CronometerLogin` and `Get-CronometerCredential` functions with `Connect-ChromeForDebugging` and `Get-ChromeDebugEndpoint`.
- Replaced the direct `Invoke-RestMethod` GraphQL call with page-side `fetch()` injection via `Runtime.evaluate` CDP command. Auth cookies are inherited from the live browser session automatically.
- Replaced `ConvertFrom-CronometerDiaryResponse` with `ConvertFrom-NutritionResponse`, which now computes remaining values for all four macros and includes fiber, sodium, and potassium fields.

### Added

- `Connect-ChromeForDebugging` — launches Chrome with `--remote-debugging-port` and `--user-data-dir` pointing at the real user profile.
- `Get-ChromeDebugEndpoint` — queries `http://localhost:9222/json` and returns the open tab list.
- `Get-CronometerTab` — finds the Cronometer tab from the tab list by URL pattern.
- `Invoke-ChromeDevToolsCommand` — opens a WebSocket to a tab's CDP debugger URL, sends a CDP command, and returns the parsed response. Compatible with PS5.1 and PS7 using `System.Net.WebSockets.ClientWebSocket`.
- `Get-NutritionDataViaNetwork` — primary extraction path. Injects a `fetch()` call into the page context to call the Cronometer diary API with the browser's existing auth cookies.
- `Get-NutritionDataViaDOM` — fallback extraction path using `document.querySelector` selectors for when the network path fails.
- `-LaunchChrome` switch parameter to optionally launch Chrome before connecting.
- `-DebuggingPort` parameter (default `9222`).
- `-ChromePath` parameter (default standard x64 install path).
- `-UserDataDir` parameter (default `%LOCALAPPDATA%\Google\Chrome\User Data`).
- `CaloriesRemaining`, `ProteinRemainingGrams`, `CarbohydratesRemaining`, and `FatRemainingGrams` fields on the output object.
- `FiberGrams`, `SodiumMg`, and `PotassiumMg` fields on the output object.
- `ExtractionMethod` field on the output object indicating `Network` or `DOM`.
- `PLAN.md` — full architecture diagram, build plan, output schema, and placeholder reference table.
- `ANALYSIS.md` — analysis of the original credential-based approach documenting what worked, what failed, and root causes.

### Removed

- `Invoke-CronometerLogin` — login via credentials is no longer used.
- `Get-CronometerCredential` — credential loading and saving removed entirely.
- `Save-CronometerCredential` — no longer needed.
- `New-CronometerWebSession` — `WebRequestSession` is no longer used.
- `Get-CronometerDiaryQueryDefinition` — replaced by inline query in `Get-NutritionDataViaNetwork`.
- `Invoke-CronometerDiaryRequest` — replaced by CDP injection.
- `Get-CronometerErrorDetail` — HTTP error extraction helper no longer needed.
- `Save-CronometerErrorResponse` — replaced by `Save-RawResponse`.
- `-Credential` parameter.
- `-CredentialPath` parameter.
- `-ErrorResponsePath` parameter.

### Fixed

- Removed the `ReadAsStringAsync()` call on a disposed `HttpConnectionResponseContent` object that caused a warning on every PS7 run in the previous version.

---

## [0.1.0] - 2026-04-29

### Added

- `Invoke-CronometerMonitor.ps1` — initial credential-based implementation.
  - `Write-CMTraceLog` — CMTrace-compatible log writer with Info, Warning, and Error severity levels.
  - `Get-CronometerCredential` — resolves credentials from parameter, encrypted XML file, or interactive prompt with optional save.
  - `Save-CronometerCredential` — persists `PSCredential` to disk using `Export-Clixml`.
  - `New-CronometerWebSession` — creates a `WebRequestSession` for cookie persistence.
  - `Invoke-CronometerLogin` — POSTs credentials to `https://cronometer.com/login`.
  - `Get-CronometerDiaryQueryDefinition` — builds a placeholder GraphQL payload for the diary query.
  - `Invoke-CronometerDiaryRequest` — POSTs the GraphQL query to the assumed diary endpoint.
  - `Save-CronometerRawResponse` — persists the raw API response to disk for schema inspection.
  - `Get-CronometerMetricValue` — safely coerces nullable response values to `double`.
  - `Get-CronometerErrorDetail` — extracts HTTP status code, content type, and response body from error records.
  - `Save-CronometerErrorResponse` — writes non-JSON or error response bodies to a text file.
  - `ConvertFrom-CronometerDiaryResponse` — parses diary totals and evaluates against goals.
  - `Start-CronometerMonitor` — main orchestration function.
  - Parameters: `-Date`, `-Credential`, `-CredentialPath`, `-LogPath`, `-RawResponsePath`, `-ErrorResponsePath`, `-ForceRawDump`, `-ProteinGoalGrams`, `-CalorieGoal`, `-CarbohydrateGoalGrams`, `-FatGoalGrams`.
- `README.md` stub with project name and one-line description.
- `LICENSE` (MIT).

---

## [0.0.1] - 2026-04-29

### Added

- Repository initialized with `LICENSE` and stub `README.md`.
