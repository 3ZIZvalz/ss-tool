# MC SS Inspector Tool - PowerShell Edition
# تشغيل مباشر: powershell -ExecutionPolicy Bypass -Command "Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/USERNAME/REPO/main/MC_SS_Tool.ps1')"

$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "Cyan"
Clear-Host

# ─── Colors ───────────────────────────────────────────────────────────────────
function Write-Color {
    param([string]$Text, [string]$Color = "Cyan", [switch]$NoNewline)
    if ($NoNewline) { Write-Host $Text -ForegroundColor $Color -NoNewline }
    else            { Write-Host $Text -ForegroundColor $Color }
}

function Write-OK   { param($m) Write-Host "  " -NoNewline; Write-Host "[+]" -ForegroundColor Green  -NoNewline; Write-Host " $m" }
function Write-Bad  { param($m) Write-Host "  " -NoNewline; Write-Host "[!]" -ForegroundColor Red    -NoNewline; Write-Host " $m" -ForegroundColor Red }
function Write-Info { param($m) Write-Host "  " -NoNewline; Write-Host "[i]" -ForegroundColor Cyan   -NoNewline; Write-Host " $m" }
function Write-Warn { param($m) Write-Host "  " -NoNewline; Write-Host "[?]" -ForegroundColor Yellow -NoNewline; Write-Host " $m" -ForegroundColor Yellow }

function Write-Section {
    param($title)
    Write-Host ""
    Write-Host ("  " + "=" * 58) -ForegroundColor Cyan
    Write-Host "  >> $title" -ForegroundColor Yellow
    Write-Host ("  " + "=" * 58) -ForegroundColor Cyan
}

# ─── Banner ───────────────────────────────────────────────────────────────────
function Show-Banner {
    $lines = @(
        "  +============================================================+",
        "  |   _____ _____   _____ _____ _____ _____ _                 |",
        "  |  |   __|   __|  |_   _|     |     | |  |                  |",
        "  |  |__   |__   |    | | |  |  | |   | |  |                  |",
        "  |  |_____|_____|    |_| |_____|_____|_____|                  |",
        "  |                                                            |",
        "  |       Minecraft SS Inspector  -  PowerShell Edition       |",
        "  |            اداة تشفيش المودات - ماين كرافت               |",
        "  |                    Version 2.0                            |",
        "  +============================================================+"
    )
    foreach ($l in $lines) { Write-Host $l -ForegroundColor Cyan }
    Write-Host ""
}

# ─── Suspicious Keywords ──────────────────────────────────────────────────────
$SUSPICIOUS = @(
    # Cheat modules
    "killaura","kill_aura","aimbot","esp","xray","x_ray","wallhack",
    "speedhack","freecam","noclip","bhop","bunnyHop","autoclick",
    "auto_click","scaffold","criticals","antikb","antiknockback",
    "reach","velocity","timer","triggerbot","autoplace","automine",
    "autofarm","nuker","tracers","chams","aimassist","aim_assist",
    "regen","fastplace","fastbreak","nofall","phase","flight",
    "forcefield","crasher","crashmod","blink","invincible",
    "godmode","god_mode","kaboom","silentaura","silent_aura",
    # Packet / Network
    "packetmod","sendpacket","interceptpacket","networkmod",
    "nethandler","bypassmod","bypass",
    # Known cheat clients
    "wurst","meteor","liquidbounce","impact","aristois","wolfram",
    "inertia","future","sigma","rise","novoline","crest","vape",
    "hyperion","rectitude","ares",
    # Red flags
    "injected","obfuscated","obfuscator","skidded","backdoor",
    "keylogger","stealer","rat","trojan"
)

$SUSPICIOUS_PKGS = @(
    "me/wurst","me/zeroeightsix","com/impact","dev/liquidbounce",
    "net/ccbluex","com/meteorclient","meteordevelopment"
)

# ─── Java .class Parser ───────────────────────────────────────────────────────
function Parse-ClassFile {
    param([byte[]]$data)

    $result = @{
        Valid     = $false
        ClassName = ""
        SuperName = ""
        Methods   = @()
        Fields    = @()
        Strings   = @()
        Interfaces= @()
    }

    if ($data.Length -lt 8) { return $result }
    # Magic: CA FE BA BE
    if ($data[0] -ne 0xCA -or $data[1] -ne 0xFE -or $data[2] -ne 0xBA -or $data[3] -ne 0xBE) {
        return $result
    }
    $result.Valid = $true

    try {
        $pos = 8  # skip magic + minor + major

        # Read big-endian UInt16
        function Read-U16 {
            $v = ([int]$data[$pos] -shl 8) -bor $data[$pos+1]
            $script:pos += 2
            return $v
        }
        function Read-U32 {
            $v = ([int]$data[$pos] -shl 24) -bor ([int]$data[$pos+1] -shl 16) -bor ([int]$data[$pos+2] -shl 8) -bor $data[$pos+3]
            $script:pos += 4
            return $v
        }

        $cpCount = Read-U16
        $cp = @($null) # 1-indexed

        $i = 1
        while ($i -lt $cpCount) {
            $tag = $data[$pos]; $pos++
            switch ($tag) {
                1 {  # Utf8
                    $len = Read-U16
                    $s = [System.Text.Encoding]::UTF8.GetString($data, $pos, $len)
                    $pos += $len
                    $cp += ,@("Utf8", $s)
                }
                7 { $idx = Read-U16; $cp += ,@("Class", $idx) }
                8 { $idx = Read-U16; $cp += ,@("String", $idx) }
                9  { $pos += 4; $cp += ,@("Ref", $null) }
                10 { $pos += 4; $cp += ,@("Ref", $null) }
                11 { $pos += 4; $cp += ,@("Ref", $null) }
                12 { $pos += 4; $cp += ,@("NameType", $null) }
                3  { $pos += 4; $cp += ,@("Int", $null) }
                4  { $pos += 4; $cp += ,@("Float", $null) }
                5  { $pos += 8; $cp += ,@("Long", $null); $cp += ,$null; $i++ }
                6  { $pos += 8; $cp += ,@("Double", $null); $cp += ,$null; $i++ }
                15 { $pos += 3; $cp += ,@("MH", $null) }
                16 { $pos += 2; $cp += ,@("MT", $null) }
                17 { $pos += 4; $cp += ,@("Dyn", $null) }
                18 { $pos += 4; $cp += ,@("Dyn", $null) }
                19 { $pos += 2; $cp += ,@("Module", $null) }
                20 { $pos += 2; $cp += ,@("Package", $null) }
                default { $cp += ,$null }
            }
            $i++
        }

        # Collect all UTF8 strings
        foreach ($entry in $cp) {
            if ($entry -and $entry[0] -eq "Utf8" -and $entry[1].Length -gt 2) {
                $result.Strings += $entry[1]
            }
        }

        # Helper to resolve class name
        function Resolve-Class($idx) {
            if ($idx -gt 0 -and $idx -lt $cp.Count -and $cp[$idx]) {
                $ni = $cp[$idx][1]
                if ($ni -gt 0 -and $ni -lt $cp.Count -and $cp[$ni] -and $cp[$ni][0] -eq "Utf8") {
                    return $cp[$ni][1] -replace '/',  '.'
                }
            }
            return ""
        }

        $pos += 2  # access flags

        $thisIdx  = Read-U16
        $result.ClassName = Resolve-Class $thisIdx

        $superIdx = Read-U16
        $result.SuperName = Resolve-Class $superIdx

        # Interfaces
        $ifCount = Read-U16
        for ($x = 0; $x -lt $ifCount; $x++) {
            $ifIdx = Read-U16
            $result.Interfaces += Resolve-Class $ifIdx
        }

        # Fields
        $fCount = Read-U16
        for ($x = 0; $x -lt $fCount; $x++) {
            $pos += 2
            $ni = Read-U16
            $pos += 2
            $attrC = Read-U16
            if ($ni -gt 0 -and $ni -lt $cp.Count -and $cp[$ni]) {
                $result.Fields += $cp[$ni][1]
            }
            for ($a = 0; $a -lt $attrC; $a++) {
                $pos += 2
                $aLen = Read-U32
                $pos += $aLen
            }
        }

        # Methods
        $mCount = Read-U16
        for ($x = 0; $x -lt $mCount; $x++) {
            $pos += 2
            $ni = Read-U16
            $di = Read-U16
            $attrC = Read-U16
            $mn = ""; $md = ""
            if ($ni -gt 0 -and $ni -lt $cp.Count -and $cp[$ni]) { $mn = $cp[$ni][1] }
            if ($di -gt 0 -and $di -lt $cp.Count -and $cp[$di]) { $md = $cp[$di][1] }
            if ($mn) { $result.Methods += "$mn$md" }
            for ($a = 0; $a -lt $attrC; $a++) {
                $pos += 2
                $aLen = Read-U32
                $pos += $aLen
            }
        }

    } catch { }

    return $result
}

# ─── Check if class is suspicious ────────────────────────────────────────────
function Get-SuspiciousHits {
    param($classInfo, [string]$filename = "")

    $all = (($classInfo.ClassName, $classInfo.SuperName) + $classInfo.Methods +
            $classInfo.Fields + $classInfo.Strings + $classInfo.Interfaces +
            @($filename)) -join " "
    $allLow = $all.ToLower()

    $hits = @()
    foreach ($kw in $SUSPICIOUS) {
        if ($allLow.Contains($kw.ToLower())) { $hits += $kw }
    }
    foreach ($pkg in $SUSPICIOUS_PKGS) {
        $p = $pkg.ToLower() -replace '/', '.'
        if ($allLow.Contains($p)) { $hits += $pkg }
    }
    return $hits | Select-Object -Unique
}

# ─── Get SHA256 ───────────────────────────────────────────────────────────────
function Get-SHA256 {
    param([string]$path)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $stream = [System.IO.File]::OpenRead($path)
        $hash = $sha.ComputeHash($stream)
        $stream.Close()
        return ([BitConverter]::ToString($hash) -replace '-','').ToLower()
    } catch { return "N/A" }
}

function Format-Size {
    param([long]$bytes)
    if ($bytes -lt 1KB)  { return "$bytes B" }
    if ($bytes -lt 1MB)  { return "{0:F1} KB" -f ($bytes/1KB) }
    if ($bytes -lt 1GB)  { return "{0:F1} MB" -f ($bytes/1MB) }
    return "{0:F1} GB" -f ($bytes/1GB)
}

# ─── Scan Single JAR ─────────────────────────────────────────────────────────
function Scan-Jar {
    param([string]$jarPath, [switch]$Verbose)

    $jarPath = Resolve-Path $jarPath -ErrorAction SilentlyContinue
    if (-not $jarPath) { Write-Bad "الملف مو موجود!"; return $null }

    $fi = Get-Item $jarPath
    Write-Section "فحص: $($fi.Name)"
    Write-Info "الحجم    : $(Format-Size $fi.Length)"
    Write-Info "SHA-256  : $(Get-SHA256 $jarPath)"
    Write-Info "التعديل  : $($fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"

    # Open as ZIP
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    } catch { }

    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jarPath)
    } catch {
        Write-Bad "الملف مش JAR صالح!"
        return $null
    }

    $entries   = $zip.Entries
    $classes   = $entries | Where-Object { $_.FullName.EndsWith(".class") }
    $others    = $entries | Where-Object { -not $_.FullName.EndsWith(".class") }

    Write-Info "الكلاسات : $($classes.Count)"
    Write-Info "ملفات أخرى: $($others.Count)"

    # MANIFEST
    $manifest = $entries | Where-Object { $_.FullName -eq "META-INF/MANIFEST.MF" }
    if ($manifest) {
        Write-Section "MANIFEST.MF"
        $reader = New-Object System.IO.StreamReader($manifest.Open())
        $mfText = $reader.ReadToEnd(); $reader.Close()
        foreach ($line in ($mfText -split "`n")) {
            if ($line.Trim()) { Write-Info $line.Trim() }
        }
    }

    # Mod meta files
    foreach ($meta in @("fabric.mod.json","mcmod.info","mods.toml","pack.mcmeta")) {
        $entry = $entries | Where-Object { $_.FullName -eq $meta } | Select-Object -First 1
        if ($entry) {
            Write-Section "معلومات المود ($meta)"
            $reader = New-Object System.IO.StreamReader($entry.Open())
            $txt = $reader.ReadToEnd(); $reader.Close()
            Write-Host ($txt.Substring(0, [Math]::Min(600, $txt.Length))) -ForegroundColor White
        }
    }

    # Scan classes
    Write-Section "فحص الكلاسات ($($classes.Count) كلاس)"

    $suspiciousClasses = @()
    $allHits = @()
    $scanned = 0
    $total = $classes.Count

    foreach ($entry in $classes) {
        $scanned++

        # Progress bar
        if ($scanned % 50 -eq 0 -or $scanned -eq $total) {
            $pct = [int]($scanned / $total * 100)
            $bar = [string]("█" * ($pct / 5)) + [string]("░" * (20 - $pct / 5))
            Write-Host "`r  [$bar] $pct% ($scanned/$total)  " -NoNewline -ForegroundColor Cyan
        }

        try {
            $stream = $entry.Open()
            $ms = New-Object System.IO.MemoryStream
            $stream.CopyTo($ms)
            $stream.Close()
            $bytes = $ms.ToArray()
            $ms.Close()

            $info = Parse-ClassFile -data $bytes
            if (-not $info.Valid) { continue }

            $hits = Get-SuspiciousHits -classInfo $info -filename $entry.FullName
            if ($hits.Count -gt 0) {
                $suspiciousClasses += @{
                    File      = $entry.FullName
                    ClassName = $info.ClassName
                    SuperName = $info.SuperName
                    Methods   = $info.Methods
                    Interfaces= $info.Interfaces
                    Hits      = $hits
                }
                $allHits += $hits
            }
        } catch { }
    }

    Write-Host ""  # newline after progress

    $zip.Dispose()

    # Results
    Write-Section "نتائج الفحص"
    $allHits = $allHits | Select-Object -Unique

    if ($suspiciousClasses.Count -eq 0) {
        Write-OK "ما لقينا شي مشبوه في $total كلاس - الملف نظيف"
    } else {
        Write-Bad "لقينا $($suspiciousClasses.Count) كلاس مشبوه!"
        Write-Bad "الكلمات المشبوهة: $($allHits -join ', ')"

        Write-Section "الكلاسات المشبوهة"
        foreach ($sc in $suspiciousClasses) {
            Write-Host ""
            Write-Host "  " -NoNewline
            Write-Host ("-" * 55) -ForegroundColor Red
            Write-Host "  [SUSPICIOUS] " -ForegroundColor Red -NoNewline
            Write-Host $sc.ClassName -ForegroundColor White
            Write-Host "  الملف     : " -ForegroundColor Cyan -NoNewline; Write-Host $sc.File
            if ($sc.SuperName -and $sc.SuperName -ne "java.lang.Object") {
                Write-Host "  يرث من   : " -ForegroundColor Cyan -NoNewline; Write-Host $sc.SuperName
            }
            if ($sc.Interfaces.Count -gt 0) {
                Write-Host "  انترفيسات: " -ForegroundColor Cyan -NoNewline
                Write-Host ($sc.Interfaces -join ", ")
            }
            Write-Host "  الميثودز  : " -ForegroundColor Cyan -NoNewline; Write-Host $sc.Methods.Count
            Write-Host "  مشبوه     : " -ForegroundColor Red -NoNewline
            Write-Host ($sc.Hits -join ", ") -ForegroundColor Yellow

            if ($Verbose -and $sc.Methods.Count -gt 0) {
                Write-Host "  الميثودز:" -ForegroundColor Cyan
                $sc.Methods | Select-Object -First 20 | ForEach-Object {
                    Write-Host "    - $_" -ForegroundColor DarkYellow
                }
                if ($sc.Methods.Count -gt 20) {
                    Write-Host "    ... و $($sc.Methods.Count - 20) ميثود أخرى" -ForegroundColor DarkGray
                }
            }
        }
    }

    return @{
        File              = [string]$jarPath
        TotalClasses      = $total
        SuspiciousClasses = $suspiciousClasses
        AllHits           = $allHits
    }
}

# ─── Scan Folder ─────────────────────────────────────────────────────────────
function Scan-Folder {
    param([string]$folderPath, [switch]$Verbose)

    if (-not (Test-Path $folderPath)) {
        Write-Bad "المجلد مو موجود: $folderPath"
        return
    }

    $jars = Get-ChildItem -Path $folderPath -Recurse -Filter "*.jar"
    if ($jars.Count -eq 0) {
        Write-Warn "ما لقينا ملفات JAR في المجلد"
        return
    }

    Write-Section "فحص المجلد: $folderPath"
    Write-Info "عدد الملفات: $($jars.Count)"

    $flagged = @()
    $clean   = 0

    foreach ($jar in $jars) {
        $r = Scan-Jar -jarPath $jar.FullName -Verbose:$Verbose
        if ($r) {
            if ($r.SuspiciousClasses.Count -gt 0) { $flagged += $jar.Name }
            else { $clean++ }
        }
    }

    Write-Section "ملخص الفحص"
    Write-Info "المجموع    : $($jars.Count)"
    Write-OK   "نظيفة      : $clean"

    if ($flagged.Count -gt 0) {
        Write-Bad "مشبوهة ($($flagged.Count)):"
        foreach ($f in $flagged) {
            Write-Host "    [!!] $f" -ForegroundColor Red
        }
    } else {
        Write-OK "كل الملفات نظيفة!"
    }
}

# ─── Dump Classes ─────────────────────────────────────────────────────────────
function Dump-Classes {
    param([string]$jarPath, [string]$OutputDir = "", [string]$Filter = "")

    $jarPath = Resolve-Path $jarPath -ErrorAction SilentlyContinue
    if (-not $jarPath) { Write-Bad "الملف مو موجود!"; return }

    $fi = Get-Item $jarPath
    if (-not $OutputDir) { $OutputDir = Join-Path (Split-Path $jarPath) "$($fi.BaseName)_classes" }

    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    Write-Section "تصدير الكلاسات: $($fi.Name)"

    try { $zip = [System.IO.Compression.ZipFile]::OpenRead($jarPath) }
    catch { Write-Bad "الملف مش JAR صالح!"; return }

    $classes = $zip.Entries | Where-Object { $_.FullName.EndsWith(".class") }
    if ($Filter) {
        $classes = $classes | Where-Object { $_.FullName -like "*$Filter*" }
        Write-Info "بعد الفلتر '$Filter': $($classes.Count) كلاس"
    }

    $summaryPath = Join-Path $OutputDir "ALL_CLASSES.txt"
    $summary = [System.IO.StreamWriter]::new($summaryPath, $false, [System.Text.Encoding]::UTF8)
    $summary.WriteLine("MC SS Inspector - Class Dump")
    $summary.WriteLine("الملف: $jarPath")
    $summary.WriteLine("التاريخ: $(Get-Date)")
    $summary.WriteLine("=" * 60)
    $summary.WriteLine()

    $count = 0
    foreach ($entry in $classes) {
        try {
            $stream = $entry.Open()
            $ms = New-Object System.IO.MemoryStream
            $stream.CopyTo($ms); $stream.Close()
            $bytes = $ms.ToArray(); $ms.Close()

            $info = Parse-ClassFile -data $bytes
            if (-not $info.Valid) { continue }

            $count++
            $line = "[$count] $($info.ClassName)"
            if ($info.SuperName -and $info.SuperName -ne "java.lang.Object") {
                $line += " extends $($info.SuperName)"
            }
            if ($info.Interfaces.Count -gt 0) {
                $line += " implements $($info.Interfaces -join ', ')"
            }
            $summary.WriteLine($line)

            # Individual file
            $safeName = $entry.FullName -replace '[/\\]', '_'
            $outFile  = Join-Path $OutputDir "$safeName.txt"
            $cf = [System.IO.StreamWriter]::new($outFile, $false, [System.Text.Encoding]::UTF8)
            $cf.WriteLine("Class      : $($info.ClassName)")
            $cf.WriteLine("Super      : $($info.SuperName)")
            $cf.WriteLine("Interfaces : $($info.Interfaces -join ', ')")
            $cf.WriteLine("")
            $cf.WriteLine("Methods ($($info.Methods.Count)):")
            $info.Methods | ForEach-Object { $cf.WriteLine("  - $_") }
            $cf.WriteLine("")
            $cf.WriteLine("Fields ($($info.Fields.Count)):")
            $info.Fields | ForEach-Object { $cf.WriteLine("  - $_") }
            $cf.WriteLine("")
            $cf.WriteLine("String Constants:")
            $info.Strings | Where-Object { $_.Length -gt 2 } | ForEach-Object { $cf.WriteLine("  `"$_`"") }
            $cf.Close()

        } catch { }
    }

    $summary.Close()
    $zip.Dispose()

    Write-OK "تم تصدير $count كلاس إلى: $OutputDir"
    Write-OK "الملخص: $summaryPath"
}

# ─── Main Interactive Menu ────────────────────────────────────────────────────
Show-Banner

Write-Host "  Enter path to the mods folder:" -ForegroundColor White
Write-Host "  (press Enter for default: %APPDATA%\.minecraft\mods)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  PATH: " -ForegroundColor Cyan -NoNewline
$inputPath = Read-Host

if ([string]::IsNullOrWhiteSpace($inputPath)) {
    $inputPath = "$env:APPDATA\.minecraft\mods"
    Write-Host ""
    Write-Host "  Continuing with: $inputPath" -ForegroundColor Green
}

if (-not (Test-Path $inputPath)) {
    Write-Bad "المسار مو موجود: $inputPath"
    Write-Host ""
    Read-Host "  اضغط Enter للخروج"
    exit
}

Write-Host ""
Write-Host "  Mode?" -ForegroundColor White
Write-Host "  [1] فحص كامل للمجلد (الافتراضي)" -ForegroundColor Cyan
Write-Host "  [2] فحص ملف JAR واحد" -ForegroundColor Cyan
Write-Host "  [3] تصدير كلاسات ملف JAR" -ForegroundColor Cyan
Write-Host ""
Write-Host "  اختر: " -ForegroundColor Yellow -NoNewline
$mode = Read-Host

switch ($mode) {
    "2" {
        Write-Host "  مسار الملف: " -ForegroundColor Cyan -NoNewline
        $jarFile = Read-Host
        Write-Host "  تفاصيل الميثودز؟ (y/n): " -ForegroundColor Cyan -NoNewline
        $v = Read-Host
        $startTime = Get-Date
        Scan-Jar -jarPath $jarFile -Verbose:($v -eq "y")
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        Write-Host "`n  ⏱  اكتمل في $([math]::Round($elapsed,2)) ثانية`n" -ForegroundColor Cyan
    }
    "3" {
        Write-Host "  مسار الملف: " -ForegroundColor Cyan -NoNewline
        $jarFile = Read-Host
        Write-Host "  فلتر (اتركه فارغ للكل): " -ForegroundColor Cyan -NoNewline
        $flt = Read-Host
        $startTime = Get-Date
        Dump-Classes -jarPath $jarFile -Filter $flt
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        Write-Host "`n  ⏱  اكتمل في $([math]::Round($elapsed,2)) ثانية`n" -ForegroundColor Cyan
    }
    default {
        $startTime = Get-Date
        Scan-Folder -folderPath $inputPath
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        Write-Host "`n  ⏱  اكتمل في $([math]::Round($elapsed,2)) ثانية`n" -ForegroundColor Cyan
    }
}

Write-Host ""
Read-Host "  اضغط Enter للخروج"
