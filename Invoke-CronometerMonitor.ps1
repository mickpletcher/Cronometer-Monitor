<#
.SYNOPSIS
Connects to an authenticated Chrome session and extracts Cronometer diary nutrition data.

.DESCRIPTION
Attaches to an existing Chrome browser running with remote debugging enabled, locates the
active Cronometer tab, reads the rendered nutrition summary panels from the DOM via the
Chrome DevTools Protocol, and returns a structured result for downstream use.

No Cronometer credentials are required. The tool uses the already authenticated Chrome
profile. The script reads whatever diary date is currently displayed in Chrome. To extract
a different date, navigate to it in Chrome before running this script.

Run Start-ChromeDebug.ps1 first if Chrome is not already open with remote debugging.

===========================================================================
.PARAMETER DebuggingPort
Chrome remote debugging port. Must match the port Chrome was launched with.

===========================================================================
.PARAMETER ChromePath
Full path to chrome.exe. Defaults to the standard x64 install location.

===========================================================================
.PARAMETER UserDataDir
Chrome user data directory used when launching Chrome with -LaunchChrome.

===========================================================================
.PARAMETER LaunchChrome
When specified, kills existing Chrome, clears the session restore flag, and relaunches
with remote debugging before connecting. Equivalent to running Start-ChromeDebug.ps1 first.

===========================================================================
.PARAMETER LogPath
Path to the CMTrace-compatible log file.

===========================================================================
.PARAMETER RawResponsePath
Path where the raw DOM response JSON will be saved for inspection.

===========================================================================
.PARAMETER ResultJsonPath
Path where the final structured result JSON will be saved for downstream tools such as n8n.

===========================================================================
.PARAMETER ForceRawDump
Always overwrite the raw response file even if it already exists.

===========================================================================
.PARAMETER ProteinGoalGrams
Daily protein goal in grams.

===========================================================================
.PARAMETER CalorieGoal
Daily calorie goal in kcal.

===========================================================================
.PARAMETER CarbohydrateGoalGrams
Daily carbohydrate goal in grams.

===========================================================================
.PARAMETER FatGoalGrams
Daily fat goal in grams.

===========================================================================
.EXAMPLE
.\Invoke-CronometerMonitor.ps1

===========================================================================
.EXAMPLE
.\Invoke-CronometerMonitor.ps1 -LaunchChrome -ForceRawDump

===========================================================================
.EXAMPLE
.\Invoke-CronometerMonitor.ps1 -CalorieGoal 2500 -ProteinGoalGrams 175
#>
[CmdletBinding()]
param(
    [Parameter()]
    [int]$DebuggingPort = 9222,

    [Parameter()]
    [string]$ChromePath = 'C:\Program Files\Google\Chrome\Application\chrome.exe',

    [Parameter()]
    [string]$UserDataDir = (Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Google\Chrome\CronometerDebug'),

    [Parameter()]
    [switch]$LaunchChrome,

    [Parameter()]
    [string]$LogPath = (Join-Path -Path $PSScriptRoot -ChildPath 'logs\CronometerMonitor.log'),

    [Parameter()]
    [string]$RawResponsePath = (Join-Path -Path $PSScriptRoot -ChildPath 'logs\CronometerDiaryRawResponse.json'),

    [Parameter()]
    [string]$ResultJsonPath = (Join-Path -Path $PSScriptRoot -ChildPath 'logs\CronometerMonitorResult.json'),

    [Parameter()]
    [string]$HistoryCsvPath = (Join-Path -Path $PSScriptRoot -ChildPath 'logs\CronometerHistory.csv'),

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

function Write-StageLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Stage,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info',

        [Parameter()]
        [string]$Category = 'General'
    )

    Write-CMTraceLog -Message ("[Stage:{0}][Category:{1}] {2}" -f $Stage, $Category, $Message) -Level $Level -Path $Path
}

function Get-SelectorRegistry {
    [CmdletBinding()]
    param()

    return @{
        date = @(
            '.diary-date-btn',
            '[class*="diary-date"]',
            '[data-testid="diary-date"]'
        )
        tables = @(
            'table.targets-table',
            'table[class*="targets-table"]',
            '[data-testid="nutrition-targets-table"]'
        )
        nutrientName = @(
            '.nutrient-name',
            '[class*="nutrient-name"]',
            'td:first-child .gwt-HTML',
            'td:first-child .gwt-Label'
        )
        nutrientValue = @(
            '.targets-table-number .gwt-HTML',
            '.targets-table-number',
            'td:nth-child(2) .gwt-HTML',
            'td:nth-child(2)'
        )
        nutrientUnit = @(
            'td:nth-child(3) .gwt-Label',
            'td:nth-child(3) .gwt-HTML',
            'td:nth-child(3)'
        )
        diaryGroup = @(
            'tr.diary-group-row',
            '.diary-group-row'
        )
        diaryTime = @(
            'td.diary-time',
            '.diary-time'
        )
    }
}

function Test-NutritionExtractionPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RawJson,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    $missingRequiredFields = [System.Collections.Generic.List[string]]::new()
    $diagnostics = $null

    try {
        $payload = $RawJson | ConvertFrom-Json -Depth 10
        $nutrients = $payload.nutrients
        $diagnostics = $payload.metadata
    }
    catch {
        Write-StageLog -Stage 'Validate' -Category 'Validation' -Level Error -Path $LogPath -Message ("Failed to parse DOM payload for validation. {0}" -f $_.Exception.Message)
        return [pscustomobject]@{
            IsValid               = $false
            QueryStatus           = 'ValidationFailed'
            ValidationStatus      = 'InvalidJson'
            MissingRequiredFields = @('RawJson')
            Diagnostics           = $null
            ShouldRetry           = $true
        }
    }

    if (-not $payload.date -or $payload.date -eq 'Unknown') {
        $missingRequiredFields.Add('DiaryDate')
    }

    foreach ($fieldName in @('Energy', 'Protein', 'Carbs', 'Fat')) {
        $property = $null
        if ($nutrients) {
            $property = $nutrients.PSObject.Properties[$fieldName]
        }

        if (-not $property) {
            $missingRequiredFields.Add($fieldName)
            continue
        }

        $valueText = [string]$property.Value.value
        $parsedValue = 0.0
        if (-not [double]::TryParse($valueText, [ref]$parsedValue)) {
            $missingRequiredFields.Add($fieldName)
        }
    }

    $isValid = ($missingRequiredFields.Count -eq 0)
    $validationStatus = if ($isValid) { 'Passed' } else { 'MissingRequiredFields' }
    $queryStatus = if ($isValid) { 'Parsed' } else { 'ValidationFailed' }

    if ($isValid) {
        Write-StageLog -Stage 'Validate' -Category 'Validation' -Path $LogPath -Message 'Required fields passed validation.'
    }
    else {
        Write-StageLog -Stage 'Validate' -Category 'Validation' -Level Warning -Path $LogPath -Message ("Required fields missing or invalid: {0}" -f ($missingRequiredFields -join ', '))
    }

    return [pscustomobject]@{
        IsValid               = $isValid
        QueryStatus           = $queryStatus
        ValidationStatus      = $validationStatus
        MissingRequiredFields = @($missingRequiredFields)
        Diagnostics           = $diagnostics
        ShouldRetry           = (-not $isValid)
    }
}

function Clear-ChromeSessionRestore {
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

        $prefs.profile | Add-Member -MemberType NoteProperty -Name 'exit_type'      -Value 'Normal' -Force
        $prefs.profile | Add-Member -MemberType NoteProperty -Name 'exited_cleanly' -Value $true    -Force

        $prefs | ConvertTo-Json -Depth 100 -Compress | Set-Content -LiteralPath $prefsPath -Encoding UTF8
        Write-CMTraceLog -Message ("Cleared Chrome session restore flag in '{0}'." -f $prefsPath) -Path $LogPath
    }
    catch {
        Write-CMTraceLog -Message ("Failed to clear Chrome session restore flag. {0}" -f $_.Exception.Message) -Level Warning -Path $LogPath
    }
}

function Connect-ChromeForDebugging {
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
        "--remote-debugging-address=0.0.0.0",
        '--remote-allow-origins=*',
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

        Write-CMTraceLog -Message ("Launching Chrome with remote debugging on port {0}." -f $Port) -Path $LogPath
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
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Port,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    $uri = "http://127.0.0.1:$Port/json"

    try {
        Write-CMTraceLog -Message ("Querying Chrome debug endpoint at '{0}'." -f $uri) -Path $LogPath
        $tabs = Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec 10
        Write-CMTraceLog -Message ("Found {0} open tab(s)." -f @($tabs).Count) -Path $LogPath
        return $tabs
    }
    catch {
        Write-CMTraceLog -Message ("Failed to reach Chrome debug endpoint. Is Chrome running with --remote-debugging-port={0}? Run Start-ChromeDebug.ps1 first. {1}" -f $Port, $_.Exception.Message) -Level Error -Path $LogPath
        throw
    }
}

function Get-CronometerTab {
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

        $ws.ConnectAsync($uri, $token).Wait($token)

        $id      = 1
        $payload = @{ id = $id; method = $Method; params = $Params } | ConvertTo-Json -Depth 10 -Compress
        $bytes   = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $segment = [System.ArraySegment[byte]]::new($bytes)

        $ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $token).Wait($token)

        $buffer      = New-Object byte[] 65536
        $recvSegment = [System.ArraySegment[byte]]::new($buffer)
        $result      = $ws.ReceiveAsync($recvSegment, $token).Result

        $json     = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count)
        $response = $json | ConvertFrom-Json

        Write-CMTraceLog -Message ("CDP response received for '{0}'." -f $Method) -Path $LogPath
        return $response
    }
    catch {
        Write-CMTraceLog -Message ("CDP command '{0}' failed. {1}" -f $Method, $_.Exception.Message) -Level Error -Path $LogPath
        throw
    }
    finally {
        if ($ws -and $ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            try {
                $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', [System.Threading.CancellationToken]::None).Wait()
            }
            catch {
                Write-CMTraceLog -Message ("CDP WebSocket close failed. {0}" -f $_.Exception.Message) -Level Warning -Path $LogPath
            }
        }
        if ($ws) { $ws.Dispose() }
    }
}

function Get-NutritionDataViaDOM {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WebSocketDebuggerUrl,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    $selectorRegistryJson = (Get-SelectorRegistry | ConvertTo-Json -Depth 10 -Compress)
    $domScript = @"
(() => {
    var selectorRegistry = $selectorRegistryJson;
    var metadata = {
        selectorMatches: {},
        tableCount: 0,
        nutrientCount: 0,
        biometricCount: 0,
        diaryGroupCount: 0,
        diaryEntryCount: 0,
        missingSignals: []
    };

    function firstMatch(selectors, root) {
        var scope = root || document;
        for (var i = 0; i < selectors.length; i++) {
            var selector = selectors[i];
            var match = scope.querySelector(selector);
            if (match) {
                return { element: match, selector: selector };
            }
        }

        return { element: null, selector: '' };
    }

    function allMatches(selectors, root) {
        var scope = root || document;
        for (var i = 0; i < selectors.length; i++) {
            var selector = selectors[i];
            var matches = scope.querySelectorAll(selector);
            if (matches && matches.length > 0) {
                return { elements: matches, selector: selector };
            }
        }

        return { elements: [], selector: '' };
    }

    var dateMatch = firstMatch(selectorRegistry.date);
    metadata.selectorMatches.date = dateMatch.selector;
    var date = dateMatch.element ? dateMatch.element.innerText.trim() : 'Unknown';
    if (!dateMatch.element) {
        metadata.missingSignals.push('DiaryDateSelector');
    }

    var nutrients = {};
    var biometrics = [];
    var diaryGroups = [];
    var diaryEntries = [];
    var tableMatch = allMatches(selectorRegistry.tables);
    metadata.selectorMatches.tables = tableMatch.selector;
    var tables = tableMatch.elements;
    metadata.tableCount = tables.length;
    if (!tableMatch.selector) {
        metadata.missingSignals.push('NutritionTableSelector');
    }

    tables.forEach(function(table) {
        var rows = table.querySelectorAll('tr:not(.table-header)');
        rows.forEach(function(row) {
            var nameMatch = firstMatch(selectorRegistry.nutrientName, row);
            var valueMatch = firstMatch(selectorRegistry.nutrientValue, row);
            var unitMatch = firstMatch(selectorRegistry.nutrientUnit, row);
            var nameEl = nameMatch.element;
            var valEl = valueMatch.element;
            var unitEl = unitMatch.element;

            if (!metadata.selectorMatches.nutrientName && nameMatch.selector) {
                metadata.selectorMatches.nutrientName = nameMatch.selector;
            }

            if (!metadata.selectorMatches.nutrientValue && valueMatch.selector) {
                metadata.selectorMatches.nutrientValue = valueMatch.selector;
            }

            if (!metadata.selectorMatches.nutrientUnit && unitMatch.selector) {
                metadata.selectorMatches.nutrientUnit = unitMatch.selector;
            }

            if (nameEl && valEl) {
                var name  = nameEl.innerText.replace(/[ \s]+/g, ' ').trim();
                var value = valEl.innerText.trim();
                var unit  = unitEl ? unitEl.innerText.trim() : '';
                if (name && value !== '-' && !nutrients[name]) {
                    nutrients[name] = { value: value, unit: unit };
                }
            }
        });
    });

    metadata.nutrientCount = Object.keys(nutrients).length;

    if (!metadata.selectorMatches.nutrientName) {
        metadata.missingSignals.push('NutrientNameSelector');
    }

    if (!metadata.selectorMatches.nutrientValue) {
        metadata.missingSignals.push('NutrientValueSelector');
    }

    if (metadata.nutrientCount === 0) {
        metadata.missingSignals.push('NoNutrientsExtracted');
    }

    function normalizeText(value) {
        if (!value) {
            return '';
        }

        return value.replace(/[ \s]+/g, ' ').trim();
    }

    function parseNameAndSource(value) {
        var text = normalizeText(value);
        var match = text.match(/^(.*?)(?:\s*\(([^)]+)\))$/);
        if (match) {
            return {
                name: normalizeText(match[1]),
                source: normalizeText(match[2])
            };
        }

        return {
            name: text,
            source: ''
        };
    }

    function parseMacroSummary(text) {
        var summaryText = normalizeText(text);
        var summary = {
            calories: null,
            proteinGrams: null,
            carbsGrams: null,
            fatGrams: null
        };

        var caloriesMatch = summaryText.match(/([0-9.]+)\s*kcal/i);
        var proteinMatch = summaryText.match(/([0-9.]+)\s*g\s*protein/i);
        var carbsMatch = summaryText.match(/([0-9.]+)\s*g\s*carbs/i);
        var fatMatch = summaryText.match(/([0-9.]+)\s*g\s*fat/i);

        if (caloriesMatch) {
            summary.calories = caloriesMatch[1];
        }

        if (proteinMatch) {
            summary.proteinGrams = proteinMatch[1];
        }

        if (carbsMatch) {
            summary.carbsGrams = carbsMatch[1];
        }

        if (fatMatch) {
            summary.fatGrams = fatMatch[1];
        }

        return summary;
    }

    function getEntryType(row) {
        if (row.querySelector('.icon-add-biometric')) {
            return 'Biometric';
        }

        if (row.querySelector('.icon-supplement')) {
            return 'Supplement';
        }

        if (row.querySelector('.icon-food')) {
            return 'Food';
        }

        return 'Unknown';
    }

    var diaryGroupMatch = allMatches(selectorRegistry.diaryGroup);
    var diaryTimeMatch = allMatches(selectorRegistry.diaryTime);
    metadata.selectorMatches.diaryGroup = diaryGroupMatch.selector;
    metadata.selectorMatches.diaryTime = diaryTimeMatch.selector;

    var allRows = document.querySelectorAll('tr');
    var currentGroup = null;

    allRows.forEach(function(row) {
        var groupTitleElement = row.querySelector('.diary-group-title');
        if (groupTitleElement) {
            var groupTitle = normalizeText(groupTitleElement.innerText);
            var groupMacrosElement = row.querySelector('.diary-group-macros');
            var groupSummaryText = groupMacrosElement ? normalizeText(groupMacrosElement.innerText) : '';
            currentGroup = {
                GroupName: groupTitle,
                SummaryText: groupSummaryText,
                Summary: parseMacroSummary(groupSummaryText),
                Entries: []
            };
            diaryGroups.push(currentGroup);
            return;
        }

        var timeCell = row.querySelector('td.diary-time');
        if (!timeCell) {
            return;
        }

        var cells = row.querySelectorAll('td');
        if (!cells || cells.length < 5) {
            return;
        }

        var entryType = getEntryType(row);
        var titleCell = cells[2];
        var timeText = normalizeText(timeCell.innerText);
        var primaryNameElement = titleCell.querySelector('.name');
        var subtitleElement = titleCell.querySelector('.name-subtitle');
        var displayName = primaryNameElement ? normalizeText(primaryNameElement.innerText) : normalizeText(titleCell.innerText);
        var subtitle = subtitleElement ? normalizeText(subtitleElement.innerText) : '';
        var parsedName = parseNameAndSource(displayName);

        if (entryType === 'Biometric') {
            biometrics.push({
                Time: timeText,
                Name: parsedName.name,
                Source: parsedName.source,
                DisplayName: displayName,
                Subtitle: subtitle,
                Value: normalizeText(cells[3] ? cells[3].innerText : ''),
                Unit: normalizeText(cells[4] ? cells[4].innerText : '')
            });
            return;
        }

        var diaryEntry = {
            GroupName: currentGroup ? currentGroup.GroupName : '',
            EntryType: entryType,
            Time: timeText,
            Name: displayName,
            Quantity: normalizeText(cells[3] ? cells[3].innerText : ''),
            Serving: normalizeText(cells[4] ? cells[4].innerText : ''),
            Calories: normalizeText(cells[5] ? cells[5].innerText : ''),
            CaloriesUnit: normalizeText(cells[6] ? cells[6].innerText : '')
        };

        diaryEntries.push(diaryEntry);

        if (currentGroup) {
            currentGroup.Entries.push(diaryEntry);
        }
    });

    metadata.biometricCount = biometrics.length;
    metadata.diaryGroupCount = diaryGroups.length;
    metadata.diaryEntryCount = diaryEntries.length;

    if (!metadata.selectorMatches.diaryGroup) {
        metadata.missingSignals.push('DiaryGroupSelector');
    }

    if (!metadata.selectorMatches.diaryTime) {
        metadata.missingSignals.push('DiaryTimeSelector');
    }

    return JSON.stringify({
        date: date,
        nutrients: nutrients,
        biometrics: biometrics,
        diaryGroups: diaryGroups,
        diaryEntries: diaryEntries,
        metadata: metadata
    });
})();
"@

    try {
        Write-StageLog -Stage 'Extract' -Category 'DOM' -Path $LogPath -Message 'Extracting nutrition data from Cronometer DOM.'

        $cdpParams = @{
            expression    = $domScript
            returnByValue = $true
        }

        $response = Invoke-ChromeDevToolsCommand `
            -WebSocketDebuggerUrl $WebSocketDebuggerUrl `
            -Method 'Runtime.evaluate' `
            -Params $cdpParams `
            -LogPath $LogPath

        if ($response.result.PSObject.Properties['exceptionDetails']) {
            throw ("Page-side script threw an exception: {0}" -f $response.result.exceptionDetails.exception.description)
        }

        if ($response.result.result.type -eq 'string') {
            Write-StageLog -Stage 'Extract' -Category 'DOM' -Path $LogPath -Message 'DOM extraction returned a payload.'
            return $response.result.result.value
        }

        throw 'DOM extraction returned an unexpected response type.'
    }
    catch {
        Write-StageLog -Stage 'Extract' -Category 'DOM' -Level Error -Path $LogPath -Message ("DOM extraction failed. {0}" -f $_.Exception.Message)
        throw
    }
}

function Invoke-RetryableNutritionExtraction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WebSocketDebuggerUrl,

        [Parameter(Mandatory)]
        [string]$LogPath,

        [Parameter()]
        [int]$MaxAttempts = 3,

        [Parameter()]
        [int]$DelaySeconds = 2
    )

    $lastRawJson = $null
    $lastValidation = $null

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        Write-StageLog -Stage 'ExtractAttempt' -Category 'DOM' -Path $LogPath -Message ("Starting DOM extraction attempt {0} of {1}." -f $attempt, $MaxAttempts)

        $lastRawJson = Get-NutritionDataViaDOM -WebSocketDebuggerUrl $WebSocketDebuggerUrl -LogPath $LogPath
        $lastValidation = Test-NutritionExtractionPayload -RawJson $lastRawJson -LogPath $LogPath

        if ($lastValidation.IsValid) {
            Write-StageLog -Stage 'ExtractAttempt' -Category 'DOM' -Path $LogPath -Message ("DOM extraction attempt {0} passed validation." -f $attempt)
            return [pscustomobject]@{
                RawJson         = $lastRawJson
                Validation      = $lastValidation
                AttemptsUsed    = $attempt
                MaxAttempts     = $MaxAttempts
                RetryExhausted  = $false
            }
        }

        if ($attempt -lt $MaxAttempts -and $lastValidation.ShouldRetry) {
            Write-StageLog -Stage 'RetryWait' -Category 'DOM' -Level Warning -Path $LogPath -Message ("Validation failed on attempt {0}. Waiting {1} second(s) before retry." -f $attempt, $DelaySeconds)
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    Write-StageLog -Stage 'ExtractAttempt' -Category 'DOM' -Level Warning -Path $LogPath -Message ("DOM extraction exhausted {0} attempt(s) without passing validation." -f $MaxAttempts)
    return [pscustomobject]@{
        RawJson         = $lastRawJson
        Validation      = $lastValidation
        AttemptsUsed    = $MaxAttempts
        MaxAttempts     = $MaxAttempts
        RetryExhausted  = $true
    }
}

function ConvertFrom-NutritionResponse {
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
        [object]$ValidationResult,

        [Parameter(Mandatory)]
        [int]$AttemptsUsed,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    function Get-NVal {
        param([object]$Nutrients, [string]$Name)
        $prop = $Nutrients.PSObject.Properties[$Name]
        if (-not $prop) { return 0.0 }
        try { return [double]$prop.Value.value } catch { return 0.0 }
    }

    function ConvertTo-OptionalDouble {
        param([object]$Value)

        if ($null -eq $Value) {
            return $null
        }

        $text = [string]$Value
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $null
        }

        try {
            return [double]$text
        }
        catch {
            return $null
        }
    }

    function ConvertTo-BiometricRecord {
        param([object]$Record)

        $name = [string]$Record.Name
        $value = [string]$Record.Value
        $unit = [string]$Record.Unit
        $numericValue = ConvertTo-OptionalDouble -Value $value
        $systolic = $null
        $diastolic = $null

        if ($name -eq 'Blood Pressure' -and $value -match '^\s*(?<Systolic>\d+(?:\.\d+)?)\s*/\s*(?<Diastolic>\d+(?:\.\d+)?)\s*$') {
            $systolic = ConvertTo-OptionalDouble -Value $Matches.Systolic
            $diastolic = ConvertTo-OptionalDouble -Value $Matches.Diastolic
        }

        return [pscustomobject]@{
            Time          = [string]$Record.Time
            Name          = $name
            Source        = [string]$Record.Source
            DisplayName   = [string]$Record.DisplayName
            Subtitle      = [string]$Record.Subtitle
            Value         = $value
            NumericValue  = $numericValue
            Unit          = $unit
            Systolic      = $systolic
            Diastolic     = $diastolic
        }
    }

    function ConvertTo-DiaryEntryRecord {
        param([object]$Record)

        return [pscustomobject]@{
            GroupName      = [string]$Record.GroupName
            EntryType      = [string]$Record.EntryType
            Time           = [string]$Record.Time
            Name           = [string]$Record.Name
            Quantity       = [string]$Record.Quantity
            Serving        = [string]$Record.Serving
            Calories       = ConvertTo-OptionalDouble -Value $Record.Calories
            CaloriesText   = [string]$Record.Calories
            CaloriesUnit   = [string]$Record.CaloriesUnit
        }
    }

    function ConvertTo-DiaryGroupRecord {
        param([object]$Group)

        $entries = @()
        if ($Group.PSObject.Properties['Entries']) {
            $entries = @(
                $Group.Entries | ForEach-Object {
                    ConvertTo-DiaryEntryRecord -Record $_
                }
            )
        }

        $summary = $null
        if ($Group.PSObject.Properties['Summary']) {
            $summary = [pscustomobject]@{
                Calories      = ConvertTo-OptionalDouble -Value $Group.Summary.calories
                ProteinGrams  = ConvertTo-OptionalDouble -Value $Group.Summary.proteinGrams
                CarbsGrams    = ConvertTo-OptionalDouble -Value $Group.Summary.carbsGrams
                FatGrams      = ConvertTo-OptionalDouble -Value $Group.Summary.fatGrams
            }
        }

        return [pscustomobject]@{
            GroupName    = [string]$Group.GroupName
            SummaryText  = [string]$Group.SummaryText
            Summary      = $summary
            Entries      = $entries
        }
    }

    try {
        $parsed    = $RawJson | ConvertFrom-Json
        $diaryDate = $parsed.date
        $n         = $parsed.nutrients
        $metadata  = $parsed.metadata
        $biometricsRaw = if ($parsed.PSObject.Properties['biometrics']) { @($parsed.biometrics) } else { @() }
        $diaryGroupsRaw = if ($parsed.PSObject.Properties['diaryGroups']) { @($parsed.diaryGroups) } else { @() }
        $diaryEntriesRaw = if ($parsed.PSObject.Properties['diaryEntries']) { @($parsed.diaryEntries) } else { @() }
        $nutrientPropertyCount = @($n.PSObject.Properties).Count

        if (-not $n -or $nutrientPropertyCount -eq 0) {
            Write-StageLog -Stage 'Validate' -Category 'Validation' -Level Warning -Path $LogPath -Message 'No nutrients found in DOM response. Ensure the Cronometer diary page is open and the nutrition summary panel is visible.'
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

        $allNutrients = @()
        if ($n) {
            $allNutrients = @(
                $n.PSObject.Properties | ForEach-Object {
                    [pscustomobject]@{
                        Name  = $_.Name
                        Value = $_.Value.value
                        Unit  = $_.Value.unit
                    }
                }
            )
        }

        $biometrics = @(
            $biometricsRaw | ForEach-Object {
                ConvertTo-BiometricRecord -Record $_
            }
        )

        $diaryGroups = @(
            $diaryGroupsRaw | ForEach-Object {
                ConvertTo-DiaryGroupRecord -Group $_
            }
        )

        $diaryEntries = @()
        if (@($diaryGroups).Count -gt 0) {
            $diaryEntries = @(
                $diaryGroups | ForEach-Object { $_.Entries }
            )
        }
        elseif (@($diaryEntriesRaw).Count -gt 0) {
            $diaryEntries = @(
                $diaryEntriesRaw | ForEach-Object {
                    ConvertTo-DiaryEntryRecord -Record $_
                }
            )
        }

        $selectorMatches = [pscustomobject]@{
            DateSelector          = if ($metadata -and $metadata.selectorMatches) { [string]$metadata.selectorMatches.date } else { '' }
            TablesSelector        = if ($metadata -and $metadata.selectorMatches) { [string]$metadata.selectorMatches.tables } else { '' }
            NutrientNameSelector  = if ($metadata -and $metadata.selectorMatches) { [string]$metadata.selectorMatches.nutrientName } else { '' }
            NutrientValueSelector = if ($metadata -and $metadata.selectorMatches) { [string]$metadata.selectorMatches.nutrientValue } else { '' }
            NutrientUnitSelector  = if ($metadata -and $metadata.selectorMatches) { [string]$metadata.selectorMatches.nutrientUnit } else { '' }
            DiaryGroupSelector    = if ($metadata -and $metadata.selectorMatches -and $metadata.selectorMatches.PSObject.Properties['diaryGroup']) { [string]$metadata.selectorMatches.diaryGroup } else { '' }
            DiaryTimeSelector     = if ($metadata -and $metadata.selectorMatches -and $metadata.selectorMatches.PSObject.Properties['diaryTime']) { [string]$metadata.selectorMatches.diaryTime } else { '' }
        }

        $missingSignals = if ($metadata -and $metadata.PSObject.Properties['missingSignals']) { @($metadata.missingSignals) } else { @() }
        $missingSignals = @($missingSignals | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        $missingSignalsSummary = if (@($missingSignals).Count -gt 0) { $missingSignals -join ', ' } else { 'None' }
        $selectorMatchesSummary = @(
            "Date=$($selectorMatches.DateSelector)"
            "Tables=$($selectorMatches.TablesSelector)"
            "Name=$($selectorMatches.NutrientNameSelector)"
            "Value=$($selectorMatches.NutrientValueSelector)"
            "Unit=$($selectorMatches.NutrientUnitSelector)"
            "DiaryGroup=$($selectorMatches.DiaryGroupSelector)"
            "DiaryTime=$($selectorMatches.DiaryTimeSelector)"
        ) -join '; '

        return [pscustomobject]@{
            SchemaVersion          = '2.1'
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
            QueryStatus             = if ($ValidationResult) { $ValidationResult.QueryStatus } elseif ($n -and $nutrientPropertyCount -gt 0) { 'Parsed' } else { 'NoDataFound' }
            ValidationStatus        = if ($ValidationResult) { $ValidationResult.ValidationStatus } else { 'NotRun' }
            RequiredFieldsPresent   = if ($ValidationResult) { $ValidationResult.IsValid } else { $false }
            MissingRequiredFields   = if ($ValidationResult) { @($ValidationResult.MissingRequiredFields) } else { @() }
            MissingRequiredSummary  = if ($ValidationResult -and @($ValidationResult.MissingRequiredFields).Count -gt 0) { @($ValidationResult.MissingRequiredFields) -join ', ' } else { 'None' }
            Biometrics              = $biometrics
            DiaryGroups             = $diaryGroups
            DiaryEntries            = $diaryEntries
            Nutrients               = $allNutrients
            Alerts                  = @($alerts)
            ExtractionMethod        = 'DOM'
            ExtractionAttemptsUsed  = $AttemptsUsed
            DateSelectorUsed        = $selectorMatches.DateSelector
            TablesSelectorUsed      = $selectorMatches.TablesSelector
            NutrientNameSelectorUsed = $selectorMatches.NutrientNameSelector
            NutrientValueSelectorUsed = $selectorMatches.NutrientValueSelector
            NutrientUnitSelectorUsed = $selectorMatches.NutrientUnitSelector
            DiaryGroupSelectorUsed = $selectorMatches.DiaryGroupSelector
            DiaryTimeSelectorUsed = $selectorMatches.DiaryTimeSelector
            MissingSignalsSummary   = $missingSignalsSummary
            OutputMetadata          = [pscustomobject]@{
                SchemaVersion        = '2.1'
                SelectorMatchesSummary = $selectorMatchesSummary
                SelectorMatches      = $selectorMatches
                TableCount           = if ($metadata) { [int]$metadata.tableCount } else { 0 }
                NutrientCount        = if ($metadata) { [int]$metadata.nutrientCount } else { 0 }
                BiometricCount       = if ($metadata -and $metadata.PSObject.Properties['biometricCount']) { [int]$metadata.biometricCount } else { @($biometrics).Count }
                DiaryGroupCount      = if ($metadata -and $metadata.PSObject.Properties['diaryGroupCount']) { [int]$metadata.diaryGroupCount } else { @($diaryGroups).Count }
                DiaryEntryCount      = if ($metadata -and $metadata.PSObject.Properties['diaryEntryCount']) { [int]$metadata.diaryEntryCount } else { @($diaryEntries).Count }
                MissingSignalsSummary = $missingSignalsSummary
                MissingSignals       = $missingSignals
            }
        }
    }
    catch {
        Write-StageLog -Stage 'Parse' -Category 'Output' -Level Error -Path $LogPath -Message ("Failed to parse nutrition response. {0}" -f $_.Exception.Message)
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

function Save-ResultJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Result,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    try {
        $directory = Split-Path -Path $Path -Parent
        if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }

        $json = $Result | ConvertTo-Json -Depth 10
        Set-Content -Path $Path -Value $json -Encoding UTF8
        Write-StageLog -Stage 'Persist' -Category 'Output' -Path $LogPath -Message ("Saved structured result JSON to '{0}'." -f $Path)
    }
    catch {
        Write-StageLog -Stage 'Persist' -Category 'Output' -Level Warning -Path $LogPath -Message ("Failed to save structured result JSON to '{0}'. {1}" -f $Path, $_.Exception.Message)
    }
}

function Save-HistoryCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Result,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    if ($Result.QueryStatus -ne 'Parsed') {
        Write-StageLog -Stage 'Persist' -Category 'Output' -Level Warning -Path $LogPath -Message ("Skipping CSV history append. QueryStatus is '{0}', not 'Parsed'." -f $Result.QueryStatus)
        return
    }

    try {
        $directory = Split-Path -Path $Path -Parent
        if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }

        $row = [pscustomobject]@{
            RunDateTime           = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            DiaryDate             = $Result.DiaryDate
            CaloriesConsumed      = $Result.CaloriesConsumed
            CalorieGoal           = $Result.CalorieGoal
            ProteinGrams          = $Result.ProteinGrams
            ProteinGoalGrams      = $Result.ProteinGoalGrams
            CarbsGrams            = $Result.CarbsGrams
            NetCarbsGrams         = $Result.NetCarbsGrams
            CarbohydrateGoalGrams = $Result.CarbohydrateGoalGrams
            FatGrams              = $Result.FatGrams
            FatGoalGrams          = $Result.FatGoalGrams
            FiberGrams            = $Result.FiberGrams
            SugarsGrams           = $Result.SugarsGrams
            AddedSugarsGrams      = $Result.AddedSugarsGrams
            SaturatedFatGrams     = $Result.SaturatedFatGrams
            TransFatGrams         = $Result.TransFatGrams
            CholesterolMg         = $Result.CholesterolMg
            SodiumMg              = $Result.SodiumMg
            PotassiumMg           = $Result.PotassiumMg
            WaterG                = $Result.WaterG
            CalciumMg             = $Result.CalciumMg
            IronMg                = $Result.IronMg
            MagnesiumMg           = $Result.MagnesiumMg
            PhosphorusMg          = $Result.PhosphorusMg
            ZincMg                = $Result.ZincMg
            CopperMg              = $Result.CopperMg
            ManganeseMg           = $Result.ManganeseMg
            SeleniumUg            = $Result.SeleniumUg
            VitaminA_ug           = $Result.VitaminA_ug
            VitaminC_mg           = $Result.VitaminC_mg
            VitaminD_IU           = $Result.VitaminD_IU
            VitaminE_mg           = $Result.VitaminE_mg
            VitaminK_ug           = $Result.VitaminK_ug
            B1_Thiamine_mg        = $Result.B1_Thiamine_mg
            B2_Riboflavin_mg      = $Result.B2_Riboflavin_mg
            B3_Niacin_mg          = $Result.B3_Niacin_mg
            B5_PantothenicAcid_mg = $Result.B5_PantothenicAcid_mg
            B6_Pyridoxine_mg      = $Result.B6_Pyridoxine_mg
            B12_Cobalamin_ug      = $Result.B12_Cobalamin_ug
            Folate_ug             = $Result.Folate_ug
            QueryStatus           = $Result.QueryStatus
            ValidationStatus      = $Result.ValidationStatus
        }

        $row | Export-Csv -LiteralPath $Path -Append -NoTypeInformation -Encoding UTF8
        Write-StageLog -Stage 'Persist' -Category 'Output' -Path $LogPath -Message ("Appended history row to '{0}'." -f $Path)
    }
    catch {
        Write-StageLog -Stage 'Persist' -Category 'Output' -Level Warning -Path $LogPath -Message ("Failed to append history row to '{0}'. {1}" -f $Path, $_.Exception.Message)
    }
}

function Start-CronometerMonitor {
    [CmdletBinding(SupportsShouldProcess)]
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
        [string]$LogPath,

        [Parameter(Mandatory)]
        [string]$RawResponsePath,

        [Parameter(Mandatory)]
        [string]$ResultJsonPath,

        [Parameter(Mandatory)]
        [string]$HistoryCsvPath,

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

    if (-not $PSCmdlet.ShouldProcess('Cronometer monitor session', 'Run extraction and persist outputs')) {
        return
    }

    Write-StageLog -Stage 'Start' -Category 'Lifecycle' -Path $LogPath -Message 'Cronometer monitor run started.'

    if ($ShouldLaunchChrome) {
        Connect-ChromeForDebugging -ChromePath $ChromePath -UserDataDir $UserDataDir -Port $Port -LogPath $LogPath
    }

    $tabs  = Get-ChromeDebugEndpoint -Port $Port -LogPath $LogPath
    $tab   = Get-CronometerTab -Tabs $tabs -LogPath $LogPath
    $wsUrl = $tab.webSocketDebuggerUrl
    Write-StageLog -Stage 'Connect' -Category 'Browser' -Path $LogPath -Message ("Attaching to tab via WebSocket: '{0}'." -f $wsUrl)

    $extractionResult = Invoke-RetryableNutritionExtraction -WebSocketDebuggerUrl $wsUrl -LogPath $LogPath -MaxAttempts 3 -DelaySeconds 2
    $rawJson = $extractionResult.RawJson

    Save-RawResponse -Content $rawJson -Path $RawResponsePath -Force:$ForceRawDump -LogPath $LogPath

    $result = ConvertFrom-NutritionResponse `
        -RawJson               $rawJson `
        -CalorieGoal           $CalorieGoal `
        -ProteinGoalGrams      $ProteinGoalGrams `
        -CarbohydrateGoalGrams $CarbohydrateGoalGrams `
        -FatGoalGrams          $FatGoalGrams `
        -ValidationResult      $extractionResult.Validation `
        -AttemptsUsed          $extractionResult.AttemptsUsed `
        -LogPath               $LogPath

    Save-ResultJson -Result $result -Path $ResultJsonPath -LogPath $LogPath
    Save-HistoryCsv -Result $result -Path $HistoryCsvPath -LogPath $LogPath

    Write-StageLog -Stage 'Complete' -Category 'Lifecycle' -Path $LogPath -Level $(if ($result.RequiredFieldsPresent) { 'Info' } else { 'Warning' }) -Message ("Monitor run complete. Status: {0}. Validation: {1}. Attempts: {2}. Date: {3}. Calories: {4:F0}/{5}. Protein: {6:F1}g/{7}g." -f `
        $result.QueryStatus, $result.ValidationStatus, $result.ExtractionAttemptsUsed, $result.DiaryDate, $result.CaloriesConsumed, $result.CalorieGoal, `
        $result.ProteinGrams, $result.ProteinGoalGrams)

    return $result
}

#endregion Functions

#region Main

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Start-CronometerMonitor `
            -Port                  $DebuggingPort `
            -ChromePath            $ChromePath `
            -UserDataDir           $UserDataDir `
            -ShouldLaunchChrome    $LaunchChrome.IsPresent `
            -LogPath               $LogPath `
            -RawResponsePath       $RawResponsePath `
            -ResultJsonPath        $ResultJsonPath `
            -HistoryCsvPath        $HistoryCsvPath `
            -ForceRawDump          $ForceRawDump.IsPresent `
            -CalorieGoal           $CalorieGoal `
            -ProteinGoalGrams      $ProteinGoalGrams `
            -CarbohydrateGoalGrams $CarbohydrateGoalGrams `
            -FatGoalGrams          $FatGoalGrams

        $result
    }
    catch {
        Write-Error -Message $_.Exception.Message
        exit 1
    }
}

#endregion Main
