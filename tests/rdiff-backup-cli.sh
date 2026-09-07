#!/bin/sh
# Tests for the rdiff-backup command line interface detection.
# rdiff-backup 2.1 replaced the option based interface with an action based
# one; the legacy interface still works in 2.2 but warns on every call.

RB_STUB="/tmp/mscs-rdiff-backup-stub.$$"
ORIG_RDIFF_BACKUP="$RDIFF_BACKUP"
RDIFF_BACKUP="$RB_STUB"

# Report the interface msctl would use for the given --version output.
detected_cli() {
  printf '#!/bin/sh\necho "%s"\n' "$1" > "$RB_STUB"
  chmod +x "$RB_STUB"
  RDIFF_BACKUP_CLI=
  RDIFF_BACKUP_GLOBAL_OPTIONS=
  rdiffBackupDetect
  echo "$RDIFF_BACKUP_CLI $RDIFF_BACKUP_GLOBAL_OPTIONS"
}

for case in \
  "rdiff-backup 2.0.5|legacy " \
  "rdiff-backup 2.1.0|new --api-version 201" \
  "rdiff-backup 2.2.6|new --api-version 201" \
  "rdiff-backup 3.0.0|new " \
  "no version here|legacy "
do
  version=${case%%|*}
  expected=${case#*|}
  got=$(detected_cli "$version")
  if [ "$got" != "$expected" ]; then
    terr "rdiffBackupDetect for '$version': got '$got' want '$expected'"
  fi
done

rm -f "$RB_STUB"
RDIFF_BACKUP="$ORIG_RDIFF_BACKUP"
RDIFF_BACKUP_CLI=
RDIFF_BACKUP_GLOBAL_OPTIONS=

# --- rdiffBackupFailed ---
# rdiff-backup 2.1 returns a bit field: 1 and 4 are errors, 2 and 8 are only
# warnings. "No increment is older than" exits 2 and must not read as failure.
for case in "0|no" "1|yes" "2|no" "3|yes" "4|yes" "8|no" "10|no" "12|yes"; do
  code=${case%%|*}
  expected=${case#*|}
  if rdiffBackupFailed "$code"; then got="yes"; else got="no"; fi
  if [ "$got" != "$expected" ]; then
    terr "rdiffBackupFailed $code: got '$got' want '$expected'"
  fi
done
