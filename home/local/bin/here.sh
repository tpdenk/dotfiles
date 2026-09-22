#!/usr/bin/env bash
#
# here: run a command (or print the path) in the working directory of the
# focused window. When that window sits in an ssh session, the command runs on
# the far side instead: a fresh connection to the same destination, landing in
# that session's remote directory.
#
#   here                           print the focused window's directory
#   here xdg-terminal-exec         a terminal, there
#   here xdg-terminal-exec -- lf   lf, there; everything after -- is the
#                                  payload that follows the session over ssh
#
# Finding the remote directory needs /proc on the far side and a direct
# connection: behind a ProxyJump, or from a multiplexed client, the port below
# does not match and the new session starts in the remote home directory.

set -uo pipefail

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

shq() {
	printf "'%s'" "${1//\'/\'\\\'\'}"
}

# The client's source port, which sshd hands the remote session as the second
# field of SSH_CONNECTION: the one name both ends have for this connection.
source_port_of() {
	local fd link inode addr state file
	local -A inodes=()

	for fd in /proc/"$1"/fd/*; do
		link=$(readlink "$fd" 2>/dev/null) || continue
		[[ $link == socket:\[*\] ]] || continue
		inode=${link#socket:\[}
		inodes[${inode%\]}]=1
	done
	((${#inodes[@]})) || return 1

	for file in /proc/net/tcp /proc/net/tcp6; do
		[[ -r $file ]] || continue
		while read -r _ addr _ state _ _ _ _ _ inode _; do
			[[ $state == 01 ]] || continue # ESTABLISHED
			[[ -n ${inodes[$inode]:-} ]] || continue
			printf '%d\n' "$((16#${addr##*:}))"
			return 0
		done <"$file"
	done
	return 1
}

# Options that say where and as whom to connect are worth repeating; the ones
# describing what that particular client was doing are not.
ssh_target_of() {
	local keep_arg="BbceFIiJlmoPpS" drop_arg="DELOQRW" keep_flag="46AaCgKkqsvXxYy"
	local -a argv=()
	local arg rest ch pending="" i

	mapfile -d '' -t argv </proc/"$1"/cmdline || return 1
	((${#argv[@]} > 1)) || return 1

	SSH_DEST=""
	SSH_OPTS=()
	for ((i = 1; i < ${#argv[@]}; i++)); do
		arg=${argv[i]}
		if [[ -n $pending ]]; then
			[[ $pending == keep ]] && SSH_OPTS+=("$arg")
			pending=""
			continue
		fi
		if [[ $arg != -?* ]]; then
			SSH_DEST=$arg # what follows is that session's remote command
			break
		fi
		rest=${arg#-}
		while [[ -n $rest ]]; do
			ch=${rest:0:1}
			rest=${rest:1}
			if [[ $keep_arg == *"$ch"* || $drop_arg == *"$ch"* ]]; then
				local keep="drop"
				[[ $keep_arg == *"$ch"* ]] && keep="keep"
				if [[ -n $rest ]]; then # -p2222
					[[ $keep == keep ]] && SSH_OPTS+=("-$ch$rest")
					rest=""
				else
					[[ $keep == keep ]] && SSH_OPTS+=("-$ch")
					pending=$keep
				fi
			elif [[ $keep_flag == *"$ch"* ]]; then
				SSH_OPTS+=("-$ch")
			fi
		done
	done
	[[ -n $SSH_DEST ]]
}

# Runs on the far side under whatever login shell the account has, so it hands
# straight over to /bin/sh. Keep it free of single quotes.
REMOTE_SCRIPT='
port=$1
shift
dir=
if [ -n "$port" ]; then
	for proc in /proc/[0-9]*; do
		conn=$(tr "\000" "\n" 2>/dev/null < "$proc/environ" | sed -n "s/^SSH_CONNECTION=//p")
		[ -n "$conn" ] || continue
		[ "$(printf "%s" "$conn" | cut -d " " -f 2)" = "$port" ] || continue
		stat=$(cat "$proc/stat" 2>/dev/null) || continue
		fg=$(printf "%s" "${stat#*) }" | cut -d " " -f 6)
		case $fg in "" | -1 | 0) continue ;; esac
		cwd=$(readlink "/proc/$fg/cwd" 2>/dev/null) || continue
		[ -d "$cwd" ] || continue
		dir=$cwd
		break
	done
fi
[ -n "$dir" ] && cd "$dir"
port_to=$(printf "%s" "${SSH_CONNECTION:-}" | cut -d " " -f 4)
printf "connected to %s@%s%s via SSH\n" "$(id -un)" "$(uname -n)" "${port_to:+:$port_to}" >&2
if [ "$#" -gt 0 ]; then
	command -v "$1" > /dev/null 2>&1 && exec "$@"
	echo "here: no $1 on $(uname -n), opening a shell instead" >&2
fi
exec "${SHELL:-/bin/sh}" -l
'

# Leaving the remote session hands the window back to a local login shell,
# which the cd below has already put in the focused window's directory.
KEEP_OPEN='ssh "$@"; exec "${SHELL:-/bin/sh}" -l'

launcher=()
payload=()
split=0
for arg in "$@"; do
	if ((!split)) && [[ $arg == -- ]]; then
		split=1
	elif ((split)); then
		payload+=("$arg")
	else
		launcher+=("$arg")
	fi
done

win_pid=$(hyprctl activewindow | sed -n 's/^[[:space:]]*pid:[[:space:]]*\([0-9]\{1,\}\)$/\1/p')

# Breadth-first walk of the window's process subtree, shallowest pid first.
tree=(${win_pid:-})
for ((i = 0; i < ${#tree[@]}; i++)); do
	while read -r kid; do
		[[ -n $kid ]] && tree+=("$kid")
	done < <(pgrep -P "${tree[i]}" 2>/dev/null)
done

dir=""
front=""
for pid in "${tree[@]}"; do
	fg=$(tpgid_of "$pid") || continue
	((fg > 0)) || continue
	dir=$(cwd_of "$fg") && { front=$fg; break; }
	dir=""
done

[[ -n $dir ]] || dir=$(cwd_of "${win_pid:-0}") || dir=$HOME

cd -- "$dir" || cd -- "$HOME" || exit 1

(($# > 0)) || { printf '%s\n' "$PWD"; exit 0; }

if [[ -n $front && $(</proc/"$front"/comm) == ssh ]] && ssh_target_of "$front"; then
	port=$(source_port_of "$front") || port=""
	remote="/bin/sh -c $(shq "$REMOTE_SCRIPT") here $(shq "$port")"
	for arg in "${payload[@]}"; do
		remote+=" $(shq "$arg")"
	done
	exec "${launcher[@]}" /bin/sh -c "$KEEP_OPEN" here \
		-t "${SSH_OPTS[@]}" "$SSH_DEST" "$remote"
fi

exec "${launcher[@]}" "${payload[@]}"
