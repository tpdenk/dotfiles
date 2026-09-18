#!/usr/bin/env sh

SOURCE=$(realpath ${0})
BOOTSTRAP=${SOURCE%/*}/../../../bootstrap.sh

if [[ ! -e $BOOTSTRAP ]]; then
	echo "can't find $BOOTSTRAP"
	exit 1
fi

$BOOTSTRAP "$@"