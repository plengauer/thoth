. ./assert.sh
. /usr/bin/opentelemetry_shell.sh

otel_instrument echo
bash auto/echo.shell

sleep 3
data=$(cat $OTEL_TRACES_LOCATION | jq '. | select(.name == "echo hello world")')
assert_equals "echo hello world" "$(\echo "$data" | jq -r '.name')"
assert_equals "SpanKind.INTERNAL" $(\echo "$data" | jq -r '.kind')
assert_not_equals "null" $(\echo "$data" | jq -r '.parent_id')
assert_equals "UNSET" $(\echo "$data" | jq -r '.status.status_code')
assert_equals "echo hello world" "$(\echo "$data" | jq -r '.attributes."subprocess.command"')"
assert_equals "hello world" "$(\echo "$data" | jq -r '.attributes."subprocess.command_args"')"
# assert_equals "echo" "$(\echo "$data" | jq -r '.attributes."executable.name"')"
# assert_equals "/usr/bin/echo" "$(\echo "$data" | jq -r '.attributes."executable.path"')" # built-in
assert_equals "0" $(\echo "$data" | jq -r '.attributes."subprocess.exit_code"')
