#!/bin/sh
set -e
if [ "$INPUT___JOB_STATUS" = 'failed' ]; then
  touch /tmp/opentelemetry_shell.github.error
fi
root_pid="$STATE_pid"
kill -USR1 "$root_pid"
while kill -0 "$root_pid" 2> /dev/null; do sleep 1; done
cat "$STATE_log_file" >&2
