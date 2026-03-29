#!/bin/sh
# Tests for platform abstraction helper functions.
# These tests verify behavior on the current platform and also test
# that IS_MACOS override works for cross-platform validation.

# --- sha1_hash ---
# Create a known test file and verify the hash.
SHA_TEST_FILE="/tmp/mscs-sha1-test.$$"
printf "hello world\n" > "$SHA_TEST_FILE"
EXPECTED_SHA1="22596363b3de40b06f981fb85d82312e8c0ed511"

got=$(sha1_hash "$SHA_TEST_FILE")
if [ "$got" != "$EXPECTED_SHA1" ]; then
  terr "sha1_hash failed: got '$got' want '$EXPECTED_SHA1'"
fi
rm -f "$SHA_TEST_FILE"

# --- date_to_epoch / epoch_to_datetime ---
# Test with a known timestamp. Use a format both platforms can parse.
# 2024-01-01T00:00:00+0000 = epoch 1704067200
TEST_DATE="2024-01-01T00:00:00+0000"
EXPECTED_EPOCH="1704067200"

got=$(date_to_epoch "$TEST_DATE")
if [ "$got" != "$EXPECTED_EPOCH" ]; then
  terr "date_to_epoch failed: got '$got' want '$EXPECTED_EPOCH'"
fi

# epoch_to_datetime should round-trip back to something parseable.
got_dt=$(epoch_to_datetime "$EXPECTED_EPOCH")
if [ -z "$got_dt" ]; then
  terr "epoch_to_datetime returned empty string for epoch $EXPECTED_EPOCH"
fi
# Verify the round-trip: converting the output back should give the same epoch.
got_rt=$(date_to_epoch "$got_dt")
if [ "$got_rt" != "$EXPECTED_EPOCH" ]; then
  terr "epoch_to_datetime round-trip failed: epoch->dt->epoch gave '$got_rt' want '$EXPECTED_EPOCH'"
fi

# --- suggest_install ---
# Verify output varies by IS_MACOS.
ORIG_IS_MACOS="$IS_MACOS"

IS_MACOS=0
got=$(suggest_install "test-pkg" "brew install test-pkg" 2>&1)
if ! printf "%s" "$got" | grep -q "apt-get install test-pkg"; then
  terr "suggest_install (Linux) failed: got '$got'"
fi

IS_MACOS=1
got=$(suggest_install "test-pkg" "brew install test-pkg" 2>&1)
if ! printf "%s" "$got" | grep -q "brew install test-pkg"; then
  terr "suggest_install (macOS) failed: got '$got'"
fi

IS_MACOS="$ORIG_IS_MACOS"

# --- DEFAULT_MIRROR_PATH ---
# Verify mirror path defaults are platform-aware.
ORIG_IS_MACOS="$IS_MACOS"

# We can't re-evaluate the global variable assignment here, but we can
# verify the value is consistent with the current platform.
if [ "$IS_MACOS" -eq 1 ]; then
  if [ "$DEFAULT_MIRROR_PATH" != "/tmp/mscs" ]; then
    terr "DEFAULT_MIRROR_PATH on macOS: got '$DEFAULT_MIRROR_PATH' want '/tmp/mscs'"
  fi
else
  if [ "$DEFAULT_MIRROR_PATH" != "/dev/shm/mscs" ]; then
    terr "DEFAULT_MIRROR_PATH on Linux: got '$DEFAULT_MIRROR_PATH' want '/dev/shm/mscs'"
  fi
fi

IS_MACOS="$ORIG_IS_MACOS"

# --- DEFAULT_LOCATION ---
# Verify the location default is platform-aware.
if [ "$IS_MACOS" -eq 1 ]; then
  if [ -d /opt/homebrew ]; then
    EXPECTED_LOCATION="/opt/homebrew/var/mscs"
  else
    EXPECTED_LOCATION="/usr/local/var/mscs"
  fi
  if [ "$DEFAULT_LOCATION" != "$EXPECTED_LOCATION" ]; then
    terr "DEFAULT_LOCATION on macOS: got '$DEFAULT_LOCATION' want '$EXPECTED_LOCATION'"
  fi
fi
