#!/usr/bin/python3
# Builds the "Xbox Cloud Gaming" game list for Batocera.
# Source: the public Xbox Game Pass catalog (all cloud games, Germany, German
# names). Fallback: the title list that the program stores after signing in.
#   one file per game in /userdata/roms/xboxcloud/<Name>.xcloud  (content: xCloud title id)
#   cover images + gamelist.xml
# Usage: gamelist.py <rom dir> <result file>
import glob
import json
import os
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor, as_completed

ROMS = sys.argv[1] if len(sys.argv) > 1 else "/userdata/roms/xboxcloud"
RESULT = sys.argv[2] if len(sys.argv) > 2 else "/tmp/xcloud-result.txt"
IMAGES = os.path.join(ROMS, "images")
MARKET, LANG = "DE", "de-DE"
CLOUD_LIST = "29a81209-df6f-41fd-a528-2ae6b91f719c"      # Game Pass: all cloud games
CATALOG = os.environ.get("XCLOUD_CATALOG", "https://catalog.gamepass.com")
HEADERS = {"Content-Type": "application/json", "ms-cv": "0",
           "calling-app-name": "Xbox Cloud Gaming Web", "calling-app-version": "21.0.0",
           "User-Agent": "Mozilla/5.0"}


def bar(label, done, total, extra=""):
    total = max(total, 1)
    pct = int(done * 100 / total)
    filled = int(pct / 4)
    sys.stdout.write("\r  %-8s [%s%s] %3d%%  %s   " % (label, "#" * filled, "." * (25 - filled), pct, extra))
    sys.stdout.flush()


def http(url, data=None, timeout=30):
    req = urllib.request.Request(url, data=data, headers=HEADERS, method="POST" if data else "GET")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


# ---------------------------------------------------------------- sources
def from_catalog():
    print("  Step 1/3: loading the list of cloud games...")
    raw = json.loads(http("%s/sigls/v2?id=%s&market=%s&language=%s" % (CATALOG, CLOUD_LIST, MARKET, LANG)))
    ids = [x["id"] for x in raw if isinstance(x, dict) and x.get("id")]
    if not ids:
        raise RuntimeError("empty list")
    print("  %d games found" % len(ids))
    print("  Step 2/3: loading names and details (German)...")
    products, batches = {}, [ids[i:i + 100] for i in range(0, len(ids), 100)]
    for n, b in enumerate(batches, 1):
        bar("Details", n - 1, len(batches))
        data = json.loads(http("%s/v3/products?market=%s&language=%s&hydration=RemoteHighSapphire0"
                               % (CATALOG, MARKET, LANG), json.dumps({"Products": b}).encode(), 60))
        products.update(data.get("Products", {}) or {})
    bar("Details", len(batches), len(batches))
    print()
    return products


def from_program_cache():
    pats = ["/userdata/system/.config/*/config.json", "/userdata/system/configs/*/config.json",
            "/root/.config/*/config.json"]
    for pat in pats:
        for p in glob.glob(pat):
            if "reenlight" not in p.lower():
                continue
            try:
                data = json.load(open(p, encoding="utf-8"))
            except Exception:
                continue
            cache = data.get("xcloud_catalog_cache") if isinstance(data, dict) else None
            if isinstance(cache, dict) and cache:
                return cache
    return {}


def game_pass(p):
    off = p.get("XCloudOfferings")
    if not isinstance(off, dict) or not off:
        return True
    return any(k.upper().startswith("XGPU") for k in off)


def safe_name(name):
    name = re.sub(r'[\\/:*?"<>|]', " ", name)
    return re.sub(r"\s+", " ", name).strip().rstrip(".") or "Game"


def clean(name):
    return re.sub(r"\s+", " ", re.sub(r"[™®©]", "", name)).strip()


def image_url(p):
    img = p.get("Image_Poster") or p.get("Image_Tile") or {}
    url = img.get("URL") if isinstance(img, dict) else None
    if not url:
        return None
    if url.startswith("//"):
        url = "https:" + url
    return url + ("&" if "?" in url else "?") + "w=400"


def download(url, path):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=30) as r, open(path + ".tmp", "wb") as o:
            o.write(r.read())
        os.replace(path + ".tmp", path)
        return True
    except Exception:
        try:
            os.remove(path + ".tmp")
        except OSError:
            pass
        return False


# ---------------------------------------------------------------- main
def main():
    source, german = "catalog", 1
    try:
        products = from_catalog()
    except Exception as e:
        print("\n  Game Pass catalog not reachable (%s)." % e)
        print("  Using the list stored by the program (needs a sign in, English names)...")
        products, source, german = from_program_cache(), "program", 0
    if not products:
        open(RESULT, "w").write("STATUS=NOLIST\n")
        return 2

    games = {}
    for key, p in products.items():
        tid = (p or {}).get("XCloudTitleId")
        if tid and game_pass(p):
            games[tid] = p

    os.makedirs(IMAGES, exist_ok=True)
    print("  Step 3/3: covers")
    todo = []
    for tid, g in games.items():
        url, img = image_url(g), os.path.join(IMAGES, tid + ".jpg")
        if url and not os.path.exists(img):
            todo.append((url, img))
    done = 0
    if todo:
        bar("Covers", 0, len(todo), "0/%d" % len(todo))
        with ThreadPoolExecutor(max_workers=8) as ex:
            futs = [ex.submit(download, u, p) for u, p in todo]
            for f in as_completed(futs):
                done += 1
                bar("Covers", done, len(todo), "%d/%d" % (done, len(todo)))
    else:
        bar("Covers", 1, 1, "already there")
    print()

    # entries
    for f in glob.glob(os.path.join(ROMS, "*.xcloud")):
        os.remove(f)
    root = ET.Element("gameList")
    used = set()
    for tid, g in sorted(games.items(), key=lambda x: clean(x[1].get("ProductTitle") or x[0]).lower()):
        name = clean(g.get("ProductTitle") or tid)
        fname = base = safe_name(name)
        n = 2
        while fname.lower() in used:
            fname = "%s (%d)" % (base, n); n += 1
        used.add(fname.lower())
        with open(os.path.join(ROMS, fname + ".xcloud"), "w") as f:
            f.write(tid + "\n")
        game = ET.SubElement(root, "game")
        ET.SubElement(game, "path").text = "./" + fname + ".xcloud"
        ET.SubElement(game, "name").text = name
        if os.path.exists(os.path.join(IMAGES, tid + ".jpg")):
            ET.SubElement(game, "image").text = "./images/" + tid + ".jpg"
            ET.SubElement(game, "thumbnail").text = "./images/" + tid + ".jpg"
        desc = g.get("ProductDescriptionShort") or g.get("ProductDescription")
        if isinstance(desc, str) and desc:
            ET.SubElement(game, "desc").text = desc
        for tag, key in (("publisher", "PublisherName"), ("developer", "DeveloperName")):
            if g.get(key):
                ET.SubElement(game, tag).text = g[key]
        cats = g.get("LocalizedCategories") or g.get("Categories")
        if isinstance(cats, list) and cats:
            ET.SubElement(game, "genre").text = ", ".join(str(c) for c in cats[:2])
    ET.ElementTree(root).write(os.path.join(ROMS, "gamelist.xml"), encoding="utf-8", xml_declaration=True)

    open(RESULT, "w").write("STATUS=OK\nGAMES=%d\nGERMAN=%d\nSOURCE=%s\n" % (len(games), german, source))
    return 0


if __name__ == "__main__":
    sys.exit(main())
