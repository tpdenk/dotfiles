#!/usr/bin/env bash
set -euo pipefail

allow_token=0
for arg in "$@"; do
	[[ $arg == --allow-token ]] && allow_token=1
done
flags=""
if (( allow_token )); then flags="r"; fi

cache="${XDG_RUNTIME_DIR:-/tmp}/share-picker.last"
cache_seconds=1

if [[ -r $cache ]]; then
	read -r stamp selection <"$cache" || true
	if [[ -n ${selection-} && $(( $(date +%s) - stamp )) -le $cache_seconds ]]; then
		printf '%s\n' "$selection"
		exit 0
	fi
fi

emit() {
	printf '%s %s\n' "$(date +%s)" "$1" >"$cache"
	printf '%s\n' "$1"
	exit 0
}

declare -A theme_vars
theme_file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/theme.conf"
if [[ -r $theme_file ]]; then
	while IFS= read -r line; do
		line="${line%%#*}"
		[[ $line =~ ^[[:space:]]*\$([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*(.*[^[:space:]])[[:space:]]*$ ]] || continue
		theme_vars["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
	done <"$theme_file"
fi

resolve() {
	local value="${theme_vars[$1]-}" depth=0
	while [[ $value == \$* && $depth -lt 8 ]]; do
		value="${theme_vars[${value#\$}]-}"
		(( depth++ ))
	done
	printf %s "$value"
}

color() {
	local value
	value="$(resolve "$1")"
	if [[ $value =~ ^rgba\(([0-9a-fA-F]{6})[0-9a-fA-F]{2}\)$ || $value =~ ^rgb\(([0-9a-fA-F]{6})\)$ ]]; then
		printf '#%s%s' "${BASH_REMATCH[1]}" "$2"
	else
		printf '#%s%s' "$3" "$2"
	fi
}

dim="$(color background 99 000000)"
border="$(color accent ff ffffff)"
fill="$(color accent 26 ffffff)"
hint="$(color muted 40 ffffff)"

monitors="$(hyprctl monitors -j)"
clients="$(hyprctl clients -j)"

boxes="$(jq -n -r --argjson monitors "$monitors" --argjson clients "$clients" '
	[$monitors[] | .activeWorkspace.id, .specialWorkspace.id] as $visible
	| $clients[]
	| select(.mapped and (.hidden | not) and (.workspace.id as $id | $visible | index($id)))
	| select(.size[0] > 0 and .size[1] > 0)
	| "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1]) \(.address)"
')"

if [[ -n $boxes ]]; then boxes+=$'\n'; fi

selection="$(printf '%s' "$boxes" | slurp -o -f '%x %y %w %h %o %l' -b "$dim" -c "$border" -s "$fill" -B "$hint")" || exit 1

read -r x y w h output label <<<"$selection"

# slurp keeps the label of the last box the pointer crossed even when the
# selection ends up being a dragged region
matches_box() {
	local bx=$1 by=$2 bw=$3 bh=$4
	(( x - bx <= 2 && bx - x <= 2 && y - by <= 2 && by - y <= 2 &&
	   w - bw <= 2 && bw - w <= 2 && h - bh <= 2 && bh - h <= 2 ))
}

if monitor="$(jq -r --arg name "$label" '.[] | select(.name == $name) | "\(.x) \(.y) \(.width / .scale | round) \(.height / .scale | round)"' <<<"$monitors")" && [[ -n $monitor ]]; then
	read -r mx my mw mh <<<"$monitor"
	if matches_box "$mx" "$my" "$mw" "$mh"; then
		emit "$(printf '[SELECTION]%s/screen:%s' "$flags" "$label")"
	fi
fi

if [[ $label == 0x* ]]; then
	window="$(jq -r --arg address "$label" '.[] | select(.address == $address) | "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"' <<<"$clients")"
	if [[ -n $window ]]; then
		read -r wx wy ww wh <<<"$window"
		if matches_box "$wx" "$wy" "$ww" "$wh"; then
			address=$(( 16#${label#0x} ))
			handle=""
			while IFS= read -r record; do
				[[ -n $record ]] || continue
				[[ ${record##*"[HE>]"} == "$address" ]] || continue
				handle="${record%%"[HC>]"*}"
				break
			done < <(printf '%s' "${XDPH_WINDOW_SHARING_LIST-}" | sed 's/\[HA>\]/\n/g')

			if [[ -n $handle ]]; then
				emit "$(printf '[SELECTION]%s/window:%s' "$flags" "$handle")"
			fi
			x=$wx y=$wy w=$ww h=$wh
		fi
	fi
fi

# capture_output_region is output-local, not layout coordinates
origin="$(jq -r --arg name "$output" '.[] | select(.name == $name) | "\(.x) \(.y)"' <<<"$monitors")"
if [[ -n $origin ]]; then
	read -r ox oy <<<"$origin"
	x=$(( x - ox ))
	y=$(( y - oy ))
fi

emit "$(printf '[SELECTION]%s/region:%s@%s,%s,%s,%s' "$flags" "$output" "$x" "$y" "$w" "$h")"
