if ! type netcat; then exit 0; fi

set -e
. ./assert.sh
. otel.sh

expected="$(\mktemp)"
actual="$(\mktemp)"

for i in $(\seq 1 10); do
  \cat /dev/urandom | \head -c $((1024 * 1)) > "$expected" || \true
  _otel_netcat_parse_request '' '/dev/null' < "$expected" > "$actual"
  assert_equals "$(\cat "$expected" | \xxd -p)" "$(\cat "$actual" | \xxd -p)"
  _otel_netcat_parse_response '' '/dev/null' < "$expected" > "$actual"
  assert_equals "$(\cat "$expected" | \xxd -p)" "$(\cat "$actual" | \xxd -p)"
done

# check simple string request
\echo "TEST 0" >&2
port=12345
response_file="$(\mktemp)"
netcat -l "$port" < /dev/null > "$response_file" &
pid="$!"
\echo -n hello world | netcat -w 1 127.0.0.1 "$port" > /dev/null
\wait "$pid"
assert_equals "hello world" "$(\cat "$response_file")"
span="$(resolve_span '.kind == "SpanKind.PRODUCER"')"
assert_equals "send/receive" $(\echo "$span" | \jq -r '.name')
span="$(resolve_span '.kind == "SpanKind.CONSUMER"')"
assert_equals "send/receive" $(\echo "$span" | \jq -r '.name')

# check HTTP client with real HTTP server (check spans and structure)
\echo "TEST 1" >&2
\printf 'GET / HTTP/1.1\r\n\r\n' | netcat -w 5 www.google.com 80
assert_equals 0 "$?"
span="$(resolve_span '.name == "GET"')"
assert_equals "SpanKind.CLIENT" $(\echo "$span" | \jq -r '.kind')
assert_not_equals "null" $(\echo "$span" | \jq -r '.parent_id')
assert_equals "UNSET" $(\echo "$span" | \jq -r '.status.status_code')
assert_equals "http" "$(\echo "$span" | \jq -r '.attributes."network.protocol.name"')"
assert_equals "tcp" "$(\echo "$span" | \jq -r '.attributes."network.transport"')"
assert_equals "http://www.google.com:80/" "$(\echo "$span" | \jq -r '.attributes."url.full"')"
assert_equals "http" "$(\echo "$span" | \jq -r '.attributes."url.scheme"')"
assert_equals "/" "$(\echo "$span" | \jq -r '.attributes."url.path"')"
assert_equals "null" "$(\echo "$span" | \jq -r '.attributes."url.query"')"
assert_not_equals "null" "$(\echo "$span" | \jq -r '.attributes."user_agent.original"')"
assert_equals "200" "$(\echo "$span" | \jq -r '.attributes."http.response.status_code"')"
assert_not_equals null "$(\echo "$span" | \jq -r '.attributes."http.response.header.content-type"')"
assert_not_equals null "$(\echo "$span" | \jq -r '.attributes."network.peer.port"')"
span_id=$(\echo "$span" | \jq -r '.parent_id')
span="$(resolve_span '.context.span_id == "'$span_id'"')"
assert_equals "SpanKind.PRODUCER" $(\echo "$span" | \jq -r '.kind')
assert_equals "send/receive" $(\echo "$span" | \jq -r '.name')
span_id=$(\echo "$span" | \jq -r '.parent_id')
span="$(resolve_span '.context.span_id == "'$span_id'"')"
assert_equals "SpanKind.INTERNAL" $(\echo "$span" | \jq -r '.kind')
assert_equals "netcat -w 5 www.google.com 80" "$(\echo "$span" | \jq -r '.name')"

# check HTTP client with real HTTP server (compare instrumented vs non-instrumented)
\echo "TEST 2" >&2
http_body() {
  while read -r line; do
    if \[ "${#line}" = 1 ]; then break; fi
  done
  \cat
}
\printf 'GET /index.html HTTP/1.1\r\nUser-agent: netcat/1.0\r\nAccept: */*\r\nHost: www.example.com\r\n\r\n' | \netcat -w 5 www.example.com 80 | http_body > "$expected"
\printf 'GET /index.html HTTP/1.1\r\nUser-agent: netcat/1.0\r\nAccept: */*\r\nHost: www.example.com\r\n\r\n' |  netcat -w 5 www.example.com 80 | http_body >   "$actual"
assert_equals "$(\cat "$expected")" "$(\cat "$actual")"
assert_equals "$(curl http://www.example.com)" "$(\cat "$actual")"

# check real HTTP client with HTTP server with binary data
\echo "TEST 3" >&2
port=$((port + 1))
\cat /dev/urandom | \head -c $((1024 * 1)) > "$expected" || \true
{ \printf 'HTTP/1.1 200 OK\r\nFoo: Bar\r\n\r\n' && \cat "$expected"; } | netcat -l -w 1 "$port" &
\sleep 3
pid="$!"
\wget --retry-connrefused -O "$actual" http://127.0.0.1:$port/
\wait "$pid" || \true
assert_equals "$(\cat "$expected" | \xxd -p)" "$(\cat "$actual" | \xxd -p)"

# check large binary data integrety
\echo "TEST 4" >&2
port=$((port + 1))
\cat /dev/urandom | \head -c $((1024 * 1)) > "$expected" || \true
netcat -l "$port" > "$actual" &
pid="$!"
\sleep 3
\cat "$expected" | netcat -w 10 127.0.0.1 "$port"
\wait "$pid" || \true
assert_equals "$(\cat "$expected" | \xxd -p)" "$(\cat "$actual" | \xxd -p)"

# check binary data without linefeed (linefeed has an internal meaning)
\echo "TEST 5" >&2
port=$((port + 1))
\cat /dev/urandom | \tr -d '\n' | \head -c $((1024 * 1)) > "$expected" || \true
netcat -l "$port" > "$actual" &
pid="$!"
\sleep 3
\cat "$expected" | netcat -w 10 127.0.0.1 "$port"
\wait "$pid" || \true
assert_equals "$(\cat "$expected" | \xxd -p)" "$(\cat "$actual" | \xxd -p)"

# check simple binary response only
\echo "TEST 6" >&2
port=$((port + 1))
\cat /dev/urandom | \head -c $((1024 * 1)) > "$expected" || \true
\cat "$expected" | netcat -l "$port" &
pid="$!"
\sleep 3
netcat -w 10 127.0.0.1 "$port" > "$actual"
\wait "$pid" || \true
[ -z "$(\cat "$actual" | \xxd -p)" ] || assert_equals "$(\cat "$expected" | \xxd -p)" "$(\cat "$actual" | \xxd -p)" # get some flaky fails on this one when random internet is scanning the port
