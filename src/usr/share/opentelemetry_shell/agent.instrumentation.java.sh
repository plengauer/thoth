#!/bin/false

_otel_inject_java() {
  # TODO injection into subprocesses
  if \[ -r /opt/opentelemetry_shell/rootcontextagent.jar ] && \[ -r /opt/opentelemetry_shell/opentelemetry-javaagent.jar ] && \[ "$(_otel_call "$1" --version | \head -n 1 | \cut -d ' ' -f 2 | \cut -d . -f 1)" -ge 8 ]; then
    JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -javaagent:/opt/opentelemetry_shell/opentelemetry-javaagent.jar -javaagent:/opt/opentelemetry_shell/rootcontextagent.jar" _otel_call "$@"
  else
    _otel_call "$@"
  fi
}

_otel_alias_prepend java _otel_inject_java
