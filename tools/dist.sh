#!/bin/sh
# Builds one release zip per platform per addon:
#   dist/<addon>-v<ver>-ashita.zip     unzips into Ashita/addons/
#   dist/<addon>-v<ver>-windower.zip   unzips into Windower/addons/ (only if <addon>/windower/<addon>.lua exists)
# The unzipped trees are left under dist/stage/<platform>/<addon>/ so a clone can symlink them
# into the game's addons folder. Addons whose entry point requires lib.chain get the shared
# engine in lib/ merged into their own lib/.
# Usage: sh tools/dist.sh <ver> [addon ...]    no addon = every folder with <addon>/<addon>.lua
#    or: make dist VER=<ver> [ADDON=<addon>]
set -eu
ver=$1
shift
if [ $# -eq 0 ]; then
    for d in */; do
        d=${d%/}
        [ -f "$d/$d.lua" ] && set -- "$@" "$d"
    done
fi

out=$(pwd)/dist
mkdir -p "$out"
stage=$out/stage

merge_shared_lib() {
    grep -q "require('lib.chain')" "$addon/$addon.lua" || return 0
    for f in lib/*.lua; do
        [ -e "$1/lib/$(basename "$f")" ] || cp "$f" "$1/lib/"
    done
}

pack() {
    rm -f "$out/$addon-v$ver-$1.zip"
    (cd "$stage/$1" && zip -qrX "$out/$addon-v$ver-$1.zip" "$addon")
    echo "$out/$addon-v$ver-$1.zip"
}

for addon in "$@"; do
    [ -f "$addon/$addon.lua" ] || { echo "no $addon/$addon.lua" >&2; exit 1; }
    rm -rf "$stage/ashita/$addon" "$stage/windower/$addon"

    # Ashita: the addon folder as is, minus dev files and the Windower entry point.
    mkdir -p "$stage/ashita"
    cp -R "$addon" "$stage/ashita/$addon"
    rm -rf "$stage/ashita/$addon/tests" "$stage/ashita/$addon/windower"
    merge_shared_lib "$stage/ashita/$addon"
    pack ashita

    # Windower: the Windower entry point takes the <addon>.lua slot; lib/ and data/ are shared.
    if [ -f "$addon/windower/$addon.lua" ]; then
        mkdir -p "$stage/windower/$addon"
        cp "$addon/windower/$addon.lua" "$stage/windower/$addon/$addon.lua"
        for f in lib data README.md; do
            if [ -e "$addon/$f" ]; then cp -R "$addon/$f" "$stage/windower/$addon/$f"; fi
        done
        merge_shared_lib "$stage/windower/$addon"
        pack windower
    fi
done
