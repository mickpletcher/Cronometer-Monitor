Get-NetTCPConnection -LocalPort 8876 -State Listen |
Select-Object -ExpandProperty OwningProcess -Unique |
ForEach-Object { Stop-Process -Id $_ -Force }