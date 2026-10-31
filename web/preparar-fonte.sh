#!/usr/bin/env bash
# JV Baiak - baixa o OTClient Redemption no commit fixo e aplica as mudancas do JV Baiak
# que NAO dependem do dominio nem das sprites (essas entram depois, na VPS).
# Usado pelo GitHub Actions (base pre-compilada) e pela VPS (quando precisa compilar tudo).
#   bash preparar-fonte.sh <pasta-destino>
set -Eeuo pipefail
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=web/versao-base.env
. "$AQUI/versao-base.env"
FONTE="${1:?informe a pasta de destino}"
erro() { printf 'ERRO: %s\n' "$*" >&2; exit 1; }

if [ "$(git -C "$FONTE" rev-parse HEAD 2>/dev/null || true)" != "$OTC_COMMIT" ]; then
	rm -rf "$FONTE"
	mkdir -p "$FONTE"
	git -C "$FONTE" init -q
	git -C "$FONTE" remote add origin "$OTC_REPO"
	for t in 1 2 3; do
		git -C "$FONTE" fetch -q --depth 1 origin "$OTC_COMMIT" && break
		[ "$t" -lt 3 ] || erro "nao consegui baixar o OTClient"
		sleep 10
	done
	git -C "$FONTE" -c advice.detachedHead=false checkout -q FETCH_HEAD
fi
# volta ao original antes de aplicar as mudancas (pode rodar varias vezes)
git -C "$FONTE" checkout -q -- .
git -C "$FONTE" clean -q -fd -- data/things src/framework/net
for p in "$AQUI"/patches/*.patch; do
	git -C "$FONTE" apply "$p" || erro "patch $(basename "$p") nao aplicou"
done

# 1) endereco da ponte WebSocket: provisorio aqui; a VPS troca pelo dominio dela
cat > "$FONTE/src/framework/net/jv_web_config.h" <<'H'
#pragma once
// Gerado pelo JV Baiak. A VPS substitui pelo dominio real antes da etapa final.
#define JV_WS_BASE "wss://jv-provisorio.invalid/ws/"
H

# 2) ajustes recomendados pelo OTClient para TFS 1.x em 8.60
SETUP="$FONTE/data/setup.otml"
sed -i 's/^\(\s*force-new-walking-formula:\).*/\1 true/; s/^\(\s*item-ticks-per-frame:\).*/\1 500/' "$SETUP"
grep -q 'force-new-walking-formula: true' "$SETUP" || erro "setup.otml com formato inesperado"

# 3) memoria: 1 GB fixo costuma falhar no Safari do iPhone; 512 MB sobra para o 8.60
sed -i 's/INITIAL_MEMORY=1073741824/INITIAL_MEMORY=536870912/g' "$FONTE/src/CMakeLists.txt"
grep -q 'INITIAL_MEMORY=536870912' "$FONTE/src/CMakeLists.txt" || erro "src/CMakeLists.txt com formato inesperado"

# 4) pasta das sprites existe (vazia aqui; a VPS copia o Tibia.dat/.spr 8.60)
mkdir -p "$FONTE/data/things/860"
echo "fonte pronta em $FONTE"
