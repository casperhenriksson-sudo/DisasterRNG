Unregister-ScheduledTask -TaskName "DisasterRNG-AutoSync" -Confirm:$false
Stop-Process -Name "rojo" -Force -ErrorAction SilentlyContinue
Write-Host "Auto-sync removed."
