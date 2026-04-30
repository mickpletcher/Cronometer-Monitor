[CmdletBinding()]
param(
    [int]$Port = 8876
)

$repoRoot = Split-Path -Path $PSCommandPath -Parent
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "Dashboard server running at http://localhost:$Port/dashboard/"
Start-Process "http://localhost:$Port/dashboard/"

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $requestPath = $context.Request.Url.AbsolutePath.TrimStart("/")

        if ([string]::IsNullOrWhiteSpace($requestPath)) {
            $requestPath = "dashboard/index.html"
        }
        elseif ($requestPath.EndsWith("/")) {
            $requestPath = Join-Path -Path $requestPath -ChildPath "index.html"
        }

        $resolvedPath = Join-Path -Path $repoRoot -ChildPath $requestPath

        if ((Test-Path -LiteralPath $resolvedPath) -and -not (Get-Item -LiteralPath $resolvedPath).PSIsContainer) {
            $extension = [System.IO.Path]::GetExtension($resolvedPath).ToLowerInvariant()
            $contentType = switch ($extension) {
                ".html" { "text/html; charset=utf-8" }
                ".css" { "text/css; charset=utf-8" }
                ".js" { "application/javascript; charset=utf-8" }
                ".json" { "application/json; charset=utf-8" }
                default { "application/octet-stream" }
            }

            $bytes = [System.IO.File]::ReadAllBytes($resolvedPath)
            $context.Response.StatusCode = 200
            $context.Response.ContentType = $contentType
            $context.Response.ContentLength64 = $bytes.Length
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        else {
            $notFoundBytes = [System.Text.Encoding]::UTF8.GetBytes("Not found")
            $context.Response.StatusCode = 404
            $context.Response.ContentType = "text/plain; charset=utf-8"
            $context.Response.ContentLength64 = $notFoundBytes.Length
            $context.Response.OutputStream.Write($notFoundBytes, 0, $notFoundBytes.Length)
        }

        $context.Response.OutputStream.Close()
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
