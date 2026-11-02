#!/usr/bin/env bash
# Correcao v2: coordenadas OffscreenCanvas, proporcao e tamanho da interface mobile.
set -Eeuo pipefail
umask 077
BASE="${BASE:-/opt/jvbaiak}"
DOMINIO="${1:-bayakjh.duckdns.org}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
falha() { printf 'ERRO: %s\n' "$*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || falha 'Execute com sudo.'
[[ "$DOMINIO" =~ ^[a-z0-9.-]+\.[a-z]{2,}$ ]] || falha 'Dominio invalido.'
for cmd in docker git flock curl python3; do command -v "$cmd" >/dev/null || falha "Falta $cmd"; done
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
NOVOS=(patches-final/0006-chat-mobile-acoplado.patch patches-final/0007-coordenadas-canvas-real.patch patches-final/0008-offscreen-e-proporcao.patch shell.html otclientrc-extra.lua)
for patch in "${NOVOS[@]}"; do
  [ -s "$SRC/web/$patch" ] || falha "Falta patch novo: $patch"
  if [ -f "$BASE/web/$patch" ]; then
    if [ "$patch" = shell.html ]; then
      atual=$(sha256sum "$BASE/web/$patch" | awk '{print $1}')
      [ "$atual" = 8d58e747eb3923db7a53e7a377f291d706b1cca1889603260f6f1f10b23bf1a4 ] || cmp -s "$SRC/web/$patch" "$BASE/web/$patch" || falha 'A pagina instalada mudou. Revisao manual necessaria.'
    elif [ "$patch" = otclientrc-extra.lua ]; then
      atual=$(sha256sum "$BASE/web/$patch" | awk '{print $1}')
      [ "$atual" = dd5a907f9953a366ddb480f38eb1fdfa5d228c31e67f29cf6066dda0c62ee017 ] || cmp -s "$SRC/web/$patch" "$BASE/web/$patch" || falha 'Os ajustes Lua instalados mudaram. Revisao manual necessaria.'
    else
      cmp -s "$SRC/web/$patch" "$BASE/web/$patch" || falha "Patch novo ja existe com outra versao: $patch"
    fi
  fi
done
[ -s "$BASE/web/www/jogar/index.html" ] && [ -s "$BASE/web/www/jogar/otclient.wasm" ] || falha 'Cliente anterior nao encontrado para backup.'
# Precisa de espaco para manter o cliente anterior; o compilador tem sua propria verificacao de disco.
NECESSARIO=$(du -sk "$BASE/web/www/jogar" | awk '{print $1}')
LIVRE=$(df -Pk "$BASE/web/www" | awk 'NR==2 {print $4}')
[ "$LIVRE" -gt "$((NECESSARIO + 1048576))" ] || falha 'Falta espaco para backup e margem de 1 GB.'
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$BASE/backups/iphone-v2-$STAMP"
mkdir -p "$BACKUP/patches"
cp -a "$BASE/web/www/jogar" "$BACKUP/jogar"
for patch in "${NOVOS[@]}"; do
  mkdir -p "$(dirname "$BACKUP/arquivos/$patch")"
  if [ -f "$BASE/web/$patch" ]; then cp -a "$BASE/web/$patch" "$BACKUP/arquivos/$patch"; fi
done
git -C "$SRC" rev-parse HEAD > "$BACKUP/revisao.txt"
rollback() {
  trap - ERR
  printf 'Falha. Restaurando cliente anterior de %s\n' "$BACKUP" >&2
  for patch in "${NOVOS[@]}"; do
    if [ -f "$BACKUP/arquivos/$patch" ]; then cp -a "$BACKUP/arquivos/$patch" "$BASE/web/$patch";
    else rm -f "$BASE/web/$patch"; fi
  done
  if [ -d "$BASE/web/www/jogar" ]; then mv "$BASE/web/www/jogar" "$BACKUP/jogar-falhou"; fi
  cp -a "$BACKUP/jogar" "$BASE/web/www/jogar"
  exit 1
}
trap rollback ERR
for patch in "${NOVOS[@]}"; do cp -a "$SRC/web/$patch" "$BASE/web/$patch"; done
# Nao copia config.lua, portal, sprites, mapa, banco nem outros scripts.
BASE="$BASE" bash "$BASE/web/compilar-web.sh" "$DOMINIO"
test -s "$BASE/web/www/jogar/otclient.wasm"
# O HTML novo tambem precisa pedir o JS novo, nao uma copia antiga do navegador.
python3 - "$BASE/web/www/jogar" <<'PYTHON'
from pathlib import Path
import re,sys
site=Path(sys.argv[1])
for name in ('index.html','otclient.html'):
 p=site/name
 if p.exists():
  s=p.read_text()
  s=re.sub(r'(src=["\']?)otclient\.js(?:\?[^"\' >]*)?',r'\1otclient.js?v=toque-v2-offscreen',s)
  if 'toque-v2-offscreen' not in s: raise RuntimeError('Marcador v2 ausente no HTML')
  p.write_text(s)
p=(site/'otclient.js').read_text()
if 'c.width/r.width' in p or 'c.height/r.height' in p:
 raise RuntimeError('A compilacao ainda contem a conversao antiga do canvas')
if not re.search(r'\(\$0-\w+\.left\)/\w+\.width',p):
 raise RuntimeError('Conversao normalizada nao encontrada no JS compilado')
(site/'versao-cliente.txt').write_text('toque-v2-offscreen\n')
PYTHON
curl --fail --silent --show-error -I "https://$DOMINIO/jogar/"
printf 'Cliente web recompilado. Backup: %s\nValidar no iPhone: proporcao, alvos de toque e cantos/escadas em retrato e paisagem.\n' "$BACKUP"
