#!/bin/bash

set -e

source "/etc/libvirt/hooks/qemu.hooks.d/.scripts/unbind_vfio.sh"
source "/etc/libvirt/hooks/qemu.hooks.d/.scripts/reattachcpu.sh"
