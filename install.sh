#!/bin/bash
# Installs the System Monitor "System" page and the local.graduatedbars sensor face
# for the current user, with the page at the top of the page list.
# Usage: ./install.sh [--page FILE] [--start-page]
#   --page FILE    install FILE instead of generating the page for this PC
#   --start-page   open System Monitor on the System page
set -euo pipefail
cd "$(dirname "$0")"

page=
start=false
while (($#)); do
    case "$1" in
        --page) page=$(realpath "${2:?--page needs a file}"); shift ;;
        --start-page) start=true ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

file=System.page

# Generate the page from this PC's sensors, before closing System Monitor, so it stays open if this fails
if [[ -z "$page" ]]; then
    page=$(mktemp --suffix=.page)
    trap 'rm -f "$page"' EXIT
    echo "Generating the page for this PC's hardware:"
    python3 -I generate-page.py -o "$page"
else
    echo "Using $page"
fi

if pgrep -x plasma-systemmo >/dev/null; then
    echo "Closing System Monitor (it would save its own configuration over the new one)"
    pkill -x plasma-systemmo
    for _ in $(seq 10); do pgrep -x plasma-systemmo >/dev/null || break; sleep 1; done
fi

data="${XDG_DATA_HOME:-$HOME/.local/share}"
mkdir -p "$data/ksysguard/sensorfaces" "$data/plasma-systemmonitor"
rm -rf "$data/ksysguard/sensorfaces/local.graduatedbars"
cp -r sensorfaces/local.graduatedbars "$data/ksysguard/sensorfaces/"
if [[ -f "$data/plasma-systemmonitor/$file" ]]; then
    cp -p "$data/plasma-systemmonitor/$file" "$data/plasma-systemmonitor/$file.$(date +%Y%m%d-%H%M%S).bak"
fi
cp "$page" "$data/plasma-systemmonitor/$file"

# Put the page at the top of the page order (moving it if it is already there)
order=$(kreadconfig6 --file systemmonitorrc --group General --key pageOrder)
order=$(echo ",$order," | sed "s/,$file,/,/g; s/^,//; s/,$//")
kwriteconfig6 --file systemmonitorrc --group General --key pageOrder "$file${order:+,$order}"
if $start; then
    kwriteconfig6 --file systemmonitorrc --group General --key startPage "$file"
fi
echo "Done. Open System Monitor: System page."
