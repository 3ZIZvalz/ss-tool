$Host.UI.RawUI.BackgroundColor = "Black"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

Write-Host ""
Write-Host "  Checking Python..." -ForegroundColor DarkGray

# Check Python
$py = $null
foreach ($cmd in @("python","python3","py")) {
    try {
        $v = & $cmd --version 2>&1
        if ($LASTEXITCODE -eq 0 -and "$v" -match "Python 3") { $py = $cmd; break }
    } catch {}
}

if (-not $py) {
    Write-Host "  Python not found. Installing silently..." -ForegroundColor Yellow
    
    $installer = "$env:TEMP\python_installer.exe"
    $url = "https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe"
    
    Write-Host "  Downloading Python 3.12..." -ForegroundColor DarkGray
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
    } catch {
        # Try winget if download fails
        Write-Host "  Trying winget..." -ForegroundColor DarkGray
        try {
            winget install Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        } catch {}
    }
    
    if (Test-Path $installer) {
        Write-Host "  Installing Python (this may take a minute)..." -ForegroundColor DarkGray
        Start-Process -FilePath $installer -ArgumentList "/quiet","InstallAllUsers=0","PrependPath=1","Include_test=0" -Wait
        Remove-Item $installer -Force -EA SilentlyContinue
        
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
    }
    
    # Try again
    foreach ($cmd in @("python","python3","py")) {
        try {
            $v = & $cmd --version 2>&1
            if ($LASTEXITCODE -eq 0 -and "$v" -match "Python 3") { $py = $cmd; break }
        } catch {}
    }
    
    if (-not $py) {
        Write-Host ""
        Write-Host "  [!] Could not install Python automatically." -ForegroundColor Red
        Write-Host "  Please install manually from: https://python.org" -ForegroundColor Yellow
        Write-Host "  Check 'Add Python to PATH' during install." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "  Press Enter to exit"
        exit
    }
    
    Write-Host "  Python installed!" -ForegroundColor Green
} else {
    Write-Host "  Python found." -ForegroundColor Green
}

# Download scanner
$scannerUrl = "https://raw.githubusercontent.com/3ZIZvalz/ss-tool/main/mc_ss.py"
$scannerPath = "$env:TEMP\mc_ss_scanner.py"

Write-Host "  Loading scanner..." -ForegroundColor DarkGray
try {
    Invoke-WebRequest -Uri $scannerUrl -OutFile $scannerPath -UseBasicParsing -EA Stop
} catch {
    Write-Host "  [!] Could not download scanner." -ForegroundColor Red
    Read-Host "  Press Enter to exit"; exit
}

Write-Host "  Ready." -ForegroundColor Green
Write-Host ""
Start-Sleep -Milliseconds 200

& $py $scannerPath

Remove-Item $scannerPath -Force -EA SilentlyContinue
