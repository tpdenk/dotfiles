#!/usr/bin/env sh
#
# pkg-updates: pending repo updates, one per line, as
#
#   <name>\t<pkgbase>\t<installed version>\t<available version>
set -eu

db=${PKG_UPDATES_DB:-${XDG_CACHE_HOME:-$HOME/.cache}/pkg-updates}
max_age=${PKG_UPDATES_MAX_AGE:-900}

mkdir -p "$db"
ln -snf "$(pacman-conf DBPath)/local" "$db/local"

now=$(date +%s)
synced=$(stat -c %Y "$db/.synced" 2>/dev/null || echo 0)
if [ "$((now - synced))" -ge "$max_age" ]; then
	# the attempt is stamped, not its success: a machine with no route to a
	# mirror would otherwise retry on every poll
	touch "$db/.synced"
	# --disable-sandbox: pacman 7 drops to the `alpm` user before downloading,
	# which under fakeroot fails outright
	fakeroot -- pacman -Sy --dbpath "$db" --logfile /dev/null --disable-sandbox >/dev/null 2>&1 || true
fi

updates=$(pacman -Qu --dbpath "$db" 2>/dev/null | awk '!/\[ignored\]/ { print $1 "\t" $2 "\t" $4 }')
[ -n "$updates" ] || exit 0

printf '%s\n' "$updates" | awk -F'\t' -v localdb="$(pacman-conf DBPath)/local" '{
	desc = localdb "/" $1 "-" $2 "/desc"
	base = $1
	while ((getline line < desc) > 0)
		if (line == "%BASE%") {
			getline base < desc
			break
		}
	close(desc)
	print $1 "\t" base "\t" $2 "\t" $3
}'
