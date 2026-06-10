#!/bin/bash

set -e

# libvirt rebinds the dGPU to nvidia on shutdown (<hostdev managed='yes'>),
# so we only restore the host CPU allocation here.
source "/etc/libvirt/hooks/qemu.hooks.d/.scripts/reattachcpu.sh"
