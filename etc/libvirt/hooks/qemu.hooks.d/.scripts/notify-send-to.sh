#!/bin/bash
# notify-send-all, notify-send-to, notify-send-others
#
#   Send a pop-up message to all users logged into a machine, asynchronously.
#   Similar to the `wall` command, but for graphical logins (X & Wayland).
#   Results from --action are prefixed with the username and a TAB.
#   Requires notify-send, dbus.
#
# CC-0 2023 hackerb9, inspired by @andy on the Unix & Linux StackExchange.

PATH=/usr/bin:/bin

send-to() {
	local name busroute
	name="$1"
	shift
	busroute="/run/user/$(id -u "$name")/bus" || return 1
	if sudo -u "$name" -- /bin/test -e "$busroute"; then
		sudo -u "$name" \
			PATH="$PATH" \
			DBUS_SESSION_BUS_ADDRESS="unix:path=$busroute" \
			-- \
			notify-send "$@" 2>&1 |
			sed "s/^/$name\t/"
	else
		echo -e "$name\tERROR: No such file $busroute" >&2
		return 1
	fi
}

# Notes
# * Works in Wayland and X (as of 2023).
# * Sends messages to all users asynchronously.
# * Results from --action are prefixed with the username and a TAB.
# * We test if the file "$DBUS_SESSION_BUS_ADDRESS" exists because
#   otherwise `--wait` hangs forever. (libnotify-1.8.1 bug?)
#
# Bugs
# * -?, --help only works if it is the first argument.
#
# * If a user is logged in on a console instead of a graphical session
#   (X or Wayland), then `notify-send` hangs for a long time before
#   timing out on StartServiceByName for org.freedesktop.Notifications.
#   This seems to be a bug in libnotify-1.8.1.
#
#   This bug is also triggered when the user is logged in on both
#   console and graphical sessions and logged into the console first.
#   In that case, not only does notify-send hang, but notifications
#   will not show up at all in the graphical session.
