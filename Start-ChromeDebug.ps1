<#
.SYNOPSIS
Kills any running Chrome processes and relaunches Chrome with remote debugging enabled.

.DESCRIPTION
Stops all Chrome processes, clears the Chrome session restore flag so the restore
prompt does not appear on relaunch, then starts Chrome with --remote-debugging-port=9222
pointed at the real user profile. Verifies the debug endpoint responds before exiting.

.PARAMETER ChromePath
Full path to chrome.exe.

.PARAMETER UserDataDir
Chrome user data directory. Defaults to the current user's real profile.

.PARAMETER Port
Remote debugging port. Must match the port used by Invoke-CronometerMonitor.ps1.

.EXAMPLE
.\Start-ChromeDebug.ps1
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$ChromePath = 'C:\Program Files\Google\Chrome\Application\chrome.exe',

    [Parameter()]
    [string]$UserDataDir = "$env:LOCALAPPDATA\Google\Chrome\CronometerDebug",

    [Parameter()]
    [int]$Port = 9222
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Kill existing Chrome
$running = Get-Process chrome -ErrorAction SilentlyContinue
if ($running) {
    Write-Output ("Stopping {0} Chrome process(es)..." -f @($running).Count)
    $running | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# Clear session restore flag
$prefsPath = Join-Path -Path $UserDataDir -ChildPath 'Default\Preferences'
if (Test-Path -LiteralPath $prefsPath) {
    try {
        $prefs = Get-Content -LiteralPath $prefsPath -Raw | ConvertFrom-Json
        if (-not $prefs.profile) {
            $prefs | Add-Member -MemberType NoteProperty -Name 'profile' -Value ([pscustomobject]@{})
        }
        $prefs.profile | Add-Member -MemberType NoteProperty -Name 'exit_type'      -Value 'Normal' -Force
        $prefs.profile | Add-Member -MemberType NoteProperty -Name 'exited_cleanly' -Value $true    -Force
        $prefs | ConvertTo-Json -Depth 100 -Compress | Set-Content -LiteralPath $prefsPath -Encoding UTF8
        Write-Output 'Cleared Chrome session restore flag.'
    }
    catch {
        Write-Warning ("Could not clear session restore flag: {0}" -f $_.Exception.Message)
    }
}

# Launch Chrome with remote debugging
Write-Output ("Launching Chrome with remote debugging on port {0}..." -f $Port)
Start-Process -FilePath $ChromePath -ArgumentList @(
    "--remote-debugging-port=$Port",
    "--remote-debugging-address=0.0.0.0",
    '--remote-allow-origins=*',
    "--user-data-dir=`"$UserDataDir`"",
    'https://cronometer.com'
)

Start-Sleep -Seconds 3

# Verify
try {
    $tabs = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json" -TimeoutSec 10
    Write-Output ("Chrome is ready. {0} tab(s) open." -f @($tabs).Count)
    Write-Output 'Navigate to your Cronometer diary date, then run Invoke-CronometerMonitor.ps1.'
}
catch {
    Write-Warning 'Chrome did not respond on the debug port. Try waiting a few seconds and running: Invoke-RestMethod -Uri ''http://localhost:9222/json'''
}
