[CmdletBinding()]
param(
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
    [string]$SnapshotDatabasePath,

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

if ([string]::IsNullOrWhiteSpace($ApiKeyPath)) {
    $ApiKeyPath = Join-Path -Path $scriptRoot -ChildPath 'logs\CronometerApi.key'
}

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path -Path $scriptRoot -ChildPath 'logs\CronometerApi.log'
}

if ([string]::IsNullOrWhiteSpace($RawResponsePath)) {
    $RawResponsePath = Join-Path -Path $scriptRoot -ChildPath 'logs\CronometerDiaryRawResponse.json'
}

if ([string]::IsNullOrWhiteSpace($ResultJsonPath)) {
    $ResultJsonPath = Join-Path -Path $scriptRoot -ChildPath 'logs\CronometerMonitorResult.json'
}

if ([string]::IsNullOrWhiteSpace($SnapshotDatabasePath)) {
    $SnapshotDatabasePath = Join-Path -Path $scriptRoot -ChildPath 'logs\CronometerHistory.sqlite'
}

if ([string]::IsNullOrWhiteSpace($NutritionTargetsPath)) {
    $NutritionTargetsPath = Join-Path -Path $scriptRoot -ChildPath 'nutrition-targets.schema.json'
}

$savedDebuggingPort = $DebuggingPort
$savedChromePath = $ChromePath
$savedUserDataDir = $UserDataDir
$savedLaunchChrome = $LaunchChrome
$savedLogPath = $LogPath
$savedRawResponsePath = $RawResponsePath
$savedResultJsonPath = $ResultJsonPath
$savedSnapshotDatabasePath = $SnapshotDatabasePath
$savedNutritionTargetsPath = $NutritionTargetsPath
$savedForceRawDump = $ForceRawDump
$savedProteinGoalGrams = $ProteinGoalGrams
$savedCalorieGoal = $CalorieGoal
$savedCarbohydrateGoalGrams = $CarbohydrateGoalGrams
$savedFatGoalGrams = $FatGoalGrams

. (Join-Path -Path $scriptRoot -ChildPath 'Invoke-CronometerMonitor.ps1')
. (Join-Path -Path $scriptRoot -ChildPath 'CronometerApi.Service.ps1')
. (Join-Path -Path $scriptRoot -ChildPath 'CronometerHistory.Service.ps1')
. (Join-Path -Path $scriptRoot -ChildPath 'CronometerAnalysis.Service.ps1')

$DebuggingPort = $savedDebuggingPort
$ChromePath = $savedChromePath
$UserDataDir = $savedUserDataDir
$LaunchChrome = $savedLaunchChrome
$LogPath = $savedLogPath
$RawResponsePath = $savedRawResponsePath
$ResultJsonPath = $savedResultJsonPath
$SnapshotDatabasePath = $savedSnapshotDatabasePath
$NutritionTargetsPath = $savedNutritionTargetsPath
$ForceRawDump = $savedForceRawDump
$ProteinGoalGrams = $savedProteinGoalGrams
$CalorieGoal = $savedCalorieGoal
$CarbohydrateGoalGrams = $savedCarbohydrateGoalGrams
$FatGoalGrams = $savedFatGoalGrams

$resolvedApiKey = Resolve-CronometerApiKey -ApiKey $ApiKey -ApiKeyPath $ApiKeyPath
$mustRequireApiKey = Test-CronometerApiKeyRequirement -BindAddress $BindAddress -RequireApiKey $RequireApiKey.IsPresent -ResolvedApiKey $resolvedApiKey

if ($mustRequireApiKey -and [string]::IsNullOrWhiteSpace($resolvedApiKey)) {
    throw "API key is required when binding beyond localhost or when RequireApiKey is specified."
}

$state = New-CronometerApiState -CacheTtlSeconds $CacheTtlSeconds -ResultJsonPath $ResultJsonPath -SnapshotDatabasePath $SnapshotDatabasePath
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://$BindAddress`:$Port/")
$listener.Start()

Write-CronometerApiLog -Path $LogPath -Message ("API listener started on http://{0}:{1}/" -f $BindAddress, $Port)
Write-Output ("Cronometer API listening at http://{0}:{1}/" -f $BindAddress, $Port)

$extractor = {
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

    try {
        [void](Save-CronometerHistorySnapshot -DatabasePath $SnapshotDatabasePath -Result $result -LogPath $LogPath)
    }
    catch {
        Write-CronometerApiLog -Path $LogPath -Level Warning -Message ("Snapshot persistence failed after fresh extraction. {0}" -f $_.Exception.Message)
    }

    return $result
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        $path = $request.Url.AbsolutePath.TrimEnd('/')
        if ([string]::IsNullOrWhiteSpace($path)) {
            $path = '/'
        }

        try {
            switch ($path) {
                '/health' {
                    if ($request.HttpMethod -ne 'GET') {
                        Send-CronometerApiJsonResponse -Response $response -StatusCode 405 -Body ([pscustomobject]@{ Error = 'MethodNotAllowed'; Message = 'Use GET for /health.' })
                        continue
                    }

                    $payload = Get-CronometerApiHealthPayload -State $state -BindAddress $BindAddress -Port $Port -RequireApiKey $mustRequireApiKey
                    Send-CronometerApiJsonResponse -Response $response -Body $payload
                    continue
                }
                '/api/latest' {
                    if ($request.HttpMethod -ne 'GET') {
                        Send-CronometerApiJsonResponse -Response $response -StatusCode 405 -Body ([pscustomobject]@{ Error = 'MethodNotAllowed'; Message = 'Use GET for /api/latest.' })
                        continue
                    }

                    if (-not (Test-CronometerApiAuthorizedRequest -Request $request -ExpectedApiKey $resolvedApiKey -RequireApiKey $mustRequireApiKey)) {
                        Send-CronometerApiJsonResponse -Response $response -StatusCode 401 -Body ([pscustomobject]@{ Error = 'Unauthorized'; Message = 'Valid API key required.' })
                        continue
                    }

                    $latest = Get-CronometerApiLatestResult -State $state -Extractor $extractor
                    Send-CronometerApiJsonResponse -Response $response -Body ([pscustomobject]@{
                        Source = $latest.Source
                        Cache = [pscustomobject]@{
                            Hit = $latest.CacheHit
                            CachedAtUtc = $latest.CachedAtUtc
                            AgeSeconds = $latest.AgeSeconds
                            TtlSeconds = $latest.CacheTtl
                        }
                        Data = $latest.Data
                    })
                    continue
                }
                '/api/analysis' {
                    if ($request.HttpMethod -ne 'GET') {
                        Send-CronometerApiJsonResponse -Response $response -StatusCode 405 -Body ([pscustomobject]@{ Error = 'MethodNotAllowed'; Message = 'Use GET for /api/analysis.' })
                        continue
                    }

                    if (-not (Test-CronometerApiAuthorizedRequest -Request $request -ExpectedApiKey $resolvedApiKey -RequireApiKey $mustRequireApiKey)) {
                        Send-CronometerApiJsonResponse -Response $response -StatusCode 401 -Body ([pscustomobject]@{ Error = 'Unauthorized'; Message = 'Valid API key required.' })
                        continue
                    }

                    $latest = Get-CronometerApiLatestResult -State $state -Extractor $extractor
                    $analysis = Get-CronometerDerivedAnalysis -Result $latest.Data -SchemaPath $NutritionTargetsPath
                    Send-CronometerApiJsonResponse -Response $response -Body ([pscustomobject]@{
                        Source = $latest.Source
                        Cache = [pscustomobject]@{
                            Hit = $latest.CacheHit
                            CachedAtUtc = $latest.CachedAtUtc
                            AgeSeconds = $latest.AgeSeconds
                            TtlSeconds = $latest.CacheTtl
                        }
                        Data = $latest.Data
                        Analysis = $analysis
                    })
                    continue
                }
                '/api/refresh' {
                    if ($request.HttpMethod -notin @('POST', 'GET')) {
                        Send-CronometerApiJsonResponse -Response $response -StatusCode 405 -Body ([pscustomobject]@{ Error = 'MethodNotAllowed'; Message = 'Use POST for /api/refresh.' })
                        continue
                    }

                    if (-not (Test-CronometerApiAuthorizedRequest -Request $request -ExpectedApiKey $resolvedApiKey -RequireApiKey $mustRequireApiKey)) {
                        Send-CronometerApiJsonResponse -Response $response -StatusCode 401 -Body ([pscustomobject]@{ Error = 'Unauthorized'; Message = 'Valid API key required.' })
                        continue
                    }

                    $fresh = Invoke-CronometerApiExtraction -State $state -Extractor $extractor
                    Send-CronometerApiJsonResponse -Response $response -Body ([pscustomobject]@{
                        Source = $fresh.Source
                        Cache = [pscustomobject]@{
                            Hit = $fresh.CacheHit
                            CachedAtUtc = $fresh.CachedAtUtc
                            AgeSeconds = $fresh.AgeSeconds
                            TtlSeconds = $fresh.CacheTtl
                        }
                        Data = $fresh.Data
                    })
                    continue
                }
                '/' {
                    Send-CronometerApiTextResponse -Response $response -Message "Cronometer API running. Endpoints: /health, /api/latest, /api/analysis, /api/refresh"
                    continue
                }
                default {
                    Send-CronometerApiJsonResponse -Response $response -StatusCode 404 -Body ([pscustomobject]@{ Error = 'NotFound'; Message = 'Endpoint not found.' })
                    continue
                }
            }
        }
        catch {
            Write-CronometerApiLog -Path $LogPath -Level Error -Message ("Request failure on {0} {1}. {2}" -f $request.HttpMethod, $path, $_.Exception.Message)
            Send-CronometerApiJsonResponse -Response $response -StatusCode 500 -Body ([pscustomobject]@{
                Error = 'ServerError'
                Message = $_.Exception.Message
            })
        }
    }
}
finally {
    Write-CronometerApiLog -Path $LogPath -Message 'API listener stopping.'
    $listener.Stop()
    $listener.Close()
}
