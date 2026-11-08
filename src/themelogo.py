import os, re, sys, shutil
logo, key = sys.argv[1], sys.argv[2]
roots = ["/usr/share/emulationstation/themes", "/etc/emulationstation/themes", "/userdata/themes"]
pat = re.compile(r'([^"\'<>\s]*\$\{system\.theme\}[^"\'<>\s]*\.png)', re.I)
themes = {}
for root in roots:
    if not os.path.isdir(root):
        continue
    for name in sorted(os.listdir(root)):
        tdir = os.path.join(root, name)
        if os.path.isdir(tdir) and name not in themes:
            themes[name] = tdir
lines = []
for name, tdir in sorted(themes.items(), key=lambda x: x[0].lower()):
    targets = set()
    for dp, dn, fn in os.walk(tdir):
        for f in fn:
            if not f.lower().endswith(".xml"):
                continue
            fp = os.path.join(dp, f)
            try:
                if os.path.getsize(fp) > 2000000:
                    continue
                text = open(fp, encoding="utf-8", errors="ignore").read()
            except OSError:
                continue
            for m in pat.findall(text):
                if "logo" not in m.lower():
                    continue
                m = m.replace("${themePath}", tdir)
                if m.replace("${system.theme}", "").count("${") or "*" in m:
                    continue
                p = m.replace("${system.theme}", key)
                if p.startswith("~/"):
                    p = "/userdata/system/" + p[2:]
                elif not p.startswith("/"):
                    p = os.path.normpath(os.path.join(dp, p))
                p = os.path.normpath(p)
                if p.startswith("/userdata/"):
                    targets.add(p)
    ok = False
    for t in sorted(targets):
        try:
            os.makedirs(os.path.dirname(t), exist_ok=True)
            shutil.copyfile(logo, t)
            ok = True
        except OSError:
            pass
    lines.append(("  [ok]   " if ok else "  [--]   ") + name)
print("\n".join(lines))
