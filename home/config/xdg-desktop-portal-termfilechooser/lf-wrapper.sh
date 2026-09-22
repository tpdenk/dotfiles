#!/usr/bin/env sh
multiple="$1"
directory="$2"
save="$3"
path="$4"
out="$5"
debug="$6"

[ "$debug" = 1 ] && set -x

termcmd="${TERMCMD:-kitty --title termfilechooser -e}"

: >"$out"
TFC_OUT="$out"
export TFC_OUT

accept='cmd tfc-accept &{{ if [ -n "${TFC_NAME:-}" ]; then t="$PWD/$TFC_NAME"; else t="$PWD"; fi; printf "%s\n" "$t" >"$TFC_OUT"; lf -remote "send $id quit" }}'

hint='\033[38;2;86;95;137m<enter> use this dir  q cancel\033[0m'

if [ "$save" = 1 ]; then
	TFC_NAME=$(basename -- "$path")
	export TFC_NAME
	label=$TFC_NAME
	set -- -command "$accept" \
		-command 'map <enter> tfc-accept' \
		-command "set promptfmt \"\033[1;38;2;158;206;106msave\033[0m \033[38;2;122;162;247m%d\033[1;38;2;192;202;245m$label\033[0m  $hint\"" \
		"$(dirname -- "$path")"
elif [ "$directory" = 1 ]; then
	set -- -command "$accept" \
		-command 'map <enter> tfc-accept' \
		-command "set promptfmt \"\033[1;38;2;158;206;106mdir\033[0m \033[38;2;122;162;247m%d\033[0m  $hint\"" \
		"$path"
else
	set -- -selection-path "$out" \
		-command 'map <enter> open' \
		-command "set promptfmt \"\033[1;38;2;158;206;106mopen\033[0m \033[38;2;122;162;247m%d\033[1;38;2;192;202;245m%f\033[0m  \033[38;2;86;95;137m<enter> select  q cancel\033[0m\"" \
		"$path"
fi

$termcmd lf "$@" || :

[ -s "$out" ]
