<#
.SYNOPSIS
Serves the Cronometer dashboard as a local HTTP server.

.DESCRIPTION
Starts an HTTP listener rooted at the script directory. The dashboard files
are served from the dashboard\ subfolder and the result JSON is served from
the logs\ subfolder. Opens the dashboard in the default browser automatically.

Serves until Ctrl+C is pressed.

.PARAMETER Port
TCP port to listen on. Default is 8876.

.PARAMETER NoBrowser
Skip opening the browser automatically on start.

.EXAMPLE
.\Start-CronometerDashboard.ps1

.EXAMPLE
.\Start-CronometerDashboard.ps1 -Port 9000 -NoBrowser
#>
[CmdletBinding()]
param(
    [Parameter()]
    [int]$Port = 8876,

    [Parameter()]
    [switch]$NoBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$mimeTypes = @{
    '.html' = 'text/html; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.ico'  = 'image/x-icon'
    '.png'  = 'image/png'
    '.svg'  = 'image/svg+xml'
}

$resolvedRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$prefix       = "http://localhost:$Port/"
$dashboardUrl = "${prefix}dashboard/"

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
}
catch {
    Write-Error ("Failed to start HTTP listener on port {0}. Is another process using that port? {1}" -f $Port, $_.Exception.Message)
    exit 1
}

Write-Output ("Dashboard running at {0}" -f $dashboardUrl)
Write-Output 'Press Ctrl+C to stop.'

if (-not $NoBrowser) {
    Start-Process $dashboardUrl
}

try {
    while ($listener.IsListening) {
        $context = $null
        try {
            $context = $listener.GetContext()
        }
        catch {
            break
        }

        $response = $context.Response

        try {
            $urlPath = $context.Request.Url.LocalPath.TrimStart('/')

            if ($urlPath -eq '') {
                $response.StatusCode = 302
                $response.Headers.Add('Location', $dashboardUrl)
                $response.Close()
                continue
            }

            $urlPath  = $urlPath -replace '/', [System.IO.Path]::DirectorySeparatorChar
            $fullPath = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $urlPath))

            if (-not $fullPath.StartsWith($resolvedRoot)) {
                $response.StatusCode = 403
                $bytes = [System.Text.Encoding]::UTF8.GetBytes('403 Forbidden')
                $response.ContentType = 'text/plain'
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
                $response.Close()
                continue
            }

            if (Test-Path -LiteralPath $fullPath -PathType Container) {
                $fullPath = Join-Path $fullPath 'index.html'
            }

            if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
                $ext   = [System.IO.Path]::GetExtension($fullPath).ToLower()
                $mime  = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { 'application/octet-stream' }
                $bytes = [System.IO.File]::ReadAllBytes($fullPath)

                $response.StatusCode      = 200
                $response.ContentType     = $mime
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            else {
                $response.StatusCode = 404
                $bytes = [System.Text.Encoding]::UTF8.GetBytes('404 Not Found')
                $response.ContentType = 'text/plain'
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
        }
        catch {
            try {
                $response.StatusCode = 500
                $bytes = [System.Text.Encoding]::UTF8.GetBytes("500 Internal Server Error: $($_.Exception.Message)")
                $response.ContentType = 'text/plain'
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            catch {
                Write-Verbose ("Failed to write error response. {0}" -f $_.Exception.Message)
            }
        }
        finally {
            try { $response.Close() } catch { Write-Verbose ("Failed to close dashboard response. {0}" -f $_.Exception.Message) }
        }
    }
}
finally {
    if ($listener.IsListening) { $listener.Stop() }
    $listener.Close()
    Write-Output 'Dashboard server stopped.'
}
