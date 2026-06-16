
Add-Type -AssemblyName System.IO.Compression.FileSystem
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"
Clear-Host

# ═══════════════════════════════════════════════════════
#  CHEAT SIGNATURES — exact class-name prefixes & method
#  keywords. Matched only as whole tokens, never substrings.
# ═══════════════════════════════════════════════════════

# Full package prefixes that belong to known cheat clients
$EVIL_PKG = @(
    "me/wurst/","net/wurstclient/","me/zero/client/",
    "com/impact/mod/","dev/liquidbounce/","net/ccbluex/",
    "com/meteorclient/","meteordevelopment/","me/sigma/",
    "com/rise/client/","com/inertia/","com/vape/client/",
    "com/future/client/","com/aristois/","com/novoline/"
)

# Exact method / field / string tokens (whole-word matched)
$EVIL_TOKENS = @(
    # Combat
    "KillAura","KillAuraModule","AutoHit","ForceAttack",
    "TriggerBot","TriggerBotModule","TriggerAttack","TriggerKey",
    "AimBot","AimBotModule","SilentAim","AimAssistModule",
    "CritSpam","AutoClicker","AutoClickModule","ClickTimer",
    "ForceField","ForceFieldModule","MultiAura","AntiBlock",
    # Movement
    "BHop","BunnyHop","NoFall","NoFallModule","AirJump",
    "NoClip","NoClipModule","AntiKnockback","AntiKB",
    "VelocityHack","FlyHack","FlyModule","SpeedHack","SpeedModule",
    "ScaffoldModule","TowerHack","PhaseModule","JesusModule",
    # Vision
    "WallHack","XRayModule","XRayHack","PlayerESP","EntityESP",
    "ChestESP","ChamsModule","ArmorChams","HitboxESP","TracerModule",
    # Network
    "PacketFly","PacketSpeed","PacketEdit","PacketCancel",
    "ReachModule","TimerModule","PingSpoof","AntiCheatBypass",
    # AutoFarm
    "NukerModule","AutoMine","AutoFarm","AutoFish","AutoSteal",
    "ChestStealer","AutoPlace","ScaffoldWalk",
    # Clients (class names)
    "WurstClient","LiquidBounce","MeteorClient","ImpactClient",
    "AristoisClient","WolframClient","FutureClient","SigmaClient",
    "RiseClient","NovolineClient","VapeClient","HyperionClient",
    # Malware
    "Backdoor","KeyLogger","TokenStealer","DiscordStealer","RatClient"
)

# ═══════════════════════════════════════════════════════
#  JAVA CLASS PARSER  (BinaryReader, no recursion)
# ═══════════════════════════════════════════════════════
function Parse-Class {
    param([byte[]]$raw)
    $out = [PSCustomObject]@{
        OK=0; Name=""; Super=""; Ifaces=@(); Methods=@(); Fields=@(); Pool=@()
    }
    if ($raw.Length -lt 10) { return $out }
    if ($raw[0] -ne 0xCA -or $raw[1] -ne 0xFE) { return $out }

    try {
        $ms = [System.IO.MemoryStream]::new($raw)
        $br = [System.IO.BinaryReader]::new($ms)
        $br.ReadBytes(8) | Out-Null   # magic + versions

        function RU16 { $b=$br.ReadBytes(2); return ([int]$b[0]*256)+$b[1] }
        function RU32 { $b=$br.ReadBytes(4); return ([long]$b[0]*16777216)+([long]$b[1]*65536)+([long]$b[2]*256)+$b[3] }

        $n  = RU16
        $cp = [System.Collections.Generic.List[object]]::new()
        $cp.Add($null) | Out-Null

        $i=1
        while ($i -lt $n) {
            $tag = $br.ReadByte()
            switch ($tag) {
                1  { $l=RU16; $cp.Add([System.Text.Encoding]::UTF8.GetString($br.ReadBytes($l))) | Out-Null }
                7  { $cp.Add([int](RU16)) | Out-Null }        # Class  -> name_index
                8  { $cp.Add($null) | Out-Null; $br.ReadBytes(2)|Out-Null }
                3  { $cp.Add($null) | Out-Null; $br.ReadBytes(4)|Out-Null }
                4  { $cp.Add($null) | Out-Null; $br.ReadBytes(4)|Out-Null }
                5  { $cp.Add($null)|Out-Null; $cp.Add($null)|Out-Null; $br.ReadBytes(8)|Out-Null; $i++ }
                6  { $cp.Add($null)|Out-Null; $cp.Add($null)|Out-Null; $br.ReadBytes(8)|Out-Null; $i++ }
                9  { $cp.Add($null)|Out-Null; $br.ReadBytes(4)|Out-Null }
                10 { $cp.Add($null)|Out-Null; $br.ReadBytes(4)|Out-Null }
                11 { $cp.Add($null)|Out-Null; $br.ReadBytes(4)|Out-Null }
                12 { $cp.Add($null)|Out-Null; $br.ReadBytes(4)|Out-Null }
                15 { $cp.Add($null)|Out-Null; $br.ReadBytes(3)|Out-Null }
                16 { $cp.Add($null)|Out-Null; $br.ReadBytes(2)|Out-Null }
                17 { $cp.Add($null)|Out-Null; $br.ReadBytes(4)|Out-Null }
                18 { $cp.Add($null)|Out-Null; $br.ReadBytes(4)|Out-Null }
                19 { $cp.Add($null)|Out-Null; $br.ReadBytes(2)|Out-Null }
                20 { $cp.Add($null)|Out-Null; $br.ReadBytes(2)|Out-Null }
                default { $br.Close(); $ms.Close(); return $out }
            }
            $i++
        }

        # Collect all UTF8 strings into pool
        $pool = [System.Collections.Generic.List[string]]::new()
        foreach ($e in $cp) { if ($e -is [string] -and $e.Length -gt 1) { $pool.Add($e) | Out-Null } }
        $out.Pool = $pool

        # Resolve class name by index
        function GN($idx) {
            if ($idx -le 0 -or $idx -ge $cp.Count) { return "" }
            $v = $cp[$idx]
            if ($v -is [int]) {
                $ni = $v
                if ($ni -gt 0 -and $ni -lt $cp.Count -and $cp[$ni] -is [string]) { return $cp[$ni] }
            }
            return ""
        }

        $br.ReadBytes(2)|Out-Null  # access flags
        $out.Name  = GN (RU16)
        $out.Super = GN (RU16)

        $ic = RU16; for($x=0;$x-lt $ic;$x++){$iname=GN(RU16);if($iname){$out.Ifaces+=$iname}}

        # Fields
        $fc = RU16
        for($x=0;$x-lt $fc;$x++){
            $br.ReadBytes(2)|Out-Null; $ni=RU16; $br.ReadBytes(2)|Out-Null; $ac=RU16
            if($ni -gt 0 -and $ni -lt $cp.Count -and $cp[$ni] -is [string]){$out.Fields+=$cp[$ni]}
            for($a=0;$a-lt $ac;$a++){$br.ReadBytes(2)|Out-Null;$al=RU32;$br.ReadBytes([int]$al)|Out-Null}
        }

        # Methods
        $mc = RU16
        for($x=0;$x-lt $mc;$x++){
            $br.ReadBytes(2)|Out-Null; $ni=RU16; $br.ReadBytes(2)|Out-Null; $ac=RU16
            if($ni -gt 0 -and $ni -lt $cp.Count -and $cp[$ni] -is [string]){$out.Methods+=$cp[$ni]}
            for($a=0;$a-lt $ac;$a++){$br.ReadBytes(2)|Out-Null;$al=RU32;$br.ReadBytes([int]$al)|Out-Null}
        }

        $out.OK = 1
        $br.Close(); $ms.Close()
    } catch { }
    return $out
}

# ═══════════════════════════════════════════════════════
#  CHECK CLASS  — exact whole-token matching only
# ═══════════════════════════════════════════════════════
function Check-Class {
    param($c, [string]$path)
    $hits = [System.Collections.Generic.List[string]]::new()

    # 1. Package-level check (file path prefix)
    foreach ($pkg in $EVIL_PKG) {
        if ($path.StartsWith($pkg)) { $hits.Add("[PKG] $($pkg.TrimEnd('/'))") | Out-Null }
    }

    # 2. Class / super name exact suffix match
    $cn = $c.Name;  $sn = $c.Super
    foreach ($tok in $EVIL_TOKENS) {
        # match class name ending with /TokenName  (e.g. "com/cheat/KillAura")
        if ($cn -eq $tok -or $cn.EndsWith("/$tok") -or $cn.EndsWith("\$tok")) {
            $hits.Add("[CLASS] $tok") | Out-Null
        }
        if ($sn -eq $tok -or $sn.EndsWith("/$tok") -or $sn.EndsWith("\$tok")) {
            $hits.Add("[SUPER] $tok") | Out-Null
        }
    }

    # 3. Method/Field name — exact whole token only
    $allTokens = $c.Methods + $c.Fields
    foreach ($tok in $EVIL_TOKENS) {
        if ($allTokens -contains $tok) { $hits.Add("[METHOD] $tok") | Out-Null }
    }

    # 4. String constants — exact match only
    foreach ($tok in $EVIL_TOKENS) {
        if ($c.Pool -contains $tok) { $hits.Add("[STRING] $tok") | Out-Null }
    }

    return @($hits | Select-Object -Unique)
}

# ═══════════════════════════════════════════════════════
#  READ ENTRY  (safe)
# ═══════════════════════════════════════════════════════
function Read-ZipEntry {
    param($e)
    try {
        $st=[System.IO.MemoryStream]::new()
        $es=$e.Open(); $es.CopyTo($st); $es.Close()
        return $st.ToArray()
    } catch { return $null }
}

# ═══════════════════════════════════════════════════════
#  SHA256
# ═══════════════════════════════════════════════════════
function SHA256File {
    param([string]$p)
    try {
        $sha=[System.Security.Cryptography.SHA256]::Create()
        $fs=[System.IO.File]::OpenRead($p)
        $h=[BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-',''
        $fs.Close(); return $h.ToLower()
    } catch { return "n/a" }
}

function FmtSize {
    param([long]$b)
    if($b-lt 1KB){return "$b B"}
    if($b-lt 1MB){return"{0:F1} KB"-f($b/1KB)}
    if($b-lt 1GB){return"{0:F1} MB"-f($b/1MB)}
    return"{0:F1} GB"-f($b/1GB)
}

# ═══════════════════════════════════════════════════════
#  DISPLAY HELPERS  (MeowMod-style)
# ═══════════════════════════════════════════════════════
function Banner {
    Clear-Host
    $c1="Cyan"; $c2="DarkCyan"
    Write-Host ""
    Write-Host "    _______ _______    _____ _______ _______  ___  ____  " -ForegroundColor $c1
    Write-Host "   |     __|     __|  |_   _|    |  |     __|/  _]|    \ " -ForegroundColor $c1
    Write-Host "   |__     |__     |    | | |       |__     |/  [_ |  _  |" -ForegroundColor $c1
    Write-Host "   |_______|_______|    |_| |__|____|_______|\_____||__|__]" -ForegroundColor $c1
    Write-Host ""
    Write-Host "        Minecraft SS Inspector  v3.2  -  PowerShell Edition" -ForegroundColor $c2
    Write-Host "   ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
}

function Divider { Write-Host "   ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray }

function Tag {
    param([string]$label,[string]$bg,[string]$fg="White")
    Write-Host "  " -NoNewline
    Write-Host " $label " -BackgroundColor $bg -ForegroundColor $fg -NoNewline
    Write-Host " " -NoNewline
}

# ═══════════════════════════════════════════════════════
#  SCAN ONE JAR  (returns object)
# ═══════════════════════════════════════════════════════
function Scan-Jar {
    param([string]$path)
    $fi = Get-Item $path -EA SilentlyContinue
    if (-not $fi) { return $null }

    $zip = $null
    try { $zip = [System.IO.Compression.ZipFile]::OpenRead($path) }
    catch { return $null }

    $classes  = @($zip.Entries | Where-Object { $_.FullName.EndsWith(".class") })
    $flagged  = [System.Collections.Generic.List[hashtable]]::new()
    $allHits  = [System.Collections.Generic.List[string]]::new()
    $sc=0; $tot=$classes.Count

    foreach ($e in $classes) {
        $sc++
        $raw = Read-ZipEntry $e
        if ($null -eq $raw) { continue }
        $c   = Parse-Class -raw $raw
        if (-not $c.OK) { continue }
        $hits = Check-Class -c $c -path $e.FullName
        if ($hits.Count -gt 0) {
            $flagged.Add(@{
                Path=$e.FullName; Name=$c.Name; Super=$c.Super
                Ifaces=$c.Ifaces; Methods=$c.Methods; Hits=$hits
            }) | Out-Null
            foreach ($h in $hits) { if (-not $allHits.Contains($h)) { $allHits.Add($h)|Out-Null } }
        }
    }
    try { $zip.Dispose() } catch {}

    return [PSCustomObject]@{
        File     = $fi.Name
        FullPath = $fi.FullName
        Size     = $fi.Length
        Hash     = SHA256File $fi.FullName
        Total    = $tot
        Flagged  = $flagged
        AllHits  = $allHits
        Clean    = ($flagged.Count -eq 0)
    }
}

# ═══════════════════════════════════════════════════════
#  SCAN FOLDER
# ═══════════════════════════════════════════════════════
function Scan-Folder {
    param([string]$folder)
    $jars = @(Get-ChildItem -Path $folder -Recurse -Filter "*.jar" -EA SilentlyContinue)
    if ($jars.Count -eq 0) { Write-Host "  No JAR files found." -ForegroundColor Yellow; return }

    Write-Host "  Path   : " -ForegroundColor DarkGray -NoNewline; Write-Host $folder -ForegroundColor Cyan
    Write-Host "  JARs   : " -ForegroundColor DarkGray -NoNewline; Write-Host $jars.Count -ForegroundColor White
    Divider; Write-Host ""

    $dirty=[System.Collections.Generic.List[object]]::new()
    $idx=0

    foreach ($jar in $jars) {
        $idx++
        Write-Host ("  [{0}/{1}] {2}" -f $idx,$jars.Count,$jar.Name) -ForegroundColor White

        $r = Scan-Jar -path $jar.FullName

        if ($null -eq $r) {
            Tag "ERROR" "DarkYellow" "Black"; Write-Host "could not read file" -ForegroundColor DarkYellow
            continue
        }

        if ($r.Clean) {
            Tag "CLEAN" "DarkGreen" "White"
            Write-Host ("$($r.Total) classes checked") -ForegroundColor DarkGray
        } else {
            Tag "FLAGGED" "DarkRed" "White"
            Write-Host ("$($r.Flagged.Count) hit(s)  —  ") -ForegroundColor Red -NoNewline
            Write-Host ($r.AllHits -join "  |  ") -ForegroundColor Yellow
            foreach ($fc in $r.Flagged) {
                Write-Host ("      >> {0}" -f $fc.Name) -ForegroundColor Red -NoNewline
                Write-Host ("  " + ($fc.Hits -join ", ")) -ForegroundColor DarkYellow
            }
            $dirty.Add($r) | Out-Null
        }
        Write-Host ""
    }

    # ── Summary ──────────────────────────────────────────────
    Divider
    Write-Host ""
    Write-Host "  SCAN COMPLETE" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("  Total    {0}" -f $jars.Count)     -ForegroundColor White
    Write-Host ("  Clean    {0}" -f ($jars.Count-$dirty.Count)) -ForegroundColor Green
    if ($dirty.Count -gt 0) {
        Write-Host ("  Flagged  {0}" -f $dirty.Count)  -ForegroundColor Red
        Write-Host ""
        Divider
        Write-Host ""
        foreach ($d in $dirty) {
            Write-Host ("  " + [char]0x2588 + " ") -ForegroundColor DarkRed -NoNewline
            Write-Host $d.File -ForegroundColor Red
            Write-Host ("    SHA256   " + $d.Hash) -ForegroundColor DarkGray
            Write-Host ("    Size     " + (FmtSize $d.Size)) -ForegroundColor DarkGray
            Write-Host ("    Hits     ") -ForegroundColor DarkGray -NoNewline
            Write-Host ($d.AllHits -join "  |  ") -ForegroundColor Yellow
            Write-Host ""
            foreach ($fc in $d.Flagged) {
                Write-Host ("    ┌ Class   : " + $fc.Name)  -ForegroundColor Red
                if ($fc.Super -and $fc.Super -ne "java/lang/Object") {
                    Write-Host ("    │ Extends : " + $fc.Super)  -ForegroundColor DarkRed
                }
                Write-Host ("    └ Flagged : ") -ForegroundColor DarkRed -NoNewline
                Write-Host ($fc.Hits -join "  |  ") -ForegroundColor Yellow
                Write-Host ""
            }
        }
        Write-Host ""
        Write-Host "  VERDICT" -ForegroundColor White -NoNewline
        Write-Host "  CHEATS DETECTED " -BackgroundColor DarkRed -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "  VERDICT" -ForegroundColor White -NoNewline
        Write-Host "  ALL CLEAN " -BackgroundColor DarkGreen -ForegroundColor White
    }
    Write-Host ""
}

# ═══════════════════════════════════════════════════════
#  SHOW CLASS LIST  (dump)
# ═══════════════════════════════════════════════════════
function Show-Classes {
    param([string]$path)
    $zip=$null
    try { $zip=[System.IO.Compression.ZipFile]::OpenRead($path) } catch { Write-Host "  Cannot open JAR." -ForegroundColor Red; return }
    $classes=@($zip.Entries|Where-Object{$_.FullName.EndsWith(".class")})
    Write-Host ("  Classes in: " + (Split-Path $path -Leaf)) -ForegroundColor Cyan
    Divider
    $i=0
    foreach ($e in $classes) {
        $i++
        $raw=Read-ZipEntry $e
        if ($null -eq $raw){continue}
        $c=Parse-Class -raw $raw
        if(-not $c.OK){continue}
        $name=$c.Name -replace '/','.'
        $extra=""
        if($c.Super -and $c.Super -ne "java/lang/Object"){$extra+=" extends "+($c.Super -replace '/','.')}
        if($c.Ifaces.Count-gt 0){$extra+=" implements "+($c.Ifaces -replace '/','.' -join ", ")}
        Write-Host ("  [{0,4}] {1}" -f $i,$name) -ForegroundColor Cyan -NoNewline
        if($extra){Write-Host $extra -ForegroundColor DarkGray} else {Write-Host ""}
    }
    $zip.Dispose()
    Divider
    Write-Host ("  Total: $i classes") -ForegroundColor DarkGray
}

# ═══════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════
Banner

Write-Host "  Enter path to mods folder or JAR file:" -ForegroundColor White
Write-Host "  (press Enter for default: $env:APPDATA\.minecraft\mods)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  PATH > " -ForegroundColor Cyan -NoNewline
$inp = Read-Host

if ([string]::IsNullOrWhiteSpace($inp)) {
    $inp = "$env:APPDATA\.minecraft\mods"
    Write-Host ""
    Write-Host "  Using: $inp" -ForegroundColor DarkGray
}

if (-not (Test-Path $inp)) {
    Write-Host "  Path not found: $inp" -ForegroundColor Red
    Read-Host "`n  Press Enter to exit"
    exit
}

Write-Host ""
$t = Get-Date

if (Test-Path $inp -PathType Leaf) {
    # Single JAR
    if ($inp.EndsWith(".jar")) {
        Write-Host "  [1] Scan for cheats" -ForegroundColor Cyan
        Write-Host "  [2] List all classes" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Choice [1]: " -ForegroundColor Yellow -NoNewline
        $m = Read-Host
        if ($m -eq "2") { Show-Classes -path $inp }
        else {
            $r = Scan-Jar -path $inp
            if ($null -eq $r){ Write-Host "  Cannot read JAR." -ForegroundColor Red }
            elseif ($r.Clean){ Tag "CLEAN" "DarkGreen" "White"; Write-Host "$($r.Total) classes — nothing found" }
            else {
                Tag "FLAGGED" "DarkRed" "White"
                Write-Host "$($r.Flagged.Count) suspicious class(es)" -ForegroundColor Red
                foreach ($fc in $r.Flagged){
                    Write-Host ("  >> "+$fc.Name) -ForegroundColor Red -NoNewline
                    Write-Host ("  "+($fc.Hits -join " | ")) -ForegroundColor Yellow
                }
            }
        }
    }
} else {
    # Folder — auto scan all
    Scan-Folder -folder $inp
}

$el=((Get-Date)-$t).TotalSeconds
Write-Host ""
Write-Host ("  Done in {0:F2}s" -f $el) -ForegroundColor DarkGray
Write-Host ""
Read-Host "  Press Enter to exit"
