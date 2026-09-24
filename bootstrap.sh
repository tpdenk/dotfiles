#!/usr/bin/env bash
#
# bootstrap.sh: take a fresh minimal Arch install to a working desktop.
# Run as your normal user (not root). Idempotent.
#
#   ./bootstrap.sh            everything, in the order below
#   ./bootstrap.sh pkgs       just package installs
#   ./bootstrap.sh links      just dotfile symlinks
#                  -f/--force recreate and overwrite existing symlinks
#   ./bootstrap.sh services   just systemctl enables
#   ./bootstrap.sh theme      just the dark-mode gsettings keys
#   ./bootstrap.sh firewall   just the ufw rules
#   ./bootstrap.sh shell      just set zsh as the login shell
#   ./bootstrap.sh rustup     just the rust toolchain
#   ./bootstrap.sh omz        just oh-my-zsh
#   ./bootstrap.sh p10k       just the powerlevel10k prompt
#   ./bootstrap.sh ssh        just the ssh key setup (keygen, gh login, upload)
#   ./bootstrap.sh gh         just the gh device-flow login
#   ./bootstrap.sh editor     just the editor installation
#   ./bootstrap.sh sabre      just the sabre_v2_pro mouse battery cli
#   ./bootstrap.sh omp        just install omp (oh-my-pi)
#   ./bootstrap.sh update     just git pull this repo

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUR_HELPER="${AUR_HELPER:-paru}"
LINKS_FORCE=0

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m warn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

[[ $EUID -ne 0 ]] || die "run as your normal user, not root"
have sudo || die "sudo not installed"

NET_CHECK_URL="${NET_CHECK_URL:-http://ping.archlinux.org/nm-check.txt}"

online() {
	if have curl; then
		curl -fsS --max-time 5 -o /dev/null "$NET_CHECK_URL"
	else
		ping -c1 -W3 archlinux.org >/dev/null 2>&1
	fi
}

wait_online() {
	local i
	for i in $(seq 10); do
		online && return 0
		sleep 2
	done
	return 1
}

wifi_connect() {
	local ssid="$1" sec="$2" pass=""
	log "connecting to $ssid"
	if nmcli -t -f NAME connection show | sed 's/\\:/:/g' | grep -qxF "$ssid"; then
		nmcli connection up id "$ssid" && return 0
		warn "saved profile for $ssid failed"
	fi
	if [[ -n "$sec" && "$sec" != '--' ]]; then
		read -rsp "  password for $ssid: " pass; echo
		nmcli device wifi connect "$ssid" password "$pass"
	else
		nmcli device wifi connect "$ssid"
	fi
}

require_online() {
	log "checking internet connection"
	
	online && return
	warn "no internet connection, and bootstrap needs one"
	have nmcli || die "nmcli not found; connect manually (iwctl, dhcpcd, ...) and re-run"
	[[ -t 0 ]] || die "not a tty; connect manually and re-run"

	if ! systemctl is-active --quiet NetworkManager; then
		log "starting NetworkManager"
		sudo systemctl start NetworkManager
		sleep 2
	fi
	nmcli radio wifi on >/dev/null 2>&1 || true

	local -a ssids secs
	local line sig sec ssid choice
	while :; do
		log "scanning for wifi networks"
		ssids=(); secs=()
		local -A seen=()
		while IFS= read -r line; do
			sig="${line%%:*}"; line="${line#*:}"
			sec="${line%%:*}"; ssid="${line#*:}"
			ssid="${ssid//\\:/:}"
			[[ -n "$ssid" && -z "${seen[$ssid]:-}" ]] || continue
			seen["$ssid"]=1
			ssids+=("$ssid"); secs+=("$sec")
			printf '  %2d) %-32s %3s%%  %s\n' "${#ssids[@]}" "$ssid" "$sig" "${sec:-open}"
		done < <(nmcli device wifi rescan >/dev/null 2>&1 || true; sleep 2
		         nmcli -t -f SIGNAL,SECURITY,SSID device wifi list --rescan no)
		(( ${#ssids[@]} )) || warn "no networks found"

		read -rp $'\n  number to connect, [r] rescan, [q] quit: ' choice
		case "$choice" in
			''|r|R) continue ;;
			q|Q)    die "internet required" ;;
			*[!0-9]*) warn "not a number"; continue ;;
		esac
		(( choice >= 1 && choice <= ${#ssids[@]} )) || { warn "out of range"; continue; }

		if wifi_connect "${ssids[choice-1]}" "${secs[choice-1]}" && wait_online; then
			log "online"
			return
		fi
		warn "still offline after trying ${ssids[choice-1]}"
	done
}

install_omp() {
	log "omp"
	if pgrep -x omp >/dev/null 2>&1; then
		warn "omp is running, skipping update (close it and rerun: ./bootstrap.sh omp)"
		return 0
	fi
	curl -fsSL https://omp.sh/install | sh || warn "omp install failed, continuing"
}

install_editor() {
	local EDITOR=ed
	local EDITOR_REPO="git@github.com:tpdenk/ed.git"
	local EDITOR_BIN="${CARGO_HOME:-$HOME/.cargo}/bin/$EDITOR"
	log "editor"
	have cargo || die "cargo not on PATH, run ./bootstrap.sh rustup first"
	mkdir -p "$HOME/Development/tpdenk"
	pushd "$HOME/Development/tpdenk" >/dev/null
	local build=0 dirty=0 reason="" before="" after=""
	if [[ -e "$EDITOR" ]]; then
		before="$(git -C "$EDITOR" rev-parse HEAD)"
		[[ -z "$(git -C "$EDITOR" status --porcelain)" ]] || dirty=1
		# A dirty worktree makes git pull refuse; that is fine, we rebuild anyway.
		if ! git -C "$EDITOR" pull; then
			(( dirty )) || die "git pull failed in $PWD/$EDITOR"
			warn "git pull skipped, worktree has local changes"
		fi
		after="$(git -C "$EDITOR" rev-parse HEAD)"
		if [[ "$before" != "$after" ]]; then
			build=1 reason="pulled ${before:0:12}..${after:0:12}"
		elif (( dirty )); then
			build=1 reason="local changes"
		elif [[ ! -x "$EDITOR_BIN" ]]; then
			build=1 reason="$EDITOR_BIN missing"
		fi
	else
		git clone "$EDITOR_REPO"
		build=1 reason="fresh clone"
	fi
	if (( build )); then
		log "building editor: $reason"
		cargo install --path "$EDITOR"
	else
		log "editor already up to date, skipping cargo install"
	fi
	popd >/dev/null
}

install_sabre() {
	local rules=/etc/udev/rules.d/70-sabre-v2-pro.rules
	local rule='KERNEL=="hidraw*", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b28|2b2a", TAG+="uaccess"'
	log "sabre_v2_pro"
	have cargo || die "cargo not on PATH, run ./bootstrap.sh rustup first"
	# cargo skips the build when the installed binary is already at the tip
	cargo install --git https://github.com/tpdenk/sabre_v2_pro

	if [[ "$(cat "$rules" 2>/dev/null)" != "$rule" ]]; then
		echo "$rule" | sudo tee "$rules" >/dev/null
		sudo udevadm control --reload
		sudo udevadm trigger --subsystem-match=hidraw
		echo "  installed $rules"
	fi
}

install_omz() {
	log "oh-my-zsh"
	if [[ ! -e "$HOME/.oh-my-zsh" ]]; then
		local installer
		installer="$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || die "could not download the oh-my-zsh installer"
		KEEP_ZSHRC=yes RUNZSH=no sh -c "$installer"
	else
		"$HOME/.oh-my-zsh/tools/upgrade.sh"
	fi
}

install_p10k() {
	local dir="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
	log "powerlevel10k"
	[[ -d "$HOME/.oh-my-zsh" ]] || die "oh-my-zsh missing, run ./bootstrap.sh omz first"
	if [[ -d "$dir/.git" ]]; then
		git -C "$dir" pull --ff-only || warn "powerlevel10k update failed, keeping the current checkout"
	else
		[[ -e "$dir" ]] && die "$dir exists but is not a git checkout, remove it and rerun"
		git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$dir"
	fi
	zsh -f "$dir/gitstatus/install" -f \
		|| warn "gitstatusd install failed, the prompt will fall back to vcs_info"
}

set_login_shell() {
	log "login shell"
	local zsh_path
	zsh_path="$(command -v zsh)" || die "zsh not installed, run ./bootstrap.sh pkgs first"
	grep -qxF "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
	if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]]; then
		sudo chsh -s "$zsh_path" "$USER"
		echo "  set to $zsh_path (re-login to apply)"
	else
		echo "  already $zsh_path"
	fi
}

github_ssh_ok() {
	local out
	out="$(ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
	[[ "$out" == *"successfully authenticated"* ]]
}

pubkey_body() { awk '{ print $1, $2 }' "$1"; }

gh_has_key() {
	gh api --paginate "$1" --jq '.[].key' 2>/dev/null | grep -qxF "$(pubkey_body "$2")"
}

GH_SCOPES="admin:public_key,admin:ssh_signing_key"

browser_available() {
	[[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] || return 1
	[[ -n "${BROWSER:-}" ]] && return 0
	local b
	for b in firefox librewolf chromium google-chrome-stable google-chrome \
	         brave vivaldi-stable qutebrowser epiphany falkon; do
		have "$b" && return 0
	done
	return 1
}

gh_device_flow() {
	log "gh device flow: enter the one-time code gh prints below"
	if browser_available; then
		echo "  a browser opens on https://github.com/login/device, or use that URL elsewhere"
		gh "$@" --hostname github.com --scopes "$GH_SCOPES"
	else
		echo "  no browser here: open https://github.com/login/device on another device"
		GH_BROWSER=true BROWSER=true gh "$@" --hostname github.com --scopes "$GH_SCOPES"
	fi
}

setup_gh() {
	have gh || die "gh not installed, run ./bootstrap.sh pkgs first"

	if ! gh auth status --hostname github.com >/dev/null 2>&1; then
		gh_device_flow auth login --web --git-protocol ssh --skip-ssh-key \
			|| die "gh auth login failed"
		return
	fi

	log "gh already authenticated"

	local have_scopes scope
	have_scopes="$(gh auth status --hostname github.com 2>/dev/null | sed -n "s/.*Token scopes: //p" | tr -d " '")"
	for scope in ${GH_SCOPES//,/ }; do
		case ",$have_scopes," in
			*",$scope,"*) ;;
			*) log "token is missing $scope, refreshing"
			   gh_device_flow auth refresh || die "gh auth refresh failed"
			   return ;;
		esac
	done
}

upload_github_keys() {
	local key="$1"
	local title="$USER@$(uname -n)"

	if gh_has_key user/keys "$key.pub"; then
		log "authentication key already on github"
	else
		log "uploading authentication key"
		gh ssh-key add "$key.pub" --title "$title" --type authentication \
			|| die "could not upload the authentication key"
	fi

	if gh_has_key user/ssh_signing_keys "$key.pub"; then
		log "signing key already on github"
	else
		log "uploading signing key"
		gh ssh-key add "$key.pub" --title "$title" --type signing \
			|| warn "could not upload the signing key, commit signatures stay unverified"
	fi
}

setup_ssh() {
	local key="$HOME/.ssh/id_ed25519"
	local st=0

	have ssh-keygen || die "ssh-keygen missing, install openssh first"

	# An existing key is never regenerated, moved, or overwritten.
	if [[ -f "$key" ]]; then
		log "ssh key present, leaving it untouched: $key"
	else
		log "generating an ed25519 key, this prompts for a passphrase"
		mkdir -p "$HOME/.ssh"
		chmod 700 "$HOME/.ssh"
		ssh-keygen -t ed25519 -a 100 -C "$USER@$(uname -n)" -f "$key"
	fi

	# ssh-add -l exits 1 for an empty agent and 2 when no agent is reachable.
	ssh-add -l >/dev/null 2>&1 || st=$?
	case $st in
		2) log "starting an ssh-agent for this run"
		   eval "$(ssh-agent -s)" >/dev/null
		   ssh-add "$key" || warn "ssh-add failed, continuing" ;;
		1) ssh-add "$key" || warn "ssh-add failed, continuing" ;;
	esac

	if have gh; then
		setup_gh
		upload_github_keys "$key"
	else
		warn "gh not installed, falling back to manual key upload"
		log "add this public key at https://github.com/settings/ssh/new"
		printf '\n%s\n\n' "$(< "$key.pub")"
		read -rp "press enter once GitHub has the key... " _
	fi

	if github_ssh_ok; then
		log "github ssh auth ok"
	else
		die "github refuses the key, check https://github.com/settings/keys"
	fi
}

update_repo() {
	have git || { warn "git not installed, skipping repo update"; return; }
	git -C "$DOTFILES" rev-parse --git-dir >/dev/null 2>&1 \
		|| { warn "$DOTFILES is not a git repo, skipping repo update"; return; }

	log "updating dotfiles repo"
	git -C "$DOTFILES" pull --ff-only \
		|| warn "git pull failed, continuing with the checkout as it is"
}

use_ssh_remote() {
	have git || { warn "git not installed, skipping remote rewrite"; return; }
	git -C "$DOTFILES" rev-parse --git-dir >/dev/null 2>&1 \
		|| { warn "$DOTFILES is not a git repo, skipping remote rewrite"; return; }

	local remote url host path
	for remote in $(git -C "$DOTFILES" remote); do
		log "switch dotfiles repo to ssh remote"
		url="$(git -C "$DOTFILES" remote get-url "$remote")"
		[[ "$url" == https://* || "$url" == http://* ]] || continue

		# https://[user@]host[:port]/owner/repo(.git) -> git@host:owner/repo.git
		path="${url#*://}"
		path="${path#*@}"
		host="${path%%/*}"
		host="${host%%:*}"
		path="${path#*/}"
		[[ -n "$host" && "$path" != "$url" && -n "$path" ]] || {
			warn "cannot parse $remote url, leaving it alone: $url"
			continue
		}
		path="${path%/}"
		path="${path%.git}"

		log "switching $remote to ssh: $url -> git@$host:$path.git"
		git -C "$DOTFILES" remote set-url "$remote" "git@$host:$path.git"
	done
}

install_firewall() {
	have ufw || { warn "ufw not installed, skipping firewall"; return; }

	log "firewall"
	sudo ufw allow ssh
	sudo ufw --force enable
}

install_rustup() {
	log "rustup"
	if have rustup; then
		rustup self update
	else
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --yes
		export PATH="$HOME/.cargo/bin:$PATH"
	fi
}

install_aur_helper() {
	have "$AUR_HELPER" && { log "$AUR_HELPER present"; return; }
	log "building $AUR_HELPER"
	sudo pacman -S --needed --noconfirm base-devel git
	local tmp; tmp="$(mktemp -d)"
	git clone --depth 1 "https://aur.archlinux.org/${AUR_HELPER}.git" "$tmp/$AUR_HELPER"
	( cd "$tmp/$AUR_HELPER" && makepkg -si --noconfirm )
	rm -rf "$tmp"
}

install_pkgs() {
	local repo="$DOTFILES/pkglist.txt"
	local aur="$DOTFILES/aurlist.txt"

	[[ -r "$repo" ]] || die "missing $repo"

	log "installing repo packages"
	grep -v '^\s*\(#\|$\)' "$repo" | sudo pacman -S --needed --noconfirm -

	if [[ -r "$aur" ]] && grep -qv '^\s*\(#\|$\)' "$aur"; then
		install_aur_helper
		log "installing AUR packages"
		grep -v '^\s*\(#\|$\)' "$aur" | "$AUR_HELPER" -S --needed --noconfirm -
	fi
}

# Config dirs are symlinked wholesale, so anything executable (lf previewers,
# hypr exec scripts, ~/.local/bin entries) has to carry the bit in the repo.
mark_scripts_executable() {
	local src
	while IFS= read -r -d '' src; do
		[[ "$(head -c 2 -- "$src")" == '#!' ]] || continue
		[[ -x "$src" ]] && continue
		chmod +x -- "$src"
		echo "  +x ${src#"$DOTFILES"/}"
	done < <(find "$DOTFILES/home" -type f -print0)
}

link_one() {
	local src="$1" dest="$2"
	if [[ -L "$dest" ]]; then
		if (( ! LINKS_FORCE )) && [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
			return
		fi
		rm "$dest"
	elif [[ -e "$dest" ]]; then
		mkdir -p "$backup"
		warn "backing up existing $dest -> $backup/$(basename "$dest")"
		mv "$dest" "$backup/$(basename "$dest")"
	fi

	ln -s "$src" "$dest"
	echo "  linked ${dest#"$HOME"/}"
}

make_user_dirs() {
	local dirs="$DOTFILES/home/config/user-dirs.dirs" name dir
	[[ -r "$dirs" ]] || return 0
	while IFS='=' read -r name dir; do
		[[ $name == XDG_*_DIR ]] || continue
		dir="${dir%\"}"; dir="${dir#\"}"
		case "$dir" in
			'$HOME') continue ;;
			'$HOME'/*) dir="$HOME${dir#\$HOME}" ;;
			/*) ;;
			*) continue ;;
		esac
		[[ -d "$dir" ]] && continue
		mkdir -p "$dir"
		echo "  dir ${dir#"$HOME"/}"
	done < "$dirs"
}

create_zsh_local() {
	local name dest
	for name in zshrc zshenv zprofile; do
		dest="$HOME/.${name}_local"
		[[ -e "$dest" ]] && continue
		: >"$dest"
		echo "  created ${dest#"$HOME"/}"
	done
}

link_dotfiles() {
	local src name dest_name backup
	backup="$HOME/.config-backup-$(date +%Y%m%d%H%M%S)"

	mkdir -p "$HOME/.config" "$HOME/.local/bin"

	mark_scripts_executable

	for src in "$DOTFILES"/home/config/*/; do
		[[ -d "$src" ]] || continue
		link_one "${src%/}" "$HOME/.config/$(basename "$src")"
	done

	for src in "$DOTFILES"/home/config/*; do
		[[ -f "$src" ]] || continue
		link_one "$src" "$HOME/.config/$(basename "$src")"
	done

	for src in "$DOTFILES"/home/*; do
		[[ -f "$src" ]] || continue
		link_one "$src" "$HOME/.$(basename "$src")"
	done

	for src in "$DOTFILES"/home/local/bin/*; do
		[[ -f "$src" ]] || continue
		name="$(basename "$src")"
		dest_name="$HOME/.local/bin/${name%.*}"
		link_one "$src" "${dest_name}"
	done

	make_user_dirs
	create_zsh_local
}

enable_services() {
	local sys=( NetworkManager sshd docker power-profiles-daemon bluetooth )
	local timers=( fwupd-refresh )
	local user=( pipewire pipewire-pulse wireplumber hypridle )
	local s

	log "system services"
	for s in "${sys[@]}"; do
		systemctl list-unit-files "$s.service" >/dev/null 2>&1 || { warn "no $s.service"; continue; }
		sudo systemctl enable --now "$s.service"
	done

	log "system timers"
	for s in "${timers[@]}"; do
		systemctl list-unit-files "$s.timer" >/dev/null 2>&1 || { warn "no $s.timer"; continue; }
		sudo systemctl enable --now "$s.timer"
	done

	# docker group is root-equivalent, takes effect after re-login
	if getent group docker >/dev/null && ! id -nG "$USER" | grep -qw docker; then
		sudo usermod -aG docker "$USER"
		echo "  added $USER to docker group (re-login to apply)"
	fi
	
	sudo systemctl set-default graphical.target

	log "user services"
	for s in "${user[@]}"; do
		systemctl --user list-unit-files "$s.service" >/dev/null 2>&1 || { warn "no user $s.service"; continue; }
		systemctl --user enable --now "$s.service"
	done

	log "dotfiles user units"
	local unit
	for s in "$DOTFILES"/home/systemd/user/*.service; do
		[[ -f "$s" ]] || continue
		unit="$(basename "$s")"
		systemctl --user link --force "$s" >/dev/null
		systemctl --user enable "$unit" >/dev/null
		echo "  enabled $unit"
	done
	systemctl --user daemon-reload
	if systemctl --user is-active -q graphical-session.target; then
		for s in "$DOTFILES"/home/systemd/user/*.service; do
			[[ -f "$s" ]] || continue
			systemctl --user try-restart "$(basename "$s")"
		done
	fi
}

set_dark_mode() {
	log "dark mode"
	have gsettings || { warn "no gsettings, skipping"; return; }
	local schema=org.gnome.desktop.interface
	gsettings list-schemas | grep -qxF "$schema" || {
		warn "no $schema schema (install gsettings-desktop-schemas), skipping"
		return
	}

	local key value
	while read -r key value; do
		gsettings set "$schema" "$key" "$value"
		echo "  $key = $value"
	done <<-'KEYS'
		color-scheme prefer-dark
		gtk-theme Adwaita-dark
		icon-theme Adwaita
		cursor-theme Adwaita
	KEYS
}

args=()
for arg in "$@"; do
	case "$arg" in
		-f|--force) LINKS_FORCE=1 ;;
		*)          args+=("$arg") ;;
	esac
done
set -- ${args[@]+"${args[@]}"}

case "${1:-all}" in
	links|theme|services|shell|firewall) ;;
	*) require_online ;;
esac

case "${1:-all}" in
	pkgs)     install_pkgs ;;
	links)    link_dotfiles ;;
	services) enable_services ;;
	theme)    set_dark_mode ;;
	firewall) install_firewall ;;
	rustup)   install_rustup ;;
	omz)      install_omz ;;
	p10k)     install_p10k ;;
	shell)    set_login_shell ;;
	ssh)      setup_ssh ;;
	gh)       setup_gh ;;
	editor)   install_editor ;;
	sabre)    install_sabre ;;
	omp)      install_omp ;;
	update)   update_repo ;;
	all)
		update_repo
		install_pkgs
		link_dotfiles
		enable_services
		set_dark_mode
		install_firewall
		install_rustup
		install_omz
		install_p10k
		set_login_shell
		setup_ssh
		use_ssh_remote
		install_editor
		install_sabre
		install_omp
		log "done. log out and back in on tty1, uwsm starts Hyprland" ;;
	*)        sed -n '/^# bootstrap.sh:/,/^$/p' "$0"; exit 1 ;;
esac
