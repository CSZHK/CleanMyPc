#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
APP_PATH="${APP_PATH:-$HOME/Applications/Atlas for Mac.app}"
BIN_PATH="$APP_PATH/Contents/MacOS/Atlas for Mac"
STATE_DIR="${STATE_DIR:-$ROOT_DIR/.build/atlas-launch-state}"

if [[ ! -x "$BIN_PATH" ]]; then
    echo "App binary not found: $BIN_PATH" >&2
    exit 1
fi

mkdir -p "$STATE_DIR"
ATLAS_STATE_DIR="$STATE_DIR" "$BIN_PATH" > /tmp/atlas-launch.log 2>&1 &
pid=$!

cleanup() {
    if kill -0 "$pid" > /dev/null 2>&1; then
        kill "$pid" > /dev/null 2>&1 || true
        wait "$pid" > /dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

sleep 3

if ! kill -0 "$pid" > /dev/null 2>&1; then
    echo "Atlas app exited immediately; see /tmp/atlas-launch.log" >&2
    cat /tmp/atlas-launch.log >&2 || true
    exit 1
fi

echo "App launch smoke test succeeded"
echo "PID: $pid"
