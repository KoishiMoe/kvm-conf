#!/bin/bash

set -e

source "/etc/libvirt/hooks/qemu.hooks.d/.scripts/better_hugepages.sh"
source "/etc/libvirt/hooks/qemu.hooks.d/.scripts/bind_vfio.sh"
source "/etc/libvirt/hooks/qemu.hooks.d/.scripts/isolatecpu.sh"
