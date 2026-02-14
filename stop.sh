#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR" || { echo "Failed to change directory to $DIR"; exit 1; }
cd .. || { echo "Failed to change directory to parent"; exit 2; }

# Set the application directory
APP_DIR=$(pwd)
echo "Application directory: '$APP_DIR'"

# Print arguments if any are provided
if [ "$#" -gt 0 ]; then\
  echo "Provided arguments: $@"
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
        cd "$WORKING_DIR" || { echo "Failed to change directory to '$WORKING_DIR'"; exit 4; }
    else
        echo "The working directory '$WORKING_DIR' does not exist."
        exit 5
    fi
fi

PID_FILE="RUNNING_PID"

# Check if the PID file exists
if [ -e "$PID_FILE" ]; then
  PID=$(<"$PID_FILE")

  # Check if the process is running
  if kill -0 "$PID" 2>/dev/null; then
    echo "Killing process $PID"
    kill "$PID"

    # Wait for the process to terminate
    sleep 5

    # Check again if the process is still running
    if kill -0 "$PID" 2>/dev/null; then
      echo "Now force killing $PID"
      kill -9 "$PID"
    fi

    # Remove the PID file
    rm -f "$PID_FILE"
  else
    echo "Removing stale PID file"
    rm -f "$PID_FILE"
  fi
else
  echo "No PID file found"
fi
