#!/usr/bin/env python3
import os,sys,zipfile,struct,hashlib,time
from pathlib import Path

R="\033[91m";G="\033[92m";Y="\033[93m";C="\033[96m"
W="\033[97m";DG="\033[90m";M="\033[95m";RE="\033[0m";B="\033[1m"
def red(s):  return f"{R}{s}{RE}"
def grn(s):  return f"{G}{s}{RE}"
def yel(s):  return f"{Y}{s}{RE}"
def cyn(s):  return f"{C}{s}{RE}"
def mag(s):  return f"{M}{s}{RE}"
def gray(s): return f"{DG}{s}{RE}"
def bold(s): return f"{B}{s}{RE}"
def tag_ok():  return f"{B}\033[42m\033[30m CLEAN   {RE}"
def tag_bad(): return f"{B}\033[41m FLAGGED {RE}"
def tag_err(): return f"{B}\033[43m\033[30m ERROR   {RE}"

# ── Package prefixes of known cheat clients ───────────────────────────────────
EVIL_PKG = [
    "me/wurst/","net/wurstclient/","me/zero/client/","com/impact/mod/",
    "dev/liquidbounce/","net/ccbluex/","com/meteorclient/","meteordevelopment/",
    "me/sigma/","com/rise/client/","com/inertia/","com/vape/client/",
    "com/future/client/","com/aristois/","com/novoline/",
]

# ── Exact class/method/field names ────────────────────────────────────────────
EVIL_EXACT = {
    "KillAura","KillAuraModule","TriggerBot","TriggerBotModule","TriggerKey",
    "AimBot","AimBotModule","SilentAim","AimAssistModule","AutoClicker",
    "AutoClickModule","ForceAttack","ForceField","ForceFieldModule","MultiAura",
    "CritSpam","BHop","BunnyHop","NoFall","NoFallModule","NoClip","NoClipModule",
    "AntiKnockback","AntiKB","VelocityModule","FlyHack","FlyModule","SpeedHack",
    "ScaffoldModule","TowerHack","PhaseModule","WallHack","XRayModule","XRay",
    "PlayerESP","EntityESP","ChestESP","ChamsModule","HitboxESP","PacketFly",
    "ReachModule","TimerModule","PingSpoof","NukerModule","AutoMine","AutoFarm",
    "AutoFish","ChestStealer","WurstClient","LiquidBounce","MeteorClient",
    "ImpactClient","AristoisClient","WolframClient","FutureClient","SigmaClient",
    "Backdoor","KeyLogger","TokenStealer","DiscordStealer","RatClient",
}

# ── String keywords — searched inside ALL constant pool strings ───────────────
# These catch obfuscated clients where class names are randomized
EVIL_STR_EXACT = [
    # Client names (exact, case-insensitive)
    "novaclient","nova client","novacliеnt",
    "wurst","liquidbounce","meteorclient","impactclient",
    "aristois","wolframclient","futureclient","sigmaclient",
    "riseclient","novoline","vapeclient","hyperion",
    # Cheat modules as strings (exact)
    "killaura","kill aura","kill_aura",
    "triggerbot","trigger bot","trigger_bot",
    "aimbot","aim bot","aim_bot",
    "silentaim","silent aim",
    "forcefield","force field",
    "multiaura","multi aura",
    "wallhack","wall hack","xrayhack","xray hack",
    "playeresp","player esp","entityesp","entity esp",
    "cheststealer","chest stealer",
    "bhop","bunny hop","bunnyhop",
    "nofall","no fall","noclip","no clip",
    "antiknockback","anti knockback","antikb",
    "velocityhack","velocity hack",
    "flyhack","fly hack","speedhack","speed hack",
    "scaffoldmod","scaffold",
    "chamsmod","hitboxesp","hitbox esp",
    "packetfly","packet fly",
    "pingspoof","ping spoof",
    "nukermod","autofarm","autofish",
    "backdoor","keylogger","tokenstealer","discordstealer",
    "autoclick","auto click","critspam","crit spam",
    "aimassist","aim assist","anti-aim","antiaim",
    # Webhook / authorization strings (definitive proof)
    "authorized user launched",
    "unauthorized user tried",
    "webhook",
    "discord.com/api/webhooks",
    "token_stealer",
    "password_stealer",
]

def parse_class(data):
    if len(data)<10 or data[:4]!=b'\xca\xfe\xba\xbe': return None
    r={'name':'','super':'','ifaces':[],'methods':[],'fields':[],'strings':[]}
    pos=8
    try:
        n=struct.unpack_from('>H',data,pos)[0];pos+=2
        cp=[None]*n
        i=1
        while i<n:
            tag=data[pos];pos+=1
            if tag==1:
                ln=struct.unpack_from('>H',data,pos)[0];pos+=2
                s=data[pos:pos+ln].decode('utf-8',errors='replace')
                cp[i]=('u',s);pos+=ln
            elif tag==7: cp[i]=('c',struct.unpack_from('>H',data,pos)[0]);pos+=2
            elif tag==8: cp[i]=('s',struct.unpack_from('>H',data,pos)[0]);pos+=2
            elif tag in(9,10,11,12):pos+=4
            elif tag in(3,4):pos+=4
            elif tag in(5,6):pos+=8;cp[i+1]=None;i+=1
            elif tag==15:pos+=3
            elif tag in(16,19,20):pos+=2
            elif tag in(17,18):pos+=4
            else: return None
            i+=1
        # ALL strings from constant pool
        r['strings']=[e[1] for e in cp if e and e[0]=='u' and len(e[1])>1]
        def gn(idx):
            if idx and 0<idx<n and cp[idx] and cp[idx][0]=='c':
                ni=cp[idx][1]
                if ni and 0<ni<n and cp[ni] and cp[ni][0]=='u': return cp[ni][1]
            return ''
        pos+=2
        r['name']=gn(struct.unpack_from('>H',data,pos)[0]);pos+=2
        r['super']=gn(struct.unpack_from('>H',data,pos)[0]);pos+=2
        ic=struct.unpack_from('>H',data,pos)[0];pos+=2
        for _ in range(ic):
            r['ifaces'].append(gn(struct.unpack_from('>H',data,pos)[0]));pos+=2
        def skip(pos,out):
            c=struct.unpack_from('>H',data,pos)[0];pos+=2
            for _ in range(c):
                pos+=2;ni=struct.unpack_from('>H',data,pos)[0];pos+=2;pos+=2
                ac=struct.unpack_from('>H',data,pos)[0];pos+=2
                if ni and 0<ni<n and cp[ni] and cp[ni][0]=='u':out.append(cp[ni][1])
                for _ in range(ac):pos+=2;al=struct.unpack_from('>I',data,pos)[0];pos+=4+al
            return pos
        pos=skip(pos,r['fields'])
        pos=skip(pos,r['methods'])
    except:pass
    return r

def check(info, fpath):
    hits=[]
    # 1. Package
    for pkg in EVIL_PKG:
        if fpath.startswith(pkg):
            hits.append(f"[PKG]    {pkg.rstrip('/')}")
    # 2. Exact class/super
    cn=info['name'];sn=info['super']
    for tok in EVIL_EXACT:
        if cn==tok or cn.endswith('/'+tok):
            hits.append(f"[CLASS]  {tok}")
        if sn and(sn==tok or sn.endswith('/'+tok)):
            hits.append(f"[SUPER]  {tok}")
    # 3. Exact method/field
    for tok in EVIL_EXACT:
        if tok in info['methods']:hits.append(f"[METHOD] {tok}")
        if tok in info['fields']: hits.append(f"[FIELD]  {tok}")
    # 4. String search — catches obfuscated clients!
    all_strings_joined = '\n'.join(info['strings'])
    all_low = all_strings_joined.lower()
    for kw in EVIL_STR_EXACT:
        if kw.lower() in all_low:
            match = next((s for s in info['strings'] if kw.lower() in s.lower()), '')
            hits.append(f"[STRING] {kw}  ← \"{match[:60]}\"")
    return list(dict.fromkeys(hits))

def sha256(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for chunk in iter(lambda:f.read(65536),b''):h.update(chunk)
    return h.hexdigest()

def fmtsize(b):
    for u in['B','KB','MB','GB']:
        if b<1024:return f"{b:.1f} {u}"
        b/=1024
    return f"{b:.1f} GB"

def div(): print(gray("  "+"─"*58))

def banner():
    os.system('cls'if os.name=='nt'else'clear')
    print()
    print(cyn(bold("  ╔══════════════════════════════════════════════╗")))
    print(cyn(bold("  ║  ███████╗███████╗  ████████╗ ██████╗  ██╗  ║")))
    print(cyn(bold("  ║  ██╔════╝██╔════╝     ██╔══╝██╔═══██╗ ██║  ║")))
    print(cyn(bold("  ║  ███████╗███████╗     ██║   ██║   ██║ ██║  ║")))
    print(cyn(bold("  ║  ╚════██║╚════██║     ██║   ██║   ██║ ██║  ║")))
    print(cyn(bold("  ║  ███████║███████║     ██║   ╚██████╔╝ ███████╗║")))
    print(cyn(bold("  ║  ╚══════╝╚══════╝     ╚═╝    ╚═════╝  ╚══════╝║")))
    print(cyn(bold("  ║                                                ║")))
    print(cyn(bold("  ║   Minecraft SS Inspector v4.1  |  ss-tool     ║")))
    print(cyn(bold("  ╚══════════════════════════════════════════════╝")))
    print()

def scan_jar(path, silent=False):
    fi=Path(path)
    if not fi.exists(): return None
    try: zf=zipfile.ZipFile(path,'r')
    except: return None
    classes=[e for e in zf.namelist() if e.endswith('.class')]
    flagged=[];all_hits=[];total=len(classes);sc=0
    for entry in classes:
        sc+=1
        if not silent and(sc%200==0 or sc==total):
            pct=int(sc/total*100)if total else 100
            bar='█'*(pct//5)+'░'*(20-pct//5)
            print(f"\r  [{bar}] {pct}% ({sc}/{total})",end='',flush=True)
        try:
            data=zf.read(entry)
            info=parse_class(data)
            if not info: continue
            hits=check(info,entry)
            if hits:
                flagged.append({
                    'path':entry,'name':info['name'],'super':info['super'],
                    'ifaces':info['ifaces'],'methods':info['methods'],
                    'fields':info['fields'],'strings':info['strings'],'hits':hits
                })
                for h in hits:
                    if h not in all_hits: all_hits.append(h)
        except: continue
    if not silent: print()
    zf.close()
    return{'file':fi.name,'path':str(fi),'size':fi.stat().st_size,
           'hash':sha256(path),'total':total,'flagged':flagged,
           'all_hits':all_hits,'clean':len(flagged)==0}

# Map keyword -> clean label
KW_LABELS = {
    'killaura':'KillAura', 'kill aura':'KillAura',
    'triggerbot':'TriggerBot', 'trigger bot':'TriggerBot',
    'aimbot':'AimBot', 'aim bot':'AimBot',
    'silentaim':'SilentAim', 'silent aim':'SilentAim',
    'aimassist':'AimAssist', 'aim assist':'AimAssist',
    'anti-aim':'AntiAim', 'antiaim':'AntiAim',
    'forcefield':'ForceField', 'force field':'ForceField',
    'multiaura':'MultiAura', 'multi aura':'MultiAura',
    'bhop':'BHop', 'bunnyhop':'BunnyHop', 'bunny hop':'BunnyHop',
    'nofall':'NoFall', 'no fall':'NoFall',
    'noclip':'NoClip', 'no clip':'NoClip',
    'antiknockback':'AntiKnockback', 'antikb':'AntiKB',
    'velocityhack':'VelocityHack', 'velocity hack':'VelocityHack',
    'flyhack':'FlyHack', 'fly hack':'FlyHack',
    'speedhack':'SpeedHack', 'speed hack':'SpeedHack',
    'scaffold':'Scaffold',
    'wallhack':'WallHack', 'wall hack':'WallHack',
    'xrayhack':'XRay', 'xray hack':'XRay',
    'playeresp':'PlayerESP', 'player esp':'PlayerESP',
    'entityesp':'EntityESP', 'entity esp':'EntityESP',
    'hitboxesp':'HitboxESP', 'hitbox esp':'HitboxESP', 'hitbox':'HitboxESP',
    'chamsmod':'Chams', 'chams':'Chams',
    'cheststealer':'ChestStealer', 'chest stealer':'ChestStealer',
    'packetfly':'PacketFly', 'packet fly':'PacketFly',
    'reachmod':'Reach', 'reach mod':'Reach',
    'pingspoof':'PingSpoof', 'ping spoof':'PingSpoof',
    'nukermod':'Nuker', 'nuker':'Nuker',
    'autofarm':'AutoFarm', 'auto farm':'AutoFarm',
    'autofish':'AutoFish', 'autoclick':'AutoClick', 'auto click':'AutoClick',
    'autosteal':'AutoSteal', 'critspam':'CritSpam',
    'novaclient':'NovaClient', 'nova client':'NovaClient',
    'wurst':'Wurst', 'liquidbounce':'LiquidBounce',
    'meteorclient':'MeteorClient', 'impactclient':'ImpactClient',
    'aristois':'Aristois', 'futureclient':'FutureClient',
    'sigmaclient':'SigmaClient', 'novoline':'Novoline',
    'vapeclient':'Vape', 'wolframclient':'Wolfram',
    'backdoor':'Backdoor', 'keylogger':'KeyLogger',
    'tokenstealer':'TokenStealer', 'discordstealer':'DiscordStealer',
    'webhook':'Webhook', 'stealer':'Stealer',
    'authorized':'NovaClient', 'unauthorized':'NovaClient',
    'bypass':'Bypass', 'cheat':'Cheat',
}

def print_class(fc, indent="  "):
    name = fc['name'].replace('/','.')
    supr = fc['super'].replace('/','.')
    print(f"{indent}{red('┌')} {bold(red(name))}")
    if supr and supr not in('java.lang.Object',''):
        print(f"{indent}{red('│')} {red('extends   ')} {red(supr)}")

    # ── Useful strings only ──────────────────────────────────────────────────
    SKIP = {
        '<init>','<clinit>','Code','LineNumberTable','SourceFile','Exceptions',
        'ConstantValue','Signature','StackMapTable','LocalVariableTable',
        'BootstrapMethods','InnerClasses','EnclosingMethod','NestHost',
        'NestMembers','AnnotationDefault','MethodParameters','Record',
        'RuntimeVisibleAnnotations','RuntimeInvisibleAnnotations',
        'RuntimeVisibleTypeAnnotations','RuntimeInvisibleTypeAnnotations',
        'PermittedSubclasses','LocalVariableTypeTable','addAll','forEach',
        'values','clone','accept','stream','filter','collect','toList',
        'append','toString','equals','hashCode','getClass','valueOf',
        'length','charAt','indexOf','isEmpty','contains','substring',
        'println','format','replace','split','strip','toLowerCase',
        'parseInt','doubleValue','intValue','booleanValue','ordinal',
        'iterator','hasNext','remove','size','get','put','add','clear',
    }
    SKIP_PREFIXES = (
        '(',   # descriptors
        '[',   # array descriptors  
        'Ljava/','Lnet/minecraft/','Lorg/','Lcom/google/',
        'java/lang/','java/util/','java/io/',
        'net/minecraft/','org/slf4j/',
        'field_','method_','comp_',   # mapped names = not useful
        'lambda$',
    )

    strs = []
    seen = set()
    for s in fc['strings']:
        if len(s) < 3: continue
        if s in SKIP: continue
        if s in seen: continue
        skip = False
        for p in SKIP_PREFIXES:
            if s.startswith(p): skip=True; break
        if skip: continue
        # Skip pure technical strings
        if s.isdigit(): continue
        if len(s) == 1: continue
        seen.add(s)
        strs.append(s)

    found_labels = set()
    # Extract from strings
    for s in strs:
        sl = s.lower()
        for kw, label in KW_LABELS.items():
            if kw in sl:
                found_labels.add(label)
    # Extract from hits (e.g. [STRING] anti-aim)
    for h in fc['hits']:
        hl = h.lower()
        for kw, label in KW_LABELS.items():
            if kw in hl:
                found_labels.add(label)
    if found_labels:
        print(f"{indent}{red('│')} {bold(red('Found:'))}")
        for label in sorted(found_labels):
            print(f"{indent}{red('│')}   {red('▶')} {bold(red(label))}")

    print(f"{indent}{red('└'+'─'*50)}")

def scan_folder(folder):
    jars=list(Path(folder).rglob("*.jar"))
    if not jars: print(yel("  No JAR files found.")); return
    print(f"  {gray('Path  :')} {cyn(folder)}")
    print(f"  {gray('JARs  :')} {W}{len(jars)}{RE}")
    div(); print()
    dirty=[]
    for idx,jar in enumerate(jars,1):
        print(f"  [{gray(str(idx)+'/'+str(len(jars)))}] {W}{jar.name}{RE}")
        r=scan_jar(str(jar),silent=True)
        if r is None:
            print(f"  {tag_err()} {yel('could not read')}")
        elif r['clean']:
            pass  # silent
        else:
            # Collect all labels from all flagged classes
            all_labels = set()
            for fc in r['flagged']:
                for s in fc['strings']:
                    sl = s.lower()
                    for kw, label in KW_LABELS.items():
                        if kw in sl:
                            all_labels.add(label)
                for h in fc['hits']:
                    hl = h.lower()
                    for kw, label in KW_LABELS.items():
                        if kw in hl:
                            all_labels.add(label)
            name = r['flagged'][0]['name'] if r['flagged'] else ''
            print(f"  {tag_bad()}")
            print(f"  {red('┌')} {bold(red(name))}")
            print(f"  {red('│')} {bold(red('Found:'))}")
            for label in sorted(all_labels):
                print(f"  {red('│')}   {red('▶')} {bold(red(label))}")
            print(f"  {red('└'+'─'*50)}")
            dirty.append(r)
        print()
    div(); print()
    print(f"  {bold('SUMMARY')}")
    print()
    print(f"  Total    {W}{len(jars)}{RE}")
    print(f"  Clean    {grn(str(len(jars)-len(dirty)))}")
    if dirty:
        print(f"  Flagged  {red(str(len(dirty)))}")
        print()
        div(); print()
        for d in dirty:
            print(f"  {red(bold('⚠ '+d['file']))}")
            print(f"  {gray('SHA256 : '+d['hash'])}")
            print(f"  {gray('Size   : '+fmtsize(d['size']))}")
            print()
        print(f"\n  {bold(red('VERDICT'))}  \033[41m{bold(' ⚠  CHEATS DETECTED ')}{RE}")
    else:
        print(f"  Flagged  {grn('0')}")
    print()

def list_classes(path):
    try: zf=zipfile.ZipFile(path,'r')
    except: print(red("  Cannot open JAR.")); return
    classes=[e for e in zf.namelist() if e.endswith('.class')]
    print(f"\n  {cyn(Path(path).name)}  {gray(str(len(classes))+' classes')}")
    div(); print()
    for idx,entry in enumerate(classes,1):
        try:
            data=zf.read(entry)
            info=parse_class(data)
            if not info: continue
            name=info['name'].replace('/','.')
            supr=info['super'].replace('/','.')
            print(f"  {gray('['+str(idx).rjust(4)+']')} {cyn(name)}")
            if supr and supr!='java.lang.Object':
                print(f"         {gray('extends   ')} {DG}{supr}{RE}")
            if info['ifaces']:
                print(f"         {gray('implements')} {DG}{','.join(i.replace('/','.')for i in info['ifaces'])}{RE}")
            methods=[m for m in info['methods'] if not m.startswith('<')]
            if methods: print(f"         {gray('methods   ')} {yel(', '.join(methods[:10]))}")
            strs=[s for s in info['strings']
                  if len(s)>2 and not s.startswith('(') and not s.startswith('[')
                  and s not in('<init>','<clinit>','Code','LineNumberTable','SourceFile','Signature')]
            if strs:
                print(f"         {gray('strings   ')}",end='')
                for s in strs[:10]: print(f"{mag(repr(s))} ",end='')
                if len(strs)>10: print(gray(f"+{len(strs)-10}"),end='')
                print()
            print()
        except: continue
    zf.close(); div()

def main():
    banner()
    appdata=os.environ.get('APPDATA','')
    # Check ModrinthApp first
    modrinth=os.path.join(appdata,'ModrinthApp','profiles')
    default=os.path.join(appdata,'.minecraft','mods')
    if os.path.exists(modrinth):
        print(f"  {gray('ModrinthApp detected:')} {cyn(modrinth)}")
    print(f"  {W}Path to mods folder or single JAR:{RE}")
    print(f"  {gray('(Enter = '+default+')')}")
    print()
    try: inp=input(f"  {C}PATH > {RE}").strip()
    except(EOFError,KeyboardInterrupt): print(); return
    if not inp: inp=default; print(f"  {gray('Using: '+inp)}")
    if not os.path.exists(inp): print(red(f"  Not found: {inp}")); return
    print(); t=time.time()
    if os.path.isdir(inp):
        scan_folder(inp)
    else:
        print(f"  {C}[1]{RE} Scan for cheats")
        print(f"  {C}[2]{RE} List all classes + strings")
        print()
        try: m=input(f"  {Y}Choice [1]: {RE}").strip() or '1'
        except(EOFError,KeyboardInterrupt): print(); return
        print()
        if m=='2': list_classes(inp)
        else:
            r=scan_jar(inp)
            if not r: print(red("  Cannot read JAR."))
            elif r['clean']:
                print(f"\n  {grn('No cheats found.')} {gray(str(r['total'])+' classes scanned.')}")
            else:
                all_labels = set()
                for fc in r['flagged']:
                    for s in fc['strings']:
                        sl = s.lower()
                        for kw, label in KW_LABELS.items():
                            if kw in sl: all_labels.add(label)
                    for h in fc['hits']:
                        hl = h.lower()
                        for kw, label in KW_LABELS.items():
                            if kw in hl: all_labels.add(label)
                name = r['flagged'][0]['name'] if r['flagged'] else ''
                print(f"\n  {tag_bad()}")
                print(f"  {red('┌')} {bold(red(name))}")
                print(f"  {red('│')} {bold(red('Found:'))}")
                for label in sorted(all_labels):
                    print(f"  {red('│')}   {red('▶')} {bold(red(label))}")
                print(f"  {red('└'+'─'*50)}")
    print()
    print(gray(f"  Done in {time.time()-t:.2f}s"))
    print()
    try: input(gray("  Press Enter to exit..."))
    except: pass

if __name__=='__main__':
    main()
