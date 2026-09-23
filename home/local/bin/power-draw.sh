#!/usr/bin/env sh
#
# power-draw: one line per power sensor the kernel publishes, as
#
#   <microwatts>\t<chip>\t<sensor label>\t<kind>\t<device name>\t<device node>
#
# kind is one of cpu, apu (a GPU sharing the CPU's package, so its figure
# contains the CPU's), cores, igpu, npu and soc (an APU package split into its
# parts), gpu, disk, wifi, net, charger, system or other. Device
# name and node are best effort; empty means the display side falls back to
# the driver name.
#
# hwmon is the only source a normal user can read: /sys/class/powercap is
# root-only (CVE-2020-8694), so a CPU appears here only when a driver
# republishes RAPL, as zenpower/amd_energy do.
#
# SYSFS points at another tree, to exercise this against absent hardware.
SYSFS=${SYSFS:-/sys}

# amdgpu exposes a vddnb (SoC) rail only on integrated graphics
is_apu() {
	for labelfile in "$1"/in*_label; do
		[ -r "$labelfile" ] || continue
		[ "$(cat "$labelfile")" = "vddnb" ] && return 0
	done
	return 1
}

classify() {
	case $1 in
	zenpower | zenergy | k10temp | coretemp | amd_energy | intel-rapl*) echo cpu ;;
	amdgpu | radeon)
		if is_apu "$2"; then echo apu; else echo gpu; fi
		;;
	nvidia* | i915 | xe) echo gpu ;;
	nvme* | drivetemp) echo disk ;;
	iwlwifi* | mt79* | ath1* | ath9* | ath10* | ath11* | brcm*) echo wifi ;;
	r8169* | igc* | igb* | e1000* | tg3*) echo net ;;
	acpi_power_meter | power_meter) echo system ;;
	*) echo other ;;
	esac
}

cpu_model() {
	awk -F': ' '/^model name/ { print $2; exit }' /proc/cpuinfo
}

# walk up from the hwmon device until something looks like a PCI address
pci_slot() {
	dir=$(readlink -f "$1/device" 2>/dev/null) || return 1
	while [ -n "$dir" ] && [ "$dir" != "/" ]; do
		case ${dir##*/} in
		*:*:*.[0-9])
			echo "${dir##*/}"
			return 0
			;;
		esac
		dir=${dir%/*}
	done
	return 1
}

# pciutils when installed, else the database it would have read
pci_name() {
	if command -v lspci >/dev/null 2>&1; then
		lspci -mm -s "$1" 2>/dev/null | awk -F'"' 'NR == 1 { print $6 }'
		return
	fi

	ids=/usr/share/hwdata/pci.ids
	[ -r "$ids" ] || return
	vendor=$(cat "$SYSFS/bus/pci/devices/$1/vendor" 2>/dev/null) || return
	device=$(cat "$SYSFS/bus/pci/devices/$1/device" 2>/dev/null) || return

	# vendors sit at column 0, their devices one tab in
	awk -v vendor="${vendor#0x}" -v device="${device#0x}" '
		/^[0-9a-f][0-9a-f][0-9a-f][0-9a-f]  / { current = $1; next }
		current == vendor && /^\t[0-9a-f][0-9a-f][0-9a-f][0-9a-f]  / {
			id = $1
			sub(/^\t[0-9a-f]+  /, "")
			if (id == device) { print; exit }
		}
	' "$ids"
}

# storage keeps its model a few levels above the hwmon node
disk_model() {
	dir=$(readlink -f "$1/device" 2>/dev/null) || return
	while [ -n "$dir" ] && [ "$dir" != "/" ]; do
		if [ -r "$dir/model" ]; then
			printf '%s\t%s\n' "$(sed -e 's/[[:space:]]\{1,\}$//' "$dir/model")" "${dir##*/}"
			return
		fi
		dir=${dir%/*}
	done
}

apu_breakdown() {
	metrics=$1/device/gpu_metrics
	[ -r "$metrics" ] || return
	od -An -tu2 -v -N136 "$metrics" 2>/dev/null | awk \
		-v chip="$2" -v name="$3" '
		{ for (i = 1; i <= NF; i++) w[n++] = $i }
		function u32(at) { return w[at / 2] + w[at / 2 + 1] * 65536 }
		function row(mw, label, kind) {
			printf "%d\t%s\t%s\t%s\t%s\t\n", mw * 1000, chip, label, kind, name
		}
		END {
			# header: u16 size, u8 format, u8 content; 3 | 0 << 8 is v3.0
			if (n < 68 || w[1] != 3) exit
			socket = u32(112); npu = w[58]; gfx = u32(124); cores = u32(132)
			rest = socket - cores - gfx - npu
			row(cores, "cores", "cores")
			row(gfx, "gfx", "igpu")
			row(npu, "ipu", "npu")
			row(rest > 0 ? rest : 0, "soc", "soc")
		}'
}

for hwmon in "$SYSFS"/class/hwmon/hwmon*; do
	chip=$(cat "$hwmon/name" 2>/dev/null) || continue
	kind=$(classify "$chip" "$hwmon")
	name=
	node=

	case $kind in
	cpu | apu)
		name=$(cpu_model)
		[ "$kind" = apu ] && apu_breakdown "$hwmon" "$chip" "$name"
		;;
	gpu | wifi | net)
		slot=$(pci_slot "$hwmon") && name=$(pci_name "$slot")
		node=$slot
		;;
	disk)
		model=$(disk_model "$hwmon")
		name=${model%%	*}
		node=${model##*	}
		;;
	esac

	# a chip reporting both an average and an instantaneous value for one
	# sensor is listed once, preferring the average
	for sensor in "$hwmon"/power*_average "$hwmon"/power*_input; do
		[ -r "$sensor" ] || continue

		base=${sensor##*/}
		base=${base%_*}
		case $sensor in
		*_input) [ -r "$hwmon/${base}_average" ] && continue ;;
		esac

		microwatts=$(cat "$sensor" 2>/dev/null) || continue
		label=$(cat "$hwmon/${base}_label" 2>/dev/null)

		printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
			"$microwatts" "$chip" "${label:-$base}" "$kind" "$name" "$node"
	done
done

# Chargers and docks are power_supply devices reporting volts and amps rather
# than watts. Batteries are left to UPower.
#
# A supply feeding a device *from* this machine is skipped: a USB-C source
# port publishes what it is willing to deliver, not what is taken, and reports
# 0 V as often as not because UCSI only refreshes it around a negotiation.
# Such a port leaves `online` at 0 even while supplying, which is what
# separates it from a charger feeding this machine.
for supply in "$SYSFS"/class/power_supply/*; do
	[ -d "$supply" ] || continue

	type=$(cat "$supply/type" 2>/dev/null) || continue
	case $type in
	Battery | UPS) continue ;;
	Mains | USB*) kind=charger ;;
	*) kind=other ;;
	esac

	[ "$(cat "$supply/online" 2>/dev/null || echo 1)" = "1" ] || continue

	if [ -r "$supply/power_now" ]; then
		microwatts=$(cat "$supply/power_now" 2>/dev/null) || continue
	else
		# microvolts * microamps overflows a 32-bit shell; mV * mA is
		# exactly microwatts
		microvolts=$(cat "$supply/voltage_now" 2>/dev/null) || continue
		microamps=$(cat "$supply/current_now" 2>/dev/null) || continue
		microwatts=$(( microvolts / 1000 * (microamps / 1000) ))
	fi

	[ "${microwatts:-0}" -gt 0 ] || continue

	node=${supply##*/}
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$microwatts" "$node" "$type" "$kind" "" "$node"
done

# NVIDIA has no hwmon power sensor, only nvidia-smi, which wakes a
# runtime-suspended GPU; so only query GPUs already awake.
command -v nvidia-smi >/dev/null 2>&1 || exit 0
for gpu in "$SYSFS"/bus/pci/drivers/nvidia/*:*:*.[0-9]; do
	[ -e "$gpu" ] || continue
	[ "$(cat "$gpu/power/runtime_status" 2>/dev/null)" = active ] || continue

	slot=${gpu##*/}
	watts=$(nvidia-smi -i "$slot" --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null) || continue
	# "[N/A]" on boards whose firmware hides the reading
	microwatts=$(printf '%s' "$watts" | awk '$1 ~ /^[0-9.]+$/ { printf "%d", $1 * 1e6 }')
	[ -n "$microwatts" ] || continue

	printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$microwatts" nvidia power gpu "$(pci_name "$slot")" "$slot"
done
