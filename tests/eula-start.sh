#!/bin/sh
# Tests for the EULA pre-flight check (requireEULA) and the console.out tail
# helper (printServerOutputTail) used to improve the first-start experience.

# Use a dedicated world dir so we don't disturb other tests' testworld data.
eulaworld="mscs-eula-test"
euladir="$WORLDS_LOCATION/$eulaworld"
eulafile="$euladir/eula.txt"
outfile="$euladir/console.out"

# start from a clean slate
rm -rf "$euladir"
mkdir -p "$euladir" || exit 1

# --- requireEULA: eula.txt missing (genuine first start) ---
out=$(requireEULA "$eulaworld" 2>&1)
rc=$?
if [ "$rc" -eq 0 ]; then
    terr "requireEULA should fail (return non-zero) when eula.txt is missing"
fi
if ! printf "%s" "$out" | grep -qs "https://aka.ms/MinecraftEULA"; then
    terr "requireEULA message should include the Mojang EULA URL; got: $out"
fi
if ! printf "%s" "$out" | grep -qs "$eulafile"; then
    terr "requireEULA message should point at the eula.txt path; got: $out"
fi
# It should have created eula.txt (as eula=false) so the path is real.
if [ ! -e "$eulafile" ]; then
    terr "requireEULA should create eula.txt when it is missing"
elif [ "$(getEULAValue "$eulaworld")" != "false" ]; then
    terr "requireEULA should create eula.txt with eula=false, not accept it"
fi

# --- requireEULA: eula.txt present but eula=false ---
printf "eula=false\n" > "$eulafile"
out=$(requireEULA "$eulaworld" 2>&1)
rc=$?
if [ "$rc" -eq 0 ]; then
    terr "requireEULA should fail when eula=false"
fi
# An existing (declined) file must not be silently flipped to true.
if [ "$(getEULAValue "$eulaworld")" != "false" ]; then
    terr "requireEULA must not modify an existing eula=false file"
fi

# --- requireEULA: eula accepted ---
printf "eula=true\n" > "$eulafile"
out=$(requireEULA "$eulaworld" 2>&1)
rc=$?
if [ "$rc" -ne 0 ]; then
    terr "requireEULA should succeed (return 0) when eula=true; rc=$rc"
fi
if [ -n "$out" ]; then
    terr "requireEULA should print nothing when the EULA is accepted; got: $out"
fi

# --- printServerOutputTail: with content ---
rm -f "$outfile"
printf "line one\nEULA marker line\nline three\n" > "$outfile"
out=$(printServerOutputTail "$eulaworld" 2>&1)
if ! printf "%s" "$out" | grep -qs "EULA marker line"; then
    terr "printServerOutputTail should echo console.out content; got: $out"
fi
if ! printf "%s" "$out" | grep -qs "$outfile"; then
    terr "printServerOutputTail should name the console.out path; got: $out"
fi

# --- printServerOutputTail: missing/empty console.out prints nothing ---
rm -f "$outfile"
out=$(printServerOutputTail "$eulaworld" 2>&1)
if [ -n "$out" ]; then
    terr "printServerOutputTail should print nothing when console.out is absent; got: $out"
fi

# clean up
rm -rf "$euladir"
