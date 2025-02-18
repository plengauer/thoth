#!/bin/sh
if [ "$(cat /tmp/opentelemetry_shell_action_name 2> /dev/null)" = "$GITHUB_ACTION" ]; then exec "$@"; fi
_OTEL_GITHUB_STEP_AGENT_INSTRUMENTATION_FILE=/usr/share/opentelemetry_shell/agent.instrumentation.shells.sh
_OTEL_GITHUB_STEP_ACTION_TYPE=shell
_OTEL_GITHUB_STEP_ACTION_PHASE=main
. decorate_action.sh # TODO where to take path
