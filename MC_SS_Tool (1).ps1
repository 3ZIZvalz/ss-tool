
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
    Write-Host "  |                       Version 3.0                             |" -ForegroundColor Cyan
    Write-Host "  +-----------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
}

# ── Suspicious keyword list ──────────────────────────────────────────────────
# Only exact/strong indicators — no generic words that cause false positives
$CHEAT_MODULES = @(
    # Aura / Combat
    "killaura","kill_aura","kill`$aura","autohit","forceattack",
    "triggerbot","trigger_bot","trigger`$bot","triggerattack",
    "aimbot","aim_bot","aimassist","aim_assist","silentaim","silent_aim",
    "criticals","crit_spam","autoclick","auto_click","autoclicker",
    "forcefield","force_field","multiaura","multi_aura","antiblock",
    # Movement
    "bhop","bunny_hop","bunnyhop","fastfall","nofall","no_fall",
    "noclip","no_clip","antiknockback","anti_knockback","antikb","anti_kb",
    "velocity_mod","velocitymod","flyhack","fly_hack","speedhack",
    "speed_hack","highjump","high_jump","longjump","long_jump",
    "scaffold_mod","scaffoldmod","towerhack","tower_hack",
    "phase_mod","phasemod","jesus_mod","jesusmod",
    # Vision / ESP
    "wallhack","wall_hack","xrayhack","x_ray_hack","chesthighlight",
    "tracers_mod","fullbright_mod","nametag_esp","playeresp",
    "player_esp","entityesp","entity_esp","itemfilter_esp",
    # Render / Visual
    "chams_mod","chamsmod","armorchams","hitbox_esp","hitboxesp",
    "breadcrumbs","tracer_mod","radar_mod","radarmod",
    # Network / Packet
    "packetfly","packet_fly","packetspeed","packet_speed",
    "packetedit","packet_edit","packetcancel","reachmod","reach_mod",
    "timermod","timer_mod","pingspoof","ping_spoof","anticheat_bypass",
    "nametag_changer",
    # AutoFarm / Utils
    "nuker_mod","nukermod","automine","auto_mine","autofarm","auto_farm",
    "autoplace","auto_place","scaffold","autofish","auto_fish",
    "chestsearch","chest_search","autosteal","auto_steal",
    # Client names (exact)
    "wurst_client","wurstclient","liquidbounce","liquid_bounce",
    "meteorclient","meteor_client","impact_client","impactclient",
    "aristois","wolfram_client","wolframclient","inertia_client",
    "future_client","futureclient","sigma_client","sigmaclient",
    "rise_client","riseclient","novoline","crest_client","vape_client",
    "hyperion_client","rectitude","ares_client",
    # Injectors / Malware
    "backdoor","keylogger","token_stealer","tokenstealer",
    "discord_stealer","discordstealer","rat_client","ratclient",
    "injected_code","obfuscator_v","skidded","malware_module"
)

# Exact package paths — only real cheat client namespaces
$CHEAT_PACKAGES = @(
    "me.wurst","net.wurstclient","me.zero.client","com.impact.mod",
    "dev.liquidbounce","net.ccbluex","com.meteorclient",
    "meteordevelopment","net.wurstplus","me.sigma.client",
    "com.rise.client","com.inertia.client","com.vape.client",
    "com.future.client","com.hyperion.client","com.aristois"
)

# ── Java Class Parser ────────────────────────────────────────────────────────
function Parse-ClassFile {
    param([byte[]]$data)
    $r = @{ Valid=$false; ClassName=""; SuperName=""; Methods=@(); Fields=@(); Strings=@(); Interfaces=@() }
    if ($data.Length -lt 8) { return $r }
    if ($data[0] -ne 0xCA -or $data[1] -ne 0xFE -or $data[2] -ne 0xBA -or $data[3] -ne 0xBE) { return $r }
    $r.Valid = $true
    try {
        $pos = 8
        function Read-U16 { $v=([int]$data[$pos]-shl 8)-bor $data[$pos+1]; $script:pos+=2; return $v }
        function Read-U32 { $v=([int]$data[$pos]-shl 24)-bor([int]$data[$pos+1]-shl 16)-bor([int]$data[$pos+2]-shl 8)-bor $data[$pos+3]; $script:pos+=4; return $v }
        $cpCount=Read-U16; $cp=@($null); $i=1
        while ($i -lt $cpCount) {
            $tag=$data[$pos]; $pos++
            switch ($tag) {
                1  { $len=Read-U16; $s=[System.Text.Encoding]::UTF8.GetString($data,$pos,$len); $pos+=$len; $cp+=,@("Utf8",$s) }
                7  { $idx=Read-U16; $cp+=,@("Class",$idx) }
                8  { $idx=Read-U16; $cp+=,@("String",$idx) }
                9  { $pos+=4; $cp+=,@("Ref",$null) }
                10 { $pos+=4; $cp+=,@("Ref",$null) }
                11 { $pos+=4; $cp+=,@("Ref",$null) }
                12 { $pos+=4; $cp+=,@("NT",$null) }
                3  { $pos+=4; $cp+=,@("I",$null) }
                4  { $pos+=4; $cp+=,@("F",$null) }
                5  { $pos+=8; $cp+=,@("L",$null); $cp+=,$null; $i++ }
                6  { $pos+=8; $cp+=,@("D",$null); $cp+=,$null; $i++ }
                15 { $pos+=3; $cp+=,@("MH",$null) }
                16 { $pos+=2; $cp+=,@("MT",$null) }
                17 { $pos+=4; $cp+=,@("Dyn",$null) }
                18 { $pos+=4; $cp+=,@("Dyn",$null) }
                19 { $pos+=2; $cp+=,@("Mod",$null) }
                20 { $pos+=2; $cp+=,@("Pkg",$null) }
                default { $cp+=,$null }
            }
            $i++
        }
        foreach ($e in $cp) { if ($e -and $e[0] -eq "Utf8" -and $e[1].Length -gt 2) { $r.Strings+=$e[1] } }
        function Resolve-Class($idx) {
            if ($idx -gt 0 -and $idx -lt $cp.Count -and $cp[$idx]) {
                $ni=$cp[$idx][1]
                if ($ni -gt 0 -and $ni -lt $cp.Count -and $cp[$ni] -and $cp[$ni][0] -eq "Utf8") { return $cp[$ni][1] -replace '/','.' }
            }; return ""
        }
        $pos+=2
        $r.ClassName=Resolve-Class (Read-U16)
        $r.SuperName=Resolve-Class (Read-U16)
        $ifC=Read-U16; for($x=0;$x-lt $ifC;$x++){$r.Interfaces+=Resolve-Class(Read-U16)}
        $fC=Read-U16
        for($x=0;$x-lt $fC;$x++){
            $pos+=2;$ni=Read-U16;$pos+=2;$ac=Read-U16
            if($ni -gt 0 -and $ni -lt $cp.Count -and $cp[$ni]){$r.Fields+=$cp[$ni][1]}
            for($a=0;$a-lt $ac;$a++){$pos+=2;$al=Read-U32;$pos+=$al}
        }
        $mC=Read-U16
        for($x=0;$x-lt $mC;$x++){
            $pos+=2;$ni=Read-U16;$di=Read-U16;$ac=Read-U16
            $mn="";$md=""
            if($ni -gt 0 -and $ni -lt $cp.Count -and $cp[$ni]){$mn=$cp[$ni][1]}
            if($di -gt 0 -and $di -lt $cp.Count -and $cp[$di]){$md=$cp[$di][1]}
            if($mn){$r.Methods+="$mn$md"}
            for($a=0;$a-lt $ac;$a++){$pos+=2;$al=Read-U32;$pos+=$al}
        }
    } catch {}
    return $r
}

# ── Check class for suspicious content ──────────────────────────────────────
function Get-Hits {
    param($info, [string]$fname="")
    $hits = @()

    # Check class/super/interface names and file path (exact package match)
    $classPath = $info.ClassName.ToLower()
    $superPath = $info.SuperName.ToLower()
    $filePath  = $fname.ToLower() -replace '/','.'

    foreach ($pkg in $CHEAT_PACKAGES) {
        $p = $pkg.ToLower()
        if ($classPath.StartsWith($p) -or $superPath.StartsWith($p) -or $filePath.Contains($p)) {
            $hits += "[PKG] $pkg"
        }
    }

    # Check string constants and method names — require word boundary style match
    $allText = ($info.Methods + $info.Fields + $info.Strings) -join "`n"
    $allLow  = $allText.ToLower()

    foreach ($kw in $CHEAT_MODULES) {
        $k = $kw.ToLower()
        # Match as whole word or separated by common delimiters
        if ($allLow -match "(^|[\n\._\$\s`"'/\\-])$([regex]::Escape($k))([\n\._\$\s`"'/\\-]|$)") {
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
    if($b -lt 1KB){return "$b B"}
    if($b -lt 1MB){return "{0:F1} KB" -f($b/1KB)}
    if($b -lt 1GB){return "{0:F1} MB" -f($b/1MB)}
    return "{0:F1} GB" -f($b/1GB)
}

# ── Scan single JAR ──────────────────────────────────────────────────────────
function Scan-Jar {
    param([string]$jarPath, [switch]$Verbose, [switch]$Silent)
    $rp = Resolve-Path $jarPath -ErrorAction SilentlyContinue
    if (-not $rp) { if (-not $Silent){ Write-Bad "File not found: $jarPath" }; return $null }
    $fi = Get-Item $rp

    if (-not $Silent) {
        Write-Section "Scanning: $($fi.Name)"
        Write-Info "Size     : $(Format-Size $fi.Length)"
        Write-Info "SHA-256  : $(Get-SHA256 $rp)"
        Write-Info "Modified : $($fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    }

    try { Add-Type -AssemblyName System.IO.Compression.FileSystem -EA Stop } catch {}
    try { $zip=[System.IO.Compression.ZipFile]::OpenRead($rp) }
    catch {
        if (-not $Silent){ Write-Bad "Invalid JAR: $($fi.Name)" }
        return $null
    }

    $entries = $zip.Entries
    $classes = $entries | Where-Object { $_.FullName.EndsWith(".class") }

    if (-not $Silent) {
        Write-Info "Classes  : $($classes.Count)"
        Write-Info "Files    : $($entries.Count)"

        # MANIFEST
        $mf = $entries | Where-Object { $_.FullName -eq "META-INF/MANIFEST.MF" } | Select-Object -First 1
        if ($mf) {
            Write-Section "MANIFEST.MF"
            $rd=New-Object System.IO.StreamReader($mf.Open())
            ($rd.ReadToEnd() -split "`n") | Where-Object{$_.Trim()} | ForEach-Object{ Write-Info $_.Trim() }
            $rd.Close()
        }

        # Mod meta
        foreach ($meta in @("fabric.mod.json","mcmod.info","mods.toml","pack.mcmeta")) {
            $me=$entries|Where-Object{$_.FullName -eq $meta}|Select-Object -First 1
            if ($me){
                Write-Section "Mod Info ($meta)"
                $rd=New-Object System.IO.StreamReader($me.Open())
                $t=$rd.ReadToEnd(); $rd.Close()
                Write-Host ($t.Substring(0,[Math]::Min(800,$t.Length))) -ForegroundColor White
            }
        }
        Write-Section "Scanning $($classes.Count) classes..."
    }

    $suspicious=@(); $allHits=@(); $sc=0; $tot=$classes.Count

    foreach ($entry in $classes) {
        $sc++
        if (-not $Silent -and ($sc % 100 -eq 0 -or $sc -eq $tot)) {
            $pct=[int]($sc/$tot*100)
            $bar=([string][char]0x2588*[int]($pct/5))+([string][char]0x2591*(20-[int]($pct/5)))
            Write-Host "`r  [$bar] $pct% ($sc/$tot)   " -NoNewline -ForegroundColor Cyan
        }
        try {
            $st=$entry.Open(); $ms=New-Object System.IO.MemoryStream
            $st.CopyTo($ms); $st.Close(); $bytes=$ms.ToArray(); $ms.Close()
            $inf=Parse-ClassFile -data $bytes
            if (-not $inf.Valid){ continue }
            $hits=Get-Hits -info $inf -fname $entry.FullName
            if ($hits.Count -gt 0){
                $suspicious+=@{
                    File=$entry.FullName; ClassName=$inf.ClassName
                    SuperName=$inf.SuperName; Methods=$inf.Methods
                    Interfaces=$inf.Interfaces; Hits=$hits
                }
                $allHits+=$hits
            }
        } catch {}
    }

    if (-not $Silent){ Write-Host "" }
    $zip.Dispose()
    $allHits = $allHits | Select-Object -Unique

    if (-not $Silent) {
        Write-Section "Results: $($fi.Name)"
        if ($suspicious.Count -eq 0) {
            Write-OK "CLEAN — No suspicious content found in $tot classes"
        } else {
            Write-Bad "FLAGGED — $($suspicious.Count) suspicious class(es) detected!"
            Write-Bad "Keywords: $($allHits -join ' | ')"
            Write-Section "Suspicious Classes"
            foreach ($s in $suspicious) {
                Write-Host ""
                Write-Host ("  " + "-"*60) -ForegroundColor DarkRed
                Write-Host "  [FLAGGED] " -ForegroundColor Red -NoNewline
                Write-Host $s.ClassName -ForegroundColor White
                Write-Host "  File      : " -ForegroundColor Cyan -NoNewline; Write-Host $s.File
                if ($s.SuperName -and $s.SuperName -ne "java.lang.Object"){
                    Write-Host "  Extends   : " -ForegroundColor Cyan -NoNewline; Write-Host $s.SuperName
                }
                if ($s.Interfaces.Count -gt 0){
                    Write-Host "  Implements: " -ForegroundColor Cyan -NoNewline; Write-Host ($s.Interfaces -join ", ")
                }
                Write-Host "  Flagged   : " -ForegroundColor Red -NoNewline
                Write-Host ($s.Hits -join " | ") -ForegroundColor Yellow
                if ($Verbose -and $s.Methods.Count -gt 0){
                    Write-Host "  Methods:" -ForegroundColor Cyan
                    $s.Methods | Select-Object -First 25 | ForEach-Object { Write-Host "    > $_" -ForegroundColor DarkYellow }
                    if($s.Methods.Count -gt 25){ Write-Host "    ... +$($s.Methods.Count-25) more" -ForegroundColor DarkGray }
                }
            }
        }
    }

    return @{
        FileName=$fi.Name; FilePath=[string]$rp
        TotalClasses=$tot; SuspiciousCount=$suspicious.Count
        SuspiciousClasses=$suspicious; AllHits=$allHits
        IsClean=($suspicious.Count -eq 0)
    }
}

# ── Scan full folder (auto, no selection) ───────────────────────────────────
function Scan-Folder {
    param([string]$folderPath, [switch]$Verbose)
    if (-not (Test-Path $folderPath)){ Write-Bad "Folder not found: $folderPath"; return }

    $jars = Get-ChildItem -Path $folderPath -Recurse -Filter "*.jar" -ErrorAction SilentlyContinue
    if ($jars.Count -eq 0){ Write-Warn "No JAR files found."; return }

    Write-Section "Scanning Folder: $folderPath"
    Write-Info "Found $($jars.Count) JAR file(s) — scanning all..."

    $results=@(); $flaggedList=@(); $cleanList=@()
    $idx=0
    foreach ($jar in $jars) {
        $idx++
        Write-Host ""
        Write-Host "  [$idx/$($jars.Count)] " -ForegroundColor DarkCyan -NoNewline
        Write-Host $jar.Name -ForegroundColor White -NoNewline
        Write-Host " — scanning..." -ForegroundColor DarkGray

        $r = Scan-Jar -jarPath $jar.FullName -Verbose:$Verbose -Silent

        if ($r) {
            $pct=[int]($r.TotalClasses)
            if ($r.IsClean) {
                Write-Host "         " -NoNewline
                Write-Host " CLEAN " -ForegroundColor Black -BackgroundColor Green -NoNewline
                Write-Host " $($r.TotalClasses) classes checked" -ForegroundColor DarkGray
                $cleanList += $jar.Name
            } else {
                Write-Host "         " -NoNewline
                Write-Host " FLAGGED " -ForegroundColor White -BackgroundColor DarkRed -NoNewline
                Write-Host " $($r.SuspiciousCount) suspicious | Keywords: " -ForegroundColor Red -NoNewline
                Write-Host ($r.AllHits -join " | ") -ForegroundColor Yellow
                $flaggedList += $r

                # Show suspicious class details
                foreach ($sc in $r.SuspiciousClasses) {
                    Write-Host "    [>>] $($sc.ClassName)" -ForegroundColor Red -NoNewline
                    Write-Host " — $($sc.Hits -join ', ')" -ForegroundColor Yellow
                }
            }
            $results += $r
        } else {
            Write-Host "         " -NoNewline
            Write-Host " ERROR  " -ForegroundColor White -BackgroundColor DarkYellow -NoNewline
            Write-Host " Could not read file" -ForegroundColor DarkYellow
        }
    }

    # ── Final Summary ────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "  +================================================================+" -ForegroundColor Cyan
    Write-Host "  |                    SCAN COMPLETE - SUMMARY                    |" -ForegroundColor Cyan
    Write-Host "  +================================================================+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Total scanned : $($jars.Count)" -ForegroundColor White
    Write-Host "  Clean         : $($cleanList.Count)" -ForegroundColor Green
    Write-Host "  Flagged       : $($flaggedList.Count)" -ForegroundColor $(if($flaggedList.Count -gt 0){"Red"}else{"Green"})
    Write-Host ""

    if ($flaggedList.Count -gt 0) {
        Write-Host "  FLAGGED FILES:" -ForegroundColor Red
        Write-Host "  " + ("-"*60) -ForegroundColor DarkRed
        foreach ($f in $flaggedList) {
            Write-Host ""
            Write-Host "  [!!] $($f.FileName)" -ForegroundColor Red
            Write-Host "       Suspicious classes : $($f.SuspiciousCount)" -ForegroundColor DarkRed
            Write-Host "       Keywords found     : " -ForegroundColor DarkRed -NoNewline
            Write-Host ($f.AllHits -join " | ") -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "  VERDICT: " -ForegroundColor White -NoNewline
        Write-Host " CHEATS DETECTED " -ForegroundColor White -BackgroundColor DarkRed
    } else {
        Write-Host "  VERDICT: " -ForegroundColor White -NoNewline
        Write-Host " ALL CLEAN " -ForegroundColor Black -BackgroundColor Green
    }
    Write-Host ""
}

# ── Dump Classes ─────────────────────────────────────────────────────────────
function Dump-Classes {
    param([string]$jarPath, [string]$OutputDir="", [string]$Filter="")
    $rp=Resolve-Path $jarPath -EA SilentlyContinue
    if (-not $rp){ Write-Bad "File not found!"; return }
    $fi=Get-Item $rp
    if (-not $OutputDir){ $OutputDir=Join-Path (Split-Path $rp) "$($fi.BaseName)_dump" }
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    Write-Section "Dumping: $($fi.Name)"
    try { $zip=[System.IO.Compression.ZipFile]::OpenRead($rp) } catch { Write-Bad "Invalid JAR!"; return }
    $classes=$zip.Entries|Where-Object{$_.FullName.EndsWith(".class")}
    if($Filter){ $classes=$classes|Where-Object{$_.FullName -like "*$Filter*"}; Write-Info "Filter '$Filter': $($classes.Count) classes" }
    $sum=[System.IO.StreamWriter]::new((Join-Path $OutputDir "ALL_CLASSES.txt"),$false,[System.Text.Encoding]::UTF8)
    $sum.WriteLine("MC SS Inspector - Class Dump | File: $rp | Date: $(Get-Date)"); $sum.WriteLine("="*60)
    $cnt=0
    foreach ($e in $classes) {
        try {
            $st=$e.Open();$ms=New-Object System.IO.MemoryStream;$st.CopyTo($ms);$st.Close();$b=$ms.ToArray();$ms.Close()
            $inf=Parse-ClassFile -data $b
            if(-not $inf.Valid){continue}
            $cnt++; $l="[$cnt] $($inf.ClassName)"
            if($inf.SuperName -and $inf.SuperName -ne "java.lang.Object"){$l+=" extends $($inf.SuperName)"}
            if($inf.Interfaces.Count -gt 0){$l+=" implements $($inf.Interfaces -join ', ')"}
            $sum.WriteLine($l)
            $sn=$e.FullName -replace '[/\\]','_'
            $cf=[System.IO.StreamWriter]::new((Join-Path $OutputDir "$sn.txt"),$false,[System.Text.Encoding]::UTF8)
            $cf.WriteLine("Class: $($inf.ClassName)"); $cf.WriteLine("Super: $($inf.SuperName)")
            $cf.WriteLine("Interfaces: $($inf.Interfaces -join ', ')")
            $cf.WriteLine("`nMethods ($($inf.Methods.Count)):"); $inf.Methods|ForEach-Object{$cf.WriteLine("  - $_")}
            $cf.WriteLine("`nFields ($($inf.Fields.Count)):"); $inf.Fields|ForEach-Object{$cf.WriteLine("  - $_")}
            $cf.WriteLine("`nStrings:"); $inf.Strings|Where-Object{$_.Length -gt 2}|ForEach-Object{$cf.WriteLine("  `"$_`"")}
            $cf.Close()
        } catch {}
    }
    $sum.Close(); $zip.Dispose()
    Write-OK "Exported $cnt classes to: $OutputDir"
}

# ── MAIN ─────────────────────────────────────────────────────────────────────
Show-Banner

Write-Host "  Enter path to mods folder:" -ForegroundColor White
Write-Host "  (press Enter for default: $env:APPDATA\.minecraft\mods)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  PATH: " -ForegroundColor Cyan -NoNewline
$inputPath = Read-Host

if ([string]::IsNullOrWhiteSpace($inputPath)) {
    $inputPath = "$env:APPDATA\.minecraft\mods"
    Write-Host "  Using default: $inputPath" -ForegroundColor Green
}

if (-not (Test-Path $inputPath)) {
    Write-Bad "Path not found: $inputPath"
    Read-Host "`n  Press Enter to exit"
    exit
}

Write-Host ""
Write-Host "  Select mode:" -ForegroundColor White
Write-Host "  [1] Scan all JARs in folder       (auto, no selection)" -ForegroundColor Cyan
Write-Host "  [2] Scan single JAR file" -ForegroundColor Cyan
Write-Host "  [3] Scan single JAR (verbose)"    -ForegroundColor Cyan
Write-Host "  [4] Dump all classes from JAR"    -ForegroundColor Cyan
Write-Host ""
Write-Host "  Choice [1]: " -ForegroundColor Yellow -NoNewline
$mode = Read-Host
if ([string]::IsNullOrWhiteSpace($mode)) { $mode = "1" }

$t = Get-Date
switch ($mode) {
    "2" {
        if (Test-Path $inputPath -PathType Leaf) { Scan-Jar -jarPath $inputPath }
        else {
            Write-Host "  JAR file path: " -ForegroundColor Cyan -NoNewline
            Scan-Jar -jarPath (Read-Host)
        }
    }
    "3" {
        if (Test-Path $inputPath -PathType Leaf) { Scan-Jar -jarPath $inputPath -Verbose }
        else {
            Write-Host "  JAR file path: " -ForegroundColor Cyan -NoNewline
            Scan-Jar -jarPath (Read-Host) -Verbose
        }
    }
    "4" {
        Write-Host "  JAR file path: " -ForegroundColor Cyan -NoNewline; $jf=Read-Host
        Write-Host "  Filter (empty = all): " -ForegroundColor Cyan -NoNewline; $fl=Read-Host
        Dump-Classes -jarPath $jf -Filter $fl
    }
    default { Scan-Folder -folderPath $inputPath }
}

$el=((Get-Date)-$t).TotalSeconds
Write-Host ""
Write-Host "  Completed in $([math]::Round($el,2))s" -ForegroundColor DarkCyan
Write-Host ""
Read-Host "  Press Enter to exit"
