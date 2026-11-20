#!/usr/bin/env bash
#
# view: open files in a Brave window without browser controls. Hyprland floats
# and centers that window: the float-view rule in hyprland.lua.
#
#   view README.md
#   view report.pdf photo.png   one window for each file
#
# --kiosk has no effect on a Brave that already runs, so --app supplies the
# bare window.

set -euo pipefail

(($# > 0)) || { echo "usage: view FILE..." >&2; exit 2; }

# Percent-encodes a path, byte by byte, for a file:// URL.
urlencode() {
	local LC_ALL=C path=$1 out="" ch i
	for ((i = 0; i < ${#path}; i++)); do
		ch=${path:i:1}
		[[ $ch == [A-Za-z0-9/._~-] ]] || printf -v ch '%%%02X' "'$ch"
		out+=$ch
	done
	printf '%s\n' "$out"
}

for file in "$@"; do
	[[ -e $file ]] || { echo "view: $file: no such file" >&2; exit 1; }
	setsid -f brave --app="file://$(urlencode "$(realpath -s -- "$file")")" >/dev/null 2>&1
done
