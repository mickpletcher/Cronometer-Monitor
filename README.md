# Cronometer Monitor

PowerShell tool that connects to an authenticated Chrome browser session and extracts daily nutrition and diary data from Cronometer. No credentials are stored. The script attaches to the existing Chrome session using the Chrome DevTools Protocol and reads data directly from the rendered page.

---

## How It Works

Chrome exposes a remote debugging interface when launched with `--remote-debugging-port`. The script connects to that interface, finds the open Cronometer tab, and uses the Chrome DevTools Protocol to execute JavaScript inside the page. The JavaScript reads the rendered nutrition summary panels from the DOM and returns all nutrient values, units, selector diagnostics, and the displayed diary date as a JSON object. The script validates required fields, retries a few times if the page is not ready yet, and returns a structured PowerShell object with a schema version and extraction metadata.

Cronometer's backend uses a proprietary GWT-RPC serialization format. There is no single API endpoint that returns pre-summed daily nutrition totals. The browser calculates totals client-side and renders them into the page. DOM scraping is the correct and reliable approach.

The script reads whatever diary date is currently displayed in the Chrome window. To extract a different date, navigate to it in Chrome before running the script.

### Reliability features

- Fallback DOM selectors for the diary date, nutrient tables, nutrient names, nutrient values, and units
- Required field validation for `Energy`, `Protein`, `Carbs`, and `Fat`
- Bounded retry behavior when the page is open but the nutrition table is not ready yet
- Stage based logging with category markers for browser, extraction, validation, parsing, and lifecycle events
- Stable output schema with `SchemaVersion`, validation status, retry count, and extraction metadata

---

## Requirements

- Windows 10 or 11
- PowerShell 5.1 or 7.x
- Google Chrome installed
- A Cronometer account with an active logged-in session in Chrome
- No third-party PowerShell modules required

---

## First Run Setup

Chrome must be running with remote debugging enabled. There are two ways to do this.

### Option A: Let the script launch Chrome

Run the script with `-LaunchChrome`. This kills any running Chrome processes, clears the session restore flag so Chrome does not prompt to restore tabs, then relaunches Chrome with remote debugging pointed at your real user profile so your existing Cronometer login is preserved.

```powershell
.\Invoke-CronometerMonitor.ps1 -LaunchChrome
```

Chrome will open to `cronometer.com`. Log in if prompted, then navigate to the diary date you want to extract and run the script again without `-LaunchChrome` for all future runs as long as Chrome stays open.

### Option B: Launch Chrome manually

Close Chrome completely, then run this once from PowerShell:

```powershell
$chromePath  = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$userDataDir = "$env:LOCALAPPDATA\Google\Chrome\CronometerDebug"

Start-Process -FilePath $chromePath -ArgumentList @(
    '--remote-debugging-port=9222',
    '--remote-debugging-address=0.0.0.0',
    '--remote-allow-origins=*',
    "--user-data-dir=`"$userDataDir`"",
    'https://cronometer.com'
)
```

Verify it is working:

```powershell
Invoke-RestMethod -Uri 'http://127.0.0.1:9222/json'
```

You should see a JSON array of open tabs. If a Cronometer tab is listed, the connection is ready.

---

## Usage

### Extract the currently displayed diary date

```powershell
.\Invoke-CronometerMonitor.ps1
```

### Save a raw response dump for inspection

```powershell
.\Invoke-CronometerMonitor.ps1 -ForceRawDump
```

### Write the final structured result to JSON for n8n

```powershell
.\Invoke-CronometerMonitor.ps1
Get-Content .\logs\CronometerMonitorResult.json
```

### Launch Chrome and extract in one command

```powershell
.\Invoke-CronometerMonitor.ps1 -LaunchChrome
```

### Use a non-default Chrome path

```powershell
.\Invoke-CronometerMonitor.ps1 -ChromePath 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
```

### Use a non-default debugging port

```powershell
.\Invoke-CronometerMonitor.ps1 -DebuggingPort 9223
```

### Override daily nutrition goals

```powershell
.\Invoke-CronometerMonitor.ps1 -CalorieGoal 2500 -ProteinGoalGrams 175 -CarbohydrateGoalGrams 250 -FatGoalGrams 80
```

### Capture the result for downstream use

```powershell
$nutrition = .\Invoke-CronometerMonitor.ps1
$nutrition.Alerts
$nutrition | ConvertTo-Json -Depth 5
```

### Open the local dashboard

Run the extractor first so the result JSON exists, then start the local web dashboard:

```powershell
.\Invoke-CronometerMonitor.ps1
.\Start-CronometerDashboard.ps1
```

This opens `http://localhost:8876/dashboard/` and loads `logs\CronometerMonitorResult.json` by default. You can also load any other JSON file from disk, including a richer payload written later by n8n.

### Run the local API

Start the API wrapper:

```powershell
.\Start-CronometerApi.ps1
```

Endpoints:

| Endpoint | Method | Purpose |
| --- | --- | --- |
| `/health` | `GET` | Service status, cache state, and result file status |
| `/api/latest` | `GET` | Latest nutrition payload using in memory cache, recent result file cache, or a fresh extractor run |
| `/api/analysis` | `GET` | Latest nutrition payload plus deterministic scoring from the nutrition target schema |
| `/api/refresh` | `POST` | Force a new browser extraction and refresh the cache |

The API listens on `http://localhost:8878/` by default. Cache TTL defaults to 60 seconds.

Example calls:

```powershell
Invoke-RestMethod -Uri 'http://localhost:8878/health'
Invoke-RestMethod -Uri 'http://localhost:8878/api/latest'
Invoke-RestMethod -Uri 'http://localhost:8878/api/analysis'
Invoke-RestMethod -Method Post -Uri 'http://localhost:8878/api/refresh'
```

Fresh extractions served through the API are also written into `logs\CronometerHistory.sqlite` by default so API-driven workflows build daily history automatically.

If you bind beyond localhost, supply an API key:

```powershell
Set-Content -LiteralPath .\logs\CronometerApi.key -Value 'replace-with-a-secret'
.\Start-CronometerApi.ps1 -BindAddress * -RequireApiKey
Invoke-RestMethod -Uri 'http://127.0.0.1:8878/api/latest' -Headers @{ 'X-API-Key' = 'replace-with-a-secret' }
```

### Use the CLI wrapper

The CLI wrapper exposes the common workflows behind one script instead of calling the extractor and API scripts directly.

```powershell
.\Invoke-CronometerCli.ps1 fetch
.\Invoke-CronometerCli.ps1 history -Limit 7 -Descending
.\Invoke-CronometerCli.ps1 export -Format Csv
.\Invoke-CronometerCli.ps1 analyze
.\Invoke-CronometerCli.ps1 serve
```

Commands:

| Command | Purpose |
| --- | --- |
| `fetch` | Run a fresh extraction, save the normal JSON output, and persist a successful daily snapshot into SQLite |
| `history` | Query stored daily snapshots from SQLite with optional date filters |
| `export` | Export history rows to JSON or CSV |
| `analyze` | Evaluate the latest result against the nutrition target schema and return deterministic scoring |
| `serve` | Start the local API wrapper with the same history store attached |

Examples:

```powershell
.\Invoke-CronometerCli.ps1 fetch -LaunchChrome
.\Invoke-CronometerCli.ps1 history -FromDate '2026-04-01' -ToDate '2026-04-30' -Descending
.\Invoke-CronometerCli.ps1 export -Format Json -IncludePayload -OutputPath .\logs\exports\april-history.json
.\Invoke-CronometerCli.ps1 analyze
.\Invoke-CronometerCli.ps1 serve -Port 8878
```

SQLite history uses Python 3 and the standard library `sqlite3` module under the hood. The public workflow stays in PowerShell.

### Nutrition target analysis

The repo can evaluate extracted intake against [nutrition-targets.schema.json](nutrition-targets.schema.json). This schema includes FDA values plus bariatric specific overrides and is the canonical target source for downstream scoring.

```powershell
.\Invoke-CronometerCli.ps1 analyze
```

The analysis output includes:

| Section | Purpose |
| --- | --- |
| `Summary` | Count of deficient, excess, optimal, and missing nutrients |
| `PriorityDeficiencies` | Top nutrients below target |
| `LimitAlerts` | Nutrients above a defined max |
| `Nutrients` | Full per nutrient scoring details with targets, percent complete, deficit, or excess |

This is the payload that should be handed to an LLM. The math and comparisons stay deterministic in code.

---

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `DebuggingPort` | int | `9222` | Chrome remote debugging port |
| `ChromePath` | string | `C:\Program Files\Google\Chrome\Application\chrome.exe` | Path to chrome.exe |
| `UserDataDir` | string | `%LOCALAPPDATA%\Google\Chrome\CronometerDebug` | Chrome profile directory used when `-LaunchChrome` is specified |
| `LaunchChrome` | switch | off | Kill existing Chrome, clear session restore flag, and relaunch with remote debugging |
| `LogPath` | string | `.\logs\CronometerMonitor.log` | CMTrace-compatible log file |
| `RawResponsePath` | string | `.\logs\CronometerDiaryRawResponse.json` | Path for raw DOM response dump |
| `ResultJsonPath` | string | `.\logs\CronometerMonitorResult.json` | Path for the final structured result JSON used by downstream tools such as n8n |
| `ForceRawDump` | switch | off | Overwrite the raw response file even if it exists |
| `ProteinGoalGrams` | double | `150` | Daily protein goal in grams |
| `CalorieGoal` | double | `2200` | Daily calorie goal in kcal |
| `CarbohydrateGoalGrams` | double | `200` | Daily carbohydrate goal in grams |
| `FatGoalGrams` | double | `70` | Daily fat goal in grams |

---

## Output

The script returns a `PSCustomObject`. The diary date reflects what is displayed in the Chrome window at the time the script runs.

### Macros and goals

| Property | Type | Description |
| --- | --- | --- |
| `DiaryDate` | string | Date displayed in the Cronometer browser window (e.g. "Apr 28") |
| `CaloriesConsumed` | double | Total energy logged in kcal |
| `CaloriesRemaining` | double | kcal remaining to reach goal |
| `CalorieGoal` | double | Daily calorie goal |
| `ProteinGrams` | double | Protein consumed |
| `ProteinRemainingGrams` | double | Protein remaining to reach goal |
| `ProteinGoalGrams` | double | Daily protein goal |
| `CarbsGrams` | double | Total carbohydrates consumed |
| `NetCarbsGrams` | double | Net carbs (total carbs minus fiber) |
| `CarbsRemainingGrams` | double | Carbs remaining to reach goal |
| `CarbohydrateGoalGrams` | double | Daily carbohydrate goal |
| `FatGrams` | double | Total fat consumed |
| `FatRemainingGrams` | double | Fat remaining to reach goal |
| `FatGoalGrams` | double | Daily fat goal |

### Additional macros

| Property | Type | Description |
| --- | --- | --- |
| `FiberGrams` | double | Dietary fiber |
| `SugarsGrams` | double | Total sugars |
| `AddedSugarsGrams` | double | Added sugars |
| `SaturatedFatGrams` | double | Saturated fat |
| `TransFatGrams` | double | Trans fat |
| `CholesterolMg` | double | Cholesterol in milligrams |
| `WaterG` | double | Water in grams |

### Minerals

| Property | Type | Description |
| --- | --- | --- |
| `SodiumMg` | double | Sodium in milligrams |
| `PotassiumMg` | double | Potassium in milligrams |
| `CalciumMg` | double | Calcium in milligrams |
| `IronMg` | double | Iron in milligrams |
| `MagnesiumMg` | double | Magnesium in milligrams |
| `PhosphorusMg` | double | Phosphorus in milligrams |
| `ZincMg` | double | Zinc in milligrams |
| `CopperMg` | double | Copper in milligrams |
| `ManganeseMg` | double | Manganese in milligrams |
| `SeleniumUg` | double | Selenium in micrograms |

### Vitamins

| Property | Type | Description |
| --- | --- | --- |
| `VitaminA_ug` | double | Vitamin A in micrograms |
| `VitaminC_mg` | double | Vitamin C in milligrams |
| `VitaminD_IU` | double | Vitamin D in IU |
| `VitaminE_mg` | double | Vitamin E in milligrams |
| `VitaminK_ug` | double | Vitamin K in micrograms |
| `B1_Thiamine_mg` | double | Vitamin B1 in milligrams |
| `B2_Riboflavin_mg` | double | Vitamin B2 in milligrams |
| `B3_Niacin_mg` | double | Vitamin B3 in milligrams |
| `B5_PantothenicAcid_mg` | double | Vitamin B5 in milligrams |
| `B6_Pyridoxine_mg` | double | Vitamin B6 in milligrams |
| `B12_Cobalamin_ug` | double | Vitamin B12 in micrograms |
| `Folate_ug` | double | Folate in micrograms |

### Biometrics and diary

| Property | Type | Description |
| --- | --- | --- |
| `Biometrics` | object[] | Biometric rows from the diary such as heart rate, weight, and blood pressure |
| `DiaryGroups` | object[] | Meal and supplement sections with summary totals and nested entries |
| `DiaryEntries` | object[] | Flat list of all meal, food, and supplement rows extracted from the diary |
| `Nutrients` | object[] | Every nutrient on the page as `{ Name, Value, Unit }` |
| `Alerts` | string[] | One entry per macro that is below its daily goal |

### Meta

| Property | Type | Description |
| --- | --- | --- |
| `SchemaVersion` | string | Current output schema version |
| `QueryStatus` | string | `Parsed` when validation passed, `ValidationFailed` when required fields were missing or invalid |
| `ValidationStatus` | string | Validation result for the required field check |
| `RequiredFieldsPresent` | bool | `True` when the required macro fields were extracted and parsed correctly |
| `MissingRequiredFields` | string[] | Missing or invalid required fields |
| `MissingRequiredSummary` | string | Friendly summary of missing required fields. `None` when all required fields were present |
| `ExtractionMethod` | string | Always `DOM` |
| `ExtractionAttemptsUsed` | int | Number of extraction attempts used before returning output |
| `DateSelectorUsed` | string | Selector that matched the diary date element |
| `TablesSelectorUsed` | string | Selector that matched the nutrient tables |
| `NutrientNameSelectorUsed` | string | Selector that matched nutrient labels |
| `NutrientValueSelectorUsed` | string | Selector that matched nutrient values |
| `NutrientUnitSelectorUsed` | string | Selector that matched nutrient units |
| `DiaryGroupSelectorUsed` | string | Selector that matched meal and supplement group header rows |
| `DiaryTimeSelectorUsed` | string | Selector that matched timestamp cells in diary rows |
| `MissingSignalsSummary` | string | Friendly summary of extraction warnings. `None` when no extraction signals were missing |
| `OutputMetadata` | object | Selector matches, selector summary text, nutrient count, biometric count, diary counts, table count, and missing extraction signals |

### Biometrics object shape

Each item in `Biometrics` includes:

| Property | Type | Description |
| --- | --- | --- |
| `Time` | string | Time shown in the diary row |
| `Name` | string | Base metric name such as `Heart Rate` or `Blood Pressure` |
| `Source` | string | Source inside parentheses such as `Withings` or `Apple Health` |
| `DisplayName` | string | Full label from the page |
| `Subtitle` | string | Optional subtitle text such as average and peak values |
| `Value` | string | Raw displayed value |
| `NumericValue` | double | Parsed numeric value when the metric is a single number |
| `Unit` | string | Display unit such as `bpm`, `lbs`, or `mmHg` |
| `Systolic` | double | Parsed systolic value for blood pressure rows |
| `Diastolic` | double | Parsed diastolic value for blood pressure rows |

### Diary group object shape

Each item in `DiaryGroups` includes:

| Property | Type | Description |
| --- | --- | --- |
| `GroupName` | string | Section name such as `Breakfast`, `Lunch`, `Snacks`, or `Supplements/Vitamins` |
| `SummaryText` | string | Raw macro summary text from the group header |
| `Summary` | object | Parsed calories, protein, carbs, and fat totals when present |
| `Entries` | object[] | Rows that belong to the group |

### Diary entry object shape

Each item in `DiaryEntries` and each nested `DiaryGroups[].Entries` item includes:

| Property | Type | Description |
| --- | --- | --- |
| `GroupName` | string | Parent group title |
| `EntryType` | string | `Food`, `Supplement`, or `Unknown` |
| `Time` | string | Time shown in the diary row |
| `Name` | string | Food or supplement name |
| `Quantity` | string | Display quantity |
| `Serving` | string | Serving text |
| `Calories` | double | Parsed calorie value when present |
| `CaloriesText` | string | Raw calorie text from the row |
| `CaloriesUnit` | string | Display unit, usually `kcal` |

### Example output

```text
SchemaVersion          : 2.1
DiaryDate               : Apr 28
CaloriesConsumed        : 1625.3
CaloriesRemaining       : 574.7
CalorieGoal             : 2200
ProteinGrams            : 193.0
ProteinRemainingGrams   : 0
ProteinGoalGrams        : 150
CarbsGrams              : 136.4
NetCarbsGrams           : 73.0
CarbsRemainingGrams     : 63.6
CarbohydrateGoalGrams   : 200
FatGrams                : 58.6
FatRemainingGrams       : 11.4
FatGoalGrams            : 70
FiberGrams              : 34.0
SugarsGrams             : 31.0
AddedSugarsGrams        : 3.0
SaturatedFatGrams       : 26.5
TransFatGrams           : 0.0
CholesterolMg           : 219.5
WaterG                  : 855.3
SodiumMg                : 2615.3
PotassiumMg             : 2039.5
CalciumMg               : 4599.7
IronMg                  : 69.4
MagnesiumMg             : 565.0
VitaminC_mg             : 315.0
VitaminD_IU             : 4235.7
B12_Cobalamin_ug        : 1.8
Biometrics              : { 6 entries }
DiaryGroups             : { 5 entries }
DiaryEntries            : { 14 entries }
Nutrients               : { 38 entries }
Alerts                  : { Calories below goal: 1625 kcal consumed / 2200 kcal goal (575 kcal remaining) }
QueryStatus             : Parsed
ValidationStatus        : Passed
RequiredFieldsPresent   : True
MissingRequiredFields   : {}
MissingRequiredSummary  : None
ExtractionMethod        : DOM
ExtractionAttemptsUsed  : 1
DateSelectorUsed        : .diary-date-btn
TablesSelectorUsed      : table.targets-table
NutrientNameSelectorUsed : .nutrient-name
NutrientValueSelectorUsed : .targets-table-number .gwt-HTML
NutrientUnitSelectorUsed : td:nth-child(3) .gwt-Label
DiaryGroupSelectorUsed   : tr.diary-group-row
DiaryTimeSelectorUsed    : td.diary-time
MissingSignalsSummary   : None
OutputMetadata          : @{SchemaVersion=2.1; SelectorMatchesSummary=Date=.diary-date-btn; Tables=table.targets-table; Name=.nutrient-name; Value=.targets-table-number .gwt-HTML; Unit=td:nth-child(3) .gwt-Label; DiaryGroup=tr.diary-group-row; DiaryTime=td.diary-time; SelectorMatches=...; TableCount=2; NutrientCount=38; BiometricCount=6; DiaryGroupCount=5; DiaryEntryCount=14; MissingSignalsSummary=None; MissingSignals=System.Object[]}
```

---

## Logs

All activity is written to a CMTrace-compatible log file at `.\logs\CronometerMonitor.log` by default. The log can be opened in CMTrace or the Configuration Manager log viewer for real-time viewing. Each entry includes timestamp, severity, thread ID, and execution context.

The script now writes stage and category markers into the message body so you can tell whether a message came from browser discovery, DOM extraction, validation, parsing, retry wait, or run completion.

The raw DOM response is saved to `.\logs\CronometerDiaryRawResponse.json` on first run or whenever `-ForceRawDump` is used. This file contains the full `{ date, nutrients, biometrics, diaryGroups, diaryEntries, metadata }` object extracted from the page and is useful for verifying what the script read from the browser.

For normal console use, the script also promotes the matched selector values and summary fields to top-level properties so you do not need to expand `OutputMetadata` just to see what happened.

On every run, the final structured output object is also written to `.\logs\CronometerMonitorResult.json`. This is the file intended for downstream tools such as n8n.

Successful daily snapshots can also be stored in `.\logs\CronometerHistory.sqlite`. The CLI `fetch` command and fresh API extractions both write to this database.

## History Storage

SQLite snapshot storage keeps one current row per diary day using the displayed Cronometer date as the daily key. Each row stores summary macro fields plus the full structured payload JSON.

Default database path:

```text
.\logs\CronometerHistory.sqlite
```

Stored fields include:

| Field | Description |
| --- | --- |
| `snapshot_key` | Daily key derived from the displayed diary date |
| `snapshot_date_text` | Raw diary date text from Cronometer |
| `snapshot_date_iso` | Best effort normalized date in `yyyy-MM-dd` when parsing succeeds |
| `captured_at_utc` | Last successful write time for that diary day |
| `schema_version` | Output schema version |
| `query_status` | Parsed or failure status |
| `calories_consumed` | Daily calorie total |
| `protein_grams` | Daily protein total |
| `carbs_grams` | Daily carbohydrate total |
| `fat_grams` | Daily fat total |
| `payload_json` | Full structured JSON payload |

## Target Schema

[nutrition-targets.schema.json](nutrition-targets.schema.json) is the canonical target definition for derived analysis. It currently includes:

- FDA daily values and max values
- Bariatric specific minimums, ranges, and target values
- Limit rules for nutrients such as sodium, saturated fat, and added sugars
- Recommendation metadata for later workflow layers

Current built in mappings cover calories, protein, carbohydrates, fiber, fat, omega 3, ALA, DHA, EPA, omega 6, LA, saturated fat, trans fat, cholesterol, sodium, added sugars, vitamin A, vitamin D, vitamin B12, iron, calcium, thiamin B1, folate, zinc, and copper.

Vitamin D is converted from the extractor output unit of IU into the schema unit of mcg before scoring.

Omega fields that are not promoted to top level extractor properties are read from the flat `Nutrients` list during analysis. ALA and LA have numeric targets. Total omega 3, total omega 6, DHA, and EPA are currently informational because the schema does not define standalone official numeric targets for those fields.

## Integrations

Example integration files are included under [examples](examples/):

| Path | Purpose |
| --- | --- |
| `examples\n8n\CronometerApiFlow.json` | n8n workflow that polls `/api/latest` and reshapes the payload |
| `examples\home-assistant\configuration.yaml` | Home Assistant REST sensor and template sensor example |

---

## Tests

Fixture-based regression coverage now exists for the output shaping path.

Run the current tests with:

```powershell
Invoke-Pester -Path .\Tests\CronometerApi.Service.Tests.ps1,.\Tests\Invoke-CronometerMonitor.Output.Tests.ps1,.\Tests\CronometerHistory.Service.Tests.ps1,.\Tests\CronometerAnalysis.Service.Tests.ps1 -CI
```

The current fixture coverage verifies:

- Empty `missingSignals` data renders as `MissingSignalsSummary = None`
- Single-item `missingSignals` data does not fail on scalar versus array shape differences
- Selector display fields are promoted correctly into the top-level output object
- Biometrics and grouped diary rows are preserved in the final shaped output
- SQLite history store creation, persistence, and CSV export
- Schema based nutrient scoring, including bariatric thresholds and vitamin D unit conversion
- Omega nutrient scoring from the flat `Nutrients` list, including ALA and LA targets

---

## Important: Diary Date Selection

The script reads whatever date is currently displayed in the Cronometer browser window. It does not navigate to a date on your behalf. To extract a specific date, navigate to it in Chrome before running the script.

The nutrition summary panels must be visible and fully loaded in the browser for the extraction to return data. If `QueryStatus` is `NoDataFound`, scroll down to the nutrition summary section in Cronometer and run the script again.

---

## File Structure

```text
Cronometer-Monitor\
    Invoke-CronometerMonitor.ps1    Main script
    Invoke-CronometerCli.ps1        CLI wrapper for fetch, history, export, analyze, and serve
    Start-ChromeDebug.ps1           Chrome launcher with remote debugging
    Start-CronometerApi.ps1         Local API wrapper
    CronometerApi.Service.ps1       API cache and auth helpers
    CronometerHistory.Service.ps1   SQLite history helpers
    CronometerAnalysis.Service.ps1  Deterministic nutrient target analysis
    CHANGELOG.md                    Version history and change log
    assessment.md                   Current repo briefing for future work
    nutrition-targets.schema.json   FDA and bariatric target schema
    docs\                           Repo audit and support docs
    specs\                          GitHub Spec packages for non-trivial changes
    Tests\                          Fixture-based regression tests
    examples\                       Example n8n and Home Assistant integrations
    tools\                          SQLite helper used by history storage
    README.md                       This file
    logs\
        CronometerMonitor.log               CMTrace-formatted activity log
        CronometerDiaryRawResponse.json     Raw DOM response for inspection
        CronometerMonitorResult.json        Final structured result JSON for downstream tools
        CronometerHistory.sqlite            Daily snapshot history store
```

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full version history and a record of all changes.

---

## Spec Workflow

Future non trivial work in this repo should start from the GitHub Spec scaffold:

1. Review [docs/repo-audit.md](docs/repo-audit.md)
2. Create or update a numbered package under [specs](specs/)
3. Work through `requirements.md`, `spec.md`, `plan.md`, and `tasks.md`
4. Implement only what the active spec covers
5. Run an audit and a regression pass before merge

The first package is [specs/001-dom-extraction-hardening](specs/001-dom-extraction-hardening/). It captures the next logical improvement area for this project without changing the current Chrome plus DOM extraction design.

---

## License

MIT

