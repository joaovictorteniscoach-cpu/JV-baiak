#!/usr/bin/env bash
# Gera dist/instalar-jvbaiak.sh: o kit inteiro num unico arquivo (para enviar por scp
# ou qualquer outro meio quando nao der para baixar do GitHub).
# Uso na VPS:  sudo bash instalar-jvbaiak.sh
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p dist
SAIDA="dist/instalar-jvbaiak.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git archive --format=tar --prefix=jv-baiak/ HEAD | gzip -9 > "$TMP/kit.tar.gz"
{
	cat <<'EOF'
#!/usr/bin/env bash
# JV Baiak - instalador completo em arquivo unico. Uso: sudo bash instalar-jvbaiak.sh
set -euo pipefail
DESTINO="$(mktemp -d /tmp/jvbaiak-kit.XXXXXX)"
sed -n '/^__KIT_ABAIXO__$/,$p' "$0" | tail -n +2 | base64 -d | tar -xz -C "$DESTINO"
if [ -n "${JVBAIAK_SO_EXTRAIR:-}" ]; then echo "$DESTINO/jv-baiak"; exit 0; fi
exec bash "$DESTINO/jv-baiak/instalar.sh" "$@"
__KIT_ABAIXO__
EOF
	base64 -w 76 "$TMP/kit.tar.gz"
} > "$SAIDA"
chmod +x "$SAIDA"
echo "gerado $SAIDA ($(du -h "$SAIDA" | cut -f1)), kit $(git rev-parse --short HEAD)"
