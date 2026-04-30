# Changelog

All notable changes to this project are documented here.

Format: `[version] - YYYY-MM-DD` followed by change categories. Versions follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added

- `Start-ChromeDebug.ps1` — standalone script to kill Chrome, clear the session restore flag, relaunch with `--remote-debugging-port=9222`, and verify the debug endpoint responds. Replaces the manual PowerShell block previously provided as a one-off troubleshooting command.
- `Write-StageLog` — lightweight wrapper that adds stage and category markers to CMTrace log messages for lifecycle, browser, DOM extraction, validation, and output parsing events.
- `Get-SelectorRegistry` — central selector registry with fallback mappings for the diary date, nutrient tables, nutrient names, nutrient values, and nutrient units.
- `Test-NutritionExtractionPayload` — explicit required field validation for the DOM payload before the final output object is returned.
- `Invoke-RetryableNutritionExtraction` — bounded retry wrapper around DOM extraction and validation for page readiness timing issues.
- Output schema metadata fields: `SchemaVersion`, `ValidationStatus`, `RequiredFieldsPresent`, `MissingRequiredFields`, `ExtractionAttemptsUsed`, and `OutputMetadata`.

### Changed

- Default `UserDataDir` changed from the real Chrome profile (`Google\Chrome\User Data`) to a dedicated persistent profile (`Google\Chrome\CronometerDebug`) in both `Start-ChromeDebug.ps1` and `Invoke-CronometerMonitor.ps1`. The real profile directory holds a lock that prevents Chrome from binding the debug port even when launched with the correct flags. The dedicated profile avoids the lock, persists the Cronometer login session between runs, and does not interfere with normal Chrome usage.
- Added `--remote-debugging-address=0.0.0.0` and `--remote-allow-origins=*` to the Chrome launch arguments in both scripts. Newer Chrome versions require these flags for the debug port to accept WebSocket connections.
- Changed all debug endpoint URLs from `http://localhost:PORT/json` to `http://127.0.0.1:PORT/json`. On Windows, `localhost` can resolve to the IPv6 address `::1` while Chrome binds only to the IPv4 address `127.0.0.1`, causing connection refused errors.
- `Get-NutritionDataViaDOM` now returns selector diagnostics and missing signal metadata along with the extracted nutrient payload.
- `Start-CronometerMonitor` now retries extraction up to three times with a short wait when the page is open but required DOM fields are not ready yet.
- `ConvertFrom-NutritionResponse` now standardizes the output schema at version `2.0` and surfaces validation state instead of treating all partial extraction results as generic `NoDataFound`.
- `README.md` updated to document the hardened DOM workflow, validation behavior, retry behavior, and the expanded output schema.
- `future-upgrades.md` updated to mark Tier 1 extraction hardening complete and shift the near term focus to tests and the next service layer work.

---

## [0.3.0] - 2026-04-30

### Changed

- `Get-NutritionDataViaDOM` is now the sole extraction method. The GWT-RPC network injection approach (`Get-NutritionDataViaNetwork`) was removed after DevTools analysis confirmed Cronometer uses a proprietary GWT-RPC serialization format with no single endpoint that returns pre-summed daily nutrition totals. Totals are calculated client-side by the browser; the DOM scrape reads the already-rendered values.
- `ConvertFrom-NutritionResponse` fully rewritten to parse the new DOM extraction format: `{ date, nutrients: { name: { value, unit } } }`. Now extracts 34 individual named nutrient fields plus a full `Nutrients` array.
- `Start-CronometerMonitor` simplified to call `Get-NutritionDataViaDOM` directly with no fallback chain.
- Output object `Date` field renamed to `DiaryDate` and now reflects the date string displayed in the Cronometer UI (e.g. "Apr 28") rather than the `-Date` parameter value.
- `ExtractionMethod` on the output object is now always `DOM`.

### Added

- Named output fields for all tracked nutrients: `NetCarbsGrams`, `SugarsGrams`, `AddedSugarsGrams`, `SaturatedFatGrams`, `TransFatGrams`, `CholesterolMg`, `WaterG`, `CalciumMg`, `IronMg`, `MagnesiumMg`, `PhosphorusMg`, `ZincMg`, `CopperMg`, `ManganeseMg`, `SeleniumUg`, `VitaminA_ug`, `VitaminC_mg`, `VitaminD_IU`, `VitaminE_mg`, `VitaminK_ug`, `B1_Thiamine_mg`, `B2_Riboflavin_mg`, `B3_Niacin_mg`, `B5_PantothenicAcid_mg`, `B6_Pyridoxine_mg`, `B12_Cobalamin_ug`, `Folate_ug`.
- `Get-NVal` helper inside `ConvertFrom-NutritionResponse` for safe nutrient property lookup.
- DOM selectors confirmed from live page analysis: `.diary-date-btn` for the displayed date, `table.targets-table` for all six nutrient panels, `.nutrient-name` for labels, `.targets-table-number .gwt-HTML` for values, `td:nth-child(3) .gwt-Label` for units.

### Removed

- `Get-NutritionDataViaNetwork` — GWT-RPC injection approach removed. Cronometer's API uses Java GWT-RPC serialization (`getDayInfo`, `getAllFood`, `getDailyMacroTargetTemplate`) with no direct nutrition totals endpoint.
- `-Date` parameter removed from `ConvertFrom-NutritionResponse`. Date is now read from the live DOM.

---

## [0.2.1] - 2026-04-29

### Added

- `Clear-ChromeSessionRestore` — edits the Chrome `Default\Preferences` file before launch to set `exit_type` to `Normal` and `exited_cleanly` to `true`, preventing the session restore prompt when Chrome is killed and relaunched.

### Changed

- `Connect-ChromeForDebugging` now kills any running Chrome processes before relaunching and calls `Clear-ChromeSessionRestore` between the kill and the launch so Chrome starts clean without the restore dialog.

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
