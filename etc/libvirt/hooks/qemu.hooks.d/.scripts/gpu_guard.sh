#!/bin/bash
set -e

## Load config + notifier
source "/etc/libvirt/hooks/kvm.conf"
source "/etc/libvirt/hooks/qemu.hooks.d/.scripts/report.sh"

# Log function
function log {
	echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >>"$LOGFILE"
}

# Notify user, log, and abort the VM start
function error_exit {
	log "ERROR: $1"
	report -u critical "VM Start Aborted" "$1"
	exit 1
}

# Pre-flight guard for managed='yes' passthrough.
#
# libvirt detaches the dGPU by asking the kernel to unbind it from its host
# driver. If a host process still has the GPU open, that unbind BLOCKS in the
# kernel; libvirt's detach then times out and can take virtqemud down with it.
# libvirt does not pre-check userspace GPU usage, so we do it here and fail fast
# & loud BEFORE libvirt touches the PCI device (this is the prepare/begin hook).
#
# Detection: scan /proc/<pid>/fd for a symlink whose TARGET is one of this GPU's
# device nodes. A process cannot use a GPU without holding an fd to one of these,
# so this catches every real user -- CUDA/NVENC via /dev/nvidiaN, OpenGL/Vulkan/
# EGL/display via the per-card DRM card/render nodes -- unlike nvidia-smi, which
# omits some clients. We use `find -lname` (reads the fd symlink only) rather
# than fuser/lsof (which stat the fd targets and so getattr every socket of
# every process -- a pile of needless SELinux denials).

dev_path="/sys/bus/pci/devices/${GPU_PCI}"

# Which host driver currently owns the device?
cur_driver="none"
if [ -L "${dev_path}/driver" ]; then
	cur_driver="$(basename "$(readlink -f "${dev_path}/driver")")"
fi

if [ "$cur_driver" = "vfio-pci" ] || [ "$cur_driver" = "none" ]; then
	# Already on vfio-pci or unbound: no host driver/process can be holding it.
	log "dGPU ${GPU_PCI} is on driver '${cur_driver}'; no host-usage check needed."
else
	# A host driver (nvidia) is bound: collect this GPU's canonical device nodes
	# (fd symlinks resolve to the canonical path, so resolve by-path links too).
	nodes=()

	minor="$(sed -n 's/^Device Minor:[[:space:]]*//p' \
		"/proc/driver/nvidia/gpus/${GPU_PCI}/information" 2>/dev/null || true)"
	if [ -n "$minor" ] && [ -e "/dev/nvidia${minor}" ]; then
		nodes+=("/dev/nvidia${minor}")
	fi

	for kind in card render; do
		bp="/dev/dri/by-path/pci-${GPU_PCI}-${kind}"
		if [ -e "$bp" ]; then
			real="$(readlink -f "$bp" 2>/dev/null || true)"
			[ -n "$real" ] && nodes+=("$real")
		fi
	done

	if [ ${#nodes[@]} -eq 0 ]; then
		log "WARNING: no device nodes found for ${GPU_PCI}; skipping usage check."
	else
		# Build: find /proc/[0-9]*/fd -lname N1 -o -lname N2 ...
		fargs=()
		for n in "${nodes[@]}"; do
			[ ${#fargs[@]} -gt 0 ] && fargs+=( -o )
			fargs+=( -lname "$n" )
		done

		holders="$(find /proc/[0-9]*/fd "${fargs[@]}" 2>/dev/null \
			| sed -n 's#^/proc/\([0-9]\+\)/fd/.*#\1#p' | sort -u | tr '\n' ' ' || true)"

		if [ -n "${holders// /}" ]; then
			names="$(ps -o comm= -p ${holders} 2>/dev/null | sort -u | paste -sd, - || true)"
			error_exit "dGPU ${GPU_PCI} is in use by host process(es) [${names:-unknown}] (PIDs: ${holders}). Close them, then start the VM again."
		fi
		log "dGPU ${GPU_PCI} is idle (checked: ${nodes[*]}); proceeding."
	fi
fi
