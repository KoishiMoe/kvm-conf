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
	send-to $NOTIFY_USER -u critical "VM Start Error" "$1"
	exit 1
}

# PCIe address validation
function validate_pci_address {
	if [[ ! -d "/sys/bus/pci/devices/$1" ]]; then
		error_exit "Invalid PCIe address: $1"
	fi
}

# Validate GPU PCI addresses
validate_pci_address "$GPU_PCI"
validate_pci_address "$AUDIO_PCI"

log "Starting GPU passthrough preparation."

# Check if GPU is held by vfio (i.e., in use by another VM)
GPU_DRIVER=$(basename "$(readlink /sys/bus/pci/devices/$GPU_PCI/driver)" 2>/dev/null || echo "none")
if [ "$GPU_DRIVER" == "vfio-pci" ]; then
	error_exit "dGPU is already in use by another VM (vfio-pci driver detected)."
fi

# Check if any host process is using the GPU with nvidia-smi
if nvidia-smi | grep -q "No running processes found"; then
	log "No host processes are using the GPU."
else
	error_exit "Host processes are using the GPU (detected by nvidia-smi)."
fi

modprobe -r nvidia_drm || error_exit "Failed to unload nvidia_drm module"
modprobe -r nvidia_modeset || error_exit "Failed to unload nvidia_modeset module"
modprobe -r nvidia_uvm || error_exit "Failed to unload nvidia_uvm module"
modprobe -r nvidia || error_exit "Failed to unload nvidia module"
log "NVIDIA modules successfully unloaded."

# Detach GPU and associated audio from the host
virsh nodedev-detach pci_${GPU_PCI//[:.]/_} || error_exit "Failed to detach GPU from host"
virsh nodedev-detach pci_${AUDIO_PCI//[:.]/_} || error_exit "Failed to detach GPU audio device"
log "GPU and audio devices detached from host."

# Load vfio modules
modprobe vfio || error_exit "Failed to load vfio module"
modprobe vfio_pci || error_exit "Failed to load vfio_pci module"
modprobe vfio_iommu_type1 || error_exit "Failed to load vfio_iommu_type1 module"
log "VFIO modules successfully loaded."

# Notify successful GPU preparation
send-to $NOTIFY_USER "VM Start" "dGPU successfully passed to the VM $1"
log "GPU passthrough to VM $1 preparation complete."
