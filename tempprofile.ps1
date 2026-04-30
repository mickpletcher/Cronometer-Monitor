Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

Start-Process 'C:\Program Files\Google\Chrome\Application\chrome.exe' -ArgumentList @(
    '--remote-debugging-port=9222',
    '--remote-debugging-address=0.0.0.0',
    '--remote-allow-origins=*',
    "--user-data-dir=`"$env:TEMP\ChromeDebug`"",
    'https://cronometer.com'
)

Start-Sleep -Seconds 5
Invoke-RestMethod -Uri 'http://127.0.0.1:9222/json'