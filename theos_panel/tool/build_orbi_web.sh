#!/usr/bin/env bash
set -euo pipefail

# Build the real Flutter PWA for Odoo's /orbi/ scope and optionally stage it
# into the connector addon. Generated files are deliberately not committed.
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEST_DIR="${ORBI_ADDON_STATIC_DIR:?Set ORBI_ADDON_STATIC_DIR to the connector static/orbi directory}"

cd "$ROOT_DIR"
flutter build web --release --base-href /orbi/
mkdir -p "$DEST_DIR"
rsync -a --delete build/web/ "$DEST_DIR/"
echo "Staged Flutter web bundle at $DEST_DIR"
