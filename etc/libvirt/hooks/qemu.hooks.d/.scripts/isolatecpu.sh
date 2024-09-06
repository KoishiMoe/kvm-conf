#!/bin/bash

set -e

systemctl set-property --runtime -- user.slice AllowedCPUs=0,1,2,3
systemctl set-property --runtime -- system.slice AllowedCPUs=0,1,2,3
systemctl set-property --runtime -- init.scope AllowedCPUs=0,1,2,3
