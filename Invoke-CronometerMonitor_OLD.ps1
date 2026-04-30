<#
.SYNOPSIS
Connects to an authenticated Chrome session and extracts Cronometer diary nutrition data.

.DESCRIPTION
Attaches to an existing Chrome browser running with remote debugging enabled, locates the
active Cronometer tab, intercepts or reads the diary API response via the Chrome DevTools
Protocol, parses daily nutrition totals, and returns a structured result for downstream use.

No Cronometer credentials are required. The tool uses the already authenticated Chrome
profile so the user never needs to log in through the script.

===========================================================================
.PARAMETER DebuggingPort
Chrome remote debugging port. Must match the port Chrome was launched with.

===========================================================================
.PARAMETER ChromePath
Full path to chrome.exe. Defaults to the standard x64 install location.

===========================================================================
.PARAMETER UserDataDir
Chrome user data directory to use when launching Chrome. Defaults to the current user profile.

===========================================================================
.PARAMETER LaunchChrome
When specified, the script launches Chrome with remote debugging enabled before connecting.
Omit this switch if Chrome is already running with --remote-debugging-port.

===========================================================================
.PARAMETER Date
The diary date to extract. Defaults to today.

===========================================================================
.PARAMETER LogPath
Path to the CMTrace-compatible log file.

===========================================================================
.PARAMETER RawResponsePath
Path where the raw diary API JSON response will be saved for schema inspection.

===========================================================================
.PARAMETER ForceRawDump
Always overwrite the raw response file even if it already exists.

===========================================================================
.PARAMETER ProteinGoalGrams
Daily protein goal in grams.

===========================================================================
.PARAMETER CalorieGoal
Daily calorie goal.

===========================================================================
.PARAMETER CarbohydrateGoalGrams
Daily carbohydrate goal in grams.

===========================================================================
.PARAMETER FatGoalGrams
Daily fat goal in grams.

===========================================================================
.EXAMPLE
# Chrome is already running with remote debugging. Pull today's diary.
.\Invoke-CronometerMonitor.ps1

===========================================================================
.EXAMPLE
# Launch Chrome against your real profile, then extract.
.\Invoke-CronometerMonitor.ps1 -LaunchChrome -ForceRawDump

===========================================================================
.EXAMPLE
# Query a specific date.
.\Invoke-CronometerMonitor.ps1 -Date '2026-04-28'

===========================================================================
.NOTES
Chrome must be launched with:
  --remote-debugging-port=9222
  --user-data-dir="$env:LOCALAPPDATA\Google\Chrome\User Data"

Run Connect-ChromeForDebugging once to start Chrome in this mode, then subsequent
script runs can attach without -LaunchChrome as long as Chrome stays open.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [int]$DebuggingPort = 9222,

    [Parameter()]
    [string]$ChromePath = 'C:\Program Files\Google\Chrome\Application\chrome.exe',

    [Parameter()]
    [string]$UserDataDir = (Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Google\Chrome\User Data'),

    [Parameter()]
    [switch]$LaunchChrome,

    [Parameter()]
    [datetime]$Date = (Get-Date).Date,

    [Parameter()]
    [string]$LogPath = (Join-Path -Path $PSScriptRoot -ChildPath 'logs\CronometerMonitor.log'),

    [Parameter()]
    [string]$RawResponsePath = (Join-Path -Path $PSScriptRoot -ChildPath 'logs\CronometerDiaryRawResponse.json'),

    [Parameter()]
    [switch]$ForceRawDump,

    [Parameter()]
    [double]$ProteinGoalGrams = 150,

    [Parameter()]
    [double]$CalorieGoal = 2200,

    [Parameter()]
    [double]$CarbohydrateGoalGrams = 200,

    [Parameter()]
    [double]$FatGoalGrams = 70
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Functions

function Write-CMTraceLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info',

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [string]$Component = 'CronometerMonitor'
    )

    try {
        $directory = Split-Path -Path $Path -Parent
        if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }

        $time    = Get-Date
        $bias    = [System.TimeZoneInfo]::Local.GetUtcOffset($time).TotalMinutes
        $type    = switch ($Level) { 'Info' { 1 } 'Warning' { 2 } 'Error' { 3 } }
        $context = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $thread  = [System.Threading.Thread]::CurrentThread.ManagedThreadId

        $entry = '<![LOG[{0}]LOG]!><time="{1}{2}" date="{3}" component="{4}" context="{5}" type="{6}" thread="{7}" file="Invoke-CronometerMonitor.ps1">' -f
            $Message,
            $time.ToString('HH:mm:ss.fff'),
            $bias.ToString('+000;-000'),
            $time.ToString('MM-dd-yyyy'),
            $Component,
            $context,
            $type,
            $thread

        Add-Content -Path $Path -Value $entry
    }
    catch {
        Write-Warning ("Failed to write CMTrace log entry: {0}" -f $_.Exception.Message)
    }
}

function Clear-ChromeSessionRestore {
    <#
    .SYNOPSIS
    Marks the Chrome profile as having exited cleanly so the restore prompt does not appear on next launch.
    Must be called after Chrome is fully stopped and before it is relaunched.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserDataDir,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    $prefsPath = Join-Path -Path $UserDataDir -ChildPath 'Default\Preferences'

    if (-not (Test-Path -LiteralPath $prefsPath)) {
        Write-CMTraceLog -Message ("Chrome Preferences file not found at '{0}'. Skipping restore clear." -f $prefsPath) -Level Warning -Path $LogPath
        return
    }

    try {
        $prefs = Get-Content -LiteralPath $prefsPath -Raw -Encoding UTF8 | ConvertFrom-Json

        if (-not $prefs.profile) {
            $prefs | Add-Member -MemberType NoteProperty -Name 'profile' -Value ([pscustomobject]@{})
        }

        $prefs.profile | Add-Member -MemberType NoteProperty -Name 'exit_type'      -Value 'Normal'  -Force
        $prefs.profile | Add-Member -MemberType NoteProperty -Name 'exited_cleanly' -Value $true     -Force

        $prefs | ConvertTo-Json -Depth 100 -Compress | Set-Content -LiteralPath $prefsPath -Encoding UTF8
        Write-CMTraceLog -Message ("Cleared Chrome session restore flag in '{0}'." -f $prefsPath) -Path $LogPath
    }
    catch {
        Write-CMTraceLog -Message ("Failed to clear Chrome session restore flag. {0}" -f $_.Exception.Message) -Level Warning -Path $LogPath
    }
}

function Connect-ChromeForDebugging {
    <#
    .SYNOPSIS
    Kills any running Chrome processes, clears the session restore flag, then relaunches
    Chrome with remote debugging enabled against the user's real profile.
    Only call this if Chrome is not already running with --remote-debugging-port.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ChromePath,

        [Parameter(Mandatory)]
        [string]$UserDataDir,

        [Parameter(Mandatory)]
        [int]$Port,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    if (-not (Test-Path -LiteralPath $ChromePath)) {
        throw "Chrome executable not found at '$ChromePath'. Set -ChromePath to the correct location."
    }

    $chromeArgs = @(
        "--remote-debugging-port=$Port",
        "--user-data-dir=`"$UserDataDir`"",
        'https://cronometer.com'
    )

    try {
        $running = Get-Process chrome -ErrorAction SilentlyContinue
        if ($running) {
            Write-CMTraceLog -Message ("Stopping {0} running Chrome process(es)." -f @($running).Count) -Path $LogPath
            $running | Stop-Process -Force
            Start-Sleep -Seconds 2
            Write-CMTraceLog -Message 'Chrome processes stopped.' -Path $LogPath
        }

        Clear-ChromeSessionRestore -UserDataDir $UserDataDir -LogPath $LogPath

        Write-CMTraceLog -Message ("Launching Chrome with remote debugging on port {0}. User data: '{1}'." -f $Port, $UserDataDir) -Path $LogPath
        Start-Process -FilePath $ChromePath -ArgumentList $chromeArgs
        Start-Sleep -Seconds 3
        Write-CMTraceLog -Message 'Chrome launch complete.' -Path $LogPath
    }
    catch {
        Write-CMTraceLog -Message ("Failed to launch Chrome. {0}" -f $_.Exception.Message) -Level Error -Path $LogPath
        throw
    }
}

function Get-ChromeDebugEndpoint {
    <#
    .SYNOPSIS
    Queries the Chrome /json endpoint and returns all open tab descriptors.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Port,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    $uri = "http://localhost:$Port/json"

    try {
        Write-CMTraceLog -Message ("Querying Chrome debug endpoint at '{0}'." -f $uri) -Path $LogPath
        $tabs = Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec 10
        Write-CMTraceLog -Message ("Found {0} open tab(s)." -f @($tabs).Count) -Path $LogPath
        return $tabs
    }
    catch {
        Write-CMTraceLog -Message ("Failed to reach Chrome debug endpoint at '{0}'. Is Chrome running with --remote-debugging-port={1}? {2}" -f $uri, $Port, $_.Exception.Message) -Level Error -Path $LogPath
        throw
    }
}

function Get-CronometerTab {
    <#
    .SYNOPSIS
    Finds the first Chrome tab whose URL contains cronometer.com.
    Returns the tab descriptor object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Tabs,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    $tab = $Tabs | Where-Object { $_.url -match 'cronometer\.com' } | Select-Object -First 1

    if (-not $tab) {
        throw 'No Cronometer tab found in the open Chrome session. Navigate to cronometer.com and try again.'
    }

    Write-CMTraceLog -Message ("Found Cronometer tab: '{0}' [{1}]." -f $tab.title, $tab.url) -Path $LogPath
    return $tab
}

function Invoke-ChromeDevToolsCommand {
    <#
    .SYNOPSIS
    Sends a single Chrome DevTools Protocol command over a WebSocket and returns the response.
    Uses .NET ClientWebSocket directly for PS5.1 and PS7 compatibility.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WebSocketDebuggerUrl,

        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter()]
        [hashtable]$Params = @{},

        [Parameter(Mandatory)]
        [string]$LogPath,

        [Parameter()]
        [int]$TimeoutSeconds = 30
    )

    $ws = $null

    try {
        Write-CMTraceLog -Message ("CDP command: {0}" -f $Method) -Path $LogPath

        $ws      = New-Object System.Net.WebSockets.ClientWebSocket
        $uri     = [System.Uri]::new($WebSocketDebuggerUrl)
        $cts     = [System.Threading.CancellationTokenSource]::new([System.TimeSpan]::FromSeconds($TimeoutSeconds))
        $token   = $cts.Token

        $connectTask = $ws.ConnectAsync($uri, $token)
        $connectTask.Wait($cts.Token)

        $id      = 1
        $payload = @{ id = $id; method = $Method; params = $Params } | ConvertTo-Json -Depth 10 -Compress
        $bytes   = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $segment = [System.ArraySegment[byte]]::new($bytes)

        $sendTask = $ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $token)
        $sendTask.Wait($token)

        $buffer      = New-Object byte[] 65536
        $recvSegment = [System.ArraySegment[byte]]::new($buffer)
        $recvTask    = $ws.ReceiveAsync($recvSegment, $token)
        $result      = $recvTask.Result

        $json     = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count)
        $response = $json | ConvertFrom-Json

        Write-CMTraceLog -Message ("CDP response received for method '{0}'." -f $Method) -Path $LogPath
        return $response
    }
    catch {
        Write-CMTraceLog -Message ("CDP command '{0}' failed. {1}" -f $Method, $_.Exception.Message) -Level Error -Path $LogPath
        throw
    }
    finally {
        if ($ws -and $ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            try { $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', [System.Threading.CancellationToken]::None).Wait() } catch {}
        }
        if ($ws) { $ws.Dispose() }
    }
}

function Get-NutritionDataViaDOM {
    <#
    .SYNOPSIS
    Reads the rendered nutrition totals from the Cronometer diary page using CDP Runtime.evaluate.
    Scrapes all six targets-table panels (General, B-Vitamins, Vitamins, Minerals, etc.),
    deduplicates by nutrient name, and returns a JSON object with the diary date and all
    nutrient values.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WebSocketDebuggerUrl,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    $domScript = @'
(() => {
    var dateEl = document.querySelector('.diary-date-btn');
    var date   = dateEl ? dateEl.innerText.trim() : 'Unknown';

    var nutrients = {};
    var tables = document.querySelectorAll('table.targets-table');
    tables.forEach(function(table) {
        var rows = table.querySelectorAll('tr:not(.table-header)');
        rows.forEach(function(row) {
            var nameEl = row.querySelector('.nutrient-name');
            var valEl  = row.querySelector('.targets-table-number .gwt-HTML');
            var unitEl = row.querySelector('td:nth-child(3) .gwt-Label');
            if (nameEl && valEl) {
                var name  = nameEl.innerText.replace(/[ \s]+/g, ' ').trim();
                var value = valEl.innerText.trim();
                var unit  = unitEl ? unitEl.innerText.trim() : '';
                if (name && value !== '-' && !nutrients[name]) {
                    nutrients[name] = { value: value, unit: unit };
                }
            }
        });
    });

    return JSON.stringify({ date: date, nutrients: nutrients });
})();
'@

    try {
        Write-CMTraceLog -Message 'Extracting nutrition data from Cronometer DOM.' -Path $LogPath

        $cdpParams = @{
            expression    = $domScript
            returnByValue = $true
        }

        $response = Invoke-ChromeDevToolsCommand `
            -WebSocketDebuggerUrl $WebSocketDebuggerUrl `
            -Method 'Runtime.evaluate' `
            -Params $cdpParams `
            -LogPath $LogPath

        if ($response.result.exceptionDetails) {
            throw ("Page-side script threw an exception: {0}" -f $response.result.exceptionDetails.exception.description)
        }

        if ($response.result.result.type -eq 'string') {
            Write-CMTraceLog -Message 'DOM extraction succeeded.' -Path $LogPath
            return $response.result.result.value
        }

        throw 'DOM extraction returned an unexpected response type.'
    }
    catch {
        Write-CMTraceLog -Message ("DOM extraction failed. {0}" -f $_.Exception.Message) -Level Error -Path $LogPath
        throw
    }
}


function ConvertFrom-NutritionResponse {
    <#
    .SYNOPSIS
    Parses the DOM-extracted JSON into a structured result object and evaluates goals.
    Input JSON shape: { date: "Apr 28", nutrients: { "Energy": { value: "1625.3", unit: "kcal" }, ... } }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RawJson,

        [Parameter(Mandatory)]
        [double]$CalorieGoal,

        [Parameter(Mandatory)]
        [double]$ProteinGoalGrams,

        [Parameter(Mandatory)]
        [double]$CarbohydrateGoalGrams,

        [Parameter(Mandatory)]
        [double]$FatGoalGrams,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    function Get-NVal {
        param([object]$Nutrients, [string]$Name)
        $prop = $Nutrients.PSObject.Properties[$Name]
        if (-not $prop) { return 0.0 }
        try { return [double]$prop.Value.value } catch { return 0.0 }
    }

    try {
        $parsed    = $RawJson | ConvertFrom-Json
        $diaryDate = $parsed.date
        $n         = $parsed.nutrients

        if (-not $n -or $n.PSObject.Properties.Count -eq 0) {
            Write-CMTraceLog -Message 'No nutrients found in DOM response. Ensure the Cronometer diary page is open and the nutrition summary panel is visible.' -Level Warning -Path $LogPath
        }

        $calories      = Get-NVal $n 'Energy'
        $protein       = Get-NVal $n 'Protein'
        $carbs         = Get-NVal $n 'Carbs'
        $netCarbs      = Get-NVal $n 'Net Carbs'
        $fat           = Get-NVal $n 'Fat'
        $fiber         = Get-NVal $n 'Fiber'
        $sugars        = Get-NVal $n 'Sugars'
        $addedSugars   = Get-NVal $n 'Added Sugars'
        $saturatedFat  = Get-NVal $n 'Saturated'
        $transFat      = Get-NVal $n 'Trans-Fats'
        $cholesterol   = Get-NVal $n 'Cholesterol'
        $sodium        = Get-NVal $n 'Sodium'
        $potassium     = Get-NVal $n 'Potassium'
        $water         = Get-NVal $n 'Water'
        $calcium       = Get-NVal $n 'Calcium'
        $iron          = Get-NVal $n 'Iron'
        $magnesium     = Get-NVal $n 'Magnesium'
        $phosphorus    = Get-NVal $n 'Phosphorus'
        $zinc          = Get-NVal $n 'Zinc'
        $copper        = Get-NVal $n 'Copper'
        $manganese     = Get-NVal $n 'Manganese'
        $selenium      = Get-NVal $n 'Selenium'
        $vitA          = Get-NVal $n 'Vitamin A'
        $vitC          = Get-NVal $n 'Vitamin C'
        $vitD          = Get-NVal $n 'Vitamin D'
        $vitE          = Get-NVal $n 'Vitamin E'
        $vitK          = Get-NVal $n 'Vitamin K'
        $vitB1         = Get-NVal $n 'B1 (Thiamine)'
        $vitB2         = Get-NVal $n 'B2 (Riboflavin)'
        $vitB3         = Get-NVal $n 'B3 (Niacin)'
        $vitB5         = Get-NVal $n 'B5 (Pantothenic Acid)'
        $vitB6         = Get-NVal $n 'B6 (Pyridoxine)'
        $vitB12        = Get-NVal $n 'B12 (Cobalamin)'
        $folate        = Get-NVal $n 'Folate'

        $caloriesRemaining = [Math]::Max(0, $CalorieGoal - $calories)
        $proteinRemaining  = [Math]::Max(0, $ProteinGoalGrams - $protein)
        $carbsRemaining    = [Math]::Max(0, $CarbohydrateGoalGrams - $carbs)
        $fatRemaining      = [Math]::Max(0, $FatGoalGrams - $fat)

        $alerts = [System.Collections.Generic.List[string]]::new()
        if ($calories -lt $CalorieGoal) {
            $alerts.Add(("Calories below goal: {0:F0} kcal consumed / {1} kcal goal ({2:F0} kcal remaining)" -f $calories, $CalorieGoal, $caloriesRemaining))
        }
        if ($protein -lt $ProteinGoalGrams) {
            $alerts.Add(("Protein below goal: {0:F1}g consumed / {1}g goal ({2:F1}g remaining)" -f $protein, $ProteinGoalGrams, $proteinRemaining))
        }
        if ($carbs -lt $CarbohydrateGoalGrams) {
            $alerts.Add(("Carbs below goal: {0:F1}g consumed / {1}g goal ({2:F1}g remaining)" -f $carbs, $CarbohydrateGoalGrams, $carbsRemaining))
        }
        if ($fat -lt $FatGoalGrams) {
            $alerts.Add(("Fat below goal: {0:F1}g consumed / {1}g goal ({2:F1}g remaining)" -f $fat, $FatGoalGrams, $fatRemaining))
        }

        $allNutrients = @(
            $n.PSObject.Properties | ForEach-Object {
                [pscustomobject]@{
                    Name  = $_.Name
                    Value = $_.Value.value
                    Unit  = $_.Value.unit
                }
            }
        )

        return [pscustomobject]@{
            DiaryDate               = $diaryDate
            CaloriesConsumed        = $calories
            CaloriesRemaining       = $caloriesRemaining
            CalorieGoal             = $CalorieGoal
            ProteinGrams            = $protein
            ProteinRemainingGrams   = $proteinRemaining
            ProteinGoalGrams        = $ProteinGoalGrams
            CarbsGrams              = $carbs
            NetCarbsGrams           = $netCarbs
            CarbsRemainingGrams     = $carbsRemaining
            CarbohydrateGoalGrams   = $CarbohydrateGoalGrams
            FatGrams                = $fat
            FatRemainingGrams       = $fatRemaining
            FatGoalGrams            = $FatGoalGrams
            FiberGrams              = $fiber
            SugarsGrams             = $sugars
            AddedSugarsGrams        = $addedSugars
            SaturatedFatGrams       = $saturatedFat
            TransFatGrams           = $transFat
            CholesterolMg           = $cholesterol
            SodiumMg                = $sodium
            PotassiumMg             = $potassium
            WaterG                  = $water
            CalciumMg               = $calcium
            IronMg                  = $iron
            MagnesiumMg             = $magnesium
            PhosphorusMg            = $phosphorus
            ZincMg                  = $zinc
            CopperMg                = $copper
            ManganeseMg             = $manganese
            SeleniumUg              = $selenium
            VitaminA_ug             = $vitA
            VitaminC_mg             = $vitC
            VitaminD_IU             = $vitD
            VitaminE_mg             = $vitE
            VitaminK_ug             = $vitK
            B1_Thiamine_mg          = $vitB1
            B2_Riboflavin_mg        = $vitB2
            B3_Niacin_mg            = $vitB3
            B5_PantothenicAcid_mg   = $vitB5
            B6_Pyridoxine_mg        = $vitB6
            B12_Cobalamin_ug        = $vitB12
            Folate_ug               = $folate
            Nutrients               = $allNutrients
            Alerts                  = @($alerts)
            QueryStatus             = if ($n.PSObject.Properties.Count -gt 0) { 'Parsed' } else { 'NoDataFound' }
            ExtractionMethod        = 'DOM'
        }
    }
    catch {
        Write-CMTraceLog -Message ("Failed to parse nutrition response. {0}" -f $_.Exception.Message) -Level Error -Path $LogPath
        throw
    }
}

function Save-RawResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [switch]$Force,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    if ((Test-Path -LiteralPath $Path) -and -not $Force) {
        Write-CMTraceLog -Message ("Raw response file exists at '{0}'. Skipping. Use -ForceRawDump to overwrite." -f $Path) -Path $LogPath
        return
    }

    try {
        $directory = Split-Path -Path $Path -Parent
        if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }

        Set-Content -Path $Path -Value $Content -Encoding UTF8
        Write-CMTraceLog -Message ("Saved raw response to '{0}'." -f $Path) -Path $LogPath
    }
    catch {
        Write-CMTraceLog -Message ("Failed to save raw response to '{0}'. {1}" -f $Path, $_.Exception.Message) -Level Warning -Path $LogPath
    }
}

function Start-CronometerMonitor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Port,

        [Parameter(Mandatory)]
        [string]$ChromePath,

        [Parameter(Mandatory)]
        [string]$UserDataDir,

        [Parameter(Mandatory)]
        [bool]$ShouldLaunchChrome,

        [Parameter(Mandatory)]
        [datetime]$Date,

        [Parameter(Mandatory)]
        [string]$LogPath,

        [Parameter(Mandatory)]
        [string]$RawResponsePath,

        [Parameter(Mandatory)]
        [bool]$ForceRawDump,

        [Parameter(Mandatory)]
        [double]$CalorieGoal,

        [Parameter(Mandatory)]
        [double]$ProteinGoalGrams,

        [Parameter(Mandatory)]
        [double]$CarbohydrateGoalGrams,

        [Parameter(Mandatory)]
        [double]$FatGoalGrams
    )

    Write-CMTraceLog -Message 'Cronometer monitor run started.' -Path $LogPath

    if ($ShouldLaunchChrome) {
        Connect-ChromeForDebugging -ChromePath $ChromePath -UserDataDir $UserDataDir -Port $Port -LogPath $LogPath
    }

    $tabs  = Get-ChromeDebugEndpoint -Port $Port -LogPath $LogPath
    $tab   = Get-CronometerTab -Tabs $tabs -LogPath $LogPath
    $wsUrl = $tab.webSocketDebuggerUrl
    Write-CMTraceLog -Message ("Attaching to tab via WebSocket: '{0}'." -f $wsUrl) -Path $LogPath

    $rawJson = Get-NutritionDataViaDOM -WebSocketDebuggerUrl $wsUrl -LogPath $LogPath

    Save-RawResponse -Content $rawJson -Path $RawResponsePath -Force:$ForceRawDump -LogPath $LogPath

    $result = ConvertFrom-NutritionResponse `
        -RawJson               $rawJson `
        -CalorieGoal           $CalorieGoal `
        -ProteinGoalGrams      $ProteinGoalGrams `
        -CarbohydrateGoalGrams $CarbohydrateGoalGrams `
        -FatGoalGrams          $FatGoalGrams `
        -LogPath               $LogPath

    Write-CMTraceLog -Message ("Monitor run complete. Status: {0}. Date: {1}. Calories: {2:F0}/{3}. Protein: {4:F1}g/{5}g." -f `
        $result.QueryStatus, $result.DiaryDate, $result.CaloriesConsumed, $result.CalorieGoal, `
        $result.ProteinGrams, $result.ProteinGoalGrams) -Path $LogPath

    return $result
}

#endregion Functions

#region Main

try {
    $result = Start-CronometerMonitor `
        -Port              $DebuggingPort `
        -ChromePath        $ChromePath `
        -UserDataDir       $UserDataDir `
        -ShouldLaunchChrome $LaunchChrome.IsPresent `
        -Date              $Date `
        -LogPath           $LogPath `
        -RawResponsePath   $RawResponsePath `
        -ForceRawDump      $ForceRawDump.IsPresent `
        -CalorieGoal       $CalorieGoal `
        -ProteinGoalGrams  $ProteinGoalGrams `
        -CarbohydrateGoalGrams $CarbohydrateGoalGrams `
        -FatGoalGrams      $FatGoalGrams

    $result
}
catch {
    Write-Error -Message $_.Exception.Message
    exit 1
}

#endregion Main
