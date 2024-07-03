#!/bin/false

# write | netcat 127.0.0.1 8080 | read
# netcat -l -p 8080 | read
# netcat -l -p 8080 -e respond

# Limitations:
# *) first line will be buffered on both request and response, so if there is a prompt/challenge like protocol that works on single byte sequences without linefeed, that case will deadlock
# *) as soon as a request or response (individually) looks like HTTP, the instrumentation assumes its valid HTTP exchange and may deadlock if its not. meaning, lets imagine that there is netcat that always response with a valid HTTP response without actually receiving an HTTP request, or not respecting the protocol.

_otel_inject_netcat() {
  local name=send/receive
  # if \[ "$(\readlink -f /proc/$$/fd/0)" != /dev/null ]; then local is_reading=1; else local is_reading=0; fi # TODO this check the stdin of the shell process, not the current context
  # if \[ "$(\readlink -f /proc/$$/fd/1)" != /dev/null ]; then local is_writing=1; else local is_writing=0; fi # TODO this check the stdout of the shell process, not the current context
  # if \[ "$is_reading" = 0 ] && \[ "$is_writing" = 0 ]; then local name=connect; fi
  # if \[ "$is_reading" = 0 ] && \[ "$is_writing" = 1 ]; then local name=receive; fi
  # if \[ "$is_reading" = 1 ] && \[ "$is_writing" = 0 ]; then local name=send; fi
  # if \[ "$is_reading" = 1 ] && \[ "$is_writing" = 1 ]; then local name=send/receive; fi
  if _otel_args_contains -l "$@" || _otel_args_contains --listen "$@" || _otel_args_contains -e "$@" || _otel_args_contains --exec "$@" || _otel_args_contains -c "$@" || _otel_args_contains --sh-exec "$@"; then
    if _otel_args_contains -e || _otel_args_contains --exec || _otel_args_contains -c || _otel_args_contains --sh-exec; then
      \eval _otel_call "$(_otel_inject_netcat_listen_and_respond_args "$@")"
    else
      local span_handle_file="$(\mktemp -u)"
      local exit_code_file="$(\mktemp)"
      \echo 0 > "$exit_code_file"
      local span_handle="$(otel_span_start CONSUMER "$name")"
      otel_span_activate "$span_handle"
      _otel_netcat_parse_args "$span_handle" "$@" > /dev/null
      _otel_netcat_parse_response 1 "$span_handle_file" | { _otel_call "$@" || \echo "$?" > "$exit_code_file"; } | _otel_netcat_parse_request 1 "$span_handle_file" "$@"
      otel_span_deactivate "$span_handle"
      otel_span_end "$span_handle"
      local exit_code="$(\cat "$exit_code_file")"
      \rm "$span_handle_file" "$exit_code_file" 2> /dev/null
      return "$exit_code"
    fi
  else
    local span_handle_file="$(\mktemp -u)"
    local exit_code_file="$(\mktemp)"
    \echo 0 > "$exit_code_file"
    local span_handle="$(otel_span_start PRODUCER "$name")"
    otel_span_activate "$span_handle"
    _otel_netcat_parse_args "$span_handle" "$@" > /dev/null
    _otel_netcat_parse_request 0 "$span_handle_file" "$@" | { _otel_call "$@" || \echo "$?" > "$exit_code_file"; } | _otel_netcat_parse_response 0 "$span_handle_file"
    otel_span_deactivate "$span_handle"
    otel_span_end "$span_handle"
    local exit_code="$(\cat "$exit_code_file")"
    \rm "$span_handle_file" "$exit_code_file" 2> /dev/null
    return "$exit_code"
  fi
}

_otel_inject_netcat_listen_and_respond_args() {
  _otel_escape_arg "$1"
  shift
  while \[ "$#" -gt 0 ]; do
    \echo -n ' '
    if (\[ "$1" = -e ] || \[ "$1" = --exec ] || \[ "$1" = -c ] || \[ "$1" = --sh-exec ]) && \[ "$#" -gt 1 ]; then
      local command="$2"; shift; shift
      # TODO the following injection doesnt maintain the exit code, does it matter though? is it important for netcat?
      _otel_escape_args -c "OTEL_SHELL_AUTO_INJECTED=FALSE
span_handle_file=\"\$(mktemp)\"
span_handle_file_inner=\"\$(mktemp -u)\"
mkfifo \"\$span_handle_file_inner\"
(tee \"\$span_handle_file_inner\" > \"\$span_handle_file\" &)
. otel.sh
span_handle=\"\$(otel_span_start CONSUMER send/receive)\"
_otel_netcat_parse_args \"\$span_handle\" $(_otel_escape_args "$@") > /dev/null
_otel_netcat_parse_request 1 \"\$span_handle_file\" $(_otel_escape_args "$@") | { local span_handle=\"\$(\cat \"\$span_handle_file_inner\")\"; if \[ \"\$span_handle\" -ge 0 ]; then otel_span_activate \"\$span_handle\"; fi; $command; } | _otel_netcat_parse_response 1 \"\$span_handle_file\"
otel_span_end \"\$span_handle\"
\rm \"\$span_handle_file\" \"\$span_handle_file_inner\" 2> /dev null"
    else
      _otel_escape_arg "$1"; shift
    fi
  done
}

_otel_netcat_parse_request() {
  local is_server_side="$1"; shift
  local span_handle_file="$1"; shift
  if ! read -r line; then
    \echo -1 > "$span_handle_file"
    \echo -n "$line"
    return 0
  fi
  if ! _otel_string_starts_with "$(\printf '%s' "$line" | \cut -sd ' ' -f 3)" HTTP/; then
    \echo -1 > "$span_handle_file"
    \echo "$line"
    \cat
    return 0
  fi
  local line="$(\printf '%s' "$line" | \tr -d '\r')"
  local protocol="$(\printf '%s' "$line" | \cut -sd ' ' -f 3)"
  local method="$(\printf '%s' "$line" | \cut -sd ' ' -f 1)"
  local path_and_query="$(\printf '%s' "$line" | \cut -sd ' ' -f 2)"
  local headers="$(\mktemp)"
  while read -r line; do
    local line="$(\printf '%s' "$line" | \tr -d '\r')"
    if \[ "${#line}" = 0 ]; then break; fi
    \echo "$line" >> "$headers"
    if \[ "$_is_server_side" = 1 ]; then
      local key="$(\printf '%s' "$line" | \cut -d ' ' -f 1 | \tr -d : | \tr '[:upper:]' '[:lower:]')"
      local value="$(\printf '%s' "$line" | \cut -d ' ' -f 2-)"
      # TODO save old traceparent and tracestate
      if \[ "$key" = traceparent ]; then export TRACEPARENT="$value"; fi
      if \[ "$key" = tracestate ]; then export TRACESTATE="$value"; fi
    fi
  done
  if \[ "$is_server_side" = 1 ]; then local span_handle="$(otel_span_start SERVER "$method")"; else local span_handle="$(otel_span_start CLIENT "$method")"; fi
  \echo "$span_handle" > "$span_handle_file"
  # TODO add span link with old traceparent and tracestate
  local host_and_port="$(_otel_netcat_parse_args "$span_handle" "$@")"
  otel_span_attribute_typed "$span_handle" string network.protocol.name="$(\printf '%s' "$protocol" | \cut -d / -f 1 | \tr '[:upper:]' '[:lower:]')"
  otel_span_attribute_typed "$span_handle" string network.protocol.version="$(\printf '%s' "$protocol" | \cut -d / -f 2-)"
  otel_span_attribute_typed "$span_handle" string url.full="$(\printf '%s' "$protocol" | \cut -d / -f 1 | \tr '[:upper:]' '[:lower:]')://$host_and_port$path_and_query"
  otel_span_attribute_typed "$span_handle" string url.path="$(\printf '%s' "$path_and_query" | \cut -d ? -f 1)"
  otel_span_attribute_typed "$span_handle" string url.query="$(\printf '%s' "$path_and_query" | \cut -sd ? -f 2-)"
  otel_span_attribute_typed "$span_handle" string url.scheme="$(\printf '%s' "$protocol" | \cut -d / -f 1 | \tr '[:upper:]' '[:lower:]')"
  otel_span_attribute_typed "$span_handle" string http.request.method="$method"
  otel_span_attribute_typed "$span_handle" string user_agent.original=netcat
  \echo -e "$method $path_and_query $protocol\r"
  if \[ "$_is_server_side" = 0 ]; then
    otel_span_activate "$span_handle"
    \echo -e "traceparent: $TRACEPARENT\r"
    \echo -e "tracestate: $TRACESTATE\r"
    otel_span_deactivate "$span_handle"
  fi
  while read -r line; do
    \echo -e "$line\r"
    local key="$(\printf '%s' "$line" | \cut -d ' ' -f 1 | \tr -d : | \tr '[:upper:]' '[:lower:]')"
    local value="$(\printf '%s' "$line" | \cut -d ' ' -f 2-)"
    otel_span_attribute_typed "$span_handle" string[1] http.request.header."$key"="$value"
  done < "$headers"
  \echo -e '\r'
  local body_size_pipe="$(\mktemp -u)"
  local body_size_file="$(\mktemp)"
  \mkfifo "$body_size_pipe"
  \wc -c < "$body_size_pipe" > "$body_size_file" &
  local pid="$!"
  \tee "$body_size_pipe"
  \wait "$pid"
  otel_span_attribute_typed "$span_handle" int http.request.body.size="$(\cat "$body_size_file")"
  \rm "$headers" "$body_size_file" "$body_size_pipe" 2> /dev/null
}

_otel_netcat_parse_response() {
  local is_server_side="$1"; shift
  local span_handle_file="$1"; shift
  if ! read -r line; then
    \echo -n "$line"
    return 0
  fi
  if ! _otel_string_starts_with "$line" HTTP/; then
    \echo "$line"
    \cat
    return 0
  fi
  local span_handle="$(\cat "$span_handle_file")"
  if \[ -z "$span_handle" ] || ! \[ "$span_handle" -ge 0 ]; then
    \echo "$line"
    \cat
    return 0
  fi
  local line="$(\printf '%s' "$line" | \tr -d '\r')"
  local protocol="$(\printf '%s' "$line" | \cut -sd ' ' -f 1)"
  local response_code="$(\printf '%s' "$line" | \cut -sd ' ' -f 2)"
  otel_span_attribute_typed "$span_handle" int http.response.status_code="$response_code"
  if \[ "$is_server_side" = 0 ] && \[ "$response_code" -ge 400 ]; then otel_span_error "$span_handle"; fi
  if \[ "$is_server_side" = 1 ] && \[ "$response_code" -ge 500 ]; then otel_span_error "$span_handle"; fi
  \echo -e "$line\r"
  while read -r line; do
    local line="$(\printf '%s' "$line" | \tr -d '\r')"
    \echo -e "$line\r"
    if \[ "${#line}" = 0 ]; then break; fi
    local key="$(\printf '%s' "$line" | \cut -d ' ' -f 1 | \tr -d : | \tr '[:upper:]' '[:lower:]')"
    local value="$(\printf '%s' "$line" | \cut -d ' ' -f 2-)"
    otel_span_attribute_typed "$span_handle" string[1] http.response.header."$key"="$value"
  done
  local body_size_pipe="$(\mktemp -u)"
  local body_size_file="$(\mktemp)"
  \mkfifo "$body_size_pipe"
  \wc -c < "$body_size_pipe" > "$body_size_file" &
  local pid="$!"
  \tee "$body_size_pipe"
  \wait "$pid"
  otel_span_attribute_typed "$span_handle" int http.response.body.size="$(\cat "$body_size_file")"
  \rm "$body_size_file" "$body_size_pipe" 2> /dev/null
  otel_span_end "$span_handle"
}

_otel_netcat_parse_args() {
  local span_handle="$1"; shift
  local transport=tcp
  local host=""
  local ip=""
  local port=31337
  local is_listening=0
  shift
  while \[ "$#" -gt 0 ]; do
    if \[ "$1" = -l ] || \[ "$1" = --listen ]; then
      local is_listening=1
    elif \[ "$1" = -u ] || \[ "$1" = --udp ]; then
      local transport=udp
    elif \[ "$1" = --sctp ]; then
      local transport=sctp
    elif \[ "$1" = -p ] && \[ "$#" -ge 2 ]; then
      local port="$2"
      shift
    elif _otel_string_starts_with "$1" - && \[ "$#" -gt 1 ] && _otel_is_netcat_arg_arg "$1"; then
      shift
    elif _otel_string_starts_with "$1" -; then
      \true
    else
      if \[ "$1" -eq "$1" ] 2> /dev/null; then
        local port="$1"
      elif _otel_is_ip "$1"; then
        local ip="$1"
        local host="$1"
      else
        local host="$1"
      fi
    fi
    shift
  done
  otel_span_attribute_typed "$span_handle" string network.transport="$transport"
  if \[ "$is_listening" = 0 ]; then
    otel_span_attribute_typed "$span_handle" string network.peer.address="$ip"
    otel_span_attribute_typed "$span_handle" int network.peer.port="$port"
  fi
  otel_span_attribute_typed "$span_handle" string server.address="$host"
  otel_span_attribute_typed "$span_handle" int server.port="$port"
  \echo "$host:$port"
}

_otel_is_ip() {
  case "$1" in
    *.*.*.*)
      for part in $(\echo "$1" | \tr '.' ' '); do
        case "$part" in
          ""|*[!0-9]*) return 1;;
        esac
      done
      return 0;;
    *:*:*:*:*:*:*:*)
      for part in $(\echo "$1" | \tr ':' ' '); do
        case "$part" in
          ""|*[!0-9a-fA-F]*) return 1;;
        esac
      done
      return 0;;
  esac
  return 1
}

_otel_is_netcat_arg_arg() {
  # https://man7.org/linux/man-pages/man1/ncat.1.html
  case "$1" in
    -i|--idle-timeout) return 0;;
    -P) return 0;;
    -T) return 0;;
    -w|--wait) return 0;;
    -x) return 0;;
    -X) return 0;;
    -L) return 0;;
    -e|--exec) return 0;;
    -c|--sh-exec) return 0;;
    --lua-exec) return 0;;
    -g) return 0;;
    -G) return 0;;
    -b) return 0;;
    -q) return 0;;
    -m|--max-conns) return 0;;
    -I) return 0;;
    -O) return 0;;
    -S) return 0;;
    -R) return 0;;
    -d|--delay) return 0;;
    -o|--output) return 0;;
    -x|--hexdump) return 0;;
    -p|--source-port) return 0;;
    -s|--source) return 0;;
    --proxy|--proxy-type|--proxy-auth|--proxy-dns) return 0;;
     *) return 1;;
  esac
}

_otel_args_contains() {
  local needle="$1"; shift
  for _otel_netcat_arg in "$@"; do
    if \[ "$_otel_netcat_arg" = "$needle" ]; then return 0; fi
  done
  return 1
}

_otel_alias_prepend nc _otel_inject_netcat
_otel_alias_prepend ncat _otel_inject_netcat
_otel_alias_prepend netcat _otel_inject_netcat
