write_pad_helper() {
cat > "$1" <<'PY'
import sys, select
try:
    from evdev import InputDevice, list_devices, ecodes as e
except Exception:
    sys.exit(0)
devs = []
for p in list_devices():
    try:
        d = InputDevice(p)
        keys = set(d.capabilities().get(e.EV_KEY, []))
        if e.BTN_SOUTH in keys and e.BTN_EAST in keys:
            devs.append(d)
        else:
            d.close()
    except Exception:
        pass
if not devs:
    sys.exit(0)
fds = {d.fd: d for d in devs}
while True:
    r, _, _ = select.select(list(fds), [], [], 1.0)
    for fd in r:
        try:
            for ev in fds[fd].read():
                if ev.type == e.EV_KEY and ev.value == 1:
                    if ev.code == e.BTN_SOUTH:
                        print("y", flush=True); sys.exit(0)
                    if ev.code == e.BTN_EAST:
                        print("n", flush=True); sys.exit(0)
        except OSError:
            fds.pop(fd, None)
    if not fds:
        sys.exit(0)
PY
}

ask_yes_no() {  # returns 0 for yes, 1 for no
    local prompt="$1" answer="" key pad_pid helper out
    helper="$(mktemp /tmp/xcloud-pad-XXXX.py)"
    out="$(mktemp /tmp/xcloud-pad-XXXX.txt)"
    write_pad_helper "$helper"
    python3 "$helper" > "$out" 2>/dev/null &
    pad_pid=$!
    printf '%s [y/n] (Controller: A = yes, B = no): ' "$prompt"
    while [[ -z "$answer" ]]; do
        if read -rsn1 -t 0.2 key; then
            case "$key" in
                y|Y) answer="y" ;;
                n|N) answer="n" ;;
            esac
        fi
        if [[ -z "$answer" && -s "$out" ]]; then
            answer="$(head -c1 "$out")"
        fi
    done
    kill "$pad_pid" 2>/dev/null; wait "$pad_pid" 2>/dev/null
    rm -f "$helper" "$out"
    echo "$answer"
    [[ "$answer" == "y" ]]
}

wait_key() {  # waits for Enter (keyboard) or A / B (controller)
    local key pad_pid helper out
    helper="$(mktemp /tmp/xcloud-pad-XXXX.py)"
    out="$(mktemp /tmp/xcloud-pad-XXXX.txt)"
    write_pad_helper "$helper"
    python3 "$helper" > "$out" 2>/dev/null &
    pad_pid=$!
    printf 'Press A / Enter to exit '
    while true; do
        if read -rsn1 -t 0.2 key; then break; fi
        [[ -s "$out" ]] && break
    done
    kill "$pad_pid" 2>/dev/null; wait "$pad_pid" 2>/dev/null
    rm -f "$helper" "$out"
    echo
}
