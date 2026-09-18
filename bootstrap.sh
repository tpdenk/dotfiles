#!/usr/bin/env bash
#
# bootstrap.sh — take a fresh minimal Arch install to a working desktop.
# Run as your normal user (not root). Idempotent: safe to re-run.
#
#   ./bootstrap.sh            everything
#   ./bootstrap.sh pkgs       just package installs
#   ./bootstrap.sh links      just dotfile symlinks
#   ./bootstrap.sh services   just systemctl enables

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUR_HELPER="${AUR_HELPER:-paru}"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m warn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

[[ $EUID -ne 0 ]] || die "run as your normal user, not root"
have sudo || die "sudo not installed"

install_rustup() {
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --yes
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

link_dotfiles() {
	local src dest name backup
	backup="$HOME/.config-backup-$(date +%Y%m%d%H%M%S)"

	mkdir -p "$HOME/.config"

	for src in "$DOTFILES"/home/config/*/; do
		[[ -d "$src" ]] || continue
		name="$(basename "$src")"
		dest="$HOME/.config/$name"

		if [[ -L "$dest" ]]; then
			[[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]] && continue
			rm "$dest"
		elif [[ -e "$dest" ]]; then
			mkdir -p "$backup"
			warn "backing up existing $dest -> $backup/$name"
			mv "$dest" "$backup/$name"
		fi

		ln -s "${src%/}" "$dest"
		echo "  linked $name"
	done

	for src in "$DOTFILES"/home/*; do
		[[ -f "$src" ]] || continue
		name="$(basename "$src")"
		dest="$HOME/.$name"
		if [[ -L "$dest" ]]; then
			[[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]] && continue
			rm "$dest"
		elif [[ -e "$dest" ]]; then
			mkdir -p "$backup"
			warn "backing up existing $dest -> $backup/.$name"
			mv "$dest" "$backup/.$name"
		fi
		ln -s "$src" "$dest"
		echo "  linked .$name"
	done
}

enable_services() {
	local sys=( NetworkManager sshd )
	local user=( pipewire pipewire-pulse wireplumber )
	local s

	log "system services"
	for s in "${sys[@]}"; do
		systemctl list-unit-files "$s.service" >/dev/null 2>&1 || { warn "no $s.service"; continue; }
		sudo systemctl enable --now "$s.service"
	done

	log "user services"
	for s in "${user[@]}"; do
		systemctl --user list-unit-files "$s.service" >/dev/null 2>&1 || { warn "no user $s.service"; continue; }
		systemctl --user enable --now "$s.service"
	done
}

case "${1:-all}" in
	pkgs)     install_pkgs ;;
	links)    link_dotfiles ;;
	services) enable_services ;;
	all)      install_pkgs; link_dotfiles; enable_services; install_rustup
		log "done. log out and start Hyprland" ;;
	*)        sed -n '3,9p' "$0"; exit 1 ;;
esac