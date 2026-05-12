$repoPath = "C:\Users\caspe\Desktop\DisasterRNG"
Set-Location $repoPath

$rojoRunning = Get-Process rojo -ErrorAction SilentlyContinue
if (-not $rojoRunning) {
    Start-Process -FilePath "rojo" -ArgumentList "serve" -WorkingDirectory $repoPath -WindowStyle Hidden
}

while ($true) {
    try {
        Set-Location $repoPath
        git fetch 2>&1 | Out-Null
        $behind = git rev-list HEAD..origin/main --count 2>&1
        if ($behind -gt 0) {
            git pull --rebase 2>&1 | Out-Null
        }
        $status = git status --porcelain
        if ($status) {
            git add .
            git commit -m "Auto-sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>&1 | Out-Null
            git push 2>&1 | Out-Null
        }
        $rojoCheck = Get-Process rojo -ErrorAction SilentlyContinue
        if (-not $rojoCheck) {
            Start-Process -FilePath "rojo" -ArgumentList "serve" -WorkingDirectory $repoPath -WindowStyle Hidden
        }
    }
    catch {}
    Start-Sleep -Seconds 120
}
