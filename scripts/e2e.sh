#!/usr/bin/env bash
# Runs pinnad with pretend headphones on a private session bus, next to a pretend media
# player and notification server, and checks what comes out. Needs python3 with dbus and gi.
set -uo pipefail
cd "$(dirname "$0")/.."
if [ -z "${PINNA_E2E_INNER:-}" ]; then
    cargo build --release -q || exit 1
    exec env PINNA_E2E_INNER=1 dbus-run-session -- "$0" "$@"
fi

tmp=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME=$tmp/cfg XDG_STATE_HOME=$tmp/state PINNA_POPUP=/bin/true
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
ctl=target/release/pinnactl
fail=0
check() { # name, expected, actual
    if [ "$2" = "$3" ]; then echo "  ok  $1"; else echo "fail  $1: wanted '$2', got '$3'"; fail=1; fi
}
field() { $ctl json | python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }
start() { # profile, extra env
    env PINNA_FAKE="$1" ${2:-} target/release/pinnad >"$tmp/pinnad.log" 2>&1 &
    daemon=$!
    for _ in $(seq 30); do $ctl json >/dev/null 2>&1 && break; sleep 0.1; done
    sleep 0.5
}
stop() { kill "$daemon"; wait "$daemon" 2>/dev/null; rm -rf "$XDG_CONFIG_HOME"/* "$XDG_STATE_HOME"/*; }

python3 -I scripts/e2e/mpris.py >"$tmp/mpris.log" &
python3 -I scripts/e2e/notifications.py >"$tmp/notify.log" &
sleep 1

echo "modes"
start pro2
$ctl mode adaptive >/dev/null
check "pro2 takes adaptive" adaptive "$(field "d['mode']")"
check "cycle follows the stem modes" "Noise Cancellation" "$($ctl cycle)"
stop
start max
check "max has one battery" True "$(field "d['oneBattery']")"
check "max refuses adaptive" 1 "$($ctl mode adaptive >/dev/null 2>&1; echo $?)"
stop
start airpods2
check "airpods 2 refuse a mode" 1 "$($ctl mode anc >/dev/null 2>&1; echo $?)"
check "airpods 2 report no mode" None "$(field "d['mode']")"
stop

echo "ear detection"
start 1 PINNA_FAKE_EAR=1
$ctl set conversationAwareness on
$ctl pref caOneBud on
sleep 4
check "one bud out pauses" PAUSE "$(tail -n1 "$tmp/mpris.log")"
check "conversation awareness off with one bud" False "$(field "d['settings']['conversationAwareness']")"
sleep 3
check "bud back in resumes" PLAY "$(tail -n1 "$tmp/mpris.log")"
check "conversation awareness back" True "$(field "d['settings']['conversationAwareness']")"
stop

echo "head gestures"
start 1
$ctl pref headGestures on
sleep 7
check "one nod plays or pauses once" 1 "$(grep -c PLAYPAUSE "$tmp/mpris.log")"
check "shake skips" NEXT "$(tail -n1 "$tmp/mpris.log")"
stop

echo "settings survive a reconnect"
start 1
$ctl set adaptiveStrength 30
stop_keep() { kill "$daemon"; wait "$daemon" 2>/dev/null; }
stop_keep
start 1
check "adaptive level is resent" 30 "$(field "d['settings']['adaptiveStrength']")"
stop

[ $fail = 0 ] && echo "all good"
exit $fail
