#!/bin/bash

set -e

## Load the config file (ALL_CPUS lives here, not hardcoded below)
source "/etc/libvirt/hooks/kvm.conf"

systemctl set-property --runtime -- user.slice AllowedCPUs=$ALL_CPUS
systemctl set-property --runtime -- system.slice AllowedCPUs=$ALL_CPUS
systemctl set-property --runtime -- init.scope AllowedCPUs=$ALL_CPUS
