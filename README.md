# Cronometer Monitor

PowerShell tool that connects to an authenticated Chrome browser session and extracts daily nutrition and diary data from Cronometer. No credentials are stored. The script attaches to the existing Chrome session using the Chrome DevTools Protocol and reads data directly from the authenticated page context.

---

## How It Works

Chrome exposes a remote debugging interface when launched with `--remote-debugging-port`. The script connects to that interface, finds the open Cronometer tab, and injects a `fetch()` call into the page. Because the fetch runs inside the browser, it inherits the existing auth cookies automatically. The response is parsed and returned as a structured object with consumed totals, remaining values, and goal comparisons.

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

Run the script with `-LaunchChrome`. This closes and relaunches Chrome with remote debugging pointed at your real user profile so your existing Cronometer login is preserved.

```powershell
.\Invoke-CronometerMonitor.ps1 -LaunchChrome
```

Chrome will open to `cronometer.com`. Log in if prompted, then run the script again without `-LaunchChrome` for all future runs as long as Chrome stays open.

### Option B: Launch Chrome manually

Close Chrome completely, then run this once from PowerShell:

```powershell
$chromePath  = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$userDataDir = "$env:LOCALAPPDATA\Google\Chrome\User Data"

Start-Process -FilePath $chromePath -ArgumentList @(
    '--remote-debugging-port=9222',
    "--user-data-dir=`"$userDataDir`"",
    'https://cronometer.com'
)
```

Verify it is working:

```powershell
Invoke-RestMethod -Uri 'http://localhost:9222/json'
```

You should see a JSON array of open tabs. If a Cronometer tab is listed, the connection is ready.

---

## Usage

### Pull today's diary

```powershell
.\Invoke-CronometerMonitor.ps1
```

### Pull a specific date

```powershell
.\Invoke-CronometerMonitor.ps1 -Date '2026-04-28'
```

### Force a fresh raw response dump for schema inspection

```powershell
.\Invoke-CronometerMonitor.ps1 -ForceRawDump
```

### Launch Chrome and pull today's diary in one command

```powershell
.\Invoke-CronometerMonitor.ps1 -LaunchChrome -ForceRawDump
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

---

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `DebuggingPort` | int | `9222` | Chrome remote debugging port |
| `ChromePath` | string | `C:\Program Files\Google\Chrome\Application\chrome.exe` | Path to chrome.exe |
| `UserDataDir` | string | `%LOCALAPPDATA%\Google\Chrome\User Data` | Chrome profile directory used when `-LaunchChrome` is specified |
| `LaunchChrome` | switch | off | Launch Chrome with remote debugging before connecting |
| `Date` | datetime | today | Diary date to query |
| `LogPath` | string | `.\logs\CronometerMonitor.log` | CMTrace-compatible log file |
| `RawResponsePath` | string | `.\logs\CronometerDiaryRawResponse.json` | Path for raw API response dump |
| `ForceRawDump` | switch | off | Overwrite the raw response file even if it exists |
| `ProteinGoalGrams` | double | `150` | Daily protein goal in grams |
| `CalorieGoal` | double | `2200` | Daily calorie goal |
| `CarbohydrateGoalGrams` | double | `200` | Daily carbohydrate goal in grams |
| `FatGoalGrams` | double | `70` | Daily fat goal in grams |

---

## Output

The script returns a `PSCustomObject` with the following properties:

| Property | Type | Description |
|---|---|---|
| `Date` | string | Query date in `yyyy-MM-dd` format |
| `CaloriesConsumed` | double | Total calories logged |
| `CaloriesRemaining` | double | Calories left to reach goal |
| `CalorieGoal` | double | Daily calorie goal |
| `ProteinGrams` | double | Protein consumed |
| `ProteinRemainingGrams` | double | Protein left to reach goal |
| `ProteinGoalGrams` | double | Daily protein goal |
| `CarbohydratesGrams` | double | Carbohydrates consumed |
| `CarbohydratesRemaining` | double | Carbohydrates left to reach goal |
| `CarbohydrateGoalGrams` | double | Daily carbohydrate goal |
| `FatGrams` | double | Fat consumed |
| `FatRemainingGrams` | double | Fat left to reach goal |
| `FatGoalGrams` | double | Daily fat goal |
| `FiberGrams` | double | Fiber consumed |
| `SodiumMg` | double | Sodium consumed in milligrams |
| `PotassiumMg` | double | Potassium consumed in milligrams |
| `Nutrients` | object[] | All tracked micronutrients: `{ Name, Unit, Value }` |
| `Alerts` | string[] | One entry per macro that is below its daily goal |
| `QueryStatus` | string | `Parsed` when data was extracted, `SchemaNeedsRefinement` if the response path was not found |
| `ExtractionMethod` | string | `Network` (preferred) or `DOM` (fallback) |

### Example output

```
Date                   : 2026-04-29
CaloriesConsumed       : 1640
CaloriesRemaining      : 560
CalorieGoal            : 2200
ProteinGrams           : 132.4
ProteinRemainingGrams  : 17.6
ProteinGoalGrams       : 150
CarbohydratesGrams     : 178.2
CarbohydratesRemaining : 21.8
CarbohydrateGoalGrams  : 200
FatGrams               : 54.1
FatRemainingGrams      : 15.9
FatGoalGrams           : 70
FiberGrams             : 22.3
SodiumMg               : 1840
PotassiumMg            : 3120
Nutrients              : { ... }
Alerts                 : { Protein below goal: 132.4g consumed / 150g goal (17.6g remaining),
                           Calories below goal: 1640 consumed / 2200 goal (560 remaining) }
QueryStatus            : Parsed
ExtractionMethod       : Network
```

### Capture the result for downstream use

```powershell
$nutrition = .\Invoke-CronometerMonitor.ps1
$nutrition.Alerts
$nutrition | ConvertTo-Json -Depth 5
```

---

## Logs

All activity is written to a CMTrace-compatible log file at `.\logs\CronometerMonitor.log` by default. The log can be opened in CMTrace or the Configuration Manager log viewer for real-time viewing. Each entry includes timestamp, severity (Info / Warning / Error), thread ID, and execution context.

The raw API response is saved to `.\logs\CronometerDiaryRawResponse.json` on first run, or whenever `-ForceRawDump` is used. This file is useful for inspecting the actual response schema if the parsed output shows `QueryStatus: SchemaNeedsRefinement`.

---

## Pending Configuration

The GraphQL endpoint URL and query fields in `Get-NutritionDataViaNetwork` are placeholders. The script will run but will return `QueryStatus: SchemaNeedsRefinement` until these are updated with values captured from a live browser session.

### How to capture the real API call

1. Launch Chrome with remote debugging (Option A or B above).
2. Log into Cronometer and navigate to the diary.
3. Open DevTools with `F12` and go to the Network tab.
4. Filter by Fetch/XHR.
5. Click any diary date to trigger a data load.
6. Find the POST request to the diary endpoint. It will have a JSON body.
7. Copy the full request URL.
8. Copy the request body (contains `operationName`, `variables`, and `query`).
9. Click the Response tab and copy the full JSON response body.

### What to update in the script

In `Get-NutritionDataViaNetwork`:

```powershell
# Replace with the real endpoint URL
$graphqlEndpoint = 'https://cronometer.com/graphql'

# Replace with the real operation name, variables, and query string
$graphqlQuery = @'
{
  "operationName": "YourRealOperationName",
  "variables": { "date": "PLACEHOLDER_DATE" },
  "query": "your real query string here"
}
'@
```

In `ConvertFrom-NutritionResponse`:

```powershell
# Replace with the real JSON property path from the captured response
$totals = $parsed.data.diary.totals
```

After updating, run with `-ForceRawDump` to confirm real data is returned and the output object populates correctly.

---

## File Structure

```
Cronometer-Monitor\
    Invoke-CronometerMonitor.ps1    Main script
    CHANGELOG.md                    Version history and change log
    PLAN.md                         Architecture and build plan
    ANALYSIS.md                     Original analysis of the project
    README.md                       This file
    logs\
        CronometerMonitor.log       CMTrace-formatted activity log
        CronometerDiaryRawResponse.json   Raw API response for schema inspection
```

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full version history and a record of all changes.

---

## License

MIT
