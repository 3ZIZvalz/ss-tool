# MC SS Tool v4.0 - Launcher
# Downloads and runs the Python scanner automatically

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
        if ($v -match "Python 3") { $py = $cmd; break }
    } catch {}
}

if (-not $py) {
    Write-Host "  [!] Python 3 is not installed!" -ForegroundColor Red
    Write-Host "  Download from: https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "  Make sure to check 'Add Python to PATH' during install." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit
}

Write-Host "  Python OK" -ForegroundColor Green

# Download latest scanner script
$scriptUrl = "https://raw.githubusercontent.com/3ZIZvalz/ss-tool/main/mc_ss.py"
$tempFile  = "$env:TEMP\mc_ss_scanner.py"

Write-Host "  Downloading scanner..." -ForegroundColor DarkGray
try {
    Invoke-WebRequest -Uri $scriptUrl -OutFile $tempFile -UseBasicParsing -ErrorAction Stop
    Write-Host "  Scanner ready" -ForegroundColor Green
} catch {
    Write-Host "  [!] Download failed: $_" -ForegroundColor Red
    Write-Host "  Make sure mc_ss.py is uploaded to your GitHub repo." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit
}

Write-Host ""
Start-Sleep -Milliseconds 300

# Run the Python scanner
& $py $tempFile

# Cleanup
try { Remove-Item $tempFile -Force -EA SilentlyContinue } catch {}
