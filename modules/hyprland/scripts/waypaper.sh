#!/usr/bin/env bash
if command -v waypaper >/dev/null; then
	waypaper "$@" &
else
	notify-send "Error" "Waypaper is not installed. Please install it to use this script."
fi
