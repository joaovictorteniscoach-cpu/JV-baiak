#!/usr/bin/env bash
# Execute de um checkout do kit; atualiza SOMENTE dois patches do cliente web.
set -Eeuo pipefail
umask 077
BASE="${BASE:-/opt/jvbaiak}"
DOMINIO="${1:-bayakjh.duckdns.org}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
falha() { printf 'ERRO: %s\n' "$*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || falha 'Execute com sudo.'
[[ "$DOMINIO" =~ ^[a-z0-9.-]+\.[a-z]{2,}$ ]] || falha 'Dominio invalido.'
for cmd in docker git flock curl; do command -v "$cmd" >/dev/null || falha "Falta $cmd"; done
[ -f "$BASE/.env" ] && [ -f "$BASE/web/compilar-web.sh" ] || falha 'Instalacao nao encontrada.'
exec 9>/run/jvbaiak-correcao-iphone.lock
flock -n 9 || falha 'Outra atualizacao iPhone esta rodando.'
if command -v systemctl >/dev/null && systemctl is-active --quiet jvbaiak-web.service; then
  falha 'A compilacao web existente ainda esta em andamento; aguarde terminar.'
fi
cmp -s "$SRC/web/versao-base.env" "$BASE/web/versao-base.env" || falha 'A base do cliente mudou. Revisao manual necessaria.'
for patch in 0001-celular-tela-e-toque.patch 0002-portugues-padrao.patch 0003-porta-do-jogo.patch 0004-teclado-iphone.patch 0005-toque-cancelado-nao-clica.patch; do
  cmp -s "$SRC/web/patches-final/$patch" "$BASE/web/patches-final/$patch" || falha "Patch instalado diferente: $patch. Nada alterado."
done
NOVOS=(0006-chat-mobile-acoplado.patch 0007-coordenadas-canvas-real.patch)
for patch in "${NOVOS[@]}"; do
  [ -s "$SRC/web/patches-final/$patch" ] || falha "Falta patch novo: $patch"
  if [ -f "$BASE/web/patches-final/$patch" ]; then
    cmp -s "$SRC/web/patches-final/$patch" "$BASE/web/patches-final/$patch" || falha "Patch novo ja existe com outra versao: $patch"
  fi
done
[ -s "$BASE/web/www/jogar/index.html" ] && [ -s "$BASE/web/www/jogar/otclient.wasm" ] || falha 'Cliente anterior nao encontrado para backup.'
# Precisa de espaco para manter o cliente anterior; o compilador tem sua propria verificacao de disco.
NECESSARIO=$(du -sk "$BASE/web/www/jogar" | awk '{print $1}')
LIVRE=$(df -Pk "$BASE/web/www" | awk 'NR==2 {print $4}')
[ "$LIVRE" -gt "$((NECESSARIO + 1048576))" ] || falha 'Falta espaco para backup e margem de 1 GB.'
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$BASE/backups/iphone-$STAMP"
mkdir -p "$BACKUP/patches"
cp -a "$BASE/web/www/jogar" "$BACKUP/jogar"
for patch in "${NOVOS[@]}"; do
  if [ -f "$BASE/web/patches-final/$patch" ]; then cp -a "$BASE/web/patches-final/$patch" "$BACKUP/patches/"; fi
done
git -C "$SRC" rev-parse HEAD > "$BACKUP/revisao.txt"
rollback() {
  trap - ERR
  printf 'Falha. Restaurando cliente anterior de %s\n' "$BACKUP" >&2
  for patch in "${NOVOS[@]}"; do
    if [ -f "$BACKUP/patches/$patch" ]; then cp -a "$BACKUP/patches/$patch" "$BASE/web/patches-final/$patch";
    else rm -f "$BASE/web/patches-final/$patch"; fi
  done
  if [ -d "$BASE/web/www/jogar" ]; then mv "$BASE/web/www/jogar" "$BACKUP/jogar-falhou"; fi
  cp -a "$BACKUP/jogar" "$BASE/web/www/jogar"
  exit 1
}
trap rollback ERR
for patch in "${NOVOS[@]}"; do cp -a "$SRC/web/patches-final/$patch" "$BASE/web/patches-final/$patch"; done
# Nao copia config.lua, portal, sprites, mapa, banco nem outros scripts.
BASE="$BASE" bash "$BASE/web/compilar-web.sh" "$DOMINIO"
test -s "$BASE/web/www/jogar/otclient.wasm"
curl --fail --silent --show-error -I "https://$DOMINIO/jogar/"
printf 'Cliente web recompilado. Backup: %s\nValidar no iPhone: chat acoplado, botoes e toque nos cantos/escadas.\n' "$BACKUP"
