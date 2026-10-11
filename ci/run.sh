#!/usr/bin/env bash
# Runs a command, streams its output, and on failure reports the last lines
# as a GitHub error annotation so the reason is visible without the raw log.
# Usage: bash ci/run.sh "Title" command [args...]
set -o pipefail
title="$1"
shift
log="$(mktemp)"
"$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
if [ "$status" -ne 0 ]; then
  # Prefer lines that look like errors; fall back to the tail.
  { grep -E "error|Error|ERROR|FAIL|Exception|failed|fatal|What went wrong" "$log" | tail -n 60; echo "-----"; tail -n 60 "$log"; } > "$log.tail"
  body="$(sed -e 's/%/%25/g' "$log.tail" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\r/%0D/g' -e 's/\n/%0A/g')"
  echo "::error title=${title} (exit ${status})::${body}"
fi
exit "$status"
