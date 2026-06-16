
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "Cyan"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

function Write-OK   { param($m) Write-Host "  [+] " -ForegroundColor Green  -NoNewline; Write-Host $m }
function Write-Bad  { param($m) Write-Host "  [!] " -ForegroundColor Red    -NoNewline; Write-Host $m -ForegroundColor Red }
function Write-Info { param($m) Write-Host "  [i] " -ForegroundColor Cyan   -NoNewline; Write-Host $m }
function Write-Warn { param($m) Write-Host "  [?] " -ForegroundColor Yellow -NoNewline; Write-Host $m -ForegroundColor Yellow }
function Write-Section {
    param($t)
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor DarkCyan
    Write-Host "   >> $t" -ForegroundColor Yellow
    Write-Host "  ================================================================" -ForegroundColor DarkCyan
}

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  +-----------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |   _______ _______    _______ _______ _______ _                |" -ForegroundColor Cyan
    Write-Host "  |  |     __|     __|  |_     _|       |       | |               |" -ForegroundColor Cyan
    Write-Host "  |  |__     |__     |    |   | |   -   |   -   | |               |" -ForegroundColor Cyan
    Write-Host "  |  |_______|_______|    |___| |_______|_______|_____|            |" -ForegroundColor Cyan
    Write-Host "  |                                                                |" -ForegroundColor Cyan
    Write-Host "  |          Minecraft SS Inspector  -  PowerShell Edition        |" -ForegroundColor Cyan
    Write-Host "  |                       Version 3.1                             |" -ForegroundColor Cyan
    Write-Host "  +-----------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
}

$CHEAT_MODULES = @(
    "killaura","kill_aura","autohit","forceattack",
    "triggerbot","trigger_bot","triggerattack",
    "aimbot","aim_bot","silentaim","silent_aim",
    "criticalspam","crit_spam","autoclick","auto_click","autoclicker",
    "forcefield","force_field","multiaura","multi_aura",
    "bhop","bunny_hop","bunnyhop","nofall","no_fall",
    "noclip","no_clip","antiknockback","anti_knockback","antikb",
    "velocitymod","velocity_mod","flyhack","fly_hack","speedhack","speed_hack",
    "scaffold_mod","scaffoldmod","towerhack",
    "phasemod","phase_mod","jesusmod","jesus_mod",
    "wallhack","wall_hack","xrayhack","x_ray_hack",
    "playeresp","player_esp","entityesp","entity_esp",
    "chamsmod","armorchams","hitboxesp","hitbox_esp",
    "packetfly","packet_fly","packetspeed","packetedit","packet_edit",
    "reachmod","reach_mod","timermod","timer_mod","pingspoof","ping_spoof",
    "nukermod","nuker_mod","automine","auto_mine","autofarm","auto_farm",
    "autoplace","auto_place","autofish","auto_fish","autosteal",
    "wurst_client","wurstclient","liquidbounce","liquid_bounce",
    "meteorclient","meteor_client","impactclient","impact_client",
    "aristois_client","wolfram_client","inertia_client",
    "future_client","futureclient","sigma_client","rise_client",
    "novoline_client","vape_client","hyperion_client",
    "backdoor","keylogger","tokenstealer","token_stealer",
    "discordstealer","ratclient","rat_client","skidded"
)

$CHEAT_PACKAGES = @(
    "me.wurst","net.wurstclient","me.zero.client","com.impact.mod",
    "dev.liquidbounce","net.ccbluex","com.meteorclient",
    "meteordevelopment","me.sigma.client","com.rise.client",
    "com.inertia.client","com.vape.client","com.future.client",
    "com.aristois"
)

# ── Safe class parser with timeout protection ────────────────────────────────
function Parse-ClassFile {
    param([byte[]]$data)
    $r = @{ Valid=$false; ClassName=""; SuperName=""; Methods=@(); Fields=@(); Strings=@(); Interfaces=@() }
    if ($null -eq $data -or $data.Length -lt 10) { return $r }
    if ($data[0] -ne 0xCA -or $data[1] -ne 0xFE -or $data[2] -ne 0xBA -or $data[3] -ne 0xBE) { return $r }
    $r.Valid = $true
    try {
        $ms = New-Object System.IO.MemoryStream(,$data)
        $br = New-Object System.IO.BinaryReader($ms)

        # Helper: read big-endian
        function RU16 { $b=$br.ReadBytes(2); return ([int]$b[0]-shl 8)-bor $b[1] }
        function RU32 { $b=$br.ReadBytes(4); return ([int]$b[0]-shl 24)-bor([int]$b[1]-shl 16)-bor([int]$b[2]-shl 8)-bor $b[3] }

        $br.ReadBytes(8) | Out-Null  # magic + minor + major
        $cpCount = RU16
        $cp = New-Object System.Collections.ArrayList
        $cp.Add($null) | Out-Null  # index 0 unused

        $i = 1
        while ($i -lt $cpCount) {
            $tag = $br.ReadByte()
            switch ($tag) {
                1  { $len=RU16; $bytes=$br.ReadBytes($len); $cp.Add([System.Text.Encoding]::UTF8.GetString($bytes)) | Out-Null }
                7  { $cp.Add([PSCustomObject]@{T="C";I=RU16}) | Out-Null }
                8  { $cp.Add([PSCustomObject]@{T="S";I=RU16}) | Out-Null }
                9  { $br.ReadBytes(4)|Out-Null; $cp.Add($null)|Out-Null }
                10 { $br.ReadBytes(4)|Out-Null; $cp.Add($null)|Out-Null }
                11 { $br.ReadBytes(4)|Out-Null; $cp.Add($null)|Out-Null }
                12 { $br.ReadBytes(4)|Out-Null; $cp.Add($null)|Out-Null }
                3  { $br.ReadBytes(4)|Out-Null; $cp.Add($null)|Out-Null }
                4  { $br.ReadBytes(4)|Out-Null; $cp.Add($null)|Out-Null }
                5  { $br.ReadBytes(8)|Out-Null; $cp.Add($null)|Out-Null; $cp.Add($null)|Out-Null; $i++ }
                6  { $br.ReadBytes(8)|Out-Null; $cp.Add($null)|Out-Null; $cp.Add($null)|Out-Null; $i++ }
                15 { $br.ReadBytes(3)|Out-Null; $cp.Add($null)|Out-Null }
                16 { $br.ReadBytes(2)|Out-Null; $cp.Add($null)|Out-Null }
                17 { $br.ReadBytes(4)|Out-Null; $cp.Add($null)|Out-Null }
                18 { $br.ReadBytes(4)|Out-Null; $cp.Add($null)|Out-Null }
                19 { $br.ReadBytes(2)|Out-Null; $cp.Add($null)|Out-Null }
                20 { $br.ReadBytes(2)|Out-Null; $cp.Add($null)|Out-Null }
                default { $br.Close(); $ms.Close(); return $r }
            }
            $i++
        }

        # Collect UTF8 strings
        foreach ($e in $cp) {
            if ($e -is [string] -and $e.Length -gt 2) { $r.Strings += $e }
        }

        function RC($idx) {
            if ($idx -gt 0 -and $idx -lt $cp.Count -and $cp[$idx] -and $cp[$idx].T -eq "C") {
                $ni = $cp[$idx].I
                if ($ni -gt 0 -and $ni -lt $cp.Count -and $cp[$ni] -is [string]) {
                    return $cp[$ni] -replace '/', '.'
                }
            }
            return ""
        }

        $br.ReadBytes(2) | Out-Null  # access flags
        $r.ClassName = RC (RU16)
        $r.SuperName = RC (RU16)

        $ifC = RU16
        for ($x=0; $x -lt $ifC; $x++) { $r.Interfaces += RC (RU16) }

        $fC = RU16
        for ($x=0; $x -lt $fC; $x++) {
            $br.ReadBytes(2)|Out-Null
            $ni = RU16
            $br.ReadBytes(2)|Out-Null
            $ac = RU16
            if ($ni -gt 0 -and $ni -lt $cp.Count -and $cp[$ni] -is [string]) { $r.Fields += $cp[$ni] }
            for ($a=0; $a -lt $ac; $a++) { $br.ReadBytes(2)|Out-Null; $al=RU32; $br.ReadBytes($al)|Out-Null }
        }

        $mC = RU16
        for ($x=0; $x -lt $mC; $x++) {
            $br.ReadBytes(2)|Out-Null
            $ni = RU16; $di = RU16; $ac = RU16
            $mn=""; $md=""
            if ($ni -gt 0 -and $ni -lt $cp.Count -and $cp[$ni] -is [string]) { $mn=$cp[$ni] }
            if ($di -gt 0 -and $di -lt $cp.Count -and $cp[$di] -is [string]) { $md=$cp[$di] }
            if ($mn) { $r.Methods += "$mn$md" }
            for ($a=0; $a -lt $ac; $a++) { $br.ReadBytes(2)|Out-Null; $al=RU32; $br.ReadBytes($al)|Out-Null }
        }

        $br.Close(); $ms.Close()
    } catch {
        # Silently skip broken classes
    }
    return $r
}

function Get-Hits {
    param($info, [string]$fname="")
    $hits = @()
    $classPath = $info.ClassName.ToLower()
    $superPath = $info.SuperName.ToLower()
    $filePath  = $fname.ToLower() -replace '/', '.'

    foreach ($pkg in $CHEAT_PACKAGES) {
        $p = $pkg.ToLower()
        if ($classPath.StartsWith($p) -or $superPath.StartsWith($p) -or $filePath.Contains($p)) {
            $hits += "[PKG] $pkg"
        }
    }

    $allText = ($info.Methods + $info.Fields + $info.Strings) -join "`n"
    $allLow  = $allText.ToLower()

    foreach ($kw in $CHEAT_MODULES) {
        $k = $kw.ToLower()
        if ($allLow -match "(^|[\n\._`$\s`"'/\\-])$([regex]::Escape($k))([\n\._`$\s`"'/\\-]|$)") {
            $hits += $kw
        }
    }
    return $hits | Select-Object -Unique
}

function Get-SHA256 {
    param([string]$p)
    try {
        $s=[System.Security.Cryptography.SHA256]::Create()
        $f=[System.IO.File]::OpenRead($p)
        $h=$s.ComputeHash($f); $f.Close()
        return ([BitConverter]::ToString($h)-replace'-','').ToLower()
    } catch { return "N/A" }
}

function Format-Size {
    param([long]$b)
    if ($b -lt 1KB) { return "$b B" }
    if ($b -lt 1MB) { return "{0:F1} KB" -f ($b/1KB) }
    if ($b -lt 1GB) { return "{0:F1} MB" -f ($b/1MB) }
    return "{0:F1} GB" -f ($b/1GB)
}

# ── Read all bytes from a ZIP entry safely ───────────────────────────────────
function Read-Entry {
    param($entry)
    try {
        $st = $entry.Open()
        $ms = New-Object System.IO.MemoryStream
        $st.CopyTo($ms)
        $st.Close()
        $b = $ms.ToArray()
        $ms.Close()
        return $b
    } catch { return $null }
}

# ── Scan a single JAR, return result object ──────────────────────────────────
function Scan-Jar {
    param([string]$jarPath, [switch]$Verbose, [switch]$Silent)
    $rp = Resolve-Path $jarPath -ErrorAction SilentlyContinue
    if (-not $rp) { return $null }
    $fi = Get-Item $rp

    if (-not $Silent) {
        Write-Section "Scanning: $($fi.Name)"
        Write-Info "Size    : $(Format-Size $fi.Length)"
        Write-Info "SHA-256 : $(Get-SHA256 $rp)"
        Write-Info "Date    : $($fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    }

    try { Add-Type -AssemblyName System.IO.Compression.FileSystem -EA Stop } catch {}

    $zip = $null
    try { $zip = [System.IO.Compression.ZipFile]::OpenRead($rp) }
    catch {
        if (-not $Silent) { Write-Bad "Cannot open: $($fi.Name)" }
        return $null
    }

    $entries = @($zip.Entries)
    $classes = @($entries | Where-Object { $_.FullName.EndsWith(".class") })

    if (-not $Silent) {
        Write-Info "Classes : $($classes.Count)"
        # MANIFEST
        $mf = $entries | Where-Object { $_.FullName -eq "META-INF/MANIFEST.MF" } | Select-Object -First 1
        if ($mf) {
            Write-Section "MANIFEST.MF"
            try {
                $rd = New-Object System.IO.StreamReader($mf.Open())
                ($rd.ReadToEnd() -split "`n") | Where-Object { $_.Trim() } | ForEach-Object { Write-Info $_.Trim() }
                $rd.Close()
            } catch {}
        }
        # Mod meta
        foreach ($meta in @("fabric.mod.json","mcmod.info","mods.toml")) {
            $me = $entries | Where-Object { $_.FullName -eq $meta } | Select-Object -First 1
            if ($me) {
                Write-Section "Mod Info ($meta)"
                try {
                    $rd = New-Object System.IO.StreamReader($me.Open())
                    $t = $rd.ReadToEnd(); $rd.Close()
                    Write-Host ($t.Substring(0,[Math]::Min(600,$t.Length))) -ForegroundColor White
                } catch {}
            }
        }
        Write-Section "Scanning $($classes.Count) classes..."
    }

    $suspicious = [System.Collections.ArrayList]@()
    $allHits    = [System.Collections.ArrayList]@()
    $sc = 0; $tot = $classes.Count

    foreach ($entry in $classes) {
        $sc++
        if (-not $Silent -and ($sc % 100 -eq 0 -or $sc -eq $tot)) {
            $pct = if ($tot -gt 0) { [int]($sc/$tot*100) } else { 100 }
            $filled = [int]($pct/5); $empty = 20-$filled
            $bar = ([string][char]0x2588 * $filled) + ([string][char]0x2591 * $empty)
            Write-Host "`r  [$bar] $pct% ($sc/$tot)   " -NoNewline -ForegroundColor Cyan
        }

        $bytes = Read-Entry $entry
        if ($null -eq $bytes) { continue }

        $inf  = Parse-ClassFile -data $bytes
        if (-not $inf.Valid) { continue }

        $hits = Get-Hits -info $inf -fname $entry.FullName
        if ($hits.Count -gt 0) {
            $suspicious.Add(@{
                File=$entry.FullName; ClassName=$inf.ClassName
                SuperName=$inf.SuperName; Methods=$inf.Methods
                Interfaces=$inf.Interfaces; Hits=$hits
            }) | Out-Null
            foreach ($h in $hits) { if (-not $allHits.Contains($h)) { $allHits.Add($h)|Out-Null } }
        }
    }

    if (-not $Silent) { Write-Host "" }
    try { $zip.Dispose() } catch {}

    if (-not $Silent) {
        Write-Section "Results: $($fi.Name)"
        if ($suspicious.Count -eq 0) {
            Write-OK "CLEAN — $tot classes checked, nothing found"
        } else {
            Write-Bad "FLAGGED — $($suspicious.Count) suspicious class(es)!"
            Write-Bad "Keywords: $($allHits -join ' | ')"
            Write-Section "Suspicious Classes"
            foreach ($s in $suspicious) {
                Write-Host ""
                Write-Host ("  " + "-"*60) -ForegroundColor DarkRed
                Write-Host "  [FLAGGED] " -ForegroundColor Red -NoNewline
                Write-Host $s.ClassName -ForegroundColor White
                Write-Host "  File      : " -ForegroundColor Cyan -NoNewline; Write-Host $s.File
                if ($s.SuperName -and $s.SuperName -ne "java.lang.Object") {
                    Write-Host "  Extends   : " -ForegroundColor Cyan -NoNewline; Write-Host $s.SuperName
                }
                if ($s.Interfaces.Count -gt 0) {
                    Write-Host "  Implements: " -ForegroundColor Cyan -NoNewline; Write-Host ($s.Interfaces -join ", ")
                }
                Write-Host "  Flagged   : " -ForegroundColor Red -NoNewline
                Write-Host ($s.Hits -join " | ") -ForegroundColor Yellow
                if ($Verbose -and $s.Methods.Count -gt 0) {
                    Write-Host "  Methods:" -ForegroundColor Cyan
                    $s.Methods | Select-Object -First 25 | ForEach-Object { Write-Host "    > $_" -ForegroundColor DarkYellow }
                    if ($s.Methods.Count -gt 25) { Write-Host "    ... +$($s.Methods.Count-25) more" -ForegroundColor DarkGray }
                }
            }
        }
    }

    return @{
        FileName=$fi.Name; TotalClasses=$tot
        SuspiciousCount=$suspicious.Count
        SuspiciousClasses=@($suspicious)
        AllHits=@($allHits)
        IsClean=($suspicious.Count -eq 0)
    }
}

# ── Scan full folder automatically ───────────────────────────────────────────
function Scan-Folder {
    param([string]$folderPath)
    if (-not (Test-Path $folderPath)) { Write-Bad "Folder not found: $folderPath"; return }

    $jars = @(Get-ChildItem -Path $folderPath -Recurse -Filter "*.jar" -ErrorAction SilentlyContinue)
    if ($jars.Count -eq 0) { Write-Warn "No JAR files found."; return }

    Write-Section "Scanning Folder: $folderPath"
    Write-Info "Found $($jars.Count) JAR file(s) — scanning all automatically..."
    Write-Host ""

    $flaggedList = [System.Collections.ArrayList]@()
    $cleanCount  = 0
    $idx = 0

    foreach ($jar in $jars) {
        $idx++
        Write-Host "  [$idx/$($jars.Count)] " -ForegroundColor DarkCyan -NoNewline
        Write-Host $jar.Name -ForegroundColor White -NoNewline
        Write-Host "..." -ForegroundColor DarkGray

        $r = Scan-Jar -jarPath $jar.FullName -Silent

        if ($null -eq $r) {
            Write-Host "         " -NoNewline
            Write-Host " ERROR  " -ForegroundColor White -BackgroundColor DarkYellow -NoNewline
            Write-Host " Could not read file" -ForegroundColor DarkYellow
            continue
        }

        if ($r.IsClean) {
            Write-Host "         " -NoNewline
            Write-Host " CLEAN  " -ForegroundColor Black -BackgroundColor Green -NoNewline
            Write-Host "  $($r.TotalClasses) classes" -ForegroundColor DarkGray
            $cleanCount++
        } else {
            Write-Host "         " -NoNewline
            Write-Host " FLAGGED " -ForegroundColor White -BackgroundColor DarkRed -NoNewline
            Write-Host "  $($r.SuspiciousCount) hit(s) — " -ForegroundColor Red -NoNewline
            Write-Host ($r.AllHits -join " | ") -ForegroundColor Yellow
            foreach ($sc in $r.SuspiciousClasses) {
                Write-Host "    [>>] $($sc.ClassName) — " -ForegroundColor Red -NoNewline
                Write-Host ($sc.Hits -join ", ") -ForegroundColor Yellow
            }
            $flaggedList.Add($r) | Out-Null
        }
    }

    # Summary
    Write-Host ""
    Write-Host "  +================================================================+" -ForegroundColor Cyan
    Write-Host "  |                    SCAN COMPLETE — SUMMARY                    |" -ForegroundColor Cyan
    Write-Host "  +================================================================+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Total     : $($jars.Count)" -ForegroundColor White
    Write-Host "  Clean     : $cleanCount"    -ForegroundColor Green
    if ($flaggedList.Count -gt 0) {
        Write-Host "  Flagged   : $($flaggedList.Count)" -ForegroundColor Red
        Write-Host ""
        Write-Host "  FLAGGED FILES:" -ForegroundColor Red
        Write-Host ("  " + "-"*60) -ForegroundColor DarkRed
        foreach ($f in $flaggedList) {
            Write-Host ""
            Write-Host "  [!!] $($f.FileName)" -ForegroundColor Red
            Write-Host "       Hits: " -ForegroundColor DarkRed -NoNewline
            Write-Host ($f.AllHits -join " | ") -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "  VERDICT: " -NoNewline -ForegroundColor White
        Write-Host " CHEATS DETECTED " -ForegroundColor White -BackgroundColor DarkRed
    } else {
        Write-Host "  Flagged   : 0" -ForegroundColor Green
        Write-Host ""
        Write-Host "  VERDICT: " -NoNewline -ForegroundColor White
        Write-Host " ALL CLEAN " -ForegroundColor Black -BackgroundColor Green
    }
    Write-Host ""
}

# ── Dump classes ─────────────────────────────────────────────────────────────
function Dump-Classes {
    param([string]$jarPath, [string]$Filter="")
    $rp = Resolve-Path $jarPath -EA SilentlyContinue
    if (-not $rp) { Write-Bad "File not found!"; return }
    $fi = Get-Item $rp
    $out = Join-Path (Split-Path $rp) "$($fi.BaseName)_dump"
    New-Item -ItemType Directory -Force -Path $out | Out-Null
    Write-Section "Dumping: $($fi.Name)"
    try { $zip=[System.IO.Compression.ZipFile]::OpenRead($rp) } catch { Write-Bad "Invalid JAR!"; return }
    $classes = @($zip.Entries | Where-Object { $_.FullName.EndsWith(".class") })
    if ($Filter) { $classes = @($classes | Where-Object { $_.FullName -like "*$Filter*" }) }
    Write-Info "Classes to dump: $($classes.Count)"
    $sum = [System.IO.StreamWriter]::new((Join-Path $out "ALL_CLASSES.txt"),$false,[System.Text.Encoding]::UTF8)
    $sum.WriteLine("MC SS Inspector — Class Dump | $rp | $(Get-Date)"); $sum.WriteLine("="*60)
    $cnt = 0
    foreach ($e in $classes) {
        $bytes = Read-Entry $e
        if ($null -eq $bytes) { continue }
        $inf = Parse-ClassFile -data $bytes
        if (-not $inf.Valid) { continue }
        $cnt++
        $l = "[$cnt] $($inf.ClassName)"
        if ($inf.SuperName -and $inf.SuperName -ne "java.lang.Object") { $l += " extends $($inf.SuperName)" }
        if ($inf.Interfaces.Count -gt 0) { $l += " implements $($inf.Interfaces -join ', ')" }
        $sum.WriteLine($l)
        $sn = $e.FullName -replace '[/\\]','_'
        $cf = [System.IO.StreamWriter]::new((Join-Path $out "$sn.txt"),$false,[System.Text.Encoding]::UTF8)
        $cf.WriteLine("Class: $($inf.ClassName)"); $cf.WriteLine("Super: $($inf.SuperName)")
        $cf.WriteLine("Interfaces: $($inf.Interfaces -join ', ')")
        $cf.WriteLine("`nMethods:"); $inf.Methods | ForEach-Object { $cf.WriteLine("  $_") }
        $cf.WriteLine("`nFields:"); $inf.Fields | ForEach-Object { $cf.WriteLine("  $_") }
        $cf.WriteLine("`nStrings:"); $inf.Strings | Where-Object { $_.Length -gt 2 } | ForEach-Object { $cf.WriteLine("  `"$_`"") }
        $cf.Close()
    }
    $sum.Close(); $zip.Dispose()
    Write-OK "Exported $cnt classes to: $out"
}

# ── MAIN — Auto start, no mode selection ─────────────────────────────────────
Show-Banner

Write-Host "  Enter path to mods folder:" -ForegroundColor White
Write-Host "  (press Enter for default: $env:APPDATA\.minecraft\mods)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  PATH: " -ForegroundColor Cyan -NoNewline
$inputPath = Read-Host

if ([string]::IsNullOrWhiteSpace($inputPath)) {
    $inputPath = "$env:APPDATA\.minecraft\mods"
    Write-Host "  Using: $inputPath" -ForegroundColor Green
}

if (-not (Test-Path $inputPath)) {
    Write-Bad "Path not found: $inputPath"
    Read-Host "`n  Press Enter to exit"
    exit
}

# Auto detect: folder or single file
$t = Get-Date

if (Test-Path $inputPath -PathType Leaf) {
    # Single JAR
    Write-Host ""
    Write-Host "  Single file detected. Options:" -ForegroundColor White
    Write-Host "  [1] Scan" -ForegroundColor Cyan
    Write-Host "  [2] Scan (verbose)" -ForegroundColor Cyan
    Write-Host "  [3] Dump classes" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Choice [1]: " -ForegroundColor Yellow -NoNewline
    $m = Read-Host
    switch ($m) {
        "2" { Scan-Jar -jarPath $inputPath -Verbose }
        "3" { Dump-Classes -jarPath $inputPath }
        default { Scan-Jar -jarPath $inputPath }
    }
} else {
    # Folder — fully automatic
    Scan-Folder -folderPath $inputPath
}

$el = ((Get-Date)-$t).TotalSeconds
Write-Host ""
Write-Host "  Completed in $([math]::Round($el,2))s" -ForegroundColor DarkCyan
Write-Host ""
Read-Host "  Press Enter to exit"
