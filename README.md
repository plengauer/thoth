_(This repository is also available under the aliases `opentelemetry-bash`, `opentelemetry-shell`, and `opentelemetry-github`.)_

This project delivers [OpenTelemetry](https://opentelemetry.io/) traces, metrics and logs from shell scripts (sh, ash, dash, bash, busybox, and many other POSIX compliant shells) as well as from GitHub workflows (including shell, node, docker and composite actions). Compared to similar projects, it delivers not just a command-line SDK to create spans manually, but also provides automatic context propagation via HTTP (wget, wget2, curl, and netcat), auto-instrumentation of all available commands, auto-injection into child scripts, into executables using shebangs, and into GitHub actions, as well as automatic log collection from stderr and from GitHub action log commands. Its installable via a debian or rpm package from the releases in this repository, from the apt-repository below, and via distributable GitHub actions for workflow-level and job-level instrumentation. This project is not officially affiliated with the CNCF project [OpenTelemetry](https://opentelemetry.io/).

The project is named after [Thoth](https://en.wikipedia.org/wiki/Thoth), the Egyptian god of (among other things) wisdom, knowledge, and science (aka observability), writing and hieroglyphs (aka shell scripts), and judgment of the dead (aka troubleshooting). Thoth was also a member of the Ogdoad, a group of gods responsible for creating the world (aka probably the original GitHub CI/CD pipeline).

[![Tests](https://github.com/plengauer/opentelemetry-bash/actions/workflows/test.yaml/badge.svg?branch=main)](https://github.com/plengauer/opentelemetry-bash/actions/workflows/test.yaml)

# Overview
Check out our detailed [Demos](https://github.com/plengauer/opentelemetry-bash/tree/main/demos).
A simple command like `curl http://www.google.at` on an AWS EC2 will produce a span like this:
```json
{
    "name": "curl http://www.google.at",
    "context": {
        "trace_id": "0xfecf2bf60c1433a33fc3b3715100f44a",
        "span_id": "0x0441d068e0d7d83a",
        "trace_state": "[]"
    },
    "kind": "SpanKind.CLIENT",
    "parent_id": "0x31877863ebe897a6",
    "start_time": "2024-04-07T15:27:35.230551Z",
    "end_time": "2024-04-07T15:27:35.790162Z",
    "status": {
        "status_code": "UNSET"
    },
    "attributes": {
        "shell.command_line": "curl http://www.google.at",
        "shell.command": "curl",
        "shell.command.type": "file",
        "shell.command.name": "curl",
        "subprocess.executable.path": "/usr/bin/curl",
        "subprocess.executable.name": "curl",
        "network.protocol.name": "http",
        "network.transport": "tcp",
        "http.request.method": "GET",
        "server.address": "www.google.at",
        "url.full": "http://www.google.at",
        "url.path": "/",
        "url.scheme": "http",
        "network.peer.address": "172.217.18.3",
        "network.peer.port": 80,
        "http.request.header.host": [ "www.google.at" ],
        "user_agent.original": "curl/8.2.1",
        "http.request.header.user-agent": [ "curl/8.2.1" ],
        "http.request.header.accept": [ "*/*" ],
        "http.request.header.traceparent": [ "00-fecf2bf60c1433a33fc3b3715100f44a-0441d068e0d7d83a-01" ],
        "http.response.status_code": 200,
        "http.response.header.date": [ "Sun, 07 Apr 2024 15:27:35 GMT" ],
        "http.response.header.expires": [ "-1" ],
        "http.response.header.cache-control": [ "private, max-age=0" ],
        "http.response.header.content-type": [ "text/html; charset=ISO-8859-1" ],
        "http.response.header.content-security-policy-report-only": [ "object-src 'none';base-uri 'self';script-src 'nonce-Z06PcaKXtGYEozZ8RwkRlA' 'strict-dynamic' 'report-sample' 'unsafe-eval' 'unsafe-inline' https: http:;report-uri https://csp.withgoogle.com/csp/gws/other-hp" ],
        "http.response.header.server": [ "gws" ],
        "http.response.header.x-xss-protection": [ "0" ],
        "http.response.header.x-frame-options": [ "SAMEORIGIN" ],
        "http.response.header.set-cookie": [ "AEC=AQTF6HxUMJNiGOP4fGxONroFJ61uidlU9uiGQsHcvRug4cz-d5iOLWCN7Q; expires=Fri, 04-Oct-2024 15:27:35 GMT; path=/; domain=.google.at; Secure; HttpOnly; SameSite=lax" ],
        "http.response.header.accept-ranges": [ "none" ],
        "http.response.header.vary": [ "Accept-Encoding" ],
        "http.response.header.transfer-encoding": [ "chunked" ],
        "http.response.body.size": 11984,
        "pipe.stdin.bytes": 0,
        "pipe.stdin.lines": 0,
        "pipe.stdout.bytes": 18750,
        "pipe.stdout.lines": 16,
        "pipe.stderr.bytes": 391,
        "pipe.stderr.lines": 4,
        "shell.command.exit_code": 0,
        "code.filepath": "./otel_demo_curl.sh",
        "code.lineno": 2,
    },
    "events": [],
    "links": [],
    "resource": {
        "attributes": {
            "telemetry.sdk.language": "shell",
            "telemetry.sdk.name": "opentelemetry",
            "telemetry.sdk.version": "4.2.1",
            "deployment.environment": "development",
            "service.name": "DemoService",
            "cloud.provider": "aws",
            "cloud.platform": "aws_ec2",
            "cloud.account.id": "785162395342",
            "cloud.region": "eu-central-1",
            "cloud.availability_zone": "eu-central-1b",
            "host.id": "i-099942b18fe209756",
            "host.type": "t3.small",
            "host.name": "ip-172-31-41-64.eu-central-1.compute.internal",
            "process.pid": 798293,
            "process.parent_pid": 786902,
            "process.executable.name": "bash",
            "process.executable.path": "/usr/bin/bash",
            "process.command_line": "bash ./otel_demo_curl.sh",
            "process.command": "bash",
            "process.owner": "ubuntu",
            "process.runtime.name": "bash",
            "process.runtime.description": "Bourne Again Shell",
            "process.runtime.version": "5.2.15-2ubuntu1",
            "process.runtime.options": "hB",
            "service.version": "1.0.0",
            "service.namespace": "Demo",
            "service.instance.id": ""
        },
        "schema_url": ""
    }
}
```

## Try For Yourself Locally
For local deployment in a shell script, install as described below. Put the following code at the start of an arbitrary script:
```bash
export OTEL_METRICS_EXPORTER=console
export OTEL_LOGS_EXPORTER=console
export OTEL_TRACES_EXPORTER=console
. otel.sh
```
Finally, run your script and see traces, metrics, and logs printed to stderr. For deployment in GitHub actions, refer to Automatic Instrumentation of GitHub Actions below.

# Security
Since version 3.43.0, this project generates artifact attestations to establish provenance for builds (<a href="https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds">link</a>) to harden against supply chain attacks. Download any build artifact from the repositories above or directly from the releases of this repository and use the following code snippet to verify that the package has indeed been built at this location.
```bash
gh attestation verify ./package.deb -R plengauer/opentelemetry-bash
```

# Documentation
You can either use the fully automatic instrumentation (recommended) or just import the API to do everything manually. In both cases, you can use the API to manually create customized spans and metrics. However, the automatic approach creates rich spans and logs fully automatically. We recommend to use the manual approach only to augment the automatic approach where necessary.

## Automatic Instrumentation of Shell Scrips
This project currently supports and is actively tested on debian-based (Debian and Ubuntu) and rpm-based (Fedora, OpenSuse, and Red Hat Enterprise Linux (RHEL)) operating systems as well as on the Windows Subsystem for Linux. The code also works on other Linux-based operating systems, however, there are no readily available installation packages for these systems. Mac-based operating systems are currently not supported. For deployment in GitHub actions, see Automatic Instrumentation of GitHub Actions below. For deployment on other any Linux-based system, install either via
```bash
wget -O - https://raw.githubusercontent.com/plengauer/opentelemetry-shell/main/INSTALL.sh | sh
```
or, for debian-based systems, via
```bash
echo "deb [arch=all] http://3.73.14.87:8000/ stable main" | sudo tee /etc/apt/sources.list.d/otel.list
sudo apt-get update
sudo apt-get install opentelemetry-shell
```
Note: the apt repo only acts as a facade to offer a better debian-native installation option, internally it redirects the apt client to the releases of this repository.

Import the OpenTelemetry auto instrumentation as well as the API by sourcing the `otel.sh` file. This will both import the API described below (in case you need or want to extend manually) as well as initialize the SDK and the auto instrumentation. No explicit calls to `otel_init` at the start or to `otel_shutdown` at the end of the script are necessary. You can configure the SDK as described <a href="https://opentelemetry.io/docs/languages/sdk-configuration/">here</a>. We recommend not just setting configuration variables, but also exporting them so that automatically injected children inherit the same configuration.
```bash
export OTEL_SERVICE_NAME=Test
export OTEL_RESOURCE_ATTRIBUTES=foo=bar,baz=foo
# TODO more config
. otel.sh
# ...
```

All commands are automatically instrumented to create spans. This includes commands on the `PATH`, as well as all aliases and built-ins. Current limitations are shell functions as well as commands that are called via an absolute or relative path (`/bin/cat` rather than `cat`). For these cases, you can use `otel_observe` described below.
For all commands, attributes of the `shell.*` (describing the command being run), `pipe.*` (describing behavior of stdin, stdout, and stderr), `subprocess.executable.*` (describing the executable being run if any), and `code.*` (describing the location in the script) families are recorded. Additionally, all lines written to stderr are recorded as logs.

If the command is a shell or an executable with a shebang (meaning it itself is script rather a than a binary), OpenTelemetry will be automatically injected into it to continue observation. No setup code or configuration is necessary in these children.
If the command is just a wrapper for another command (e.g., `sudo`, `find`, `xargs`, `parallel`, ...), OpenTelemetry will automatically be injected into the inner command to continue observation as well.
If the command represents communication to a third party service (like a HTTP request via `curl` or `wget`), relevant attributes from the `http.*`, `server.*`, `url.*`, and `network.*` families are added. Additionally, a W3C traceparent header is injected.

Finally, a single root span will be created and activated that represents the script. This span will automatically be deactivated and ended when the script ends.

## Automatic Instrumentation of GitHub Actions
To automatically monitor your GitHub Actions by exporting logs, metrics and traces, this project can be used to instrument at workflow level as well as on job level. The workflow-level instrumentation is deployed as a separate workflow (see below), triggered by `workflow run` events, and uses the GitHub API to create logs, metrics, and spans based on the meta data that GitHub provides. The job-level instrumentation is deployed as the first action within a job definition (see below) and runs on the GitHub runner itself.

The workflow-level instrumentation is a good starting point to get an overview of the GitHub actions of repository. It can export logs (all logs that GitHub records), metrics (count and duration metrics for workflows, jobs, steps, and actions), as well as spans for workflows, jobs, and steps. However, since it observes any signal only after the fact, it lacks depth and details. The job-level instrumentation can be deployed into any job running on a linux-based runner and exports the same logs, the same metrics for jobs, steps, and actions, and the same traces for jobs and steps. Since it is injected and running inside a job, metrics and spans are richer in details. For example, it can capture detailed input and output paramters to every step, as well as state transitions. Additionally, job-level instrumentation can actually inject into every GitHub step (no matter if its a script action, docker action, node action, or composite action) and generate detailed traces describing their internal activities. Additionally, measurements are more accurate compared to the workflow-level instrumentation.

Both methods of instrumentation can be combined arbitrarily. Deploying them both at the same time, will combine their advantages without any double recording of any log, metric, trace or span.

To deploy workflow-level instrumentation, use the code snippet below in a dedicated workflow to run after any other explicitly configured workflow. You can configure the SDK as described <a href="https://opentelemetry.io/docs/languages/sdk-configuration/">here</a> by adding according environment variables. Workflow-level instrumentation can be combined arbitrarily with job-level instrumentation.
```yaml
name: OpenTelemetry
on:
  workflow_run:
    workflows: [Build, Test, Publish] # TODO list the workflows that should be observed
    types:
      - completed
jobs:
  export:
    runs-on: ubuntu-latest
    steps:
      - uses: plengauer/opentelemetry-github/actions/instrument/workflow@main
        env:
          OTEL_SERVICE_NAME: ${{ secrets.SERVICE_NAME }}
          # ...
```

To deploy job-level instrumetnation, add the following step as first in every job you want to observe. You can configure the SDK as described <a href="https://opentelemetry.io/docs/languages/sdk-configuration/">here</a> by adding according environment variables to the setup step. Job-level instrumentation can be combined arbitrarily with workflow-level instrumentation.
```yaml
- uses: plengauer/opentelemetry-github/actions/instrument/job@main
  env:
    OTEL_SERVICE_NAME: 'Test'
    # ...
- run: ...
```
Depending on the actions in use, GitHub `secrets` or other sensitive information could appear in commandlines or action inputs/states which may captured as attributes on spans, metrics, or logs recorded by job-level instrumentation. To redact these secrets, use the following parameter to redact their values from any attribute. The value of the parameter must be a `json` object, whereas every value of every field is considered a secret to be redacted. By default, if left unset, the implicit GitHub token is redacted.
```yaml
- uses: plengauer/opentelemetry-github/actions/instrument/job@main
  with:
    secrets_to_redact: '${{ toJSON(secrets) }}' # Redact all secrets from any attribute, span name, or log body.
```

## Manual Instrumentation
Import the API by referencing the `otelapi.sh` file. This is only necessary if you do not choose a fully automatic approach described above. In case you use automatic instrumentation, the API will be imported automatically for you.
The SDK needs to be initialized and shut down manually at the start and at the end of your script respectively. All config must be set before the call to `otel_init`. You can configure the underlying SDK with the same variables as any other OpenTelemetry SDK as described <a href="https://opentelemetry.io/docs/languages/sdk-configuration/">here</a>. We recommend not just setting the environment variables, but also exporting them so that automatically injected children inherit the same configuration.
```bash
export OTEL_SERVICE_NAME=Test
export OTEL_RESOURCE_ATTRIBUTES=foo=bar,baz=foo
# TODO more config
. otelapi.sh

otel_init
# ... 
otel_shutdown
```

## Configuration
You can configure the underlying SDK with the same variables as any other OpenTelemetry SDK as described <a href="https://opentelemetry.io/docs/languages/sdk-configuration/">here</a>. Currently only the `otlp`, `console`, and `none` exporters are supported. In addition to that, use the following environment variables to further configure behavior of this project:
| Variable                                    | Values          | Default                                      | Description                                                                                 | State        |
| ------------------------------------------- | --------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------- | ------------ |
| OTEL_SHELL_CONFIG_OBSERVE_PIPES             | `TRUE`, `FALSE` | `TRUE` for GitHub Actions, `FALSE` otherwise | Count bytes and lines on stdout, and stderr and add counts as attributes on spans.          | stable       |
| OTEL_SHELL_CONFIG_OBSERVE_PIPES_STDIN       | `TRUE`, `FALSE` | `FALSE`                                      | Count bytes and lines on stdin and add counts as attributes on spans.                       | unsafe       |
| OTEL_SHELL_CONFIG_MUTE_INTERNALS            | `TRUE`, `FALSE` | `FALSE`                                      | Only create `SERVER`, `CONSUMER`, `CLIENT` and `PRODUCER` spans, mute all `INTERNAL` spans. | stable       |
| OTEL_SHELL_CONFIG_MUTE_BUILTINs             | `TRUE`, `FALSE` | `TRUE` for GitHub Actions, `FALSE` otherwise | Do not create spans for built-in commands like `echo`, `printf`, `[`, ...                   | stable       |
| OTEL_SHELL_CONFIG_INJECT_DEEP               | `TRUE`, `FALSE` | `TRUE` for GitHub Actions, `FALSE` otherwise | Inject native OpenTelemetry into scripting languages like node.js, python or java.          | stable       |
| OTEL_SHELL_CONFIG_INSTRUMENT_ABSOLUTE_PATHS | `TRUE`, `FALSE` | `FALSE`                                      | Create spans for commands with an absolute path to the executable.                          | experimental |
| OTEL_SHELL_CONFIG_OBSERVE_SIGNALS           | `TRUE`, `FALSE` | `TRUE` for GitHub Actions, `FALSE` otherwise | Create events for received signals.                                                         | stable       |
| OTEL_SHELL_CONFIG_OBSERVE_SUBPROCESSES      | `TRUE`, `FALSE` | `TRUE` for GitHub Actions, `FALSE` otherwise | Create additional minimal spans for all indirect subprocesses.                              | stable       |

Flags that are marked as `stable` are tested and verified in tests and real-world scenarios. Flags marked as `experimental` are new features that are tested but still lack long-term verification in real-world applications. They will eventually reach `stable` or `unsafe`. Flags marked as `unsafe` have implicit assumptions about the nature of the instrumented scripts and will therefore never reach `stable`.

## Limitations
Currently, we do not support restricted mode in shells (`set -r`).

## Traces
The API described below is for manually creating and customizing spans. We recommend to do this only if the automatic instrumentation is not sufficient.

### Spans
Create spans with a span kind (`SERVER`, `CONSUMER`, `CLIENT`, `PRODUCER`, `INTERNAL`) and an arbitrary name. The returned span handle is used to end the span and to customize it (see below). The span handle is similar to a file descriptor. It is only valid within this process and used for subsequent calls for customization. It is not the actual span ID.
```bash
span_handle="$(otel_span_start INTERNAL my span)"
# ... 
otel_span_end "$span_handle"
```

Creating a span alone will not make new spans its children (see span activation below). Start and end time of the span as well as its parent (if another span is currently active) is automatically recorded.

### Span Attributes
Customize your spans by manually setting span attributes with the span handle. This is only possible between `otel_span_start` and `otel_span_end` for the respective span handle. Valid types are `string`, `int`, `float`, and `auto`. The `auto` type will try to guess the type based on the value.
```bash
otel_span_attribute "$span_handle" key=value
otel_span_attribute_typed "$span_handle" string foo=bar
otel_span_attribute_typed "$span_handle" int numberkey=0
```

### Span Events
Customize your spans by manually adding span events with the span handle. This is only possible between `otel_span_start` and `otel_span_end` for the respective span handle. Valid types for event attributes `string`, `int`, `float`, and `auto`. The `auto` type will try to guess the type based on the value.
```bash
event_handle="$(otel_event_create "my event")"
otel_event_attribute "$event_handle" key=value
otel_event_attribute_typed "$event_handle" string foo=bar
otel_event_add "$event_handle" "$span_handle"
```

### Span Links
Customize your spans by manually adding span links to other spans. This is only possible between `otel_span_start` and `otel_span_end` for the respective span handle. Valid types for link attributes `string`, `int`, `float`, and `auto`. The `auto` type will try to guess the type based on the value.
```bash
link_handle="$(otel_link_create "$foreign_traceparent" "$foreign_tracestate")"
otel_link_attribute "$link_handle" key=value
otel_link_attribute_typed "$link_handle" string foo=bar
otel_link_add "$link_handle" "$span_handle"
```

### Span Error
Customize your spans by marking them as failed. This is only possible between `otel_span_start` and `otel_span_end` for the respective span handle.
```bash
otel_span_error "$span_handle"
```

### Span Activation
Customize your spans by marking them as failed. This is only possible between `otel_span_start` and `otel_span_end` for the respective span handle. Please note, that `span_start` does not automatically activate a span, nor does `span_end` automatically deactivate it.
```bash
otel_span_activate "$span_handle"
# ... all spans created here will be children of the activated span
otel_span_deactivate
```

### Semi-automatic Spans 
The easiest way to create a span manually and fill it with some simple default attributes is to use the command `otel_observe`. This command acts as a wrapper for the given command. It first starts an `INTERNAL` span with the command as name, records some default attributes, activates the span (in case the command in turn creates spans), and then runs the command. After the command terminates, it deactivates the span and ends it. The automatically recorded attributes are of the `shell.*`, `pipe.*`, and `subprocess.executable.*` families. All lines, written to stderr will be recorded as logs. The command is fully transparent in its behavior, i.e., stdin, stdout, and stderr of the wrapped command are piped to the caller accordingly, and the command exits with the same exit code as the wrapped command does.
```bash
otel_observe cat file.txt
```

Please note, that this command will not perform injection or context propagation. This can only be done via the fully automatic approach described above.

## Metrics
To record metric data points, first create a new counter with a type, name, unit, and description. Valid types are `counter`, `up_down_counter`, and `gauge` as well as `observable_counter`, `observable_up_down_counter`, and `observable_gauge`. Then create an observation with the amount and arbitrary attributes. The observable counters will continuously report every observation until its replaced with another observation with the same attribute values. The returned counter handle is used to observe data points and their attributes. Valid observation attribute types are `string`, `int`, `float`, and `auto`. The `auto` type will try to guess the type based on the value.
```bash
counter_handle="$(otel_counter_create up_down_counter my.metric MB 'this is an example metric')"
observation_handle="$(otel_observation_create 5)"
otel_observation_attribute "$observation_handle" key=value
otel_observation_attribute_typed "$observation_handle" string foo=bar
otel_counter_observe "$counter_handle" "$observation_handle"
observation_handle="$(otel_observation_create -3)"
otel_observation_attribute "$observation_handle" key=value
otel_observation_attribute_typed "$observation_handle" string foo=bar
otel_counter_observe "$counter_handle" "$observation_handle"
```

## Logs
As of now, there is no way to manually record logs. Logs, i.e., lines that are written to stderr, are recorded automatically when using auto-instrumentation and when using `otel_observe` as described above.

# Performance
Every command executed in an automatically instrumented script produces a small amount of constant overhead. This is usually not a problem, especially in traditional scripts where the heavy lifting is done within external processes and not in the script itself.

When a script is instrumented for the first time, instrumenting will cause some additional overhead. To speed up subsequent invocations of the same script, an instrumentation cache is created. The cache will be invalidated if the script changes or additional executables are installed on the system and will be automatically rebuilt on the next invocation of the script.

# Extension to Semantic Conventions
This projects adheres to the <a href="https://opentelemetry.io/docs/specs/semconv">OpenTelemetry Semantic Conventions</a>, but it also defines a number of shell-specifc extensions.

## Shell Commands
| Attribute               | Type   | Description                                                                                     | Examples                                          |
| ----------------------- | ------ | ----------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| shell.command_line      | string | The full command line as it appears in the script, with all variables resolved to their values. | `echo hello world`, `/bin/cat file.txt`           |
| shell.command           | string | The 0-th string of the command line.                                                            | `echo`, `/bin/cat`                                |
| shell.command.name      | string | The 0-th string of the command line resolved to its name only.                                  | `echo`, `cat`                                     |
| shell.command.type      | string | The type of the command.                                                                        | `file`, `builtin`, `function`, `alias`, `keyword` |
| shell.command.exit_code | int    | The exit code of the command.                                                                   | `0`, `1`, `127`                                   |

## Pipes
| Attribute         | Type | Description                                   | Examples |
| ----------------- | ---- | --------------------------------------------- | -------- |
| pipe.stdin.bytes  | int  | The number of bytes read from stdin (fd 0).   | `0`      |
| pipe.stdin.lines  | int  | The number of lines read from stdin (fd 0).   | `0`      |
| pipe.stdout.bytes | int  | The number of bytes written to stdout (fd 1). | `0`      |
| pipe.stdout.lines | int  | The number of lines written to stdout (fd 1). | `0`      |
| pipe.stderr.bytes | int  | The number of bytes written to stderr (fd 2). | `0`      |
| pipe.stderr.lines | int  | The number of lines written to stderr (fd 2). | `0`      |

## SSH
These attributes are set when the script is called via an SSH connection.
| Attribute | Type   | Description                                           | Examples  |
| --------- | ------ | ----------------------------------------------------- | --------- |
| ssh.ip    | string | The IP address of the ssh deamon used for connecting. | `1.1.1.1` |
| ssh.port  | int    | The port of the ssh deamon used for connecting.       | `1.1.1.1` |

## Debian
These attributes are set when the script is a debian package maintainer script (`preinst`, `postinst`, `prerm`, `postrm`)
| Attribute              | Type   | Description                 | Examples              |
| ---------------------- | ------ | --------------------------- | --------------------- |
| debian.package.name    | string | The name of the package.    | `opentelemetry-shell` |
| debian.package.version | string | The version of the package. | `1.2.3`               |
