#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR" || { echo "Failed to change directory to $DIR"; exit 1; }

if [[ -x "./stop.sh" && -x "./start.sh" ]]; then
    ./stop.sh
    ./start.sh "$@"
else
    echo "Required scripts stop.sh or start.sh not found or not executable"
    exit 2
fi
