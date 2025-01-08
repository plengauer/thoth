import sys
import os

try:
    import opentelemetry
    from opentelemetry.context import attach
    from opentelemetry.trace.propagation import tracecontext
    
    traceparent = os.getenv("TRACEPARENT")
    if traceparent:
        propagator = tracecontext.TraceContextTextMapPropagator()
        carrier = { "traceparent": traceparent }
        new_context = propagator.extract(carrier=carrier)
        attach(new_context)
    
    def inject_env(env):
        if not env:
            env = os.environ.copy()
        carrier = {}
        tracecontext.TraceContextTextMapPropagator().inject(carrier, opentelemetry.trace.set_span_in_context(opentelemetry.trace.get_current_span(), None))
        if 'traceparent' in carrier:
          env["OTEL_TRACEPARENT"] = carrier["traceparent"]
        if 'tracestate' in carrier:
          env["OTEL_TRACESTATE"] = carrier["tracestate"]
        return env;
        
except ModuleNotFoundError:
    def inject_env(env):
        if not env:
            env = os.environ.copy()
        return env

import functools

def inject_file(file):
  return '/bin/sh'

def inject_arguments(file, args):
  try:
    file = file.decode()
  except (UnicodeDecodeError, AttributeError):
    pass
  if type(args) is tuple:
      args = list(args)
  if '/' in file and (not os.path.exists(file) or not os.path.isfile(file) or not os.access(file, os.X_OK)):
    raise FileNotFoundError(file) # python will just trial and error all possible paths if the 'p' variants of exec are used
  return [ args[0], '-x', '-c', '. otel.sh\n_otel_inject "' + str(file) + '" "$@"', 'python' ] + args[1:]

def observed_os_execv(original_os_execve, file, args):
  # print('os.execv(' + str(file) + ', ' + str(args) + ')', file=sys.stderr)
  # print('os.execv(' + inject_file(file) + ', [' + ','.join(inject_arguments(file, args)) + '], ' + str(inject_env(None)) + ')', file=sys.stderr)
  return original_os_execve(inject_file(file), inject_arguments(file, args), inject_env(None))

def observed_os_execve(original_os_execve, file, args, env):
  # print('os.execve(' + str(file) + ', ' + str(args) + ', ' + str(env) + ')', file=sys.stderr)
  # print('os.execve(' + inject_file(file) + ', [' + ','.join(inject_arguments(file, args)) + '], ' + str(inject_env(env)) + ')', file=sys.stderr)
  return original_os_execve(inject_file(file), inject_arguments(file, args), inject_env(env))

# def observed_os_execvp(original_os_execvpe, file, args):
#    return original_os_execvpe(inject_file(file), inject_arguments(file, args), inject_env(None))

# def observed_os_execvpe(original_os_execvpe, file, args, env):
#    return original_os_execvpe(inject_file(file), inject_arguments(file, args), inject_env(env))

def instrument(observed_function, original_function):
   return functools.partial(observed_function, original_function)

os.execv = instrument(observed_os_execv, os.execve)
os.execve = instrument(observed_os_execve, os.execve)
# os.execvp = instrument(observed_os_execvp, os.execvpe)
# os.execvpe = instrument(observed_os_execvpe, os.execvpe)
# print('INSTRUMENTED', file=sys.stderr)
