#!/usr/bin/env bash
# git restack [--onto <base>] <worktree-path|branch>...
#
# Rebases every given branch onto its parent, where the parent is inferred
# from the given set: the branch whose fork point with the child is deepest.
# Branches with no parent in the set are roots; they are left alone unless
# --onto <base> is given, in which case they are rebased onto <base>.
#
#   git restack ~/worktrees/myproj/*
#   git restack --onto main ~/worktrees/myproj/*
set -euo pipefail

if [[ -t 1 ]]; then
	bold=$'\e[1m' dim=$'\e[2m' green=$'\e[32m' reset=$'\e[0m'
else
	bold="" dim="" green="" reset=""
fi
if [[ -t 2 ]]; then
	red=$'\e[31m' yellow=$'\e[33m' ereset=$'\e[0m'
else
	red="" yellow="" ereset=""
fi

die() { echo "${red}git-restack:${ereset} $*" >&2; exit 1; }
warn() { echo "${yellow}skip${ereset} $*" >&2; }

base=""
if [[ ${1:-} == --onto ]]; then
	[[ $# -ge 2 ]] || die "--onto needs a base"
	base=$2; shift 2
fi
[[ $# -gt 0 ]] || die "usage: git restack [--onto <base>] <worktree-path|branch>..."

wt_for() { # path of the worktree that has branch $1 checked out
	git worktree list --porcelain | awk -v b="refs/heads/$1" '
		/^worktree /{p=substr($0,10)} $0=="branch "b{print p}'
}

# arg -> branch name; worktree path if the branch is already checked out
declare -A wt=() tip=()
branches=()
for arg in "$@"; do
	if [[ -d $arg ]]; then
		b=$(git -C "$arg" symbolic-ref --short -q HEAD) \
			|| { warn "$arg: detached HEAD"; continue; }
		w=$(cd "$arg" && pwd -P)
	else
		git show-ref -q --verify "refs/heads/$arg" || die "no such branch: $arg"
		b=$arg
		w=$(wt_for "$b")
	fi
	[[ -n ${tip[$b]:-} ]] && continue
	[[ $b == "$base" ]] && continue
	branches+=("$b")
	wt[$b]=$w
	tip[$b]=$(git rev-parse "refs/heads/$b")
done
[[ ${#branches[@]} -gt 0 ]] || die "nothing to restack"

fork_point() { # commit on $1 that $2 was forked from, per $1's reflog
	git merge-base --fork-point "$1" "$2" 2>/dev/null
}

# Pick each branch's parent before touching anything: all fork points are
# computed against the pre-rebase tips. Only reflog-backed fork points count,
# a plain merge-base cannot tell parent from child once the parent was amended.
declare -A parent=() upstream=()
for b in "${branches[@]}"; do
	best="" best_fp="" best_depth=-1
	for p in "${branches[@]}"; do
		[[ $p == "$b" ]] && continue
		fp=$(fork_point "$p" "$b") || continue
		[[ $fp == "${tip[$b]}" ]] && continue # p descends from b: a child, not a parent
		depth=$(git rev-list --count "$fp")
		if (( depth > best_depth )); then
			best=$p; best_fp=$fp; best_depth=$depth
		fi
	done
	if [[ -n $best ]]; then
		parent[$b]=$best; upstream[$b]=$best_fp
	elif [[ -n $base ]]; then
		parent[$b]=$base; upstream[$b]=$(fork_point "$base" "$b" || git merge-base "$base" "$b")
	fi
done

restack() { # rebase branch $1 onto ${parent[$1]} in its worktree
	local b=$1 w=${wt[$b]} tmp=""
	if [[ -z $w ]]; then
		tmp=$(mktemp -d); git worktree add -q "$tmp" "$b"; w=$tmp
	fi
	echo "${green}>>${reset} ${bold}$b${reset} onto ${bold}${parent[$b]}${reset}"
	git -C "$w" rebase --autostash --onto "${parent[$b]}" "${upstream[$b]}"
	if [[ -n $tmp ]]; then git worktree remove "$tmp"; fi
}

# Parents first: a branch is ready once its parent is done or outside the set.
declare -A done=()
remaining=("${branches[@]}")
while [[ ${#remaining[@]} -gt 0 ]]; do
	next=()
	progressed=0
	for b in "${remaining[@]}"; do
		p=${parent[$b]:-}
		if [[ -n $p && -z ${done[$p]:-} && -n ${tip[$p]:-} ]]; then
			next+=("$b"); continue
		fi
		if [[ -n $p ]]; then
			restack "$b"
		else
			echo "${dim}-- $b is a root, left as is${reset}"
		fi
		done[$b]=1; progressed=1
	done
	(( progressed )) || die "parent cycle among: ${next[*]}"
	remaining=("${next[@]}")
done
