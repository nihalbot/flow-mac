#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="${SCRIPT_DIR}/build/Flow.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "Building Flow.app first..."
    "${SCRIPT_DIR}/build_app.sh"
fi

echo "Launching Flow..."
open "${APP_PATH}"
