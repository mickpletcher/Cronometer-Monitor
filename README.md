# Cronometer Monitor

PowerShell tool that connects to an authenticated Chrome browser session and extracts daily nutrition and diary data from Cronometer. No credentials are stored. The script attaches to the existing Chrome session using the Chrome DevTools Protocol and reads data directly from the rendered page.

---

## How It Works

Chrome exposes a remote debugging interface when launched with `--remote-debugging-port`. The script connects to that interface, finds the open Cronometer tab, and uses the Chrome DevTools Protocol to execute JavaScript inside the page. The JavaScript reads the rendered nutrition summary panels from the DOM and returns all nutrient values, units, and the displayed diary date as a JSON object. The script parses that response and returns a structured PowerShell object.

Cronometer's backend uses a proprietary GWT-RPC serialization format. There is no single API endpoint that returns pre-summed daily nutrition totals. The browser calculates totals client-side and renders them into the page. DOM scraping is the correct and reliable approach.

The script reads whatever diary date is currently displayed in the Chrome window. To extract a different date, navigate to it in Chrome before running the script.

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

---

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `DebuggingPort` | int | `9222` | Chrome remote debugging port |
| `ChromePath` | string | `C:\Program Files\Google\Chrome\Application\chrome.exe` | Path to chrome.exe |
| `UserDataDir` | string | `%LOCALAPPDATA%\Google\Chrome\CronometerDebug` | Chrome profile directory used when `-LaunchChrome` is specified |
| `LaunchChrome` | switch | off | Kill existing Chrome, clear session restore flag, and relaunch with remote debugging |
| `LogPath` | string | `.\logs\CronometerMonitor.log` | CMTrace-compatible log file |
| `RawResponsePath` | string | `.\logs\CronometerDiaryRawResponse.json` | Path for raw DOM response dump |
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
|---|---|---|
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
|---|---|---|
| `FiberGrams` | double | Dietary fiber |
| `SugarsGrams` | double | Total sugars |
| `AddedSugarsGrams` | double | Added sugars |
| `SaturatedFatGrams` | double | Saturated fat |
| `TransFatGrams` | double | Trans fat |
| `CholesterolMg` | double | Cholesterol in milligrams |
| `WaterG` | double | Water in grams |

### Minerals

| Property | Type | Description |
|---|---|---|
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
|---|---|---|
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

### Meta

| Property | Type | Description |
|---|---|---|
| `Nutrients` | object[] | Every nutrient on the page as `{ Name, Value, Unit }` |
| `Alerts` | string[] | One entry per macro that is below its daily goal |
| `QueryStatus` | string | `Parsed` when nutrients were found, `NoDataFound` if the summary panel was not visible |
| `ExtractionMethod` | string | Always `DOM` |

### Example output

```
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
Nutrients               : { 38 entries }
Alerts                  : { Calories below goal: 1625 kcal consumed / 2200 kcal goal (575 kcal remaining) }
QueryStatus             : Parsed
ExtractionMethod        : DOM
```

---

## Logs

All activity is written to a CMTrace-compatible log file at `.\logs\CronometerMonitor.log` by default. The log can be opened in CMTrace or the Configuration Manager log viewer for real-time viewing. Each entry includes timestamp, severity (Info / Warning / Error), thread ID, and execution context.

The raw DOM response is saved to `.\logs\CronometerDiaryRawResponse.json` on first run or whenever `-ForceRawDump` is used. This file contains the full `{ date, nutrients }` object extracted from the page and is useful for verifying what the script read from the browser.

---

## Important: Diary Date Selection

The script reads whatever date is currently displayed in the Cronometer browser window. It does not navigate to a date on your behalf. To extract a specific date, navigate to it in Chrome before running the script.

The nutrition summary panels must be visible and fully loaded in the browser for the extraction to return data. If `QueryStatus` is `NoDataFound`, scroll down to the nutrition summary section in Cronometer and run the script again.

---

## File Structure

```
Cronometer-Monitor\
    Invoke-CronometerMonitor.ps1    Main script
    Start-ChromeDebug.ps1           Chrome launcher with remote debugging
    CHANGELOG.md                    Version history and change log
    PLAN.md                         Architecture and build plan
    ANALYSIS.md                     Original project analysis
    README.md                       This file
    logs\
        CronometerMonitor.log               CMTrace-formatted activity log
        CronometerDiaryRawResponse.json     Raw DOM response for inspection
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
