#!/bin/bash
# report: status reporter for the libvirt GPU-passthrough hooks.
#
# The original helper ran `sudo -u <user> notify-send` to pop a desktop
# notification. Libvirt runs hooks inside the virtqemud_t SELinux domain, so
# that `sudo` forced virtqemud_t to exec sudo/unix_chkpwd and read /etc/shadow,
# contact logind, and connect to the user session bus — a pile of denials and a
# genuine privilege-escalation smell for a root hook.
#
# We don't need a popup to know a VM (un)bound the GPU. Write to stderr instead:
# libvirt captures hook stderr into the daemon journal, so messages land in
#   journalctl -u virtqemud -t <vm>
# with no sudo, no /etc/shadow, no cross-domain D-Bus — i.e. no SELinux holes.
#
# Signature (the leading <user> arg is gone now that NOTIFY_USER was dropped):
#   report [-u <urgency>] <summary> <body...>

report() {
	if [ "${1:-}" = "-u" ]; then shift 2; fi   # drop an optional notify-send "-u <urgency>"
	local summary="${1:-}"; shift || true
	printf 'gpu-passthrough: %s: %s\n' "$summary" "$*" >&2
}
