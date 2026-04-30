# Cronometer Monitor Implementation Plan

**Last updated:** 2026-04-29

---

## Section 1: Project Summary

### Problem

The original approach (POST credentials to the login endpoint, then hit a GraphQL URL) failed because the GraphQL endpoint URL was a guess and returned 404. Solving this requires either finding the real endpoint or taking a different approach entirely.

The new approach eliminates credential handling completely. Chrome already has an authenticated Cronometer session. The script attaches to that session, injects a fetch call into the page context (which inherits the auth cookies), and reads the response.

### What the system must do

1. Connect to an existing Chrome browser running with remote debugging on port 9222.
2. Find the open Cronometer tab.
3. Inject a fetch request into the page using Chrome DevTools Protocol (CDP) so the call runs with the browser's existing auth cookies.
4. Capture the diary API response.
5. Parse calories consumed, calories remaining, and all macro and micronutrients.
6. Compare values against user-defined daily goals.
7. Return a structured object suitable for use in n8n, Windows Task Scheduler, or direct console output.
8. Log all activity in CMTrace format.

### Constraints

- No Cronometer credentials stored anywhere.
- Native PowerShell only. No third-party modules.
- Must work on PS5.1 and PS7.
- Chrome must be running with `--remote-debugging-port=9222` and the real user profile directory.
- The GraphQL query and endpoint URL are still placeholders pending DevTools capture.

### Technologies

- Chrome DevTools Protocol (CDP) over WebSocket
- `System.Net.WebSockets.ClientWebSocket` (.NET, available in PS5.1+)
- `Invoke-RestMethod` for the `/json` tab list endpoint
- CMTrace log format
- `Runtime.evaluate` CDP method to execute JavaScript in page context

---

## Section 2: Architecture

```
Chrome (authenticated session, port 9222)
        |
        | HTTP GET http://localhost:9222/json
        v
Get-ChromeDebugEndpoint   -- returns list of open tabs
        |
        v
Get-CronometerTab         -- finds cronometer.com tab, gets webSocketDebuggerUrl
        |
        | WebSocket connection to tab's debugger URL
        v
Invoke-ChromeDevToolsCommand
        |
        | Runtime.evaluate (injects fetch into page context)
        v
Get-NutritionDataViaNetwork  -- primary path
        |
        | on failure
        v
Get-NutritionDataViaDOM      -- DOM selector fallback
        |
        v
ConvertFrom-NutritionResponse  -- parse JSON, compute remaining, build alerts
        |
        v
Save-RawResponse (optional)
        |
        v
Structured PSCustomObject output
```

### Why inject via Runtime.evaluate

Direct PowerShell HTTP calls to the diary API require session cookies. Extracting those cookies from Chrome and replaying them in PowerShell is fragile (cookie jar format, CSRF tokens, rotating tokens). Injecting a `fetch()` call into the live page context is simpler: the browser handles auth, cookies, and headers automatically. The script just reads the result.

---

## Section 3: Build Plan

### Phase 1: Chrome remote debugging setup (manual, one-time)

**Task 1.1** Close all running Chrome instances completely.

**Task 1.2** Launch Chrome with remote debugging:

```powershell
$chromePath  = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$userDataDir = "$env:LOCALAPPDATA\Google\Chrome\User Data"

Start-Process -FilePath $chromePath -ArgumentList @(
    '--remote-debugging-port=9222',
    "--user-data-dir=`"$userDataDir`"",
    'https://cronometer.com'
)
```

Or use the script's `-LaunchChrome` switch once.

**Task 1.3** Verify the debug endpoint responds:

```powershell
Invoke-RestMethod -Uri 'http://localhost:9222/json'
```

Expect a JSON array of open tabs. If you see a Cronometer tab, Phase 1 is done.

### Phase 2: Capture the real API call (manual, one-time)

**Task 2.1** With Chrome open and logged into Cronometer, open DevTools (F12).

**Task 2.2** Go to the Network tab. Filter by Fetch/XHR.

**Task 2.3** Click to any diary date in Cronometer. Watch for a POST request.

**Task 2.4** Click the POST request and inspect:
- Full URL (copy it)
- Request payload (the JSON body including `operationName`, `variables`, `query`)
- Response body (the full JSON)

**Task 2.5** Copy the complete `query` string. Note the field names under the response (calories, protein, carbohydrates, fat, and any nutrient array structure).

**Task 2.6** Update these two locations in `Invoke-CronometerMonitor.ps1`:
- `$graphqlEndpoint` in `Get-NutritionDataViaNetwork` (replace with real URL)
- `$graphqlQuery` in `Get-NutritionDataViaNetwork` (replace with real operation and fields)
- Property paths in `ConvertFrom-NutritionResponse` under `# PLACEHOLDER`

### Phase 3: Validate end-to-end

**Task 3.1** Run with `-ForceRawDump` and inspect `logs\CronometerDiaryRawResponse.json`. Confirm the correct data came back.

**Task 3.2** Update the field paths in `ConvertFrom-NutritionResponse` to match the actual response structure.

**Task 3.3** Confirm the output object contains correct values for calories, protein, carbs, fat, fiber, sodium, potassium.

**Task 3.4** Run without `-ForceRawDump`. Confirm normal operation.

### Phase 4: Downstream integration (future)

**Task 4.1** Pipe result to n8n via a webhook POST.

**Task 4.2** Schedule via Windows Task Scheduler for a daily summary.

**Task 4.3** Add a Windows toast notification for alerts (macros below goal).

---

## Section 4: PowerShell Script

See `Invoke-CronometerMonitor.ps1`.

### Key functions

| Function | Responsibility |
|---|---|
| `Connect-ChromeForDebugging` | Launches Chrome with `--remote-debugging-port` if needed |
| `Get-ChromeDebugEndpoint` | GETs `http://localhost:9222/json`, returns tab list |
| `Get-CronometerTab` | Finds the Cronometer tab by URL pattern |
| `Invoke-ChromeDevToolsCommand` | Opens a WebSocket to the tab's CDP URL, sends one command, returns response |
| `Get-NutritionDataViaNetwork` | Primary path: injects `fetch()` into page context via `Runtime.evaluate` |
| `Get-NutritionDataViaDOM` | Fallback: reads rendered text values via `document.querySelector` |
| `ConvertFrom-NutritionResponse` | Parses raw JSON, computes remaining values, builds alert list |
| `Save-RawResponse` | Persists raw JSON to disk for schema inspection |
| `Start-CronometerMonitor` | Orchestrates all steps |

### Output object

```
Date                    string    yyyy-MM-dd
CaloriesConsumed        double
CaloriesRemaining       double
CalorieGoal             double
ProteinGrams            double
ProteinRemainingGrams   double
ProteinGoalGrams        double
CarbohydratesGrams      double
CarbohydratesRemaining  double
CarbohydrateGoalGrams   double
FatGrams                double
FatRemainingGrams       double
FatGoalGrams            double
FiberGrams              double
SodiumMg                double
PotassiumMg             double
Nutrients               object[]   { Name, Unit, Value }
Alerts                  string[]   one per macro below goal
QueryStatus             string     'Parsed' | 'SchemaNeedsRefinement'
ExtractionMethod        string     'Network' | 'DOM'
```

### Placeholders still active

| Location | What to replace |
|---|---|
| `Get-NutritionDataViaNetwork` `$graphqlEndpoint` | Real GraphQL URL |
| `Get-NutritionDataViaNetwork` `$graphqlQuery` | Real operation name, variables, query string |
| `Get-NutritionDataViaDOM` selectors | Real CSS selectors from the Cronometer UI |
| `ConvertFrom-NutritionResponse` `$totals = $parsed.data.diary.totals` | Real JSON path from captured response |

---

## Section 5: Next Actions

### What to do in Chrome DevTools

1. Launch Chrome with the script (`-LaunchChrome`) or manually with `--remote-debugging-port=9222`.
2. Log into Cronometer if not already logged in.
3. Open DevTools, Network tab, filter Fetch/XHR.
4. Click any diary date to trigger a data load.
5. Find the POST to the diary/graphql endpoint. It will have a JSON request body with `operationName` or a query string.
6. Right-click the request, "Copy as cURL" or "Copy request body" for the payload.
7. Click the response tab and copy the full JSON body.

### What to update in the script after capture

**In `Get-NutritionDataViaNetwork`:**

```powershell
# Replace:
$graphqlEndpoint = 'https://cronometer.com/graphql'

# With the real URL, e.g.:
$graphqlEndpoint = 'https://cronometer.com/api/cronometer/v3/graphql'
```

```powershell
# Replace the $graphqlQuery here-string with the real payload, e.g.:
$graphqlQuery = @'
{
  "operationName": "DiaryTotals",
  "variables": { "date": "PLACEHOLDER_DATE" },
  "query": "query DiaryTotals($date: Date!) { diary(date: $date) { totals { calories protein carbohydrates fat fiber sodium potassium nutrients { name unit value } } } }"
}
'@
```

**In `ConvertFrom-NutritionResponse`:**

```powershell
# Replace:
$totals = $parsed.data.diary.totals

# With the real path, e.g.:
$totals = $parsed.data.diaryDay.nutritionValues
```

Update individual field names (`$totals.calories`, `$totals.protein`, etc.) to match the real response property names.

Once those two edits are in, run with `-ForceRawDump` and verify the output object contains real values.
