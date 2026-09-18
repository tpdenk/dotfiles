#!/usr/bin/env bash
#
# term-here: open a terminal in the working directory of the focused window.

set -uo pipefail

term=${TERMINAL:-alacritty}

# /proc/<pid>/stat fields, numbered after the ") " that terminates comm:
#   1 state  2 ppid  3 pgrp  4 session  5 tty_nr  6 tpgid
tpgid_of() {
	local stat
	stat=$(</proc/"$1"/stat) || return 1
	stat=${stat#*") "}
	# shellcheck disable=SC2086 # deliberate splitting into positional params
	set -- $stat
	printf '%s\n' "$6"
}

cwd_of() {
	local dir
	dir=$(readlink -e /proc/"$1"/cwd 2>/dev/null) || return 1
	[[ -d $dir ]] || return 1
	printf '%s\n' "$dir"
}

win_pid=$(hyprctl activewindow | sed -n 's/^[[:space:]]*pid:[[:space:]]*\([0-9]\{1,\}\)$/\1/p')

# Breadth-first walk of the window's process subtree, shallowest pid first.
tree=(${win_pid:-})
for ((i = 0; i < ${#tree[@]}; i++)); do
	while read -r kid; do
		[[ -n $kid ]] && tree+=("$kid")
	done < <(pgrep -P "${tree[i]}" 2>/dev/null)
done

dir=""
for pid in "${tree[@]}"; do
	fg=$(tpgid_of "$pid") || continue
	((fg > 0)) || continue
	dir=$(cwd_of "$fg") && break
	dir=""
done

[[ -n $dir ]] || dir=$(cwd_of "${win_pid:-0}") || dir=$HOME

cd -- "$dir" || cd -- "$HOME" || exit 1
exec "$term"
