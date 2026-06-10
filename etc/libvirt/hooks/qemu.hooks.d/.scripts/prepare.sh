#!/bin/bash

set -e

# The dGPU is bound to vfio-pci / handed back to nvidia by libvirt itself
# (<hostdev managed='yes'>), so the hooks no longer touch the nvidia module.
# But libvirt won't check if the GPU is busy before detaching it, so guard that
# FIRST (aborts the start cleanly if a host app holds the GPU). Then do the
# things libvirt can't: ease hugepage allocation and pin CPUs.
source "/etc/libvirt/hooks/qemu.hooks.d/.scripts/gpu_guard.sh"
source "/etc/libvirt/hooks/qemu.hooks.d/.scripts/better_hugepages.sh"
source "/etc/libvirt/hooks/qemu.hooks.d/.scripts/isolatecpu.sh"
