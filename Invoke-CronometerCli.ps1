[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('fetch', 'history', 'export', 'analyze', 'serve')]
    [string]$Command,

    [Parameter()]
    [string]$DatabasePath,

    [Parameter()]
    [Nullable[datetime]]$FromDate = $null,

    [Parameter()]
    [Nullable[datetime]]$ToDate = $null,

    [Parameter()]
    [int]$Limit = 30,

    [Parameter()]
    [switch]$Descending,

    [Parameter()]
    [ValidateSet('Json', 'Csv')]
    [string]$Format = 'Json',

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [switch]$IncludePayload,

    [Parameter()]
    [switch]$NoPersist,

    [Parameter()]
    [int]$Port = 8878,

    [Parameter()]
    [string]$BindAddress = 'localhost',

    [Parameter()]
    [int]$CacheTtlSeconds = 60,

    [Parameter()]
    [string]$ApiKey,

    [Parameter()]
    [string]$ApiKeyPath,

    [Parameter()]
    [switch]$RequireApiKey,

    [Parameter()]
    [int]$DebuggingPort = 9222,

    [Parameter()]
    [string]$ChromePath = 'C:\Program Files\Google\Chrome\Application\chrome.exe',

    [Parameter()]
    [string]$UserDataDir = (Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Google\Chrome\CronometerDebug'),

    [Parameter()]
    [switch]$LaunchChrome,

    [Parameter()]
    [string]$LogPath,

    [Parameter()]
    [string]$RawResponsePath,

    [Parameter()]
    [string]$ResultJsonPath,

    [Parameter()]
    [string]$NutritionTargetsPath,

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

$scriptRoot = Split-Path -Path $PSCommandPath -Parent

if ([string]::IsNullOrWhiteSpace($DatabasePath)) {
    $DatabasePath = Join-Path -Path $scriptRoot -ChildPath 'logs\CronometerHistory.sqlite'
}

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path -Path $scriptRoot -ChildPath 'logs\CronometerCli.log'
}

if ([string]::IsNullOrWhiteSpace($RawResponsePath)) {
    $RawResponsePath = Join-Path -Path $scriptRoot -ChildPath 'logs\CronometerDiaryRawResponse.json'
}

if ([string]::IsNullOrWhiteSpace($ResultJsonPath)) {
    $ResultJsonPath = Join-Path -Path $scriptRoot -ChildPath 'logs\CronometerMonitorResult.json'
}

if ([string]::IsNullOrWhiteSpace($NutritionTargetsPath)) {
    $NutritionTargetsPath = Join-Path -Path $scriptRoot -ChildPath 'nutrition-targets.schema.json'
}

if ([string]::IsNullOrWhiteSpace($ApiKeyPath)) {
    $ApiKeyPath = Join-Path -Path $scriptRoot -ChildPath 'logs\CronometerApi.key'
}

$savedDebuggingPort = $DebuggingPort
$savedChromePath = $ChromePath
$savedUserDataDir = $UserDataDir
$savedLaunchChrome = $LaunchChrome
$savedLogPath = $LogPath
$savedRawResponsePath = $RawResponsePath
$savedResultJsonPath = $ResultJsonPath
$savedForceRawDump = $ForceRawDump
$savedProteinGoalGrams = $ProteinGoalGrams
$savedCalorieGoal = $CalorieGoal
$savedCarbohydrateGoalGrams = $CarbohydrateGoalGrams
$savedFatGoalGrams = $FatGoalGrams

. (Join-Path -Path $scriptRoot -ChildPath 'Invoke-CronometerMonitor.ps1')
. (Join-Path -Path $scriptRoot -ChildPath 'CronometerHistory.Service.ps1')
. (Join-Path -Path $scriptRoot -ChildPath 'CronometerAnalysis.Service.ps1')

$DebuggingPort = $savedDebuggingPort
$ChromePath = $savedChromePath
$UserDataDir = $savedUserDataDir
$LaunchChrome = $savedLaunchChrome
$LogPath = $savedLogPath
$RawResponsePath = $savedRawResponsePath
$ResultJsonPath = $savedResultJsonPath
$ForceRawDump = $savedForceRawDump
$ProteinGoalGrams = $savedProteinGoalGrams
$CalorieGoal = $savedCalorieGoal
$CarbohydrateGoalGrams = $savedCarbohydrateGoalGrams
$FatGoalGrams = $savedFatGoalGrams

switch ($Command) {
    'fetch' {
        $result = Start-CronometerMonitor `
            -Port $DebuggingPort `
            -ChromePath $ChromePath `
            -UserDataDir $UserDataDir `
            -ShouldLaunchChrome $LaunchChrome.IsPresent `
            -LogPath $LogPath `
            -RawResponsePath $RawResponsePath `
            -ResultJsonPath $ResultJsonPath `
            -ForceRawDump $ForceRawDump.IsPresent `
            -CalorieGoal $CalorieGoal `
            -ProteinGoalGrams $ProteinGoalGrams `
            -CarbohydrateGoalGrams $CarbohydrateGoalGrams `
            -FatGoalGrams $FatGoalGrams

        $snapshot = $null
        if (-not $NoPersist.IsPresent) {
            $snapshot = Save-CronometerHistorySnapshot -DatabasePath $DatabasePath -Result $result -LogPath $LogPath
        }

        [pscustomobject]@{
            Command      = 'fetch'
            DatabasePath = $DatabasePath
            Snapshot     = $snapshot
            Data         = $result
        }
        break
    }
    'history' {
        Get-CronometerHistory -DatabasePath $DatabasePath -FromDate $FromDate -ToDate $ToDate -Limit $Limit -Descending:$Descending -IncludePayload:$IncludePayload
        break
    }
    'export' {
        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            $extension = if ($Format -eq 'Csv') { 'csv' } else { 'json' }
            $OutputPath = Join-Path -Path $scriptRoot -ChildPath ("logs\exports\CronometerHistory_{0}.{1}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'), $extension)
        }

        Export-CronometerHistory -DatabasePath $DatabasePath -OutputPath $OutputPath -Format $Format -FromDate $FromDate -ToDate $ToDate -Limit $Limit -Descending:$Descending -IncludePayload:$IncludePayload
        break
    }
    'analyze' {
        $result = $null
        if ((Test-Path -LiteralPath $ResultJsonPath) -and -not $LaunchChrome.IsPresent) {
            $result = Get-Content -LiteralPath $ResultJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20
        }
        else {
            $result = Start-CronometerMonitor `
                -Port $DebuggingPort `
                -ChromePath $ChromePath `
                -UserDataDir $UserDataDir `
                -ShouldLaunchChrome $LaunchChrome.IsPresent `
                -LogPath $LogPath `
                -RawResponsePath $RawResponsePath `
                -ResultJsonPath $ResultJsonPath `
                -ForceRawDump $ForceRawDump.IsPresent `
                -CalorieGoal $CalorieGoal `
                -ProteinGoalGrams $ProteinGoalGrams `
                -CarbohydrateGoalGrams $CarbohydrateGoalGrams `
                -FatGoalGrams $FatGoalGrams
        }

        [pscustomobject]@{
            Command  = 'analyze'
            Data     = $result
            Analysis = Get-CronometerDerivedAnalysis -Result $result -SchemaPath $NutritionTargetsPath
        }
        break
    }
    'serve' {
        & (Join-Path -Path $scriptRoot -ChildPath 'Start-CronometerApi.ps1') `
            -Port $Port `
            -BindAddress $BindAddress `
            -CacheTtlSeconds $CacheTtlSeconds `
            -ApiKey $ApiKey `
            -ApiKeyPath $ApiKeyPath `
            -RequireApiKey:$RequireApiKey `
            -DebuggingPort $DebuggingPort `
            -ChromePath $ChromePath `
            -UserDataDir $UserDataDir `
            -LaunchChrome:$LaunchChrome `
            -LogPath $LogPath `
            -RawResponsePath $RawResponsePath `
            -ResultJsonPath $ResultJsonPath `
            -NutritionTargetsPath $NutritionTargetsPath `
            -ForceRawDump:$ForceRawDump `
            -ProteinGoalGrams $ProteinGoalGrams `
            -CalorieGoal $CalorieGoal `
            -CarbohydrateGoalGrams $CarbohydrateGoalGrams `
            -FatGoalGrams $FatGoalGrams `
            -SnapshotDatabasePath $DatabasePath
        break
    }
}
