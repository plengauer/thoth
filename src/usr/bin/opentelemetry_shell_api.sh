#!/bin/false
##################################################################################################
# This file is providing an API for creating and managing open telemetry spans.                  #
# It should be sourced at the very top of any shell script where the functions are to be used.   #
# All variables are for internal use only and therefore subject to change without notice!        #
##################################################################################################

# translate legacy config
if \[ -n "$OTEL_SHELL_TRACES_ENABLE" ] || \[ -n "$OTEL_SHELL_METRICS_ENABLE" ] || \[ -n "$OTEL_SHELL_LOGS_ENABLE" ]; then
  \[ "$OTEL_SHELL_TRACES_ENABLE" = TRUE ] && export OTEL_TRACES_EXPORTER=otlp || export OTEL_TRACES_EXPORTER=""
  \[ "$OTEL_SHELL_METRICS_ENABLE" = TRUE ] && export OTEL_METRICS_EXPORTER=otlp || export OTEL_METRICS_EXPORTER=""
  \[ "$OTEL_SHELL_LOGS_ENABLE" = TRUE ] && export OTEL_LOGS_EXPORTER=otlp || export OTEL_LOGS_EXPORTER=""
  export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=delta
fi

# basic setup
_otel_remote_sdk_pipe="$(\mktemp -u)_opentelemetry_shell_$$.pipe"
_otel_shell="$(\readlink "/proc/$$/exe" | \rev | \cut -d / -f 1 | \rev)"
if \[ "$OTEL_SHELL_COMMANDLINE_OVERRIDE_SIGNATURE" = 0 ] || \[ "$OTEL_SHELL_COMMANDLINE_OVERRIDE_SIGNATURE" = "$PPID" ] || \[ "$(\tr '\000' ' ' < /proc/$PPID/cmdline)" = "$(\tr '\000' ' ' < /proc/$OTEL_SHELL_COMMANDLINE_OVERRIDE_SIGNATURE/cmdline)" ]; then _otel_commandline_override="$OTEL_SHELL_COMMANDLINE_OVERRIDE"; fi
unset OTEL_SHELL_COMMANDLINE_OVERRIDE
unset OTEL_SHELL_COMMANDLINE_OVERRIDE_SIGNATURE
unset OTEL_SHELL_COMMAND_TYPE_OVERRIDE
unset OTEL_SHELL_SUPPRESS_LOG_COLLECTION

otel_init() {
  if \[ -e "/dev/stderr" ] && \[ -e "$(\readlink -f /dev/stderr)" ]; then local sdk_output=/dev/stderr; else local sdk_output=/dev/null; fi
  local sdk_output="${OTEL_SHELL_SDK_OUTPUT_REDIRECT:-$sdk_output}"
  \mkfifo "$_otel_remote_sdk_pipe"
  _otel_package_version opentelemetry-shell > /dev/null # to build the cache outside a subshell
  # several weird things going on in the next line, (1) using '((' fucks up the syntax highlighting in github while '( (' does not, and (2) &> causes weird buffering / late flushing behavior
  if \env --help | \grep -q 'ignore-signal'; then local extra_env_flags='--ignore-signal=INT --ignore-signal=HUP'; fi
  ( (\env $extra_env_flags otelsdk "shell" "$(_otel_package_version opentelemetry-shell)" < "$_otel_remote_sdk_pipe" 1> "$sdk_output" 2> "$sdk_output") &)
  \exec 7> "$_otel_remote_sdk_pipe"
  _otel_resource_attributes | while IFS= read -r kvp; do _otel_sdk_communicate "RESOURCE_ATTRIBUTE" "$kvp"; done
  _otel_sdk_communicate "INIT"
}

otel_shutdown() {
  _otel_sdk_communicate "SHUTDOWN"
  \exec 7>&-
  \rm "$_otel_remote_sdk_pipe"
}

_otel_sdk_communicate() {
  \echo "$@" >&7 # tr -d '\000-\037'
}

_otel_resource_attributes() {
  \echo telemetry.sdk.name=opentelemetry
  \echo telemetry.sdk.language=shell
  \echo -n telemetry.sdk.version=; _otel_package_version opentelemetry-shell

  local process_command="$(_otel_command_self)"
  local process_executable_path="$(\readlink -f "/proc/$$/exe")"
  local process_executable_name="${process_executable_path##*/}" # "$(\printf '%s' "$process_executable_path" | \rev | \cut -d / -f 1 | \rev)"
  \echo process.pid="$$"
  \echo process.executable.name="$process_executable_name"
  \echo process.executable.path="$process_executable_path"
  \echo process.command="$process_command"
  \echo process.command_args=${process_command#* } # "$(\printf '%s' "$process_command" | \cut -d ' ' -f 2-)"
  \echo process.owner="$USER"
  case "$_otel_shell" in
       sh) \echo process.runtime.name="Bourne Shell" ;;
      ash) \echo process.runtime.name="Almquist Shell" ;;
     dash) \echo process.runtime.name="Debian Almquist Shell" ;;
     bash) \echo process.runtime.name="Bourne Again Shell" ;;
      zsh) \echo process.runtime.name="Z Shell" ;;
      ksh) \echo process.runtime.name="Korn Shell" ;;
    pdksh) \echo process.runtime.name="Public Domain Korn Shell" ;;
     posh) \echo process.runtime.name="Policy-compliant Ordinary Shell" ;;
     yash) \echo process.runtime.name="Yet Another Shell" ;;
     bosh) \echo process.runtime.name="Bourne Shell" ;;
     fish) \echo process.runtime.name="Friendly Interactive Shell" ;;
        *) \echo process.runtime.name="$process_executable_name" ;;
  esac
  \echo -n process.runtime.version=; _otel_package_version "$process_executable_name"
  \echo process.runtime.options="$-"

  \echo service.name="${OTEL_SERVICE_NAME:-unknown_service}"
  \echo service.version="$OTEL_SERVICE_VERSION"
  \echo service.namespace="$OTEL_SERVICE_NAMESPACE"
  \echo service.instance.id="$OTEL_SERVICE_INSTANCE_ID"
}

_otel_command_self() {
  if \[ -n "$_otel_commandline_override" ]; then
    \echo "$_otel_commandline_override"
  else
    _otel_resolve_command_self
  fi
}

_otel_resolve_command_self() {
  \tr '\000' ' ' < "/proc/$$/cmdline"
}

if \[ "$_otel_shell" = bash ]; then
  _otel_package_version() {
    # dpkg is very expensive, lets cache and be a bit less exact in case packages get updated why children are spawned!
    local package_name="$1"
    local varname="OTEL_SHELL_PACKAGE_VERSION_CACHE_$package_name"
    local varname="${varname//-/_}"
    if \[ -n "${!varname}" ]; then \echo "${!varname}"; return 0; fi
    \export "$varname=$(_otel_resolve_package_version "$1")"
    _otel_package_version "$package_name"
  }
else
  _otel_package_version() {
    _otel_resolve_package_version "$1"
  }
fi

_otel_resolve_package_version() {
  dpkg -s "$1" 2> /dev/null | \grep Version: | \cut -d ' ' -f 2
}

otel_span_current() {
  local response_pipe="$(\mktemp -u)_opentelemetry_shell_$$.pipe"
  \mkfifo "$response_pipe"
  _otel_sdk_communicate "SPAN_ID" "$response_pipe" "$OTEL_TRACEPARENT"
  \cat "$response_pipe"
  \rm "$response_pipe" &> /dev/null
}

otel_span_start() {
  local kind="$1"
  local name="$2"
  local response_pipe="$(\mktemp -u)_opentelemetry_shell_$$.pipe"
  \mkfifo "$response_pipe"
  _otel_sdk_communicate "SPAN_START" "$response_pipe" "$OTEL_TRACEPARENT" "$kind" "$name"
  \cat "$response_pipe"
  \rm "$response_pipe" &> /dev/null
}

otel_span_end() {
  local span_id="$1"
  _otel_sdk_communicate "SPAN_END" "$span_id"
}

otel_span_error() {
  local span_id="$1"
  _otel_sdk_communicate "SPAN_ERROR" "$span_id"
}

otel_span_attribute() {
  local span_id="$1"
  local kvp="$2"
  _otel_sdk_communicate "SPAN_ATTRIBUTE" "$span_id" "$kvp"
}

otel_span_traceparent() {
  local span_id="$1"
  local response_pipe="$(\mktemp -u)_opentelemetry_shell_$$.pipe"
  \mkfifo "$response_pipe"
  _otel_sdk_communicate "SPAN_TRACEPARENT" "$response_pipe" "$span_id"
  \cat "$response_pipe"
  \rm "$response_pipe" &> /dev/null
}

otel_span_activate() {
  local span_id="$1"
  export OTEL_TRACEPARENT_STACK="$OTEL_TRACEPARENT/$OTEL_TRACEPARENT_STACK"
  export OTEL_TRACEPARENT="$(otel_span_traceparent "$span_id")"
}

otel_span_deactivate() {
  if _otel_string_contains "$OTEL_TRACEPARENT_STACK" /; then
    export OTEL_TRACEPARENT="${OTEL_TRACEPARENT_STACK%%/*}"
    export OTEL_TRACEPARENT_STACK="${OTEL_TRACEPARENT_STACK#*/}"
  else
    export OTEL_TRACEPARENT="$OTEL_TRACEPARENT_STACK"
    export OTEL_TRACEPARENT_STACK=""
  fi
}

otel_metric_create() {
  local metric_name="$1"
  local response_pipe="$(\mktemp -u)_opentelemetry_shell_$$.pipe"
  \mkfifo "$response_pipe"
  _otel_sdk_communicate "METRIC_CREATE" "$response_pipe" "$metric_name"
  \cat "$response_pipe"
  \rm "$response_pipe" &> /dev/null
}

otel_metric_attribute() {
  local metric_id="$1"
  local kvp="$2"
  _otel_sdk_communicate "METRIC_ATTRIBUTE" "$metric_id" "$kvp"
}

otel_metric_add() {
  local metric_id="$1"
  local value="$2"
  _otel_sdk_communicate "METRIC_ADD" "$metric_id" "$value"
}

otel_observe() {
  # validate and clean arguments
  local dollar_star="$(_otel_dollar_star "$@")"
  local command="$dollar_star"
  while _otel_string_starts_with "$command" "_otel_"; do local command="${command#* }"; done
  local command="${command#\\}"
  local kind="${OTEL_SHELL_SPAN_KIND_OVERRIDE:-INTERNAL}"
  local attributes="$OTEL_SHELL_SPAN_ATTRIBUTES_OVERRIDE"
  local command_type="$OTEL_SHELL_COMMAND_TYPE_OVERRIDE"
  unset OTEL_SHELL_SPAN_ATTRIBUTES_OVERRIDE
  unset OTEL_SHELL_COMMAND_TYPE_OVERRIDE
  
  # create span, set initial attributes
  local span_id="$(otel_span_start "$kind" "$command")"
  otel_span_attribute "$span_id" shell.command="$command"
  if _otel_string_contains "$command" " "; then local command_name="${command%% *}"; else  local command_name="$command"; fi # "$(\printf '%s' "$command" | \cut -sd ' ' -f 2-)" # this returns the command if there are no args, its the cut -s that cant be done via expansion alone
  if \[ -z "$command_type" ]; then local command_type="$(_otel_command_type "$command_name")"; fi
  otel_span_attribute "$span_id" shell.command.type="$command_type"
  otel_span_attribute "$span_id" shell.command.name="$command_name"
  if \[ "$command_type" = file ]; then
    local executable_path="$(_otel_string_contains "$command_name" / && \echo "$command_name" || \which "$command_name")"
    otel_span_attribute "$span_id" subprocess.executable.path="$executable_path"
    otel_span_attribute "$span_id" subprocess.executable.name="${executable_path##*/}" # "$(\printf '%s' "$command" | \cut -d' ' -f1 | \rev | \cut -d / -f 1 | \rev)"
  fi
  
  # run command
  otel_span_activate "$span_id"
  local exit_code=0
  if ! \[ -t 0 ] && ! \[ -t 1 ] && ! \[ -t 2 ] && \[ "$OTEL_SHELL_EXPERIMENTAL_OBSERVE_PIPES" = TRUE ]; then
    local call_command="_otel_call_and_record_pipes $span_id _otel_call_and_record_logs _otel_call"
  elif ! \[ -t 2 ]; then
    local call_command="_otel_call_and_record_logs _otel_call"
  else
    local call_command=_otel_call
  fi
  OTEL_SHELL_COMMANDLINE_OVERRIDE="$command" OTEL_SHELL_COMMANDLINE_OVERRIDE_SIGNATURE="$$" $call_command "$@" || local exit_code="$?"
  otel_span_deactivate "$span_id"
  
  # set custom attributes, set final attributes, finish span
  otel_span_attribute "$span_id" shell.command.exit_code="$exit_code"
  if \[ "$exit_code" -ne 0 ]; then
    otel_span_error "$span_id"
  fi
  if \[ -n "$attributes" ]; then
    local OLD_IFS="$IFS"
    local IFS=','
    set -- $attributes
    IFS="$OLD_IFS"
    for attribute in "$@"; do
      if \[ -n "$attribute" ]; then
        otel_span_attribute "$span_id" "$attribute"
      fi
    done
  fi
  otel_span_end "$span_id"
  
  return "$exit_code"
}

if \[ "$_otel_shell" = dash ]; then # TODO its only old dashes
  # old versions of dash dont set env vars properly
  # more specifically they do not make variables that are set in front of commands part of the child process env vars but only of the local execution environment
  _otel_call() {
    local command="$1"; shift
    if ! _otel_string_starts_with "$command" "\\"; then local command="$(_otel_escape_arg "$command")"; fi
    \eval "$( { \printenv; \set; } | \grep '^OTEL_' | \cut -d = -f 1 | \sort -u | \awk '{ print $1 "=\"$" $1 "\"" }' | _otel_line_join)" "$command" "$(_otel_escape_args "$@")"
  }
else
  _otel_call() {
    local command="$1"; shift
    if ! _otel_string_starts_with "$command" "\\"; then local command="$(_otel_escape_arg "$command")"; fi
    \eval "$command" "$(_otel_escape_args "$@")"
  }
fi

_otel_call_and_record_logs() {
  case "$-" in
    *m*) local job_control=1; \set +m;;
    *) local job_control=0;;
  esac
  local call_command="$1"; shift
  local traceparent="$OTEL_TRACEPARENT"
  local stderr_logs="$(\mktemp -u)_opentelemetry_shell_$$.stderr.logs.pipe"
  \mkfifo "$stderr_logs"
  while IFS= read -r line; do _otel_log_record "$traceparent" "$line"; \echo "$line" >&2; done < "$stderr_logs" &
  local stderr_pid="$!"
  local exit_code=0
  $call_command "$@" 2> "$stderr_logs" || local exit_code="$?"
  \wait "$stderr_pid"
  \rm "$stderr_logs" 2> /dev/null
  if \[ "$job_control" = 1 ]; then \set -m; fi
  return "$exit_code"
}

_otel_call_and_record_pipes() {
  # some notes about this function
  # (*) we have to wait for the background processes because otherwise the span_id may not be valid anymore
  # (*) waiting for the processes only works when its not a subshell so we can access the last process id
  # (*) not using a subshell means we have to disable job control, otherwise we get unwanted output
  # (*) we can only directly tee stdin, otherwise the exit code cannot be captured propely if we pipe stdout directly
  # (*) tee for stdin does ONLY terminate when it writes something and realizes the process has terminated
  # (**) so in cases where stdin is open but nobody every writes to it and the process doesnt expect input, tee hangs forever
  # (**) this is different to output streams, because they get properly terminated with SIGPIPE on read
  case "$-" in
    *m*) local job_control=1; \set +m;;
    *) local job_control=0;;
  esac
  local span_id="$1"; shift
  local call_command="$1"; shift
  local stdin_bytes_result="$(\mktemp -u)_opentelemetry_shell_$$.stdin.bytes.result"
  local stdin_lines_result="$(\mktemp -u)_opentelemetry_shell_$$.stdin.lines.result"
  local stdout_bytes_result="$(\mktemp -u)_opentelemetry_shell_$$.stdout.bytes.result"
  local stdout_lines_result="$(\mktemp -u)_opentelemetry_shell_$$.stdout.lines.result"
  local stderr_bytes_result="$(\mktemp -u)_opentelemetry_shell_$$.stderr.bytes.result"
  local stderr_lines_result="$(\mktemp -u)_opentelemetry_shell_$$.stderr.lines.result"
  local stdout="$(\mktemp -u)_opentelemetry_shell_$$.stdout.pipe"
  local stderr="$(\mktemp -u)_opentelemetry_shell_$$.stderr.pipe"
  local stdin_bytes="$(\mktemp -u)_opentelemetry_shell_$$.stdin.bytes.pipe"
  local stdin_lines="$(\mktemp -u)_opentelemetry_shell_$$.stdin.lines.pipe"
  local stdout_bytes="$(\mktemp -u)_opentelemetry_shell_$$.stdout.bytes.pipe"
  local stdout_lines="$(\mktemp -u)_opentelemetry_shell_$$.stdout.lines.pipe"
  local stderr_bytes="$(\mktemp -u)_opentelemetry_shell_$$.stderr.bytes.pipe"
  local stderr_lines="$(\mktemp -u)_opentelemetry_shell_$$.stderr.lines.pipe"
  local exit_code=0
  \mkfifo "$stdout" "$stderr" "$stdin_bytes" "$stdin_lines" "$stdout_bytes" "$stdout_lines" "$stderr_bytes" "$stderr_lines"
  \wc -c "$stdin_bytes" > "$stdin_bytes_result" &
  local stdin_bytes_pid="$!"
  \wc -l "$stdin_lines" > "$stdin_lines_result" &
  local stdin_lines_pid="$!"
  \wc -c "$stdout_bytes" > "$stdout_bytes_result" &
  local stdout_bytes_pid="$!"
  \wc -l "$stdout_lines" > "$stdout_lines_result" &
  local stdout_lines_pid="$!"
  \wc -c "$stderr_bytes" > "$stderr_bytes_result" &
  local stderr_bytes_pid="$!"
  \wc -l "$stderr_lines" > "$stderr_lines_result" &
  local stderr_lines_pid="$!"
  \tee "$stdout_bytes" "$stdout_lines" < "$stdout" &
  local stdout_pid="$!"
  \tee "$stderr_bytes" "$stderr_lines" < "$stderr" >&2 &
  local stderr_pid="$!"
  if \[ "$(\readlink -f /proc/self/fd/0)" = /dev/null ] || \[ "$(\readlink -f /proc/self/fd/0)" = "/proc/$$/fd/0" ]; then
    \echo -n '' > "$stdin_bytes"
    \echo -n '' > "$stdin_lines"
    $call_command "$@" 1> "$stdout" 2> "$stderr" || local exit_code="$?"
  else
    \tee "$stdin_bytes" "$stdin_lines" | $call_command "$@" 1> "$stdout" 2> "$stderr" || local exit_code="$?"
    local stdin_jid="$(\jobs | \grep -F "tee $stdin_bytes $stdin_lines" | \cut -d ' ' -f 1 | \tr -d '[]+-')"
    if \[ -n "$stdin_jid" ]; then \kill -9 "%$stdin_jid" 2> /dev/null || true; fi
    local stdin_pid="$(\ps -o '%p,%a' | \grep -F "tee $stdin_bytes $stdin_lines" | \cut -d , -f1 | \tr -d ' ')"
    if \[ -n "$stdin_pid" ]; then \kill -9 "$stdin_pid" 2> /dev/null || true; fi
  fi
  \wait "$stdin_bytes_pid" "$stdin_lines_pid" "$stdout_bytes_pid" "$stdout_lines_pid" "$stderr_bytes_pid" "$stderr_lines_pid" "$stdout_pid" "$stderr_pid"
  \rm "$stdout" "$stderr" "$stdin_bytes" "$stdin_lines" "$stdout_bytes" "$stdout_lines" "$stderr_bytes" "$stderr_lines" 2> /dev/null
  otel_span_attribute "$span_id" pipe.stdin.bytes="$(\cat "$stdin_bytes_result")"
  otel_span_attribute "$span_id" pipe.stdin.lines="$(\cat "$stdin_lines_result")"
  otel_span_attribute "$span_id" pipe.stdout.bytes="$(\cat "$stdout_bytes_result")"
  otel_span_attribute "$span_id" pipe.stdout.lines="$(\cat "$stdout_lines_result")"
  otel_span_attribute "$span_id" pipe.stderr.bytes="$(\cat "$stderr_bytes_result")"
  otel_span_attribute "$span_id" pipe.stderr.lines="$(\cat "$stderr_lines_result")"
  \rm "$stdin_bytes_result" "$stdin_lines_result" "$stdout_bytes_result" "$stdout_lines_result" "$stderr_bytes_result" "$stderr_lines_result" 2> /dev/null
  if \[ "$job_control" = 1 ]; then \set -m; fi
  return "$exit_code"
}

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
      "$1 is a shell function") \echo 'function';;
      "$1 is a shell builtin") \echo builtin;;
      "$1 is $1") \echo file;;
      *) \echo file;;
    esac
  }
fi

_otel_log_record() {
  local traceparent="$1"
  shift
  local line="$(_otel_dollar_star "$@")"
  _otel_sdk_communicate "LOG_RECORD" "$traceparent" "$line"
}

_otel_escape_args() {
  # for arg in "$@"; do \echo "$arg"; done | _otel_escape_in # this may seem correct, but it doesnt handle linefeeds in arguments correctly
  local first=1
  for arg in "$@"; do
    if \[ "$first" = 1 ]; then local first=0; else \echo -n " "; fi
    _otel_escape_arg "$arg"
  done
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
      *[[:space:]\&\<\>\|\'\"\(\)\`!\$\;\\]*) local do_escape=1 ;;
      *) local do_escape=0 ;;
    esac
  fi
  if \[ "$do_escape" = 1 ]; then    
    if \[ "$no_quote" = 1 ]; then local format_string='%s'; else local format_string="'%s'"; fi
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
