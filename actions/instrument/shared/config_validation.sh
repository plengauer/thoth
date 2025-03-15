#/bin/false
if [ -n "${INPUT___KILL_SWITCH:-}" ]; then
  echo "::warning ::OpenTelemetry for GitHub actions disabled by kill switch!" && exit 0
fi
if [ "${OTEL_LOGS_EXPORTER:-otlp}" != otlp ] && [ "${OTEL_LOGS_EXPORTER:-otlp}" != console ] && [ "${OTEL_LOGS_EXPORTER:-otlp}" != none ]; then
  echo "::error ::OpenTelemetry for GitHub actions only supports otlp exporters ($OTEL_LOGS_EXPORTER). For other exporters, pipe the data through a collector outside of GitHub to translate the data to a different protocol." && false
fi
if [ "${OTEL_METRICS_EXPORTER:-otlp}" != otlp ] && [ "${OTEL_METRICS_EXPORTER:-otlp}" != console ] && [ "${OTEL_METRICS_EXPORTER:-otlp}" != none ]; then
  echo "::error ::OpenTelemetry for GitHub actions only supports otlp exporters ($OTEL_METRICS_EXPORTER). For other exporters, pipe the data through a collector outside of GitHub to translate the data to a different protocol." && false
fi
if [ "${OTEL_TRACES_EXPORTER:-otlp}" != otlp ] && [ "${OTEL_TRACES_EXPORTER:-otlp}" != console ] && [ "${OTEL_TRACES_EXPORTER:-otlp}" != none ]; then
  echo "::error ::OpenTelemetry for GitHub actions only supports otlp exporters ($OTEL_TRACES_EXPORTER). For other exporters, pipe the data through a collector outside of GitHub to translate the data to a different protocol." && false
fi
if [ -z "${OTEL_EXPORTER_OTLP_LOGS_ENDPOINT:-${OTEL_EXPORTER_OTLP_ENDPOINT:-}}" ] && [ -z "${OTEL_LOGS_EXPORTER:-}" ]; then
  export OTEL_LOGS_EXPORTER=none
  echo "::notice ::OpenTelemetry for GitHub actions has no logs export configured. Consult the documentation for instructions."
fi
if [ -z "${OTEL_EXPORTER_OTLP_METRICS_ENDPOINT:-${OTEL_EXPORTER_OTLP_ENDPOINT:-}}" ] && [ -z "${OTEL_METRICS_EXPORTER:-}" ]; then
  export OTEL_METRICS_EXPORTER=none
  echo "::notice ::OpenTelemetry for GitHub actions has no metrics export configured. Consult the documentation for instructions."
fi
if [ -z "${OTEL_EXPORTER_OTLP_TRACES_ENDPOINT:-${OTEL_EXPORTER_OTLP_ENDPOINT:-}}" ] && [ -z "${OTEL_TRACES_EXPORTER:-}" ]; then
  export OTEL_TRACES_EXPORTER=none
  echo "::notice ::OpenTelemetry for GitHub actions has no traces export configured. Consult the documentation for instructions."
fi
if [ "${OTEL_LOGS_EXPORTER:-}" = console ] || [ "${OTEL_METRICS_EXPORTER:-}" = console ] || [ "${OTEL_TRACES_EXPORTER:-}" = console ]; then
  export OTEL_SHELL_SDK_OUTPUT_REDIRECT="${OTEL_SHELL_SDK_OUTPUT_REDIRECT:-/dev/stderr}"
fi
export OTEL_EXPORTER_OTLP_PROTOCOL="${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf}" # default is not uniform, so lets pin it here
export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=delta # only delta makes sense in a volatile environment, user can always reset in specific places
