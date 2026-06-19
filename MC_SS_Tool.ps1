$Host.UI.RawUI.BackgroundColor = "Black"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

# Find Python silently
$py = $null
foreach ($cmd in @("python","python3","py")) {
    try {
        $v = & $cmd --version 2>&1
        if ($LASTEXITCODE -eq 0 -and "$v" -match "Python 3") { $py = $cmd; break }
    } catch {}
}

# Auto-install if not found
if (-not $py) {
    $installer = "$env:TEMP\pysetup.exe"
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe" -OutFile $installer -UseBasicParsing 2>$null
        Start-Process -FilePath $installer -ArgumentList "/quiet","InstallAllUsers=0","PrependPath=1","Include_test=0" -Wait 2>$null
        Remove-Item $installer -Force -EA SilentlyContinue
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
    } catch {}
    foreach ($cmd in @("python","python3","py")) {
        try {
            $v = & $cmd --version 2>&1
            if ($LASTEXITCODE -eq 0 -and "$v" -match "Python 3") { $py = $cmd; break }
        } catch {}
    }
    if (-not $py) {
        Write-Host "  [!] Python install failed. Get it from python.org" -ForegroundColor Red
        Read-Host; exit
    }
}

# Download and run scanner silently
$tmp = "$env:TEMP\mc_ss.py"
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/3ZIZvalz/ss-tool/main/mc_ss.py" -OutFile $tmp -UseBasicParsing 2>$null
} catch {
    Write-Host "  [!] Download failed." -ForegroundColor Red
    Read-Host; exit
}

& $py $tmp
Remove-Item $tmp -Force -EA SilentlyContinue
