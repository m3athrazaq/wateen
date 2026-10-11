#!/usr/bin/env bash
# Runs a command, streams its output, and reports the important lines as a
# GitHub annotation so the reason is visible without the raw log.
#   - on failure: an error annotation with error-looking lines and the tail
#   - with REPORT=1: a notice annotation with the tail even on success
# Usage: [REPORT=1] bash ci/run.sh "Title" command [args...]
set -o pipefail
title="$1"
shift
log="$(mktemp)"
"$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}

encode() { sed -e 's/%/%25/g' | sed -e ':a' -e 'N' -e '$!ba' -e 's/\r/%0D/g' -e 's/\n/%0A/g'; }

if [ "$status" -ne 0 ]; then
  { grep -E "error|Error|ERROR|FAIL|Exception|failed|fatal|What went wrong|Expected|Actual" "$log" | tail -n 80; echo "-----"; tail -n 60 "$log"; } > "$log.tail"
  echo "::error title=${title} (exit ${status})::$(encode < "$log.tail")"
elif [ "${REPORT:-0}" = "1" ]; then
  tail -n 60 "$log" > "$log.tail"
  echo "::notice title=${title}::$(encode < "$log.tail")"
fi
exit "$status"
