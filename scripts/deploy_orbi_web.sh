#!/usr/bin/env bash
# Publica Orbi web en https://orbi.galapagos.tech desde un COMMIT.
#
#   scripts/deploy_orbi_web.sh            # publica HEAD
#   scripts/deploy_orbi_web.sh 9a53b96    # publica ese commit
#
# 🔴 Se compila SIEMPRE desde un commit, en un worktree temporal, y nunca desde el
# árbol de trabajo. El 12-sep-2026 el árbol tenía cambios a medio hacer de varios
# agentes; compilar desde ahí habría publicado eso a todos los clientes. Así, lo
# que está en el servidor es exactamente un commit, y `orbi-commit.txt` dice cuál.
#
# Cómo está montado el sitio (servidor, volumen, vhost, certificado): memoria
# `orbi-galapagos-tech-hosting`, y el vhost versionado en
# dev_odoo20/etl/orbi/servidor/.
set -euo pipefail

COMMIT="${1:-HEAD}"
FLUTTER="${FLUTTER:-flutter}"
HOST="root@72.62.101.29"
DEST="/var/lib/docker/volumes/global-nginx-proxy_html/_data/orbi-app/"
URL="https://orbi.galapagos.tech"
FLUTTER_REQUERIDO="3.47.1"

ROOT="$(git rev-parse --show-toplevel)"
SHA="$(git -C "$ROOT" rev-parse --short "$COMMIT")"
ASUNTO="$(git -C "$ROOT" log -1 --format=%s "$SHA")"

# La versión de Flutter está fijada en todo el monorepo (coincide con CI). Otra
# versión compila, pero no produce lo mismo que se probó.
if ! "$FLUTTER" --version 2>/dev/null | head -1 | grep -q "Flutter $FLUTTER_REQUERIDO"; then
  echo "❌ Hace falta Flutter $FLUTTER_REQUERIDO; hay: $("$FLUTTER" --version 2>/dev/null | head -1)" >&2
  exit 1
fi

WT="$(mktemp -d "${TMPDIR:-/tmp}/orbi-web-release.XXXXXX")"
limpiar() {
  git -C "$ROOT" worktree remove --force "$WT" >/dev/null 2>&1 || rm -rf "$WT"
  git -C "$ROOT" worktree prune
}
trap limpiar EXIT

git -C "$ROOT" worktree add --detach "$WT" "$SHA" >/dev/null
echo "==> Compilando $SHA — $ASUNTO"
echo "    Tarda entre dos y tres minutos y no imprime nada mientras: no está colgado."
(
  cd "$WT/theos_panel"
  "$FLUTTER" pub get >/dev/null
  "$FLUTTER" build web --release --base-href=/
)

OUT="$WT/theos_panel/build/web"
# El paquete que sirve cada Odoo en /orbi/ se compila con otra base. Si por error
# saliera con esa, la página cargaría en blanco pidiendo ficheros en /orbi/.
if ! grep -q '<base href="/">' "$OUT/index.html"; then
  echo "❌ index.html no trae <base href=\"/\">; no se publica." >&2
  exit 1
fi
echo "$SHA" > "$OUT/orbi-commit.txt"

# Todo menos el índice primero, y el índice al final: así nunca hay un instante en
# que un index.html nuevo pida un main.dart.js que todavía no llegó. --delete no
# borra index.html porque está excluido, así que el viejo sigue sirviendo hasta
# que se reemplaza.
echo "==> Subiendo todo menos index.html"
rsync -rlt --delete --exclude index.html "$OUT/" "$HOST:$DEST"
echo "==> Subiendo index.html al final"
rsync -rlt "$OUT/index.html" "$HOST:$DEST"
ssh -n "$HOST" "chmod -R a+rX '$DEST'"

echo "==> Verificando desde fuera"
PUBLICADO="$(curl -fsS --max-time 20 "$URL/orbi-commit.txt")"
if [ "$PUBLICADO" != "$SHA" ]; then
  echo "❌ El sitio dice $PUBLICADO y se esperaba $SHA." >&2
  exit 1
fi
# `main.dart.js` pesa más de 6 MB y se descarga entero: con 20 s de tope el chequeo
# se cortó (curl 28) con el sitio sirviendo bien. 120 s mide lo mismo sin falso rojo.
for RUTA in / /main.dart.js /flutter_bootstrap.js /envases; do
  CODIGO="$(curl -s -o /dev/null -w '%{http_code}' --max-time 120 "$URL$RUTA" || true)"
  printf '    %-24s %s\n' "$RUTA" "$CODIGO"
  [ "$CODIGO" = 200 ] || { echo "❌ $RUTA respondió $CODIGO." >&2; exit 1; }
done
echo "==> Publicado $SHA en $URL"
