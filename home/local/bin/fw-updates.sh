#!/usr/bin/env sh
#
# fw-updates: pending firmware updates, one per line, as
#
#   <device id>\t<name>\t<installed version>\t<available version>\t<blocked reason>
set -eu

command -v fwupdmgr >/dev/null 2>&1 || exit 0

json=$(fwupdmgr get-updates --json 2>/dev/null) || case $? in
	2) exit 0 ;;
	*) exit 1 ;;
esac

printf '%s' "$json" | jq -r '
	(.Devices // [])[]
	| select((.Releases // []) | length > 0)
	| [.DeviceId, .Name, (.Version // ""), (.Releases[0].Version // ""),
	   (.UpdateError // (if ((.Flags // []) | index("updatable")) then "" else "not updatable" end))]
	| @tsv'
