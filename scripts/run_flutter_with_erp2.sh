#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
credential_file=${THEOS_ERP2_ENV_FILE:-"$HOME/.config/tecnosmart/erp2_api.env"}
device=${1:-macos}
shift || true

case "$device" in
  chrome|web-server)
    echo "THEOS_ERP2_API_KEY injection is disabled for Web targets." >&2
    exit 2
    ;;
esac

for argument in "$@"; do
  case "$argument" in
    --release|--release=*|--profile|--profile=*)
      echo "THEOS_ERP2_API_KEY injection is limited to native debug builds." >&2
      exit 2
      ;;
  esac
done

if [[ ! -r "$credential_file" ]]; then
  echo "ERP2 credential file is not readable: $credential_file" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$credential_file"
set +a

if [[ -z "${ERP2_API_KEY:-}" ]]; then
  echo "ERP2_API_KEY is missing from $credential_file" >&2
  exit 1
fi

cd "$repo_root/theos_pos"
exec flutter run \
  -d "$device" \
  --dart-define="THEOS_ERP2_API_KEY=$ERP2_API_KEY" \
  "$@"
