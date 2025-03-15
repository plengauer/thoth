#!/bin/false
##################################################################################################
# This file is providing an API for creating and managing open telemetry spans.                  #
# It should be sourced at the very top of any shell script where the functions are to be used.   #
# All variables are for internal use only and therefore subject to change without notice!        #
##################################################################################################

# translate legacy config
if \[ -n "${OTEL_SHELL_TRACES_ENABLE:-}" ] || \[ -n "${OTEL_SHELL_METRICS_ENABLE:-}" ] || \[ -n "${OTEL_SHELL_LOGS_ENABLE:-}" ]; then
  \[ "${OTEL_SHELL_TRACES_ENABLE:-FALSE}" = TRUE ] && \export OTEL_TRACES_EXPORTER=otlp || \export OTEL_TRACES_EXPORTER=""
  \[ "${OTEL_SHELL_METRICS_ENABLE:-FALSE}" = TRUE ] && \export OTEL_METRICS_EXPORTER=otlp || \export OTEL_METRICS_EXPORTER=""
  \[ "${OTEL_SHELL_LOGS_ENABLE:-FALSE}" = TRUE ] && \export OTEL_LOGS_EXPORTER=otlp || \export OTEL_LOGS_EXPORTER=""
  \export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=delta
fi

# check environment
case "$-" in
  *r*) \echo "WARNING The OpenTelemetry shell API does not support restricted mode (set -r)!" >&2; exit 1;;
esac

# basic setup
if \[ -z "${TMPDIR:-}" ]; then TMPDIR=/tmp; fi
_otel_shell_pipe_dir="${OTEL_SHELL_PIPE_DIR:-$TMPDIR}"
_otel_remote_sdk_pipe="${OTEL_REMOTE_SDK_PIPE:-$(\mktemp -u -p "$_otel_shell_pipe_dir")_opentelemetry_shell_$$.pipe}"
_otel_remote_sdk_fd="${OTEL_REMOTE_SDK_FD:-7}"
_otel_shell="$(\readlink "/proc/$$/exe")"
_otel_shell="${_otel_shell##*/}"
if \[ "$_otel_shell" = busybox ]; then _otel_shell="busybox sh"; fi
if \[ "${OTEL_SHELL_COMMANDLINE_OVERRIDE_SIGNATURE:-}" = 0 ] || \[ "${OTEL_SHELL_COMMANDLINE_OVERRIDE_SIGNATURE:-}" = "$PPID" ] || \[ "${PPID:-}" = 0 ] || \[ "$(\tr '\000-\037' ' ' < /proc/$PPID/cmdline)" = "$(\tr '\000-\037' ' ' < /proc/${OTEL_SHELL_COMMANDLINE_OVERRIDE_SIGNATURE:-}/cmdline)" ]; then _otel_commandline_override="$OTEL_SHELL_COMMANDLINE_OVERRIDE"; fi
unset OTEL_SHELL_COMMANDLINE_OVERRIDE
unset OTEL_SHELL_COMMANDLINE_OVERRIDE_SIGNATURE
unset OTEL_SHELL_COMMAND_TYPE_OVERRIDE
unset OTEL_SHELL_SPAN_KIND_OVERRIDE

if \[ -p "$_otel_remote_sdk_pipe" ]; then
  otel_init() {
    _otel_mkfifo_flags=--mode=666
    \eval "\\exec ${_otel_remote_sdk_fd}> \"$_otel_remote_sdk_pipe\""
  }

  otel_shutdown() {
    \eval "\\exec ${_otel_remote_sdk_fd}>&-"
  }
else
  otel_init() {
    \mkfifo "$_otel_remote_sdk_pipe"
    _otel_package_version opentelemetry-shell > /dev/null # to build the cache outside a subshell
    _otel_package_version "$_otel_shell" > /dev/null
    # several weird things going on in the next line, (1) using '((' fucks up the syntax highlighting in github while '( (' does not, and (2) &> causes weird buffering / late flushing behavior
    if \env --help 2>&1 | \grep -q 'ignore-signal'; then local extra_env_flags='--ignore-signal=INT --ignore-signal=HUP'; fi
    ( (\env ${extra_env_flags:-} /opt/opentelemetry_shell/sdk/venv/bin/python /usr/share/opentelemetry_shell/sdk.py "shell" "$(_otel_package_version opentelemetry-shell)" < "$_otel_remote_sdk_pipe" 1> "${OTEL_SHELL_SDK_OUTPUT_REDIRECT:-/dev/stderr}" 2> "${OTEL_SHELL_SDK_OUTPUT_REDIRECT:-/dev/stderr}") &)
    \eval "\\exec ${_otel_remote_sdk_fd}> \"$_otel_remote_sdk_pipe\""
    _otel_resource_attributes
    _otel_sdk_communicate "INIT"
  }

  otel_shutdown() {
    _otel_sdk_communicate "SHUTDOWN"
    \eval "\\exec ${_otel_remote_sdk_fd}>&-"
    \rm "$_otel_remote_sdk_pipe"
  }
fi

_otel_sdk_communicate() {
  if _otel_string_contains "$*" "
"; then
    local IFS=' '
    _otel_sdk_communicate "$(\printf '%s' "$*" | \tr '\n' ' ')"
  else
    \echo "$@" >&7
  fi
}

_otel_resource_attributes() {
  _otel_resource_attributes_process
  _otel_resource_attributes_service
  _otel_resource_attribute string telemetry.sdk.name=opentelemetry
  _otel_resource_attribute string telemetry.sdk.language=shell
  _otel_resource_attribute string telemetry.sdk.version="$(_otel_package_version opentelemetry-shell)"

  _otel_resource_attributes_custom
}

_otel_resource_attributes_service() {
  _otel_resource_attribute string service.name="${OTEL_SERVICE_NAME:-unknown_service}"
  _otel_resource_attribute string service.version="${OTEL_SERVICE_VERSION:-}"
  _otel_resource_attribute string service.namespace="${OTEL_SERVICE_NAMESPACE:-}"
  _otel_resource_attribute string service.instance.id="${OTEL_SERVICE_INSTANCE_ID:-}"
}

_otel_resource_attributes_process() {
  local process_command="$(_otel_command_self)"
  local process_executable_path="$(\readlink -f "/proc/$$/exe")"
  local process_executable_name="${process_executable_path##*/}" # "$(\printf '%s' "$process_executable_path" | \rev | \cut -d / -f 1 | \rev)"
  _otel_resource_attribute int process.pid="$$"
  _otel_resource_attribute int process.parent_pid="$PPID"
  _otel_resource_attribute string process.executable.name="$process_executable_name"
  _otel_resource_attribute string process.executable.path="$process_executable_path"
  _otel_resource_attribute string process.command_line="$process_command"
  _otel_resource_attribute string process.command="${process_command%% *}" # "$(\printf '%s' "$process_command" | \cut -d ' ' -f 1)"
  _otel_resource_attribute string process.owner="${USER:-"$(\whoami)"}"
  _otel_resource_attribute string process.runtime.name="$_otel_shell"
  case "$_otel_shell" in
       sh) _otel_resource_attribute string process.runtime.description="Bourne Shell" ;;
      ash) _otel_resource_attribute string process.runtime.description="Almquist Shell" ;;
     dash) _otel_resource_attribute string process.runtime.description="Debian Almquist Shell" ;;
     bash) _otel_resource_attribute string process.runtime.description="Bourne Again Shell" ;;
      zsh) _otel_resource_attribute string process.runtime.description="Z Shell" ;;
      ksh) _otel_resource_attribute string process.runtime.description="Korn Shell" ;;
    pdksh) _otel_resource_attribute string process.runtime.description="Public Domain Korn Shell" ;;
     posh) _otel_resource_attribute string process.runtime.description="Policy-compliant Ordinary Shell" ;;
     yash) _otel_resource_attribute string process.runtime.description="Yet Another Shell" ;;
     bosh) _otel_resource_attribute string process.runtime.description="Bourne Shell" ;;
     fish) _otel_resource_attribute string process.runtime.description="Friendly Interactive Shell" ;;
     'busybox sh') _otel_resource_attribute string process.runtime.description="Busy Box" ;;
  esac
  _otel_resource_attribute string process.runtime.version="$(_otel_package_version "$process_executable_name")"
  _otel_resource_attribute string process.runtime.options="$-"
}

_otel_resource_attributes_custom() {
  : # this is intentionally empty to declare after import
}

_otel_resource_attribute() {
  _otel_sdk_communicate RESOURCE_ATTRIBUTE "$@"
}

_otel_command_self() {
  if \[ -n "${_otel_commandline_override:-}" ]; then
    \echo "$_otel_commandline_override" | \tr '\000-\037' ' '
  else
    _otel_resolve_command_self
  fi
}

_otel_resolve_command_self() {
  \tr '\000-\037' ' ' < "/proc/$$/cmdline"
}

if \[ "$_otel_shell" = bash ]; then
  _otel_package_version() {
    # dpkg is very expensive, lets cache and be a bit less exact in case packages get updated why children are spawned!
    local package_name="$1"
    local varname="OTEL_SHELL_PACKAGE_VERSION_CACHE_$package_name"
    local varname="${varname//-/_}"
    \eval "local varvalue=\${$varname:-}"
    if \[ -n "$varvalue" ]; then \echo "$varvalue"; return 0; fi
    \export "$varname=$(_otel_resolve_package_version "$1")"
    \echo "${!varname}"
  }
else
  _otel_package_version() {
    _otel_resolve_package_version "$1"
  }
fi

_otel_resolve_package_version() {
  (\dpkg -s "$1" || \rpm -qi "$1") 2> /dev/null | \grep Version | \cut -d : -f 2 | tr -d ' '
}

otel_span_current() {
  local response_pipe="$(\mktemp -u -p "$_otel_shell_pipe_dir")_opentelemetry_shell_$$.span_handle.pipe"
  \mkfifo ${_otel_mkfifo_flags:-} "$response_pipe"
  _otel_sdk_communicate "SPAN_HANDLE" "$response_pipe" "${TRACEPARENT:-}"
  \cat "$response_pipe"
  \rm "$response_pipe" 1> /dev/null 2> /dev/null
}

otel_span_start() {
  if _otel_string_starts_with "${1:-}" @; then local time="${1#@}"; shift; else local time=auto; fi
  local kind="$1"
  local name="$2"
  local response_pipe="$(\mktemp -u -p "$_otel_shell_pipe_dir")_opentelemetry_shell_$$.span_handle.pipe"
  \mkfifo ${_otel_mkfifo_flags:-} "$response_pipe"
  _otel_sdk_communicate "SPAN_START" "$response_pipe" "${TRACEPARENT:-}" "${TRACESTATE:-}" "$time" "$kind" "$name"
  \cat "$response_pipe"
  \rm "$response_pipe" 1> /dev/null 2> /dev/null
}

otel_span_end() {
  local span_handle="$1"
  if _otel_string_starts_with "${2:-}" @; then local time="${2#@}"; else local time=auto; fi
  _otel_sdk_communicate "SPAN_END" "$span_handle" "$time"
}

otel_span_name() {
  local span_handle="$1"
  local span_name="$2"
  _otel_sdk_communicate "SPAN_NAME" "$span_handle" "$span_name"
}

otel_span_error() {
  local span_handle="$1"
  _otel_sdk_communicate "SPAN_ERROR" "$span_handle"
}

otel_span_attribute() {
  local span_handle="$1"
  local kvp="$2"
  otel_span_attribute_typed "$span_handle" auto "$kvp"
}

otel_span_attribute_typed() {
  local span_handle="$1"
  local type="$2"
  local kvp="$3"
  _otel_sdk_communicate "SPAN_ATTRIBUTE" "$span_handle" "$type" "$kvp"
}

otel_span_traceparent() {
  local span_handle="$1"
  local response_pipe="$(\mktemp -u -p "$_otel_shell_pipe_dir")_opentelemetry_shell_$$.traceparent.pipe"
  \mkfifo ${_otel_mkfifo_flags:-} "$response_pipe"
  _otel_sdk_communicate "SPAN_TRACEPARENT" "$response_pipe" "$span_handle"
  \cat "$response_pipe"
  \rm "$response_pipe" 1> /dev/null 2> /dev/null
}

otel_span_activate() {
  local span_handle="$1"
  \export TRACEPARENT_STACK="${TRACEPARENT:-}/${TRACEPARENT_STACK:-}"
  \export TRACEPARENT="$(otel_span_traceparent "$span_handle")"
  if \[ -z "${TRACESTATE:-}" ]; then \export TRACESTATE=""; fi
}

otel_span_deactivate() {
  if _otel_string_contains "$TRACEPARENT_STACK" /; then
    \export TRACEPARENT="${TRACEPARENT_STACK%%/*}"
    \export TRACEPARENT_STACK="${TRACEPARENT_STACK#*/}"
  else
    \export TRACEPARENT="$TRACEPARENT_STACK"
    \export TRACEPARENT_STACK=""
  fi
  if \[ -z "$TRACEPARENT" ]; then
    unset TRACEPARENT_STACK
    unset TRACEPARENT
    unset TRACESTATE
  fi
}

otel_event_create() {
  local event_name="$1"
  local response_pipe="$(\mktemp -u -p "$_otel_shell_pipe_dir")_opentelemetry_shell_$$.event_handle.pipe"
  \mkfifo ${_otel_mkfifo_flags:-} "$response_pipe"
  _otel_sdk_communicate "EVENT_CREATE" "$response_pipe" "$event_name"
  \cat "$response_pipe"
  \rm "$response_pipe" 1> /dev/null 2> /dev/null
}

otel_event_attribute() {
  local event_handle="$1"
  local kvp="$2"
  otel_event_attribute_typed "$event_handle" auto "$kvp"
}

otel_event_attribute_typed() {
  local event_handle="$1"
  local type="$2"
  local kvp="$3"
  _otel_sdk_communicate "EVENT_ATTRIBUTE" "$event_handle" "$type" "$kvp"
}

otel_event_add() {
  local event_handle="$1"
  local span_handle="$2"
  _otel_sdk_communicate "EVENT_ADD" "$event_handle" "$span_handle"
}

otel_link_create() {
  local traceparent="$1"
  local tracestate="$2"
  local response_pipe="$(\mktemp -u -p "$_otel_shell_pipe_dir")_opentelemetry_shell_$$.link_handle.pipe"
  \mkfifo ${_otel_mkfifo_flags:-} "$response_pipe"
  _otel_sdk_communicate "LINK_CREATE" "$response_pipe" "$traceparent" "$tracestate" END
  \cat "$response_pipe"
  \rm "$response_pipe" 1> /dev/null 2> /dev/null
}

otel_link_attribute() {
  local link_handle="$1"
  local kvp="$2"
  otel_link_attribute_typed "$link_handle" auto "$kvp"
}

otel_link_attribute_typed() {
  local link_handle="$1"
  local type="$2"
  local kvp="$3"
  _otel_sdk_communicate "LINK_ATTRIBUTE" "$link_handle" "$type" "$kvp"
}

otel_link_add() {
  local link_handle="$1"
  local span_handle="$2"
  _otel_sdk_communicate "LINK_ADD" "$link_handle" "$span_handle"
}

otel_counter_create() {
  local type="$1"
  local name="$2"
  local unit="${3:-1}"
  local description="${4:-}"
  local response_pipe="$(\mktemp -u -p "$_otel_shell_pipe_dir")_opentelemetry_shell_$$.counter_handle.pipe"
  \mkfifo ${_otel_mkfifo_flags:-} "$response_pipe"
  _otel_sdk_communicate "COUNTER_CREATE" "$response_pipe" "$type" "$name" "$unit" "$description"
  \cat "$response_pipe"
  \rm "$response_pipe" 1> /dev/null 2> /dev/null
}

otel_counter_observe() {
  local counter_handle="$1"
  local observation_handle="$2"
  _otel_sdk_communicate "COUNTER_OBSERVE" "$counter_handle" "$observation_handle"
}

otel_observation_create() {
  local value="$1"
  local response_pipe="$(\mktemp -u -p "$_otel_shell_pipe_dir")_opentelemetry_shell_$$.observation_handle.pipe"
  \mkfifo ${_otel_mkfifo_flags:-} "$response_pipe"
  _otel_sdk_communicate "OBSERVATION_CREATE" "$response_pipe" "$value"
  \cat "$response_pipe"
  \rm "$response_pipe" 1> /dev/null 2> /dev/null
}

otel_observation_attribute_typed() {
  local observation_handle="$1"
  local type="$2"
  local kvp="$3"
  _otel_sdk_communicate "OBSERVATION_ATTRIBUTE" "$observation_handle" "$type" "$kvp"
}

otel_observation_attribute() {
  local observation_handle="$1"
  local kvp="$2"
  otel_observation_attribute_typed "$observation_handle" auto "$kvp"
}

otel_observe() {
  local IFS=' 
'
  # validate and clean arguments
  local dollar_star="$(_otel_dollar_star "$@")"
  local command="$dollar_star"
  while _otel_string_starts_with "$command" "_otel_"; do local command="${command#* }"; done
  local command="${command#\\}"
  local kind="${OTEL_SHELL_SPAN_KIND_OVERRIDE:-INTERNAL}"
  local attributes="${OTEL_SHELL_SPAN_ATTRIBUTES_OVERRIDE:-}"
  local command_type="${OTEL_SHELL_COMMAND_TYPE_OVERRIDE:-}"
  local command="${OTEL_SHELL_COMMAND_OVERRIDE:-$command}"
  unset OTEL_SHELL_COMMAND_OVERRIDE
  unset OTEL_SHELL_SPAN_ATTRIBUTES_OVERRIDE
  unset OTEL_SHELL_COMMAND_TYPE_OVERRIDE
  unset OTEL_SHELL_COMMAND_OVERRIDE
  
  # create span, set initial attributes
  local span_handle="$(otel_span_start "$kind" "$command")"
  otel_span_attribute_typed "$span_handle" string shell.command_line="$command"
  if _otel_string_contains "$command" " "; then local command_name="${command%% *}"; else local command_name="$command"; fi # "$(\printf '%s' "$command" | \cut -sd ' ' -f 2-)" # this returns the command if there are no args, its the cut -s that cant be done via expansion alone
  if \[ -z "${command_type:-}" ]; then local command_type="$(_otel_command_type "$command_name")"; fi
  otel_span_attribute_typed "$span_handle" string shell.command="$command_name"
  otel_span_attribute_typed "$span_handle" string shell.command.type="$command_type"
  if _otel_string_contains "$command_name" /; then
    otel_span_attribute_typed "$span_handle" string shell.command.name=""${command_name##*/}""
  else
    otel_span_attribute_typed "$span_handle" string shell.command.name="$command_name"
  fi
  if \[ "$command_type" = file ]; then
    local executable_path="$(_otel_string_contains "$command_name" / && \echo "$command_name" || \which "$command_name")"
    otel_span_attribute_typed "$span_handle" string subprocess.executable.path="$executable_path"
    otel_span_attribute_typed "$span_handle" string subprocess.executable.name="${executable_path##*/}" # "$(\printf '%s' "$command" | \cut -d' ' -f1 | \rev | \cut -d / -f 1 | \rev)"
  fi
  
  # run command
  otel_span_activate "$span_handle"
  local exit_code=0
  local call_command=_otel_call
  if \[ "${OTEL_SHELL_CONFIG_OBSERVE_SUBPROCESSES:-FALSE}" = TRUE ] || \[ "${OTEL_SHELL_CONFIG_OBSERVE_SIGNALS:-FALSE}" = TRUE ]; then if ! _otel_string_starts_with "$1" _otel_ && \[ "$command_type" = file ] && \type strace 1> /dev/null 2> /dev/null; then local call_command="_otel_call_and_record_subprocesses $span_handle $call_command"; fi; fi
  if ! \[ -t 2 ] && ! _otel_string_contains "$-" x; then local call_command="_otel_call_and_record_logs $call_command"; fi
  if ! \[ -t 0 ] && ! \[ -t 1 ] && ! \[ -t 2 ] && ! _otel_string_contains "$-" x && \[ "${OTEL_SHELL_CONFIG_OBSERVE_PIPES:-FALSE}" = TRUE ]; then local call_command="_otel_call_and_record_pipes $span_handle $command_type $call_command"; fi
  $call_command "$@" || local exit_code="$?"
  otel_span_deactivate "$span_handle"
  
  # set custom attributes, set final attributes, finish span
  otel_span_attribute_typed "$span_handle" int shell.command.exit_code="$exit_code"
  if \[ "$exit_code" -ne 0 ]; then
    otel_span_error "$span_handle"
  fi
  if \[ -n "$attributes" ]; then
    local OLD_IFS="$IFS"
    local IFS=','
    set -- $attributes
    IFS="$OLD_IFS"
    for attribute in "$@"; do
      if \[ -n "$attribute" ]; then
        otel_span_attribute "$span_handle" "$attribute"
      fi
    done
  fi
  otel_span_end "$span_handle"
  
  return "$exit_code"
}

if ! \type which 1> /dev/null 2> /dev/null; then
  if \[ "$_otel_shell" = bash ]; then
    which() {
      \type -P "$1"
    }
  else
    which() {
      if \[ -x "$1" ]; then \echo "$1"; return 0; fi
      local IFS=:
      for directory in $PATH; do
        local path="$directory"/"$1"
        if \[ -x "$path" ]; then
          \echo "$path"
          return 0
        fi
      done
      return 1
    }
  fi
fi

if \[ "$_otel_shell" = dash ] || \[ "$_otel_shell" = 'busybox sh' ]; then # LEGACY this seems to be only necessary for old dashes on focal
  # old versions of dash dont set env vars properly
  # more specifically they do not make variables that are set in front of commands part of the child process env vars but only of the local execution environment
  _otel_call() {
    local command="$1"; shift
    if ! _otel_string_starts_with "$command" "\\"; then local command="$(_otel_escape_arg "$command")"; fi
    \eval "$( { \printenv; \set; } | \grep -E '^OTEL_|^PYTHONPATH=|^JAVA_TOOL_OPTIONS=' | \cut -d = -f 1 | \sort -u | \awk '{ print $1 "=\"$" $1 "\"" }' | _otel_line_join)" "$command" "$(_otel_escape_args "$@")"
  }
else
  _otel_call() {
    local command="$1"; shift
    if ! _otel_string_starts_with "$command" "\\"; then local command="$(_otel_escape_arg "$command")"; fi
    \eval "$command" "$(_otel_escape_args "$@")"
  }
fi

\. /usr/share/opentelemetry_shell/api.observe.logs.sh
\. /usr/share/opentelemetry_shell/api.observe.pipes.sh
\. /usr/share/opentelemetry_shell/api.observe.subprocesses.sh

if \[ "$_otel_shell" = bash ]; then
  _otel_command_type() {
    \type -t "$1" || \echo file
  }
else
  _otel_command_type() {
    case "$(\type "$1")" in
      "$1 is a shell keyword") \echo keyword;;
      "$1 is a shell alias for "*) \echo alias;;
      "$1 is an alias for "*) \echo alias;;
      "$1 is aliased to "*) \echo alias;;
      "$1 is a shell function") \echo 'function';;
      "$1 is a function") \echo 'function';;
      "$1 is a shell builtin") \echo builtin;;
      "$1 is $1") \[ "$_otel_shell" = 'busybox sh' ] && \help | \tail -n +3 | \grep -q "$1" && \echo builtin || \echo file;;
      "$1 is hashed (/"*"/$1)") \echo file;; 
      *) \echo file;;
    esac
  }
fi

_otel_escape_stdin() {
  local first=1
  while IFS= \read -r line; do
    if \[ "$first" = 1 ]; then local first=0; else \echo -n " "; fi
    _otel_escape_arg "$line"
  done
}

_otel_escape_args() {
  # for arg in "$@"; do \echo "$arg"; done | _otel_escape_in # this may seem correct, but it doesnt handle linefeeds in arguments correctly
  local first=1
  for _otel_escape_args__arg in "$@"; do
    if \[ "$first" = 1 ]; then local first=0; else \echo -n " "; fi
    _otel_escape_arg "$_otel_escape_args__arg"
  done
  unset _otel_escape_args__arg
}

_otel_escape_arg() {
   # that SO article shows why this is extra fun! https://stackoverflow.com/questions/16991270/newlines-at-the-end-get-removed-in-shell-scripts-why
  local do_escape=0
  if \[ -z "$1" ]; then
    local do_escape=1
  elif \[ "$1X" != "$(\echo "$1")"X ]; then # fancy check for "contains linefeed"
    local do_escape=1
  else
    case "$1X" in
      *[[:space:]\&\<\>\|\'\"\(\)\`\!\$\;\\\*]*) local do_escape=1 ;;
      *) local do_escape=0 ;;
    esac
  fi
  if \[ "$do_escape" = 1 ]; then
    if \[ "${no_quote:-0}" = 1 ]; then local format_string='%s'; else local format_string="'%s'"; fi
    _otel_escape_arg_format "$format_string" "$1"
  else
    \printf '%s' "$1"
  fi
}

if \[ "$_otel_shell" = bash ]; then
  _otel_escape_arg_format() {
    \printf "$1" "${2//\'/\'\\\'\'}"
  }
else
  _otel_escape_arg_format() {
    local escaped="$(\printf '%s' "$2X" | \sed "s/'/'\\\\''/g")" # need the extra X to preserve trailing linefeeds (yay)
    \printf "$1" "${escaped%X}"
  }
fi

_otel_line_join() {
  \sed '/^$/d' | \tr '\n' ' ' | \sed 's/ $//'
}

_otel_line_split() {
  \tr ' ' '\n'
}

# this is functionally equivalent with "$*" but does not require IFS to be set properly
_otel_dollar_star() {
  # \echo "$*" # dont do this because it uses the IFS which may not be set properly (and we dont wanna reset and cause a sideeffect, especially because we would have to set empty and unset state of IFS properly)
  # \echo "$@" # dont do this because it starts interpreting backslashes
  local IFS=' '
  \printf '%s' "$*"
}

_otel_string_contains() {
  case "$1" in
    *"$2"*) return 0;;
    *) return 1;;
  esac
}

_otel_string_starts_with() {
  case "$1" in
    "$2"*) return 0;;
    *) return 1;;
  esac
}

_otel_string_ends_with() {
  case "$1" in
    *"$2") return 0;;
    *) return 1;;
  esac
}
