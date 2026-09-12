#!/usr/bin/env bash
set -euo pipefail

# Reproducible, read-only gallery capture. The gallery target is intentionally
# separate from lib/ and must not initialize ERP2/Odoo or write business data.
# Usage:
#   ./tool/capture_operational_shell_gallery.sh dev/operational_shell_gallery.dart

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_FILE="${1:-dev/operational_shell_gallery.dart}"
OUTPUT_DIR="${ORBI_GALLERY_OUTPUT_DIR:-$ROOT_DIR/tool/gallery-captures}"
PORT="${ORBI_GALLERY_PORT:-$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')}"
FLUTTER_PID=""
BROWSER_PROFILE=""

kill_tree() {
  local pid="$1"
  local child
  [[ -n "$pid" ]] || return 0
  for child in $(pgrep -P "$pid" 2>/dev/null || true); do
    kill_tree "$child"
  done
  kill "$pid" 2>/dev/null || true
}

cleanup() {
  if [[ -n "$FLUTTER_PID" ]] && kill -0 "$FLUTTER_PID" 2>/dev/null; then
    kill_tree "$FLUTTER_PID"
    wait "$FLUTTER_PID" 2>/dev/null || true
  fi
  if [[ -n "$BROWSER_PROFILE" ]] && [[ -d "$BROWSER_PROFILE" ]]; then
    rm -rf "$BROWSER_PROFILE"
  fi
}
trap cleanup EXIT INT TERM

if ! command -v flutter >/dev/null 2>&1; then
  echo 'flutter is required' >&2
  exit 127
fi

CHROME_BIN="${CHROME_BIN:-}"
if [[ -z "$CHROME_BIN" ]]; then
  for candidate in \
    "$(command -v google-chrome 2>/dev/null || true)" \
    "$(command -v chromium 2>/dev/null || true)" \
    "$(command -v chromium-browser 2>/dev/null || true)"; do
    if [[ -n "$candidate" ]]; then
      CHROME_BIN="$candidate"
      break
    fi
  done
fi
if [[ -z "$CHROME_BIN" ]]; then
  echo 'Set CHROME_BIN to a Chromium-compatible browser' >&2
  exit 127
fi

BROWSER_PROFILE="$(mktemp -d /tmp/orbi-operational-shell-chrome.XXXXXX)"
mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"
flutter run -d web-server --web-port "$PORT" --web-hostname 127.0.0.1 \
  --target "$TARGET_FILE" >"$OUTPUT_DIR/flutter-web-server.log" 2>&1 &
FLUTTER_PID=$!

for attempt in $(seq 1 60); do
  if grep -q "is being served at http://127.0.0.1:$PORT" \
    "$OUTPUT_DIR/flutter-web-server.log"; then
    break
  fi
  if ! kill -0 "$FLUTTER_PID" 2>/dev/null; then
    echo 'Flutter web-server exited before becoming ready' >&2
    exit 1
  fi
  sleep 1
  if [[ "$attempt" == 60 ]]; then
    echo 'Timed out waiting for Flutter web-server' >&2
    exit 1
  fi
done

URL="http://127.0.0.1:$PORT"
run_capture() {
  local name="$1"
  local width="$2"
  local height="$3"
  local browser_pid
  "$CHROME_BIN" --headless=new --disable-gpu --no-sandbox \
    --user-data-dir="$BROWSER_PROFILE/$name" \
    --run-all-compositor-stages-before-draw --virtual-time-budget=5000 \
    --window-size="$width,$height" \
    --screenshot="$OUTPUT_DIR/operational-shell-$name.png" "$URL" \
    >"$OUTPUT_DIR/chrome-$name.log" 2>&1 &
  browser_pid=$!
  for attempt in $(seq 1 30); do
    if ! kill -0 "$browser_pid" 2>/dev/null; then
      wait "$browser_pid"
      return 0
    fi
    sleep 1
  done
  echo "Timed out capturing $name" >&2
  kill_tree "$browser_pid"
  wait "$browser_pid" 2>/dev/null || true
  return 1
}

run_capture 390x844 390 844
run_capture 820x1180 820 1180
run_capture 1440x900 1440 900

echo "Captured gallery viewports in $OUTPUT_DIR"
