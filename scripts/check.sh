#!/usr/bin/env bash
# Runs before a commit: tests, lints, and every page rendered offscreen with each fixture,
# theme and language. Any QML warning fails it.
set -euo pipefail
cd "$(dirname "$0")/.."

cargo test -q
cargo clippy -q --all-targets -- -D warnings
cmake --build app/build >/dev/null

out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
fail=0
for fixture in app/fixtures/*.json; do
    for theme in light dark; do
        for lang in en tr; do
            for page in 0 1 2 3 4 5 6; do
                log=$(QT_QPA_PLATFORM=offscreen PINNA_STATE="$fixture" PINNA_THEME=$theme PINNA_LANG=$lang \
                    PINNA_PAGE=$page PINNA_SHOT="$out/shot.png" timeout 20 app/build/pinna 2>&1 \
                    | grep -v propagateSizeHints || true)
                if [ -n "$log" ]; then
                    echo "$(basename "$fixture") $theme $lang page $page:"
                    echo "$log" | sed 's/^/  /'
                    fail=1
                fi
            done
        done
    done
    log=$(QT_QPA_PLATFORM=offscreen PINNA_STATE="$fixture" PINNA_SHOT="$out/card.png" timeout 20 app/build/pinna --popup 2>&1 \
        | grep -v propagateSizeHints || true)
    if [ -n "$log" ]; then
        echo "$(basename "$fixture") card:"
        echo "$log" | sed 's/^/  /'
        fail=1
    fi
done
[ $fail = 0 ] && echo "all good"
exit $fail
