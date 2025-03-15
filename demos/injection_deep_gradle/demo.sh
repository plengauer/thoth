export GRADLE_HOME=/opt/gradle/latest
export PATH="$(pwd)":"$GRADLE_HOME"/bin:"$PATH"
export OTEL_SHELL_CONFIG_INJECT_DEEP=TRUE
. otel.sh
gradlew build
