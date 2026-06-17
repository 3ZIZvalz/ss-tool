
Add-Type -AssemblyName System.IO.Compression.FileSystem
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"
Clear-Host

# ═══════════════════════════════════════════════════════════════
#  SIGNATURES
# ═══════════════════════════════════════════════════════════════
$EVIL_PKG = @(
    "me/wurst/","net/wurstclient/","me/zero/client/","com/impact/mod/",
    "dev/liquidbounce/","net/ccbluex/","com/meteorclient/",
    "meteordevelopment/","me/sigma/","com/rise/client/",
    "com/inertia/","com/vape/client/","com/future/client/",
    "com/aristois/","com/novoline/"
)

$EVIL_EXACT = @(
    "KillAura","KillAuraModule","AutoHit","ForceAttack",
    "TriggerBot","TriggerBotModule","TriggerAttack","TriggerKey",
    "AimBot","AimBotModule","SilentAim","AimAssistModule",
    "CritSpam","AutoClicker","AutoClickModule","ClickTimer",
    "ForceField","ForceFieldModule","MultiAura","AntiBlock",
    "BHop","BunnyHop","NoFall","NoFallModule","AirJump",
    "NoClip","NoClipModule","AntiKnockback","AntiKB",
    "VelocityHack","FlyHack","FlyModule","SpeedHack","SpeedModule",
    "ScaffoldModule","TowerHack","PhaseModule","JesusModule",
    "WallHack","XRayModule","XRayHack","PlayerESP","EntityESP",
    "ChestESP","ChamsModule","ArmorChams","HitboxESP","TracerModule",
    "PacketFly","PacketSpeed","PacketEdit","PacketCancel",
    "ReachModule","TimerModule","PingSpoof","AntiCheatBypass",
    "NukerModule","AutoMine","AutoFarm","AutoFish","AutoSteal",
    "ChestStealer","AutoPlace","ScaffoldWalk",
    "WurstClient","LiquidBounce","MeteorClient","ImpactClient",
    "AristoisClient","WolframClient","FutureClient","SigmaClient",
    "RiseClient","NovolineClient","VapeClient","HyperionClient",
    "Backdoor","KeyLogger","TokenStealer","DiscordStealer","RatClient"
)

# Case-insensitive substring keywords checked against ALL strings
$EVIL_SUBSTR = @(
    "killaura","triggerbot","trigger_bot","aimbot","silentaim",
    "forcefield","multiaura","bhop","bunnyhop","nofall","noclip",
    "antiknockback","antikb","velocityhack","flyhack","speedhack",
    "scaffoldmod","scaffold_mod","wallhack","xrayhack","playeresp",
    "entityesp","chamsmod","packetfly","reachmod","timermod",
    "pingspoof","nukermod","autofarm","autofish","autosteal",
    "cheststealer","wurst","liquidbounce","meteorclient","impactclient",
    "aristois","wolframclient","futureclient","sigmaclient","riseclient",
    "novoline","vapeclient","backdoor","keylogger","tokenstealer",
    "discordstealer","ratclient","autoclick","critspam","aimbotmod",
    "esp_module","cheat_module","hack_module","bypass_ac","anticheat_bypass"
)

# ═══════════════════════════════════════════════════════════════
#  JAVA .class PARSER — reads full constant pool
# ═══════════════════════════════════════════════════════════════
function Parse-Class {
    param([byte[]]$raw)
    $out = [PSCustomObject]@{
        OK=0; Name=""; Super=""; Ifaces=@()
        Methods=@(); Fields=@()
        Strings=[System.Collections.Generic.List[string]]::new()
        ClassRefs=[System.Collections.Generic.List[string]]::new()
    }
    if ($raw.Length -lt 10) { return $out }
    if ($raw[0] -ne 0xCA -or $raw[1] -ne 0xFE) { return $out }
    try {
        $ms = [System.IO.MemoryStream]::new($raw)
        $br = [System.IO.BinaryReader]::new($ms)
        $br.ReadBytes(8) | Out-Null

        function RU16 { $b=$br.ReadBytes(2); ([int]$b[0]*256)+$b[1] }
        function RU32 { $b=$br.ReadBytes(4); ([long]$b[0]*16777216)+([long]$b[1]*65536)+([long]$b[2]*256)+$b[3] }

        $n  = RU16
        $cp = [System.Collections.Generic.List[object]]::new()
        $cp.Add($null) | Out-Null   # slot 0 unused

        $i = 1
        while ($i -lt $n) {
            $tag = $br.ReadByte()
            switch ($tag) {
                1  { $l=RU16; $cp.Add([System.Text.Encoding]::UTF8.GetString($br.ReadBytes($l))) | Out-Null }
                7  { $cp.Add([PSCustomObject]@{T=7;I=RU16}) | Out-Null }
                8  { $cp.Add([PSCustomObject]@{T=8;I=RU16}) | Out-Null }
                3  { $br.ReadBytes(4)|Out-Null; $cp.Add($null)|Out-Null }
                4  { $br.ReadBytes(4)|Out-Null; $cp.Add($null)|Out-Null }
                5  { $br.ReadBytes(8)|Out-Null; $cp.Add($null)|Out-Null; $cp.Add($null)|Out-Null; $i++ }
                6  { $br.ReadBytes(8)|Out-Null; $cp.Add($null)|Out-Null; $cp.Add($null)|Out-Null; $i++ }
                9  { $br.ReadBytes(4)|Out-Null; $cp.Add($null)|Out-Null }
                10 { $br.ReadBytes(4)|Out-Null; $cp.Add($null)|Out-Null }
                11 { $br.ReadBytes(4)|Out-Null; $cp.Add($null)|Out-Null }
                12 { $br.ReadBytes(4)|Out-Null; $cp.Add($null)|Out-Null }
                15 { $br.ReadBytes(3)|Out-Null; $cp.Add($null)|Out-Null }
                16 { $br.ReadBytes(2)|Out-Null; $cp.Add($null)|Out-Null }
                17 { $br.ReadBytes(4)|Out-Null; $cp.Add($null)|Out-Null }
                18 { $br.ReadBytes(4)|Out-Null; $cp.Add($null)|Out-Null }
                19 { $br.ReadBytes(2)|Out-Null; $cp.Add($null)|Out-Null }
                20 { $br.ReadBytes(2)|Out-Null; $cp.Add($null)|Out-Null }
                default { $br.Close(); $ms.Close(); return $out }
            }
            $i++
        }

        # ── Collect all UTF8 strings (any length > 1) ──
        foreach ($e in $cp) {
            if ($e -is [string] -and $e.Length -gt 1) {
                $out.Strings.Add($e) | Out-Null
            }
        }

        # ── Resolve class name helper ──
        function GN($idx) {
            if ($idx -le 0 -or $idx -ge $cp.Count) { return "" }
            $v = $cp[$idx]
            if ($v -and $v.T -eq 7) {
                $ni = $v.I
                if ($ni -gt 0 -and $ni -lt $cp.Count -and $cp[$ni] -is [string]) { return $cp[$ni] }
            }
            return ""
        }

        # ── Collect String constants (tag 8) ──
        foreach ($e in $cp) {
            if ($e -and $e.T -eq 8) {
                $ni = $e.I
                if ($ni -gt 0 -and $ni -lt $cp.Count -and $cp[$ni] -is [string]) {
                    $out.ClassRefs.Add($cp[$ni]) | Out-Null
                }
            }
        }

        $br.ReadBytes(2) | Out-Null  # access flags
        $out.Name  = GN (RU16)
        $out.Super = GN (RU16)

        $ic = RU16
        for ($x=0;$x-lt $ic;$x++) { $v=GN(RU16); if($v){$out.Ifaces+=$v} }

        $fc = RU16
        for ($x=0;$x-lt $fc;$x++) {
            $br.ReadBytes(2)|Out-Null; $ni=RU16; $br.ReadBytes(2)|Out-Null; $ac=RU16
            if($ni-gt 0-and $ni-lt $cp.Count-and $cp[$ni]-is [string]){$out.Fields+=$cp[$ni]}
            for($a=0;$a-lt $ac;$a++){$br.ReadBytes(2)|Out-Null;$al=RU32;$br.ReadBytes([int]$al)|Out-Null}
        }
        $mc = RU16
        for ($x=0;$x-lt $mc;$x++) {
            $br.ReadBytes(2)|Out-Null; $ni=RU16; $br.ReadBytes(2)|Out-Null; $ac=RU16
            if($ni-gt 0-and $ni-lt $cp.Count-and $cp[$ni]-is [string]){$out.Methods+=$cp[$ni]}
            for($a=0;$a-lt $ac;$a++){$br.ReadBytes(2)|Out-Null;$al=RU32;$br.ReadBytes([int]$al)|Out-Null}
        }

        $out.OK=1
        $br.Close(); $ms.Close()
    } catch {}
    return $out
}

# ═══════════════════════════════════════════════════════════════
#  HIT CHECKER
# ═══════════════════════════════════════════════════════════════
function Check-Class {
    param($c, [string]$path)
    $hits = [System.Collections.Generic.List[string]]::new()

    # 1. Package prefix
    foreach ($pkg in $EVIL_PKG) {
        if ($path.StartsWith($pkg)) { $hits.Add("[PKG] $($pkg.TrimEnd('/'))") | Out-Null }
    }

    # 2. Exact class/super name
    foreach ($tok in $EVIL_EXACT) {
        if ($c.Name -eq $tok -or $c.Name.EndsWith("/$tok")) {
            $hits.Add("[CLASS] $tok") | Out-Null
        }
        if ($c.Super -and ($c.Super -eq $tok -or $c.Super.EndsWith("/$tok"))) {
            $hits.Add("[SUPER] $tok") | Out-Null
        }
    }

    # 3. Exact method/field name
    foreach ($tok in $EVIL_EXACT) {
        if ($c.Methods -contains $tok) { $hits.Add("[METHOD] $tok") | Out-Null }
        if ($c.Fields  -contains $tok) { $hits.Add("[FIELD] $tok")  | Out-Null }
    }

    # 4. Substring search on ALL strings in constant pool
    $allStrings = ($c.Strings + $c.ClassRefs) -join "`n"
    $low = $allStrings.ToLower()
    foreach ($kw in $EVIL_SUBSTR) {
        if ($low.Contains($kw.ToLower())) {
            # find the actual string that matched
            $matched = ($c.Strings + $c.ClassRefs) | Where-Object { $_.ToLower().Contains($kw.ToLower()) } | Select-Object -First 1
            $hits.Add("[STRING] $kw  <- `"$matched`"") | Out-Null
        }
    }

    return @($hits | Select-Object -Unique)
}

# ═══════════════════════════════════════════════════════════════
#  HELPERS
# ═══════════════════════════════════════════════════════════════
function Read-Entry {
    param($e)
    try {
        $ms=[System.IO.MemoryStream]::new()
        $es=$e.Open(); $es.CopyTo($ms); $es.Close()
        return $ms.ToArray()
    } catch { return $null }
}

function SHA256File {
    param([string]$p)
    try {
        $sha=[System.Security.Cryptography.SHA256]::Create()
        $fs=[System.IO.File]::OpenRead($p)
        $h=[BitConverter]::ToString($sha.ComputeHash($fs))-replace'-',''
        $fs.Close(); return $h.ToLower()
    } catch { return "n/a" }
}

function FmtSize {
    param([long]$b)
    if($b-lt 1KB){return"$b B"}
    if($b-lt 1MB){return"{0:F1} KB"-f($b/1KB)}
    if($b-lt 1GB){return"{0:F1} MB"-f($b/1MB)}
    return"{0:F1} GB"-f($b/1GB)
}

# ═══════════════════════════════════════════════════════════════
#  UI HELPERS
# ═══════════════════════════════════════════════════════════════
function Banner {
    Clear-Host
    Write-Host ""
    Write-Host "    _______ _______    _____ _______  ___  ____  " -ForegroundColor Cyan
    Write-Host "   |     __|     __|  |_   _|       |/  _]|    \ " -ForegroundColor Cyan
    Write-Host "   |__     |__     |    | | |   -   /  [_ |  _  |" -ForegroundColor Cyan
    Write-Host "   |_______|_______|    |_| |_______|\_____||__|__|" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    Minecraft SS Inspector  v3.3  |  PowerShell Edition" -ForegroundColor DarkCyan
    Write-Host "   ─────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
}
function Div  { Write-Host "   ─────────────────────────────────────────────────────" -ForegroundColor DarkGray }
function Tag  {
    param([string]$lbl,[string]$bg,[string]$fg="White")
    Write-Host " $lbl " -BackgroundColor $bg -ForegroundColor $fg -NoNewline
    Write-Host "  " -NoNewline
}

# ═══════════════════════════════════════════════════════════════
#  SCAN JAR
# ═══════════════════════════════════════════════════════════════
function Scan-Jar {
    param([string]$path, [switch]$ShowStrings)
    $fi = Get-Item $path -EA SilentlyContinue
    if (-not $fi) { return $null }
    $zip = $null
    try { $zip=[System.IO.Compression.ZipFile]::OpenRead($path) } catch { return $null }

    $entries = @($zip.Entries)
    $classes = @($entries | Where-Object { $_.FullName.EndsWith(".class") })
    $flagged = [System.Collections.Generic.List[hashtable]]::new()
    $allHits = [System.Collections.Generic.List[string]]::new()
    $sc=0; $tot=$classes.Count

    foreach ($e in $classes) {
        $sc++
        $raw = Read-Entry $e
        if ($null -eq $raw) { continue }
        $c = Parse-Class -raw $raw
        if (-not $c.OK) { continue }

        $hits = Check-Class -c $c -path $e.FullName
        if ($hits.Count -gt 0) {
            $flagged.Add(@{
                Path=$e.FullName; Name=$c.Name; Super=$c.Super
                Ifaces=$c.Ifaces; Methods=$c.Methods; Fields=$c.Fields
                Strings=@($c.Strings); Hits=$hits
            }) | Out-Null
            foreach ($h in $hits) { if (-not $allHits.Contains($h)) { $allHits.Add($h)|Out-Null } }
        }
    }
    try { $zip.Dispose() } catch {}

    return [PSCustomObject]@{
        File=$fi.Name; FullPath=$fi.FullName; Size=$fi.Length
        Hash=(SHA256File $fi.FullName); Total=$tot
        Flagged=$flagged; AllHits=$allHits; Clean=($flagged.Count-eq 0)
    }
}

# ═══════════════════════════════════════════════════════════════
#  LIST ALL CLASSES IN A JAR  (with all strings)
# ═══════════════════════════════════════════════════════════════
function List-Classes {
    param([string]$path)
    $zip=$null
    try { $zip=[System.IO.Compression.ZipFile]::OpenRead($path) } catch {
        Write-Host "  Cannot open JAR." -ForegroundColor Red; return
    }
    $classes = @($zip.Entries | Where-Object { $_.FullName.EndsWith(".class") })
    Write-Host ""
    Write-Host ("  File: " + (Split-Path $path -Leaf)) -ForegroundColor Cyan
    Write-Host ("  Classes: " + $classes.Count) -ForegroundColor DarkGray
    Div; Write-Host ""
    $i=0
    foreach ($e in $classes) {
        $raw = Read-Entry $e
        if ($null -eq $raw) { continue }
        $c = Parse-Class -raw $raw
        if (-not $c.OK) { continue }
        $i++
        $name = $c.Name -replace '/',  '.'
        Write-Host ("  [{0,4}] " -f $i) -ForegroundColor DarkGray -NoNewline
        Write-Host $name -ForegroundColor Cyan
        if ($c.Super -and $c.Super -ne "java/lang/Object") {
            Write-Host ("         extends : " + ($c.Super -replace '/','.'  )) -ForegroundColor DarkGray
        }
        if ($c.Ifaces.Count -gt 0) {
            Write-Host ("         impls   : " + ($c.Ifaces -replace '/','.' -join ", ")) -ForegroundColor DarkGray
        }
        if ($c.Methods.Count -gt 0) {
            Write-Host ("         methods : " + ($c.Methods -join ", ")) -ForegroundColor DarkYellow
        }
        # Print ALL non-trivial strings
        $strs = @($c.Strings | Where-Object {
            $_.Length -gt 2 -and
            $_ -notmatch '^[\(\)\[A-Z;/]+$' -and   # skip descriptors like (Ljava/lang/String;)V
            $_ -notmatch '^\s*$'
        })
        if ($strs.Count -gt 0) {
            Write-Host "         strings :" -ForegroundColor Magenta -NoNewline
            foreach ($s in $strs | Select-Object -First 30) {
                Write-Host (" `"$s`"") -ForegroundColor DarkMagenta -NoNewline
            }
            Write-Host ""
        }
        Write-Host ""
    }
    $zip.Dispose()
    Div
    Write-Host ("  Total: $i classes") -ForegroundColor DarkGray
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
#  SCAN FOLDER — auto, no selection needed
# ═══════════════════════════════════════════════════════════════
function Scan-Folder {
    param([string]$folder)
    $jars = @(Get-ChildItem -Path $folder -Recurse -Filter "*.jar" -EA SilentlyContinue)
    if ($jars.Count -eq 0) { Write-Host "  No JAR files found." -ForegroundColor Yellow; return }

    Write-Host "  Path   : $folder" -ForegroundColor DarkGray
    Write-Host "  JARs   : $($jars.Count)" -ForegroundColor White
    Div; Write-Host ""

    $dirty=[System.Collections.Generic.List[object]]::new()
    $idx=0

    foreach ($jar in $jars) {
        $idx++
        Write-Host ("  [{0}/{1}] {2}" -f $idx,$jars.Count,$jar.Name) -ForegroundColor White

        $r = Scan-Jar -path $jar.FullName

        if ($null -eq $r) {
            Tag "ERROR" "DarkYellow" "Black"
            Write-Host "could not read" -ForegroundColor DarkYellow; continue
        }

        if ($r.Clean) {
            Tag "CLEAN" "DarkGreen"
            Write-Host "$($r.Total) classes" -ForegroundColor DarkGray
        } else {
            Tag "FLAGGED" "DarkRed"
            Write-Host "$($r.Flagged.Count) hit(s)" -ForegroundColor Red
            foreach ($fc in $r.Flagged) {
                Write-Host ("    >> " + ($fc.Name -replace '/','.' )) -ForegroundColor Red
                foreach ($h in $fc.Hits) {
                    Write-Host ("       " + $h) -ForegroundColor Yellow
                }
            }
            $dirty.Add($r) | Out-Null
        }
        Write-Host ""
    }

    # ── Summary ──────────────────────────────────────────────
    Div; Write-Host ""
    Write-Host "  SUMMARY" -ForegroundColor Cyan
    Write-Host ("  Total   : $($jars.Count)") -ForegroundColor White
    Write-Host ("  Clean   : $($jars.Count - $dirty.Count)") -ForegroundColor Green

    if ($dirty.Count -gt 0) {
        Write-Host ("  Flagged : $($dirty.Count)") -ForegroundColor Red
        Write-Host ""; Div; Write-Host ""
        foreach ($d in $dirty) {
            Write-Host ("  " + [char]0x2588 + " " + $d.File) -ForegroundColor Red
            Write-Host ("    SHA256 : " + $d.Hash) -ForegroundColor DarkGray
            Write-Host ("    Size   : " + (FmtSize $d.Size)) -ForegroundColor DarkGray
            Write-Host ""
            foreach ($fc in $d.Flagged) {
                Write-Host ("    ┌ Class   : " + ($fc.Name   -replace '/','.' )) -ForegroundColor Red
                if ($fc.Super -and $fc.Super -ne "java/lang/Object") {
                    Write-Host ("    │ Extends : " + ($fc.Super -replace '/','.' )) -ForegroundColor DarkRed
                }
                Write-Host "    │ Hits    :" -ForegroundColor DarkRed
                foreach ($h in $fc.Hits) {
                    Write-Host ("    │           " + $h) -ForegroundColor Yellow
                }
                # Show strings from this class
                $strs = @($fc.Strings | Where-Object {
                    $_.Length-gt 2 -and $_ -notmatch '^[\(\)\[A-Z;/]+$' -and $_ -notmatch '^\s*$'
                })
                if ($strs.Count -gt 0) {
                    Write-Host "    │ Strings :" -ForegroundColor Magenta
                    foreach ($s in $strs | Select-Object -First 20) {
                        Write-Host ("    │           `"$s`"") -ForegroundColor DarkMagenta
                    }
                }
                Write-Host ("    └" + "─"*40) -ForegroundColor DarkRed
                Write-Host ""
            }
        }
        Write-Host ""
        Write-Host "  VERDICT " -NoNewline -ForegroundColor White
        Write-Host " CHEATS DETECTED " -BackgroundColor DarkRed -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "  VERDICT " -NoNewline -ForegroundColor White
        Write-Host " ALL CLEAN " -BackgroundColor DarkGreen -ForegroundColor White
    }
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════
Banner

Write-Host "  Path to mods folder or single JAR:" -ForegroundColor White
Write-Host "  (Enter = $env:APPDATA\.minecraft\mods)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  PATH > " -ForegroundColor Cyan -NoNewline
$inp = Read-Host

if ([string]::IsNullOrWhiteSpace($inp)) {
    $inp = "$env:APPDATA\.minecraft\mods"
    Write-Host "  Using default: $inp" -ForegroundColor DarkGray
}

if (-not (Test-Path $inp)) {
    Write-Host "  Not found: $inp" -ForegroundColor Red
    Read-Host "`n  Press Enter to exit"; exit
}

Write-Host ""; $t = Get-Date

if ((Get-Item $inp).PSIsContainer) {
    # ── FOLDER: auto scan all ──
    Scan-Folder -folder $inp
} else {
    # ── SINGLE JAR ──
    Write-Host "  [1] Scan for cheats" -ForegroundColor Cyan
    Write-Host "  [2] List all classes + strings" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Choice [1]: " -ForegroundColor Yellow -NoNewline
    $m = Read-Host
    if ($m -eq "2") {
        List-Classes -path $inp
    } else {
        $r = Scan-Jar -path $inp
        if ($null -eq $r) { Write-Host "  Cannot read JAR." -ForegroundColor Red }
        elseif ($r.Clean) {
            Tag "CLEAN" "DarkGreen"
            Write-Host "$($r.Total) classes — nothing found" -ForegroundColor DarkGray
        } else {
            Tag "FLAGGED" "DarkRed"
            Write-Host "$($r.Flagged.Count) class(es)" -ForegroundColor Red
            Write-Host ""
            foreach ($fc in $r.Flagged) {
                Write-Host ("  ┌ Class   : " + ($fc.Name -replace '/','.' )) -ForegroundColor Red
                Write-Host "  │ Hits    :" -ForegroundColor DarkRed
                foreach ($h in $fc.Hits) { Write-Host ("  │           $h") -ForegroundColor Yellow }
                $strs = @($fc.Strings | Where-Object { $_.Length-gt 2 -and $_ -notmatch '^[\(\)\[A-Z;/]+$' -and $_ -notmatch '^\s*$' })
                if ($strs.Count -gt 0) {
                    Write-Host "  │ Strings :" -ForegroundColor Magenta
                    foreach ($s in $strs|Select-Object -First 20){ Write-Host ("  │           `"$s`"") -ForegroundColor DarkMagenta }
                }
                Write-Host ("  └"+"─"*40) -ForegroundColor DarkRed
            }
        }
    }
}

Write-Host ""
Write-Host ("  Done in {0:F2}s" -f ((Get-Date)-$t).TotalSeconds) -ForegroundColor DarkGray
Write-Host ""
Read-Host "  Press Enter to exit"
