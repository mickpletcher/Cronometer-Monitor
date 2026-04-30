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

function Connect-ChromeForDebugging {
    <#
    .SYNOPSIS
    Launches Chrome with remote debugging enabled against the user's real profile.
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

    $args = @(
        "--remote-debugging-port=$Port",
        "--user-data-dir=`"$UserDataDir`"",
        'https://cronometer.com'
    )

    try {
        Write-CMTraceLog -Message ("Launching Chrome with remote debugging on port {0}. User data: '{1}'." -f $Port, $UserDataDir) -Path $LogPath
        Start-Process -FilePath $ChromePath -ArgumentList $args
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

function Get-NutritionDataViaNetwork {
    <#
    .SYNOPSIS
    Navigates the Cronometer tab to the correct diary date and intercepts the GraphQL
    response via CDP Network domain events.

    PLACEHOLDER: The GraphQL operation name, endpoint, and field paths must be updated
    after capturing a real request in Chrome DevTools Network tab.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WebSocketDebuggerUrl,

        [Parameter(Mandatory)]
        [datetime]$Date,

        [Parameter(Mandatory)]
        [string]$LogPath,

        [Parameter()]
        [int]$TimeoutSeconds = 20
    )

    # PLACEHOLDER: Replace with the real GraphQL endpoint URL once captured from DevTools.
    $graphqlEndpoint = 'https://cronometer.com/graphql'

    # PLACEHOLDER: Replace with the real GraphQL operation name and fields.
    # Capture this from DevTools > Network > Fetch/XHR while navigating the diary.
    $graphqlQuery = @'
{
  "operationName": "PLACEHOLDER_OPERATION_NAME",
  "variables": {
    "date": "PLACEHOLDER_DATE"
  },
  "query": "PLACEHOLDER_QUERY_STRING"
}
'@

    # NOTE: This function requires a two-step CDP approach:
    # 1. Enable Network domain to intercept responses.
    # 2. Execute the GraphQL fetch from within the page context using Runtime.evaluate.
    # This avoids needing a WebSocket event loop for network events.

    $dateString = $Date.ToString('yyyy-MM-dd')
    $escapedQuery = $graphqlQuery.Replace('PLACEHOLDER_DATE', $dateString)

    # Inject a fetch call from within the page — it inherits the page's auth cookies.
    $fetchScript = @"
(async () => {
    const body = $escapedQuery;
    const response = await fetch('$graphqlEndpoint', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        },
        body: JSON.stringify(body),
        credentials: 'include'
    });
    return await response.text();
})();
"@

    try {
        Write-CMTraceLog -Message ("Injecting diary fetch into page for date {0}." -f $dateString) -Path $LogPath

        $cdpParams = @{
            expression            = $fetchScript
            awaitPromise          = $true
            returnByValue         = $true
            timeout               = ($TimeoutSeconds * 1000)
        }

        $response = Invoke-ChromeDevToolsCommand `
            -WebSocketDebuggerUrl $WebSocketDebuggerUrl `
            -Method 'Runtime.evaluate' `
            -Params $cdpParams `
            -LogPath $LogPath `
            -TimeoutSeconds ($TimeoutSeconds + 5)

        if ($response.result.result.type -eq 'string') {
            Write-CMTraceLog -Message 'Diary fetch returned a string response.' -Path $LogPath
            return $response.result.result.value
        }

        if ($response.result.exceptionDetails) {
            $exMsg = $response.result.exceptionDetails.exception.description
            throw ("Page-side fetch threw an exception: {0}" -f $exMsg)
        }

        throw 'Unexpected CDP Runtime.evaluate response structure.'
    }
    catch {
        Write-CMTraceLog -Message ("Network extraction failed. {0}" -f $_.Exception.Message) -Level Error -Path $LogPath
        throw
    }
}

function Get-NutritionDataViaDOM {
    <#
    .SYNOPSIS
    Fallback extraction path. Reads rendered nutrition values from the DOM using
    Runtime.evaluate and document.querySelector calls.

    PLACEHOLDER: Selectors must be confirmed from the live Cronometer UI.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WebSocketDebuggerUrl,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    # PLACEHOLDER: Update selectors after inspecting the live Cronometer page.
    $domScript = @'
(() => {
    const getText = (selector) => {
        const el = document.querySelector(selector);
        return el ? el.innerText.trim() : null;
    };

    return JSON.stringify({
        calories:      getText('PLACEHOLDER_CALORIES_SELECTOR'),
        protein:       getText('PLACEHOLDER_PROTEIN_SELECTOR'),
        carbohydrates: getText('PLACEHOLDER_CARBS_SELECTOR'),
        fat:           getText('PLACEHOLDER_FAT_SELECTOR'),
        fiber:         getText('PLACEHOLDER_FIBER_SELECTOR'),
        sodium:        getText('PLACEHOLDER_SODIUM_SELECTOR'),
        potassium:     getText('PLACEHOLDER_POTASSIUM_SELECTOR')
    });
})();
'@

    try {
        Write-CMTraceLog -Message 'Attempting DOM fallback extraction.' -Path $LogPath

        $cdpParams = @{
            expression    = $domScript
            returnByValue = $true
        }

        $response = Invoke-ChromeDevToolsCommand `
            -WebSocketDebuggerUrl $WebSocketDebuggerUrl `
            -Method 'Runtime.evaluate' `
            -Params $cdpParams `
            -LogPath $LogPath

        if ($response.result.result.type -eq 'string') {
            Write-CMTraceLog -Message 'DOM extraction returned a string response.' -Path $LogPath
            return $response.result.result.value
        }

        throw 'DOM extraction returned an unexpected response type.'
    }
    catch {
        Write-CMTraceLog -Message ("DOM fallback extraction failed. {0}" -f $_.Exception.Message) -Level Error -Path $LogPath
        throw
    }
}

function ConvertFrom-NutritionResponse {
    <#
    .SYNOPSIS
    Parses the raw JSON diary response into a structured result object and evaluates goals.

    PLACEHOLDER: Field paths within the JSON must be updated after confirming the real
    API response schema.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RawJson,

        [Parameter(Mandatory)]
        [datetime]$Date,

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

    function safe ([object]$val, [double]$default = 0) {
        if ($null -eq $val) { return $default }
        try { return [double]$val } catch { return $default }
    }

    try {
        $parsed = $RawJson | ConvertFrom-Json

        # PLACEHOLDER: Update these property paths to match the real response schema.
        # After a successful fetch, inspect RawResponsePath to find the correct paths.
        $totals = $parsed.data.diary.totals

        $calories      = safe $totals.calories
        $protein       = safe $totals.protein
        $carbohydrates = safe $totals.carbohydrates
        $fat           = safe $totals.fat
        $fiber         = safe $totals.fiber
        $sodium        = safe $totals.sodium
        $potassium     = safe $totals.potassium

        $caloriesRemaining      = [Math]::Max(0, $CalorieGoal - $calories)
        $proteinRemaining       = [Math]::Max(0, $ProteinGoalGrams - $protein)
        $carbohydratesRemaining = [Math]::Max(0, $CarbohydrateGoalGrams - $carbohydrates)
        $fatRemaining           = [Math]::Max(0, $FatGoalGrams - $fat)

        $alerts = [System.Collections.Generic.List[string]]::new()
        if ($protein -lt $ProteinGoalGrams) {
            $alerts.Add(("Protein below goal: {0:F1}g consumed / {1}g goal ({2:F1}g remaining)" -f $protein, $ProteinGoalGrams, $proteinRemaining))
        }
        if ($calories -lt $CalorieGoal) {
            $alerts.Add(("Calories below goal: {0:F0} consumed / {1} goal ({2:F0} remaining)" -f $calories, $CalorieGoal, $caloriesRemaining))
        }
        if ($carbohydrates -lt $CarbohydrateGoalGrams) {
            $alerts.Add(("Carbs below goal: {0:F1}g consumed / {1}g goal ({2:F1}g remaining)" -f $carbohydrates, $CarbohydrateGoalGrams, $carbohydratesRemaining))
        }
        if ($fat -lt $FatGoalGrams) {
            $alerts.Add(("Fat below goal: {0:F1}g consumed / {1}g goal ({2:F1}g remaining)" -f $fat, $FatGoalGrams, $fatRemaining))
        }

        $nutrients = @()
        if ($totals -and $totals.nutrients) {
            $nutrients = @($totals.nutrients | ForEach-Object {
                [pscustomobject]@{
                    Name  = $_.name
                    Unit  = $_.unit
                    Value = safe $_.value
                }
            })
        }

        $schemaStatus = if ($totals) { 'Parsed' } else { 'SchemaNeedsRefinement' }

        if (-not $totals) {
            Write-CMTraceLog -Message 'Response parsed but diary totals path (data.diary.totals) was not found. Schema placeholder is still active.' -Level Warning -Path $LogPath
        }

        return [pscustomobject]@{
            Date                    = $Date.ToString('yyyy-MM-dd')
            CaloriesConsumed        = $calories
            CaloriesRemaining       = $caloriesRemaining
            CalorieGoal             = $CalorieGoal
            ProteinGrams            = $protein
            ProteinRemainingGrams   = $proteinRemaining
            ProteinGoalGrams        = $ProteinGoalGrams
            CarbohydratesGrams      = $carbohydrates
            CarbohydratesRemaining  = $carbohydratesRemaining
            CarbohydrateGoalGrams   = $CarbohydrateGoalGrams
            FatGrams                = $fat
            FatRemainingGrams       = $fatRemaining
            FatGoalGrams            = $FatGoalGrams
            FiberGrams              = $fiber
            SodiumMg                = $sodium
            PotassiumMg             = $potassium
            Nutrients               = $nutrients
            Alerts                  = @($alerts)
            QueryStatus             = $schemaStatus
            ExtractionMethod        = 'Network'
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

    Write-CMTraceLog -Message ("Cronometer monitor run started for date {0}." -f $Date.ToString('yyyy-MM-dd')) -Path $LogPath

    if ($ShouldLaunchChrome) {
        Connect-ChromeForDebugging -ChromePath $ChromePath -UserDataDir $UserDataDir -Port $Port -LogPath $LogPath
    }

    $tabs = Get-ChromeDebugEndpoint -Port $Port -LogPath $LogPath
    $tab  = Get-CronometerTab -Tabs $tabs -LogPath $LogPath

    $wsUrl = $tab.webSocketDebuggerUrl
    Write-CMTraceLog -Message ("Attaching to tab via WebSocket: '{0}'." -f $wsUrl) -Path $LogPath

    $rawJson = $null

    try {
        $rawJson = Get-NutritionDataViaNetwork -WebSocketDebuggerUrl $wsUrl -Date $Date -LogPath $LogPath
        Write-CMTraceLog -Message 'Network extraction succeeded.' -Path $LogPath
    }
    catch {
        Write-CMTraceLog -Message ("Network extraction failed, falling back to DOM. {0}" -f $_.Exception.Message) -Level Warning -Path $LogPath
        $rawJson = Get-NutritionDataViaDOM -WebSocketDebuggerUrl $wsUrl -LogPath $LogPath
        Write-CMTraceLog -Message 'DOM extraction succeeded.' -Path $LogPath
    }

    Save-RawResponse -Content $rawJson -Path $RawResponsePath -Force:$ForceRawDump -LogPath $LogPath

    $result = ConvertFrom-NutritionResponse `
        -RawJson $rawJson `
        -Date $Date `
        -CalorieGoal $CalorieGoal `
        -ProteinGoalGrams $ProteinGoalGrams `
        -CarbohydrateGoalGrams $CarbohydrateGoalGrams `
        -FatGoalGrams $FatGoalGrams `
        -LogPath $LogPath

    Write-CMTraceLog -Message ("Monitor run complete. Status: {0}. Calories: {1}/{2}. Protein: {3}g/{4}g." -f `
        $result.QueryStatus, $result.CaloriesConsumed, $result.CalorieGoal, `
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
