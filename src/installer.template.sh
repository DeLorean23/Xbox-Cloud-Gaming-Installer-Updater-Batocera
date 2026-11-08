#!/bin/bash
# Xbox Cloud Gaming Installer & Updater for Batocera
# Adds the system "Xbox Cloud Gaming": every cloud game is its own entry and
# starts straight into the stream. Runs on the open-source client Greenlight
# (https://github.com/unknownskl/greenlight). Needs Game Pass Ultimate.
# Created by DeLorean23

set -uo pipefail

REPO="unknownskl/greenlight"
API_URL="https://api.github.com/repos/${REPO}/releases?per_page=10"

BASE=/userdata/system/xboxcloud
APP="$BASE/XboxCloudGaming.AppImage"
BACKUP="$BASE/backup"
TMP="$BASE/tmp"
VERSION_FILE="$BASE/version.txt"
ROM_DIR=/userdata/roms/xboxcloud
ES_CFG=/userdata/system/configs/emulationstation/es_systems_xboxcloud.cfg
DESKTOP=/userdata/system/.local/share/applications/xboxcloud.desktop
LOG_DIR=/userdata/system/logs
LOG="$LOG_DIR/xboxcloud-installer.log"

SELF="$(readlink -f "$0")"
SELF_DIR="$(dirname "$SELF")"
SELF_NAME="$(basename "$SELF")"
SELF_STEM="${SELF_NAME%.*}"

# ---------------------------------------------------------------------------
# Open a visible terminal window (Ports scripts run without one by default)
# ---------------------------------------------------------------------------
if [[ "${1:-}" != "--in-terminal" ]]; then
    mkdir -p "$LOG_DIR"
    export DISPLAY="${DISPLAY:-:0.0}"
    if command -v xterm >/dev/null 2>&1; then
        exec xterm -fullscreen -fa "Monospace" -fs 11 -bg black -fg white \
            -T "Xbox Cloud Gaming Installer & Updater" -e /bin/bash "$SELF" --in-terminal
    fi
    echo "xterm not found - cannot open a terminal window." >> "$LOG"
    exit 1
fi

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG") 2>&1
echo "===== $(date) ====="
export DISPLAY="${DISPLAY:-:0.0}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
show_banner() {
cat <<'BANNER'
@@BANNER@@
BANNER
printf '\n'
}

fail() {
    echo
    echo "[ERROR] $*"
    echo "Log: $LOG"
    rm -rf "$TMP"
    echo
    wait_key
    exit 1
}

@@HELPERS@@

extract_payload() {  # extract_payload <name> <target file>
    awk -v n="$1" '$0=="__"n"_BEGIN__"{f=1;next} $0=="__"n"_END__"{f=0} f' "$SELF" | base64 -d > "$2"
}

# Ports entry: cover image
update_ports_entry() {
    mkdir -p "$SELF_DIR/images"
    extract_payload POSTER "$SELF_DIR/images/$SELF_STEM.jpg"
python3 - "$SELF_DIR/gamelist.xml" "./$SELF_NAME" "./images/$SELF_STEM.jpg" "$SELF_STEM" <<'PY'
import os, sys
import xml.etree.ElementTree as ET
gl, path, image, name = sys.argv[1:5]
if os.path.exists(gl):
    tree = ET.parse(gl); root = tree.getroot()
else:
    root = ET.Element("gameList"); tree = ET.ElementTree(root)
game = None
for g in root.findall("game"):
    if os.path.basename(g.findtext("path") or "") == os.path.basename(path):
        game = g; break
if game is None:
    game = ET.SubElement(root, "game"); ET.SubElement(game, "path").text = path
for tag, val in (("name", name), ("image", image), ("thumbnail", image)):
    el = game.find(tag)
    if el is None:
        el = ET.SubElement(game, tag)
    el.text = val
tree.write(gl, encoding="utf-8", xml_declaration=True)
PY
}

write_helpers() {  # helper files (always refreshed from this installer)
    mkdir -p "$BASE/assets"
    extract_payload GAMELIST  "$BASE/gamelist.py"
    extract_payload HOTKEY    "$BASE/hotkey.py"
    extract_payload THEMELOGO "$BASE/themelogo.py"
    extract_payload LOGO      "$BASE/assets/xboxcloud.png"
}

reload_es() { curl -s --max-time 5 http://127.0.0.1:1234/reloadgames >/dev/null 2>&1; }

# Sign in: opens Xbox Cloud Gaming in a window and waits until it is closed
do_login() {
    echo
    echo "----------------------------------------------------------------------"
    echo " SIGN IN (keyboard needed):"
    echo "  1. Xbox Cloud Gaming opens now."
    echo "  2. Sign in with your Microsoft account."
    echo "  3. When you see the start page, close the window"
    echo "     (Hotkey + Start, or Alt + F4)."
    echo "----------------------------------------------------------------------"
    echo
    "$BASE/xboxcloud-app.sh" >> "$LOG" 2>&1
    echo "Xbox Cloud Gaming closed."
}

# Builds the game list with progress bars (no sign in needed)
build_games() {
    local res=/tmp/xcloud-result.txt
    rm -f "$res"
    echo "Building the game list (German names and covers)..."
    python3 -u "$BASE/gamelist.py" "$ROM_DIR" "$res"
    if grep -q '^STATUS=OK' "$res" 2>/dev/null; then
        GAMES="$(grep '^GAMES=' "$res" | cut -d= -f2)"
        echo
        echo "  Game list ready: $GAMES games in the system \"Xbox Cloud Gaming\""
        grep -q '^GERMAN=1' "$res" || echo "  (German names were not available, English names used)"
        return 0
    fi
    echo
    echo "  Could not build the game list (no internet or the Game Pass catalog is down)."
    echo "  Run this installer again later."
    return 1
}

# Offers the one-time sign in (needed to play, not for the list)
offer_login() {
    echo
    echo "To play you need to sign in once with your Microsoft account."
    if ask_yes_no "Sign in now?"; then
        do_login
    else
        echo
        echo "You can sign in later: F1 file manager -> Applications -> Xbox Cloud Gaming"
    fi
}

# ---------------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------------
clear
show_banner

[[ "$(uname -m)" == "x86_64" ]]  || fail "This installer only supports x86_64 PCs."
command -v curl >/dev/null 2>&1    || fail "curl not found."
command -v python3 >/dev/null 2>&1 || fail "python3 not found."

echo "Checking for the latest version..."
RELEASE_JSON="$(mktemp /tmp/xcloud-rel-XXXX.json)"
if ! curl -fsSL -H "Accept: application/vnd.github+json" "$API_URL" -o "$RELEASE_JSON"; then
    rm -f "$RELEASE_JSON"
    fail "Could not reach GitHub. Check the internet connection."
fi
INFO="$(python3 - "$RELEASE_JSON" <<'PY'
import json, sys
try:
    rels = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
if not isinstance(rels, list):
    sys.exit(1)
rels = [r for r in rels if not r.get("draft") and not r.get("prerelease")]
rels.sort(key=lambda r: r.get("published_at") or "", reverse=True)
for r in rels:
    for a in r.get("assets", []):
        n = a.get("name", "")
        if n.endswith(".AppImage") and "arm" not in n.lower():
            print(r["tag_name"]); print(a["browser_download_url"]); print(a["size"])
            sys.exit(0)
sys.exit(2)
PY
)"
rc=$?
rm -f "$RELEASE_JSON"
(( rc == 0 )) || fail "No Linux build found on GitHub (or the GitHub API limit was reached, try again later)."
mapfile -t R <<< "$INFO"
TAG="${R[0]}"; URL="${R[1]}"; SIZE="${R[2]}"

INSTALLED=""
[[ -f "$VERSION_FILE" ]] && INSTALLED="$(head -n1 "$VERSION_FILE")"
FRESH=1
[[ -n "$INSTALLED" && -x "$APP" ]] && FRESH=0

echo "Latest version:    $TAG"
echo "Installed version: ${INSTALLED:-none}"
echo

if (( FRESH == 0 )); then
    # Already installed: update the program if needed, always refresh the game list
    if [[ "$INSTALLED" == "$TAG" ]]; then
        echo "Program: up to date"
        echo
        write_helpers
        update_ports_entry
        build_games
        reload_es
        echo
        echo "up to date"
        echo
        wait_key
        exit 0
    fi
    echo "Update found: $TAG"
    echo
    if ! ask_yes_no "Install the update?"; then
        echo
        echo "Cancelled. Nothing was changed."
        echo
        wait_key
        exit 0
    fi
else
    echo "----------------------------------------------------------------------"
    echo " WARNING: This is an unofficial system."
    echo " Future Batocera updates may affect it."
    echo
    echo " Xbox Cloud Gaming needs Game Pass Ultimate and a Microsoft account."
    echo " You sign in once with a keyboard, after that everything works"
    echo " with the controller."
    echo
    echo " After the installation Batocera needs a REBOOT."
    echo " You will be asked before it reboots."
    echo "----------------------------------------------------------------------"
    echo
    if ! ask_yes_no "Install Xbox Cloud Gaming ($TAG)?"; then
        echo
        echo "Cancelled. Nothing was changed."
        echo
        wait_key
        exit 0
    fi
fi
echo

# ---------------------------------------------------------------------------
# Download + install
# ---------------------------------------------------------------------------
rm -rf "$TMP"
mkdir -p "$TMP" "$BASE" || fail "Cannot create $BASE"
echo "Downloading Xbox Cloud Gaming $TAG..."
curl -fL --retry 3 -o "$TMP/app.AppImage" "$URL" || fail "Download failed."
GOT="$(stat -c %s "$TMP/app.AppImage" 2>/dev/null || echo 0)"
[[ "$GOT" == "$SIZE" ]] || fail "The download is incomplete ($GOT of $SIZE bytes)."
chmod +x "$TMP/app.AppImage"
echo

echo "Installing..."
if [[ -f "$APP" ]]; then
    mkdir -p "$BACKUP"
    mv -f "$APP" "$BACKUP/XboxCloudGaming.AppImage"
    [[ -f "$VERSION_FILE" ]] && cp "$VERSION_FILE" "$BACKUP/version.txt"
    echo "Previous version saved to: $BACKUP"
fi
mv "$TMP/app.AppImage" "$APP" || fail "Could not install the program."
rm -rf "$TMP"
echo "$TAG" > "$VERSION_FILE"

mkdir -p "$ROM_DIR/images" /userdata/system/configs/emulationstation "$(dirname "$DESKTOP")" "$BASE/assets"

write_helpers

# Start a game (called by EmulationStation)
cat > "$BASE/launch.sh" <<'SH'
#!/bin/bash
# Starts one Xbox Cloud Gaming title straight into the stream
BASE=/userdata/system/xboxcloud
LOG=/userdata/system/logs/xboxcloud.log
ROM="${1:-}"
TITLE="$(head -n1 "$ROM" 2>/dev/null | tr -d '\r\n ')"
[[ -n "$TITLE" ]] || { echo "No title id in: $ROM" >> "$LOG"; exit 1; }
export DISPLAY="${DISPLAY:-:0.0}"
unset WAYLAND_DISPLAY
cd "$BASE" || exit 1
{ echo "===== $(date) ====="; echo "Game: $ROM ($TITLE)"; } >> "$LOG"
setsid "$BASE/XboxCloudGaming.AppImage" --no-sandbox --fullscreen "--connect=xcloud_$TITLE" >> "$LOG" 2>&1 &
PID=$!
python3 "$BASE/hotkey.py" "$PID" >> "$LOG" 2>&1 &
HK=$!
wait "$PID"
RC=$?
kill "$HK" 2>/dev/null
exit "$RC"
SH

# Open the program without a game (sign in, settings)
cat > "$BASE/xboxcloud-app.sh" <<'SH'
#!/bin/bash
BASE=/userdata/system/xboxcloud
export DISPLAY="${DISPLAY:-:0.0}"
unset WAYLAND_DISPLAY
cd "$BASE" || exit 1
setsid "$BASE/XboxCloudGaming.AppImage" --no-sandbox >> /userdata/system/logs/xboxcloud.log 2>&1 &
PID=$!
python3 "$BASE/hotkey.py" "$PID" >/dev/null 2>&1 &
HK=$!
wait "$PID"
kill "$HK" 2>/dev/null
SH
chmod +x "$BASE/launch.sh" "$BASE/xboxcloud-app.sh" "$APP"

# System "Xbox Cloud Gaming"
cat > "$ES_CFG" <<'XML'
<?xml version="1.0"?>
<systemList>
  <system>
    <name>xboxcloud</name>
    <fullname>Xbox Cloud Gaming</fullname>
    <manufacturer>Microsoft</manufacturer>
    <hardware>console</hardware>
    <path>/userdata/roms/xboxcloud</path>
    <extension>.xcloud</extension>
    <command>/userdata/system/xboxcloud/launch.sh %ROM%</command>
    <platform>ignore</platform>
    <theme>xboxcloud</theme>
  </system>
</systemList>
XML

# F1 file manager -> Applications
cat > "$DESKTOP" <<'DESKTOPEOF'
[Desktop Entry]
Type=Application
Name=Xbox Cloud Gaming
Comment=Sign in and settings
Exec=/userdata/system/xboxcloud/xboxcloud-app.sh
Path=/userdata/system/xboxcloud
Icon=/userdata/system/xboxcloud/assets/xboxcloud.png
Terminal=false
Categories=Game;batocera.linux;
DESKTOPEOF
chmod +x "$DESKTOP"

# System logo in every theme that can take it
THEME_REPORT="$(python3 "$BASE/themelogo.py" "$BASE/assets/xboxcloud.png" xboxcloud 2>/dev/null)"

update_ports_entry
echo "Done."

# Game list, then sign in (first install only)
LIST_OK=0
build_games && LIST_OK=1
if (( FRESH == 1 )); then
    offer_login
    (( LIST_OK == 1 )) || { echo; build_games; }
fi

echo
echo "======================================================================"
echo " Xbox Cloud Gaming $TAG"
echo
echo " System:    Xbox Cloud Gaming (one entry per game)"
echo " Sign in / settings: F1 file manager -> Applications -> Xbox Cloud Gaming"
echo " Exit a game: Hotkey + Start"
echo " New games: run this installer again"
echo
echo " System logo per theme ([--] = theme folder is read-only):"
echo "${THEME_REPORT:-  no themes found}"
echo "======================================================================"
echo

if (( FRESH == 0 )); then
    reload_es
    echo "Update complete"
    echo
    wait_key
    exit 0
fi

echo "Installation complete"
echo
if ! ask_yes_no "Reboot now?"; then
    echo
    echo "No reboot. The system \"Xbox Cloud Gaming\" appears after the next reboot."
    echo
    wait_key
    exit 0
fi
echo "Rebooting..."
sync
reboot
exit 0

__POSTER_BEGIN__
@@POSTER@@
__POSTER_END__
__LOGO_BEGIN__
@@LOGO@@
__LOGO_END__
__GAMELIST_BEGIN__
@@GAMELIST@@
__GAMELIST_END__
__HOTKEY_BEGIN__
@@HOTKEY@@
__HOTKEY_END__
__THEMELOGO_BEGIN__
@@THEMELOGO@@
__THEMELOGO_END__
