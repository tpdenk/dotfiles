#!/usr/bin/env bash
#
# bootstrap.sh: take a fresh minimal Arch install to a working desktop.
# Run as your normal user (not root). Idempotent.
#
#   ./bootstrap.sh            everything, in the order below
#   ./bootstrap.sh pkgs       just package installs
#   ./bootstrap.sh links      just dotfile symlinks
#   ./bootstrap.sh services   just systemctl enables
#   ./bootstrap.sh rustup     just the rust toolchain
#   ./bootstrap.sh omz        just oh-my-zsh
#   ./bootstrap.sh ssh        just the ssh key setup
#   ./bootstrap.sh editor     just the editor installation

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUR_HELPER="${AUR_HELPER:-paru}"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m warn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

[[ $EUID -ne 0 ]] || die "run as your normal user, not root"
have sudo || die "sudo not installed"

install_editor() {
	local EDITOR=ed
	local EDITOR_REPO="git@github.com:tpdenk/ed.git"
	pushd $HOME/Development/tpdenk
	if [[ -e "$EDITOR" ]]; then
		pushd "$EDITOR"
		git pull
		popd
	else
		git clone "$EDITOR_REPO"
	fi
	pushd "$EDITOR"
	cargo install --path .
	popd
	popd
}

install_omz() {
	if [[ ! -e "$HOME/.oh-my-zsh" ]]; then
		KEEP_ZSHRC=yes RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	else
		$HOME/.oh-my-zsh/tools/upgrade.sh
	fi
}

github_ssh_ok() {
	local out
	out="$(ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
	[[ "$out" == *"successfully authenticated"* ]]
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

	if github_ssh_ok; then
		log "github ssh auth ok"
		return
	fi

	log "add this public key at https://github.com/settings/ssh/new"
	printf '\n%s\n\n' "$(< "$key.pub")"
	read -rp "press enter once GitHub has the key... " _
	github_ssh_ok || die "github still refuses the key, check https://github.com/settings/keys"
}

install_rustup() {
	log "rustup"
	if have rustup; then
		rustup self update
	else
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --yes
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

link_one() {
	local src="$1" dest="$2"
	if [[ -L "$dest" ]]; then
		[[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]] && return
		rm "$dest"
	elif [[ -e "$dest" ]]; then
		mkdir -p "$backup"
		warn "backing up existing $dest -> $backup/$(basename "$dest")"
		mv "$dest" "$backup/$(basename "$dest")"
	fi

	ln -s "$src" "$dest"
	echo "  linked ${dest#"$HOME"/}"
}

link_dotfiles() {
	local src name backup
	backup="$HOME/.config-backup-$(date +%Y%m%d%H%M%S)"

	mkdir -p "$HOME/.config" "$HOME/.local/bin"

	for src in "$DOTFILES"/home/config/*/; do
		[[ -d "$src" ]] || continue
		link_one "${src%/}" "$HOME/.config/$(basename "$src")"
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
		chmod +x "${dest_name}"
	done
}

enable_services() {
	local sys=( NetworkManager sshd docker )
	local user=( pipewire pipewire-pulse wireplumber hypridle )
	local s

	log "system services"
	for s in "${sys[@]}"; do
		systemctl list-unit-files "$s.service" >/dev/null 2>&1 || { warn "no $s.service"; continue; }
		sudo systemctl enable --now "$s.service"
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
	for s in "$DOTFILES"/home/systemd/user/*.service; do
		[[ -f "$s" ]] || continue
		systemctl --user enable "$s"
		echo "  enabled $(basename "$s")"
	done
	systemctl --user daemon-reload
	if systemctl --user is-active -q graphical-session.target; then
		for s in "$DOTFILES"/home/systemd/user/*.service; do
			[[ -f "$s" ]] || continue
			systemctl --user try-restart "$(basename "$s")"
		done
	fi
}

case "${1:-all}" in
	pkgs)     install_pkgs ;;
	links)    link_dotfiles ;;
	services) enable_services ;;
	rustup)   install_rustup ;;
	omz)      install_omz ;;
	ssh)      setup_ssh ;;
	editor)   install_editor ;;
	all)
		install_pkgs
		link_dotfiles
		enable_services
		install_rustup
		install_omz
		setup_ssh
		install_editor
		log "done. log out and back in on tty1, uwsm starts Hyprland" ;;
	*)        sed -n '3,12p' "$0"; exit 1 ;;
esac
