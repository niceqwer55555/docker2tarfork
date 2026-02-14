#!/bin/bash

set -e

# Get the directory of the current script
BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Change to that directory
cd "$BIN_DIR" || { echo "Failed to change directory to '$DIR'"; exit 1; }
# Change to the parent directory
cd .. || { echo "Failed to change directory to parent"; exit 2; }

APP_DIR=$(pwd)

# Load VM options
VM_OPTIONS=()
if [[ -f "$BIN_DIR/vmoptions" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -n "$line" ]] && VM_OPTIONS+=("$line")
    done < "$BIN_DIR/vmoptions"
else
    echo "Missing vmoptions file."
    exit 2
fi

# Simple key-value reader for properties
get_prop() {
    local key="$1"
    local file="$2"
    grep -E "^[[:space:]]*$key[[:space:]]*=" "$file" | \
        sed -E 's/^[[:space:]]*'"$key"'[[:space:]]*=[[:space:]]*//' | \
        sed -E 's/[[:space:]]*$//'
}

# Override properties from command-line -D args
STARTSCRIPT_MAIN_OVERRIDE=""
STARTSCRIPT_COMMAND_OVERRIDE=""

for arg in "$@"; do
    case "$arg" in
        -Dstartscript.main=*) STARTSCRIPT_MAIN_OVERRIDE="${arg#*=}" ;;
        -Dstartscript.command=*) STARTSCRIPT_COMMAND_OVERRIDE="${arg#*=}" ;;
    esac
done

# Load properties from file, apply overrides
MAIN_CLASS="${STARTSCRIPT_MAIN_OVERRIDE:-$(get_prop startscript.main "$BIN_DIR/start.properties")}"
COMMAND="${STARTSCRIPT_COMMAND_OVERRIDE:-$(get_prop startscript.command "$BIN_DIR/start.properties")}"
APP_PATH_PARAM="$(get_prop startscript.apppath "$BIN_DIR/start.properties")"

# Java command logic
case "$COMMAND" in
    ""|"auto")
        if [[ -n "$JAVA_HOME" ]]; then
            JAVA_CMD="$JAVA_HOME/bin/java"
        else
            JAVA_CMD="java"
        fi
        ;;
    *)
        JAVA_CMD="$COMMAND"
        ;;
esac

if [[ -z "$MAIN_CLASS" ]]; then
    echo "Required property missing: startscript.main"
    exit 3
fi

if [[ -z "$APP_PATH_PARAM" ]]; then
    echo "Required property missing: startscript.apppath"
    exit 3
fi

# Determine the platform (OS)
case "${OSTYPE}" in
  darwin*) PLATFORM="mac" ;;
  linux*)
    if [ -z "$LC_CTYPE" ] || [ "$LC_CTYPE" = "UTF-8" ]; then
        export LC_CTYPE="C.UTF-8"
    fi
    PLATFORM="linux"
    if [ "$LC_CTYPE" = "UTF-8" ]; then
      export LC_CTYPE="C.UTF-8"
    fi
    ;;
  *) echo "Unsupported OS: $OSTYPE"; exit 4 ;;
esac

ARCH_SUFFIX=""
case "$(uname -m)" in
    *arm*|aarch64) ARCH_SUFFIX="-aarch64" ;;
esac

CLASSIFIER="${PLATFORM}${ARCH_SUFFIX}"
JFX_DIR="$APP_DIR/jfx"
LIBS_DIR="$APP_DIR/libs"
JPRO_LIBS="$APP_DIR/jprolibs"
FONT_DIR="$APP_DIR/fonts/"

if [ ! -d "$JFX_DIR/$CLASSIFIER" ]; then
    echo "Failed to find JavaFX builds for platform '$CLASSIFIER' in this release."
    exit 4
fi

# Set default working directory from environment variable if available
WORKING_DIR="${JPRO_WORKING_DIR:-}"

# Parse arguments to find the working directory if specified and filter out the argument
FILTERED_ARGS=()
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --working-dir) WORKING_DIR="$2"; shift 2 ;;
        *) FILTERED_ARGS+=("$1"); shift ;;
    esac
done

# Use the filtered arguments list for further processing
set -- "${FILTERED_ARGS[@]}"

# Change to the working directory if specified
if [ -n "$WORKING_DIR" ]; then
    if [ -d "$WORKING_DIR" ]; then
        echo "Working directory: '$WORKING_DIR'"
        cd "$WORKING_DIR" || { echo "Failed to change directory to '$WORKING_DIR'"; exit 5; }
    else
        echo "The working directory '$WORKING_DIR' does not exist."
        exit 6
    fi
fi

# Compose classpath/module-path
CLASSPATH=$(JARS=("$LIBS_DIR"/*.jar "$JFX_DIR/$CLASSIFIER"/*.jar); IFS=:; echo "${JARS[*]}")
JPROCLASSPATH=$(JARS=("$JPRO_LIBS"/*.jar); IFS=:; echo "${JARS[*]}")
APP_ARGS=(${APP_ARGS} "-Dprism.fontdir=$FONT_DIR")

# Launch
"$JAVA_CMD" \
      "${VM_OPTIONS[@]}" \
      "${APP_ARGS[@]}" \
      "-Djprocp=$JPROCLASSPATH" \
      "$@" \
      "$APP_PATH_PARAM" "$CLASSPATH" \
      "$MAIN_CLASS"
