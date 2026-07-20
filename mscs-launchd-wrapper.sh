#!/bin/sh
# Wrapper for launchd: starts all servers, traps SIGTERM for graceful stop.
# launchd has no ExecStop equivalent, so we trap signals to stop servers.

# Resolve the mscs binary rather than hardcoding a prefix: Homebrew lives at
# /opt/homebrew on Apple Silicon and /usr/local on Intel.  launchd injects a
# prefix-aware PATH (see com.mscs.all.plist), so prefer PATH, then fall back to
# the known Homebrew locations for when the wrapper is run outside launchd.
MSCS=$(command -v mscs 2>/dev/null)
[ -z "$MSCS" ] && [ -x /opt/homebrew/bin/mscs ] && MSCS=/opt/homebrew/bin/mscs
[ -z "$MSCS" ] && [ -x /usr/local/bin/mscs ] && MSCS=/usr/local/bin/mscs
if [ -z "$MSCS" ]; then
  echo "mscs-launchd-wrapper: could not find the mscs command in PATH" >&2
  exit 1
fi

trap '"$MSCS" stop; exit 0' TERM INT

"$MSCS" start

# Keep process alive so launchd can signal us.
# Using sleep & wait allows the shell to handle signals promptly.
while true; do
  sleep 86400 &
  wait $!
done
