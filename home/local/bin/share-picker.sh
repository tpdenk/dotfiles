#!/usr/bin/env bash
set -euo pipefail

# The picker every capture goes through: the xdg-desktop-portal screencast
# prompt (XDPH's custom_picker_binary), `screenshot`, and the shell's screen
# recorder all run this one, so a monitor, a window or a region is always
# picked the same way and looks the same being picked.
#
#   share-picker         an XDPH [SELECTION] line on stdout, plus the area file
#                        the bar's capture outline reads
#   share-picker --area  "kind output x y w h address" on stdout, in layout
#                        coordinates: what grim -g and gpu-screen-recorder
#                        -region take
#
# kind is screen, window or region; address is the Hyprland address of a picked
# window and "-" otherwise. A cancelled pick exits 1 and prints nothing.
#
# The selection never carries the "r" flag, so XDPH is never told it may hand
# the client a restore token. A token is self-renewing once granted - a share
# restored from one counts as the user having allowed it again - so a client
# that got one would never be asked again. Every share asks.

mode=portal
for arg in "$@"; do
	case $arg in
		--area) mode=area ;;
	esac
done

cache="${XDG_RUNTIME_DIR:-/tmp}/share-picker.last"
area_file="${XDG_RUNTIME_DIR:-/tmp}/share-picker.area"
cache_seconds=1

# a portal pick answers every portal ask within the next second, so one prompt
# asked twice opens one picker. A screenshot or a recording always picks anew.
if [[ $mode == portal && -r $cache ]]; then
	read -r stamp selection <"$cache" || true
	if [[ -n ${selection-} && $(( $(date +%s) - stamp )) -le $cache_seconds ]]; then
		printf '%s\n' "$selection"
		exit 0
	fi
fi

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

# XDPH lists the windows it can share in the environment, as
# handle[HC>]class[HT>]title[HE>]decimal address, each entry closed by [HA>].
# The read keeps going on a last entry that is not, so the list format only has
# to separate rather than terminate.
window_handle() {
	local address record
	address=$(( 16#${1#0x} ))
	while IFS= read -r record || [[ -n $record ]]; do
		[[ -n $record ]] || continue
		[[ ${record##*"[HE>]"} == "$address" ]] || continue
		printf %s "${record%%"[HC>]"*}"
		break
	done < <(printf '%s' "${XDPH_WINDOW_SHARING_LIST-}" | sed 's/\[HA>\]/\n/g')
	return 0
}

# x y w h arrive in layout coordinates, which is what --area hands out;
# the portal's capture_output_region is output-local, so the monitor origin
# comes off on the way to it
emit() {
	local kind=$1 output=$2 x=$3 y=$4 w=$5 h=$6 address=$7

	if [[ $mode == area ]]; then
		printf '%s %s %s %s %s %s %s\n' "$kind" "$output" "$x" "$y" "$w" "$h" "$address"
		exit 0
	fi

	local ox=0 oy=0 origin handle="" selection stamp
	origin="$(jq -r --arg name "$output" '.[] | select(.name == $name) | "\(.x) \(.y)"' <<<"$monitors")"
	if [[ -n $origin ]]; then read -r ox oy <<<"$origin"; fi
	x=$(( x - ox ))
	y=$(( y - oy ))

	# the portal can only share a window it gave us a handle for; the same box
	# as a region carries the same pixels, minus following the window around
	if [[ $kind == window ]]; then
		handle="$(window_handle "$address")"
		if [[ -z $handle ]]; then
			kind=region
			address=-
		fi
	fi

	case $kind in
		screen) selection="[SELECTION]/screen:${output}" ;;
		window) selection="[SELECTION]/window:${handle}" ;;
		region) selection="$(printf '[SELECTION]/region:%s@%s,%s,%s,%s' "$output" "$x" "$y" "$w" "$h")" ;;
	esac

	stamp="$(date +%s)"
	printf '%s %s\n' "$stamp" "$selection" >"$cache"
	# the shell watches this file; a rename lands the whole line at once
	printf '%s %s %s %s %s %s %s %s\n' "$stamp" "$kind" "$output" "$x" "$y" "$w" "$h" "$address" >"$area_file.tmp"
	mv -f "$area_file.tmp" "$area_file"
	printf '%s\n' "$selection"
	exit 0
}

boxes="$(jq -n -r --argjson monitors "$monitors" --argjson clients "$clients" '
	[$monitors[] | .activeWorkspace.id, .specialWorkspace.id] as $visible
	| $clients[]
	| select(.mapped and (.hidden | not) and (.workspace.id as $id | $visible | index($id)))
	| select(.size[0] > 0 and .size[1] > 0)
	| "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1]) \(.address)"
')"

if [[ -n $boxes ]]; then boxes+=$'\n'; fi

# every window of the visible workspaces, plus (via -o) every monitor: slurp
# picks the smallest box under the pointer, so a click inside a window takes
# the window, one on bare desktop takes the monitor, and a drag takes a region
selection="$(printf '%s' "$boxes" | slurp -o -f '%x %y %w %h %o %l' -b "$dim" -c "$border" -s "$fill" -B "$hint")" || exit 1

read -r x y w h output label <<<"$selection"

# slurp keeps the label of the last box the pointer crossed even when the
# selection ends up being a dragged region, so a label only counts when the
# pick is that box
matches_box() {
	local bx=$1 by=$2 bw=$3 bh=$4
	(( x - bx <= 2 && bx - x <= 2 && y - by <= 2 && by - y <= 2 &&
	   w - bw <= 2 && bw - w <= 2 && h - bh <= 2 && bh - h <= 2 ))
}

monitor="$(jq -r --arg name "$label" '.[] | select(.name == $name) | "\(.x) \(.y) \(.width / .scale | round) \(.height / .scale | round)"' <<<"$monitors")"
if [[ -n $monitor ]]; then
	read -r mx my mw mh <<<"$monitor"
	if matches_box "$mx" "$my" "$mw" "$mh"; then
		emit screen "$label" "$mx" "$my" "$mw" "$mh" -
	fi
fi

if [[ $label == 0x* ]]; then
	window="$(jq -r --arg address "$label" '.[] | select(.address == $address) | "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"' <<<"$clients")"
	if [[ -n $window ]]; then
		read -r wx wy ww wh <<<"$window"
		if matches_box "$wx" "$wy" "$ww" "$wh"; then
			emit window "$output" "$wx" "$wy" "$ww" "$wh" "$label"
		fi
	fi
fi

emit region "$output" "$x" "$y" "$w" "$h" -
