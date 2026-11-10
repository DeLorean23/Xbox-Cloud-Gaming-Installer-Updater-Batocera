#!/bin/bash
# Builds both installers and their ZIPs into dist/
#   dist/Xbox Cloud Gaming Installer & Updater (German).zip   game list from the German store
#   dist/Xbox Cloud Gaming Installer & Updater (English).zip  game list from the US store
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="$ROOT/dist"
NAME="Xbox Cloud Gaming Installer & Updater"

rm -rf "$DIST"
mkdir -p "$DIST"

# build_variant <de|en> <installer name> <zip name> <cover>
build_variant() {
    local lang="$1" inst="$2" zipname="$3" cover="$4"
    local STAGE="$DIST/stage-$lang"
    mkdir -p "$STAGE/roms/ports/images"
    python3 - "$ROOT" "$STAGE/roms/ports/$inst.sh" "$lang" "$cover" <<'PY'
import base64, sys
root, out, lang, cover = sys.argv[1:5]
src, assets = root + "/src/", root + "/assets/"

def rep(text, old, new):
    assert old in text, old
    return text.replace(old, new)

def b64data(data):
    return base64.encodebytes(data).decode().rstrip("\n")

banner = open(src + "banner.txt").read().rstrip("\n")
gamelist = open(src + "gamelist.py").read()
t = open(src + "installer.template.sh").read()

if lang == "en":
    # game list from the US store: English names, descriptions and covers
    gamelist = rep(gamelist, 'MARKET, LANG = "DE", "de-DE"', 'MARKET, LANG = "US", "en-US"')
    gamelist = rep(gamelist, "(all cloud games, Germany, German\n# names)",
                   "(all cloud games, USA, English\n# names)")
    # own cover folder, so covers of the German list are not reused
    gamelist = rep(gamelist, 'IMAGES = os.path.join(ROMS, "images")', 'IMAGES = os.path.join(ROMS, "images-en")')
    gamelist = gamelist.replace('"./images/"', '"./images-en/"')
    gamelist = rep(gamelist, "loading names and details (German)...",
                   "loading names and details (English, US store)...")
    banner = rep(banner, "             Xbox Cloud Gaming Installer & Updater\n",
                 "        Xbox Cloud Gaming Installer & Updater (English)\n"
                 "     Game list in English: names, descriptions and covers\n")
    t = rep(t, "# Xbox Cloud Gaming Installer & Updater for Batocera",
            "# Xbox Cloud Gaming Installer & Updater (English) for Batocera\n"
            "# Game list in English: names, descriptions and covers from the US store")
    t = rep(t, '-T "Xbox Cloud Gaming Installer & Updater"',
            '-T "Xbox Cloud Gaming Installer & Updater (English)"')
    t = rep(t, 'echo "Building the game list (German names and covers)..."',
            'echo "Building the game list (English names, descriptions and covers - US store)..."')
    t = rep(t, "        grep -q '^GERMAN=1' \"$res\" || echo \"  (German names were not available, English names used)\"\n", "")

for key, val in {
    "@@BANNER@@":    banner,
    "@@HELPERS@@":   open(src + "helpers.sh").read().rstrip("\n"),
    "@@POSTER@@":    b64data(open(assets + cover, "rb").read()),
    "@@LOGO@@":      b64data(open(assets + "logo.png", "rb").read()),
    "@@GAMELIST@@":  b64data(gamelist.encode()),
    "@@HOTKEY@@":    b64data(open(src + "hotkey.py", "rb").read()),
    "@@THEMELOGO@@": b64data(open(src + "themelogo.py", "rb").read()),
}.items():
    assert key in t, key
    t = t.replace(key, val)
assert "@@" not in t
open(out, "w", newline="\n").write(t)
PY
    chmod +x "$STAGE/roms/ports/$inst.sh"
    bash -n "$STAGE/roms/ports/$inst.sh"
    cp "$ROOT/assets/$cover" "$STAGE/roms/ports/images/$inst.jpg"
    cp "$ROOT/README.md" "$STAGE/README.txt"
    cp "$ROOT/LIESMICH.md" "$STAGE/LIESMICH.txt"
    (cd "$STAGE" && zip -qr "$DIST/$zipname.zip" README.txt LIESMICH.txt roms)
    cp "$STAGE/roms/ports/$inst.sh" "$DIST/"
    rm -rf "$STAGE"
    echo "built: dist/$zipname.zip"
}

# German: same installer name as always (an existing installation just keeps working)
build_variant de "$NAME" "$NAME (German)" cover.jpg
build_variant en "$NAME (English)" "$NAME (English)" cover-en.jpg
