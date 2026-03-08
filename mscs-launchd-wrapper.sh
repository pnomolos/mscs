#!/bin/sh
# Wrapper for launchd: starts all servers, traps SIGTERM for graceful stop.
# launchd has no ExecStop equivalent, so we trap signals to stop servers.

trap '/usr/local/bin/mscs stop; exit 0' TERM INT

/usr/local/bin/mscs start

# Keep process alive so launchd can signal us.
# Using sleep & wait allows the shell to handle signals promptly.
while true; do
  sleep 86400 &
  wait $!
done
