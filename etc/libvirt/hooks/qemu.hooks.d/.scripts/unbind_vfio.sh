#!/bin/bash
set -e

## Load the config file
source "/etc/libvirt/hooks/kvm.conf"
source "/etc/libvirt/hooks/qemu.hooks.d/.scripts/notify-send-to.sh"

# Log function
function log {
	echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >>"$LOGFILE"
}

# Notify user on error, log, and exit
function error_exit {
	log "ERROR: $1"
	send-to $NOTIFY_USER -u critical "VM Cleanup Error" "$1"
	exit 1
}

# Check if GPU is held by vfio
GPU_DRIVER=$(basename "$(readlink /sys/bus/pci/devices/$GPU_PCI/driver)" 2>/dev/null || echo "none")
if [ "$GPU_DRIVER" != "vfio-pci" ]; then
	error_exit "dGPU is not used by vfio."
fi

# Unload vfio modules
modprobe -r vfio_pci || error_exit "Failed to unload vfio_pci module"
modprobe -r vfio_iommu_type1 || error_exit "Failed to unload vfio_iommu_type1 module"
modprobe -r vfio || error_exit "Failed to unload vfio module"
log "vfio modules successfully unloaded."

# Reattach GPU to the host
virsh nodedev-reattach pci_${GPU_PCI//[:.]/_} || error_exit "Failed to reattach GPU to host"
virsh nodedev-reattach pci_${AUDIO_PCI//[:.]/_} || error_exit "Failed to reattach GPU audio device"
log "dGPU reattached to host"

# Reload NVIDIA kernel modules
modprobe nvidia || error_exit "Failed to load nvidia module"
modprobe nvidia_modeset || error_exit "Failed to load nvidia_modeset module"
modprobe nvidia_uvm || error_exit "Failed to load nvidia_uvm module"
modprobe nvidia_drm || error_exit "Failed to load nvidia_drm module"
log "nvidia modules successfully loaded"

# Notify successful cleanup
send-to $NOTIFY_USER "VM Cleanup" "VM $1 stopped and dGPU successfully reattached to the host"
log "GPU passthrough to VM $1 cleanup complete."
