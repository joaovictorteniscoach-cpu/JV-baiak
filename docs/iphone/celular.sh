#!/usr/bin/env bash
# Envie pelo botao Fazer upload do arquivo no SSH e execute: bash celular.sh
set -Eeuo pipefail
umask 077
REVISAO=e5bc39a1984cf1217b601ec7bb119086aa72b547
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

exec 8>/run/jvbaiak-celular5-preparacao.lock
flock -n 8 || falha 'A preparacao ja esta aberta em outra janela.'
KIT=$(mktemp -d /var/tmp/jvbaiak-celular5.XXXXXX)
printf '\nBaixando a versao v5 do cliente para celular...\n'
git init --quiet "$KIT"
git -C "$KIT" remote add origin "$REPOSITORIO"
git -C "$KIT" fetch --depth=1 origin "$REVISAO"
git -C "$KIT" checkout --quiet --detach FETCH_HEAD
[ "$(git -C "$KIT" rev-parse HEAD)" = "$REVISAO" ] || falha 'A revisao baixada nao confere.'
UNIDADE="jvbaiak-celular5-$(date +%Y%m%d%H%M%S)-$$"
systemd-run --unit="$UNIDADE" --description='JV Baiak: mapa, chat e controles no celular' \
  --property=Type=oneshot --property=RemainAfterExit=yes \
  /bin/bash "$KIT/web/instalar-correcao-toque-v5.sh" "$DOMINIO"
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
printf '\nATUALIZACAO CONCLUIDA.\nFeche e abra novamente o jogo no iPhone. Em pe: mapa largo, chat e quatro atalhos embaixo. Equipamento abre pelo menu; Voltar ao mapa fecha o painel. Confira os toques nas duas orientacoes. Se o toque continuar deslocado: menu > Mostrar toque, toque no mapa e envie uma foto das marcas azul e amarela. A versao nova aparece em /jogar/versao-cliente.txt.\n'
