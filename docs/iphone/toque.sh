#!/usr/bin/env bash
# Envie pelo botao Fazer upload do arquivo no SSH e execute: bash toque.sh
set -Eeuo pipefail
umask 077
REVISAO=fa244862d94404e9b8179021246627fb02a37d89
REPOSITORIO=https://github.com/joaovictorteniscoach-cpu/JV-baiak.git
DOMINIO=bayakjh.duckdns.org

falha() { printf '\nERRO: %s\nEnvie uma foto desta mensagem para revisarmos.\n' "$*" >&2; exit 1; }
trap 'printf "\nA preparacao encontrou um erro. Envie uma foto da mensagem acima.\n" >&2' ERR
if [ "$(id -u)" -ne 0 ]; then
  command -v sudo >/dev/null || falha 'Este servidor precisa de sudo.'
  exec sudo /bin/bash "$(readlink -f -- "${BASH_SOURCE[0]}")"
fi
for comando in git systemd-run systemctl journalctl flock; do
  command -v "$comando" >/dev/null || falha "Falta o comando $comando."
done
[ -f /opt/jvbaiak/.env ] && [ -f /opt/jvbaiak/web/compilar-web.sh ] || falha 'Nao encontrei a instalacao em /opt/jvbaiak. Nenhum arquivo do jogo foi alterado.'

exec 8>/run/jvbaiak-iphone-preparacao.lock
flock -n 8 || falha 'A preparacao ja esta aberta em outra janela.'
KIT=$(mktemp -d /var/tmp/jvbaiak-iphone.XXXXXX)
printf '\nBaixando a correcao v2 de toque e proporcao do iPhone...\n'
git init --quiet "$KIT"
git -C "$KIT" remote add origin "$REPOSITORIO"
git -C "$KIT" fetch --depth=1 origin "$REVISAO"
git -C "$KIT" checkout --quiet --detach FETCH_HEAD
[ "$(git -C "$KIT" rev-parse HEAD)" = "$REVISAO" ] || falha 'A revisao baixada nao confere.'
UNIDADE="jvbaiak-iphone-$(date +%Y%m%d%H%M%S)-$$"
systemd-run --unit="$UNIDADE" --description='JV Baiak: toque preciso e proporcao no iPhone' \
  --property=Type=oneshot --property=RemainAfterExit=yes \
  /bin/bash "$KIT/web/instalar-correcao-iphone-v2.sh" "$DOMINIO"
printf '\nAtualizacao iniciada. Ela continua mesmo se o SSH desconectar.\n'
printf 'Para consultar depois: sudo journalctl -u %s --no-pager -n 40\n\n' "$UNIDADE"
journalctl --follow --unit="$UNIDADE" --no-pager &
LOG_PID=$!
limpar() { kill "$LOG_PID" 2>/dev/null || true; wait "$LOG_PID" 2>/dev/null || true; }
trap limpar EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
while :; do
  ESTADO=$(systemctl show "$UNIDADE" --property=ActiveState --value)
  case "$ESTADO" in
    activating|reloading) sleep 2 ;;
    active) break ;;
    *) limpar; journalctl --unit="$UNIDADE" --no-pager -n 30; falha 'A atualizacao nao terminou. Confira a mensagem acima; o instalador tenta restaurar o cliente anterior se a compilacao falhar.' ;;
  esac
done
limpar
trap - EXIT
journalctl --unit="$UNIDADE" --no-pager -n 12
printf '\nATUALIZACAO CONCLUIDA.\nFeche e abra novamente o jogo no iPhone. Confira a proporcao, os botoes e os toques no mapa. A versao nova aparece em /jogar/versao-cliente.txt.\n'
