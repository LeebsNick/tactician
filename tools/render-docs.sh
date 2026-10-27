#!/bin/sh
# Renders the walk-through pictures under docs/images/ from the editor mock-up in
# docs/images/src/mock.html with headless Chrome, one PNG per step, the editor window at its
# default 1300x520. Usage from the repo root: sh tools/render-docs.sh   (CHROME=chromium to override)
set -eu
chrome=${CHROME:-google-chrome}
src="file://$(cd docs/images/src && pwd)/mock.html"
for spec in '1 01-load 1400,760' '2 02-empty-editor 1300,520' '3 03-picker 1300,520' \
            '4 04-running 1300,520' '5 05-fired-and-inert 1300,520' '6 06-file-and-reload 1200,560'; do
    set -- $spec
    "$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
        --window-size="$3" --screenshot="docs/images/$2.png" "$src?step=$1" >/dev/null 2>&1
    echo "docs/images/$2.png"
done
