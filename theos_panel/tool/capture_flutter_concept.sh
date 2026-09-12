#!/usr/bin/env bash
set -euo pipefail

# Captura una maqueta Flutter aislada en tres tamaños. El target se sirve con
# web-server local: no arranca la aplicación de producción ni toca ERP2/Odoo.
# Uso:
#   ./tool/capture_flutter_concept.sh TARGET_DART OUTPUT_DIR
# También acepta TARGET_DART y OUTPUT_DIR como variables de entorno.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DART="${1:-${TARGET_DART:-}}"
OUTPUT_DIR="${2:-${OUTPUT_DIR:-}}"
PORT="${ORBI_CONCEPT_PORT:-$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')}"
FLUTTER_PID=""
BROWSER_PROFILE=""

if [[ -z "$TARGET_DART" || -z "$OUTPUT_DIR" ]]; then
  echo "Uso: $0 TARGET_DART OUTPUT_DIR" >&2
  exit 64
fi

kill_tree() {
  local pid="$1" child
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0
  for child in $(pgrep -P "$pid" 2>/dev/null || true); do
    kill_tree "$child"
  done
  kill "$pid" 2>/dev/null || true
}

cleanup() {
  if [[ "$FLUTTER_PID" =~ ^[0-9]+$ ]] && kill -0 "$FLUTTER_PID" 2>/dev/null; then
    kill_tree "$FLUTTER_PID"
    wait "$FLUTTER_PID" 2>/dev/null || true
  fi
  if [[ -n "$BROWSER_PROFILE" && -d "$BROWSER_PROFILE" ]]; then
    rm -rf "$BROWSER_PROFILE"
  fi
}
trap cleanup EXIT INT TERM

command -v flutter >/dev/null 2>&1 || { echo 'flutter is required' >&2; exit 127; }

CHROME_BIN="${CHROME_BIN:-}"
if [[ -z "$CHROME_BIN" ]]; then
  for candidate in \
    "$(command -v google-chrome 2>/dev/null || true)" \
    "$(command -v chromium 2>/dev/null || true)" \
    "$(command -v chromium-browser 2>/dev/null || true)"; do
    if [[ -n "$candidate" ]]; then CHROME_BIN="$candidate"; break; fi
  done
fi
[[ -n "$CHROME_BIN" ]] || { echo 'Set CHROME_BIN to a Chromium-compatible browser' >&2; exit 127; }

mkdir -p "$OUTPUT_DIR"
BROWSER_PROFILE="$(mktemp -d /tmp/orbi-flutter-concept-chrome.XXXXXX)"
cd "$ROOT_DIR"
flutter run -d web-server --web-port "$PORT" --web-hostname 127.0.0.1 \
  --target "$TARGET_DART" >"$OUTPUT_DIR/flutter-web-server.log" 2>&1 &
FLUTTER_PID=$!

# Readiness requires Flutter's own served-at line and a successful HTTP probe;
# an open TCP port alone can still be the compiler/server startup window.
for attempt in $(seq 1 60); do
  if grep -q "is being served at http://127.0.0.1:$PORT" \
    "$OUTPUT_DIR/flutter-web-server.log" && \
    curl --silent --show-error --fail --max-time 2 "http://127.0.0.1:$PORT" >/dev/null; then
    break
  fi
  if ! kill -0 "$FLUTTER_PID" 2>/dev/null; then
    echo 'Flutter web-server exited before becoming ready' >&2
    exit 1
  fi
  sleep 1
  [[ "$attempt" != 60 ]] || { echo 'Timed out waiting for Flutter web-server' >&2; exit 1; }
done

URL="http://127.0.0.1:$PORT"
run_capture() {
  local name="$1" width="$2" height="$3" browser_pid=""
  "$CHROME_BIN" --headless=new --disable-gpu --no-sandbox \
    --user-data-dir="$BROWSER_PROFILE/$name" \
    --run-all-compositor-stages-before-draw --virtual-time-budget=5000 \
    --window-size="$width,$height" \
    --screenshot="$OUTPUT_DIR/concept-$name.png" "$URL" \
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
echo "Captured concept viewports in $OUTPUT_DIR"
