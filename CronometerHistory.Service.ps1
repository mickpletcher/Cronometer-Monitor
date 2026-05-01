Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-CronometerHistoryLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [string]$Path,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    if (Get-Command -Name 'Write-CMTraceLog' -ErrorAction SilentlyContinue) {
        Write-CMTraceLog -Message $Message -Level $Level -Path $Path -Component 'CronometerHistory'
        return
    }

    $directory = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    $timestamp = (Get-Date).ToString('s')
    Add-Content -Path $Path -Value ("[{0}][{1}] {2}" -f $timestamp, $Level.ToUpperInvariant(), $Message)
}

function Get-CronometerHistoryPythonCommand {
    [CmdletBinding()]
    param()

    $pythonCommand = Get-Command -Name 'python' -ErrorAction SilentlyContinue
    if ($pythonCommand) {
        return $pythonCommand.Source
    }

    $pyCommand = Get-Command -Name 'py' -ErrorAction SilentlyContinue
    if ($pyCommand) {
        return $pyCommand.Source
    }

    throw 'Python 3 is required for SQLite snapshot storage because the helper uses the built in sqlite3 module.'
}

function Get-CronometerHistoryToolPath {
    [CmdletBinding()]
    param()

    return Join-Path -Path $PSScriptRoot -ChildPath 'tools\cronometer_history_store.py'
}

function Invoke-CronometerHistoryPython {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $pythonCommand = Get-CronometerHistoryPythonCommand
    $toolPath = Get-CronometerHistoryToolPath

    if (-not (Test-Path -LiteralPath $toolPath)) {
        throw "SQLite helper not found at '$toolPath'."
    }

    $allArguments = @($toolPath) + $Arguments
    $output = & $pythonCommand @allArguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = [string]::Join([Environment]::NewLine, @($output | ForEach-Object { [string]$_ }))

    if ($exitCode -ne 0) {
        throw "SQLite helper failed with exit code $exitCode. $text"
    }

    return $text
}

function Initialize-CronometerHistoryStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath
    )

    $directory = Split-Path -Path $DatabasePath -Parent
    if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    $json = Invoke-CronometerHistoryPython -Arguments @(
        'init',
        '--db',
        $DatabasePath
    )

    return ($json | ConvertFrom-Json)
}

function Test-CronometerSnapshotEligible {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Result
    )

    if ($null -eq $Result) {
        return $false
    }

    $queryStatus = if ($Result.PSObject.Properties['QueryStatus']) { [string]$Result.QueryStatus } else { '' }
    $requiredFieldsPresent = if ($Result.PSObject.Properties['RequiredFieldsPresent']) { [bool]$Result.RequiredFieldsPresent } else { $false }

    return ($queryStatus -eq 'Parsed' -and $requiredFieldsPresent)
}

function Save-CronometerHistorySnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath,

        [Parameter(Mandatory)]
        [object]$Result,

        [Parameter()]
        [string]$LogPath
    )

    if (-not (Test-CronometerSnapshotEligible -Result $Result)) {
        Write-CronometerHistoryLog -Path $LogPath -Level Warning -Message 'Skipping snapshot persistence because the result is not a successful parsed extraction.'
        return [pscustomobject]@{
            Saved   = $false
            Reason  = 'ResultNotEligible'
            Storage = 'SQLite'
        }
    }

    [void](Initialize-CronometerHistoryStore -DatabasePath $DatabasePath)

    $tempPath = [System.IO.Path]::GetTempFileName()
    try {
        $Result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tempPath -Encoding UTF8
        $json = Invoke-CronometerHistoryPython -Arguments @(
            'upsert',
            '--db',
            $DatabasePath,
            '--payload',
            $tempPath
        )
        $saved = $json | ConvertFrom-Json
        Write-CronometerHistoryLog -Path $LogPath -Message ("Saved snapshot '{0}' to '{1}'." -f $saved.SnapshotKey, $DatabasePath)
        return $saved
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force
        }
    }
}

function Get-CronometerHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
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
        [switch]$IncludePayload
    )

    [void](Initialize-CronometerHistoryStore -DatabasePath $DatabasePath)

    $arguments = @(
        'query',
        '--db',
        $DatabasePath,
        '--limit',
        [string]$Limit,
        '--order',
        $(if ($Descending.IsPresent) { 'desc' } else { 'asc' })
    )

    if ($null -ne $FromDate) {
        $arguments += @('--from-date', ([datetime]$FromDate).ToString('yyyy-MM-dd'))
    }

    if ($null -ne $ToDate) {
        $arguments += @('--to-date', ([datetime]$ToDate).ToString('yyyy-MM-dd'))
    }

    if ($IncludePayload.IsPresent) {
        $arguments += '--include-payload'
    }

    $json = Invoke-CronometerHistoryPython -Arguments $arguments
    $data = $json | ConvertFrom-Json -Depth 20
    if ($null -eq $data) {
        return @()
    }

    return @($data)
}

function Export-CronometerHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter()]
        [ValidateSet('Json', 'Csv')]
        [string]$Format = 'Json',

        [Parameter()]
        [Nullable[datetime]]$FromDate = $null,

        [Parameter()]
        [Nullable[datetime]]$ToDate = $null,

        [Parameter()]
        [int]$Limit = 30,

        [Parameter()]
        [switch]$Descending,

        [Parameter()]
        [switch]$IncludePayload
    )

    $rows = Get-CronometerHistory -DatabasePath $DatabasePath -FromDate $FromDate -ToDate $ToDate -Limit $Limit -Descending:$Descending -IncludePayload:$IncludePayload
    $directory = Split-Path -Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    switch ($Format) {
        'Json' {
            $rows | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
        }
        'Csv' {
            $rows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8
        }
    }

    return [pscustomobject]@{
        OutputPath = $OutputPath
        Format     = $Format
        RowCount   = @($rows).Count
    }
}
