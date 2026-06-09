#!/bin/bash

set -e

## Load the config file (HOST_CPUS lives here, not hardcoded below)
source "/etc/libvirt/hooks/kvm.conf"

systemctl set-property --runtime -- user.slice AllowedCPUs=$HOST_CPUS
systemctl set-property --runtime -- system.slice AllowedCPUs=$HOST_CPUS
systemctl set-property --runtime -- init.scope AllowedCPUs=$HOST_CPUS
