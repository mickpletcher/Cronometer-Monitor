Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-CronometerApiLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    if (Get-Command -Name 'Write-CMTraceLog' -ErrorAction SilentlyContinue) {
        Write-CMTraceLog -Message $Message -Level $Level -Path $Path -Component 'CronometerApi'
        return
    }

    $directory = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    $timestamp = (Get-Date).ToString('s')
    Add-Content -Path $Path -Value ("[{0}][{1}] {2}" -f $timestamp, $Level.ToUpperInvariant(), $Message)
}

function Test-CronometerLoopbackBinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BindAddress
    )

    return $BindAddress -in @('localhost', '127.0.0.1', '::1')
}

function Resolve-CronometerApiKey {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowEmptyString()]
        [string]$ApiKey,

        [Parameter()]
        [AllowEmptyString()]
        [string]$ApiKeyPath
    )

    if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
        return $ApiKey.Trim()
    }

    if (-not [string]::IsNullOrWhiteSpace($ApiKeyPath) -and (Test-Path -LiteralPath $ApiKeyPath)) {
        return (Get-Content -LiteralPath $ApiKeyPath -Raw -Encoding UTF8).Trim()
    }

    return $null
}

function Test-CronometerApiKeyRequirement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BindAddress,

        [Parameter()]
        [bool]$RequireApiKey = $false,

        [Parameter()]
        [AllowEmptyString()]
        [string]$ResolvedApiKey
    )

    if ($RequireApiKey) {
        return $true
    }

    if (-not (Test-CronometerLoopbackBinding -BindAddress $BindAddress) -and -not [string]::IsNullOrWhiteSpace($ResolvedApiKey)) {
        return $true
    }

    return -not (Test-CronometerLoopbackBinding -BindAddress $BindAddress)
}

function New-CronometerApiState {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [int]$CacheTtlSeconds,

        [Parameter(Mandatory)]
        [string]$ResultJsonPath,

        [Parameter()]
        [string]$SnapshotDatabasePath
    )

    if (-not $PSCmdlet.ShouldProcess('Cronometer API state', 'Initialize in memory')) {
        return $null
    }

    return [pscustomobject]@{
        CacheTtlSeconds  = $CacheTtlSeconds
        ResultJsonPath   = $ResultJsonPath
        SnapshotDatabasePath = $SnapshotDatabasePath
        CachedResult     = $null
        CachedAtUtc      = $null
        CacheSource      = $null
        LastRefreshUtc   = $null
        LastRefreshError = $null
    }
}

function Get-CronometerApiCacheEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [Parameter()]
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    if ($null -eq $State.CachedResult -or $null -eq $State.CachedAtUtc) {
        return $null
    }

    $ageSeconds = ($NowUtc - [datetime]$State.CachedAtUtc).TotalSeconds
    if ($ageSeconds -ge $State.CacheTtlSeconds) {
        return $null
    }

    return [pscustomobject]@{
        Data         = $State.CachedResult
        Source       = $State.CacheSource
        CachedAtUtc  = $State.CachedAtUtc
        AgeSeconds   = [math]::Round($ageSeconds, 3)
        CacheTtl     = $State.CacheTtlSeconds
        CacheHit     = $true
    }
}

function Set-CronometerApiCacheEntry {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [Parameter(Mandatory)]
        [object]$Data,

        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter()]
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    if (-not $PSCmdlet.ShouldProcess('Cronometer API cache entry', 'Update in memory')) {
        return $null
    }

    $State.CachedResult = $Data
    $State.CachedAtUtc = $NowUtc
    $State.CacheSource = $Source
    $State.LastRefreshUtc = $NowUtc
    $State.LastRefreshError = $null

    return [pscustomobject]@{
        Data         = $Data
        Source       = $Source
        CachedAtUtc  = $State.CachedAtUtc
        AgeSeconds   = 0
        CacheTtl     = $State.CacheTtlSeconds
        CacheHit     = ($Source -ne 'FreshExtraction')
    }
}

function Read-CronometerApiResultFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [Parameter()]
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    if (-not (Test-Path -LiteralPath $State.ResultJsonPath)) {
        return $null
    }

    $item = Get-Item -LiteralPath $State.ResultJsonPath
    $ageSeconds = ($NowUtc - $item.LastWriteTimeUtc).TotalSeconds
    if ($ageSeconds -ge $State.CacheTtlSeconds) {
        return $null
    }

    $content = Get-Content -LiteralPath $State.ResultJsonPath -Raw -Encoding UTF8
    $data = $content | ConvertFrom-Json -Depth 20
    return (Set-CronometerApiCacheEntry -State $State -Data $data -Source 'ResultFile' -NowUtc $NowUtc)
}

function Invoke-CronometerApiExtraction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [Parameter(Mandatory)]
        [scriptblock]$Extractor,

        [Parameter()]
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    try {
        $result = & $Extractor
        return (Set-CronometerApiCacheEntry -State $State -Data $result -Source 'FreshExtraction' -NowUtc $NowUtc)
    }
    catch {
        $State.LastRefreshError = $_.Exception.Message
        throw
    }
}

function Get-CronometerApiLatestResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [Parameter(Mandatory)]
        [scriptblock]$Extractor,

        [Parameter()]
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    $cached = Get-CronometerApiCacheEntry -State $State -NowUtc $NowUtc
    if ($null -ne $cached) {
        return $cached
    }

    $fromFile = Read-CronometerApiResultFile -State $State -NowUtc $NowUtc
    if ($null -ne $fromFile) {
        return $fromFile
    }

    return (Invoke-CronometerApiExtraction -State $State -Extractor $Extractor -NowUtc $NowUtc)
}

function Get-CronometerApiRequestKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Net.HttpListenerRequest]$Request
    )

    $headerValue = $Request.Headers['X-API-Key']
    if (-not [string]::IsNullOrWhiteSpace($headerValue)) {
        return $headerValue.Trim()
    }

    $queryValue = $Request.QueryString['apiKey']
    if (-not [string]::IsNullOrWhiteSpace($queryValue)) {
        return $queryValue.Trim()
    }

    return $null
}

function Test-CronometerApiAuthorizedRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Net.HttpListenerRequest]$Request,

        [Parameter()]
        [AllowEmptyString()]
        [string]$ExpectedApiKey,

        [Parameter()]
        [bool]$RequireApiKey = $false
    )

    if (-not $RequireApiKey) {
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($ExpectedApiKey)) {
        return $false
    }

    $actualKey = Get-CronometerApiRequestKey -Request $Request
    return $actualKey -ceq $ExpectedApiKey
}

function Send-CronometerApiJsonResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Net.HttpListenerResponse]$Response,

        [Parameter(Mandatory)]
        [object]$Body,

        [Parameter()]
        [int]$StatusCode = 200
    )

    $json = $Body | ConvertTo-Json -Depth 20
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $Response.StatusCode = $StatusCode
    $Response.ContentType = 'application/json; charset=utf-8'
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Response.OutputStream.Close()
}

function Send-CronometerApiTextResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Net.HttpListenerResponse]$Response,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [int]$StatusCode = 200
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Message)
    $Response.StatusCode = $StatusCode
    $Response.ContentType = 'text/plain; charset=utf-8'
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Response.OutputStream.Close()
}

function Get-CronometerApiHealthPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [Parameter(Mandatory)]
        [string]$BindAddress,

        [Parameter(Mandatory)]
        [int]$Port,

        [Parameter()]
        [bool]$RequireApiKey = $false
    )

    $cacheEntry = Get-CronometerApiCacheEntry -State $State

    return [pscustomobject]@{
        Service            = 'CronometerApi'
        Status             = 'Healthy'
        BindAddress        = $BindAddress
        Port               = $Port
        RequireApiKey      = $RequireApiKey
        CacheTtlSeconds    = $State.CacheTtlSeconds
        CacheLoaded        = ($null -ne $State.CachedResult)
        CacheSource        = $State.CacheSource
        CacheAgeSeconds    = if ($cacheEntry) { $cacheEntry.AgeSeconds } else { $null }
        LastRefreshUtc     = $State.LastRefreshUtc
        LastRefreshError   = $State.LastRefreshError
        ResultJsonPath     = $State.ResultJsonPath
        ResultFileExists   = (Test-Path -LiteralPath $State.ResultJsonPath)
        SnapshotDatabasePath = $State.SnapshotDatabasePath
        SnapshotDatabaseExists = if ([string]::IsNullOrWhiteSpace($State.SnapshotDatabasePath)) { $false } else { Test-Path -LiteralPath $State.SnapshotDatabasePath }
        TimestampUtc       = [datetime]::UtcNow
    }
}
