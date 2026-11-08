#!/bin/bash
# Builds the ready-to-use installer and its ZIP into dist/
#   dist/Xbox Cloud Gaming Installer & Updater.zip
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="$ROOT/dist"
NAME="Xbox Cloud Gaming Installer & Updater"

rm -rf "$DIST"
STAGE="$DIST/stage"
mkdir -p "$STAGE/roms/ports/images"
python3 - "$ROOT" "$STAGE/roms/ports/$NAME.sh" <<'PY'
import base64, sys
root, out = sys.argv[1:3]
src, assets = root + "/src/", root + "/assets/"
def b64(p):
    return base64.encodebytes(open(p, "rb").read()).decode().rstrip("\n")
t = open(src + "installer.template.sh").read()
for key, val in {
    "@@BANNER@@":    open(src + "banner.txt").read().rstrip("\n"),
    "@@HELPERS@@":   open(src + "helpers.sh").read().rstrip("\n"),
    "@@POSTER@@":    b64(assets + "cover.jpg"),
    "@@LOGO@@":      b64(assets + "logo.png"),
    "@@GAMELIST@@":  b64(src + "gamelist.py"),
    "@@HOTKEY@@":    b64(src + "hotkey.py"),
    "@@THEMELOGO@@": b64(src + "themelogo.py"),
}.items():
    assert key in t, key
    t = t.replace(key, val)
assert "@@" not in t
open(out, "w", newline="\n").write(t)
PY
chmod +x "$STAGE/roms/ports/$NAME.sh"
bash -n "$STAGE/roms/ports/$NAME.sh"
cp "$ROOT/assets/cover.jpg" "$STAGE/roms/ports/images/$NAME.jpg"
cp "$ROOT/README.md" "$STAGE/README.txt"
cp "$ROOT/LIESMICH.md" "$STAGE/LIESMICH.txt"
(cd "$STAGE" && zip -qr "$DIST/$NAME.zip" README.txt LIESMICH.txt roms)
cp "$STAGE/roms/ports/$NAME.sh" "$DIST/"
rm -rf "$STAGE"
echo "built: dist/$NAME.zip"
