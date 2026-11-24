#!/usr/bin/env bash
# Runs before a commit: tests, lints, and every page rendered offscreen with each fixture,
# theme and language. Any QML warning fails it.
set -euo pipefail
cd "$(dirname "$0")/.."

cargo test -q
cargo clippy -q --all-targets -- -D warnings
cmake --build app/build >/dev/null

# every text in the code is in the translation files, and Turkish is complete
before=$(cat app/i18n/pinna_*.ts | md5sum)
python3 app/i18n/update.py 2>/dev/null
if [ "$(cat app/i18n/pinna_*.ts | md5sum)" != "$before" ]; then
    echo "translation files were out of date; app/i18n/update.py updated them"
    exit 1
fi
if grep -q 'type="unfinished"' app/i18n/pinna_tr.ts; then
    echo "untranslated Turkish strings:"
    grep -B2 'type="unfinished"' app/i18n/pinna_tr.ts | grep '<source>' | sed 's/^ */  /'
    exit 1
fi

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
