#!/usr/bin/env bash
# JV Baiak - compila o cliente WEB (OTClient Redemption em WebAssembly) para
# jogar pelo navegador, inclusive no iPhone. EXPERIMENTAL.
#
# Uso (o "jvbaiak web" chama este script em segundo plano):
#   bash compilar-web.sh <dominio>
# Leva de 1 a 2 horas na primeira vez. Nao mexe no servidor do jogo.
set -Eeuo pipefail

BASE="${BASE:-/opt/jvbaiak}"
DOMINIO="${1:?informe o dominio, ex.: meubaiak.duckdns.org}"
REPO="https://github.com/opentibiabr/otclient.git"
COMMIT="1fcea26f23ef1d1857103ef446c0190955523ca8"
FONTE="$BASE/web/fonte"
# Caddy monta web/www; a pasta jogar/ e trocada inteira quando fica pronta
SITE="$BASE/web/www/jogar"
SPR="$BASE/clientes-cache/sprites860"
DAT_SHA256="38e4e23ee550503842388e3aa3119125692316facf5adf97f4c24385735ddaee"
SPR_SHA256="672351b1a3dd0f45da7c76bca35a1d8f7fbf1db3be65e080aeb1d8789c61a575"

# Andamento visivel no celular em https://<dominio>/jogar/status.txt (sem terminal)
STATUS="$BASE/web/www/jogar/status.txt"
anota() { [ -d "$(dirname "$STATUS")" ] && [ ! -f "$BASE/web/www/jogar/otclient.wasm" ] && printf '%s\n' "$*" >> "$STATUS" || true; }
log() { printf '[web %s] %s\n' "$(date +%H:%M:%S)" "$*"; anota "$(date '+%d/%m %H:%M') $*"; }
falha() {
	trap - ERR
	printf '[web] ERRO: %s\n' "$*" >&2
	anota "ERRO: $*"
	if [ -f /var/log/jvbaiak-web-build.log ]; then
		anota "--- fim do log da compilacao ---"
		anota "$(tail -n 40 /var/log/jvbaiak-web-build.log)"
	fi
	exit 1
}
trap 'falha "parou na linha $LINENO: $BASH_COMMAND"' ERR

[[ "$DOMINIO" =~ ^[a-z0-9.-]+\.[a-z]{2,}$ ]] || falha "dominio invalido: $DOMINIO"
[ -f "$STATUS" ] && : > "$STATUS"
NOME="$(grep -E '^NOME_SERVIDOR=' "$BASE/.env" | tail -n1 | cut -d= -f2-)"
NOME="${NOME:-JV Baiak}"

confere() { [ "$(sha256sum "$1" | awk '{print $1}')" = "$2" ] || falha "arquivo $1 diferente do esperado"; }
[ -f "$SPR/Tibia.spr" ] || falha "sprites 8.60 nao encontrados; rode antes: jvbaiak clientes"
confere "$SPR/Tibia.dat" "$DAT_SHA256"
confere "$SPR/Tibia.spr" "$SPR_SHA256"

log "baixando OTClient Redemption (commit ${COMMIT:0:7})"
if [ "$(git -C "$FONTE" rev-parse HEAD 2>/dev/null || true)" != "$COMMIT" ]; then
	rm -rf "$FONTE"
	mkdir -p "$FONTE"
	git -C "$FONTE" init -q
	git -C "$FONTE" remote add origin "$REPO"
	git -C "$FONTE" fetch -q --depth 1 origin "$COMMIT"
	git -C "$FONTE" -c advice.detachedHead=false checkout -q FETCH_HEAD
fi
# volta ao original antes de aplicar as mudancas (pode rodar varias vezes)
git -C "$FONTE" checkout -q -- .
git -C "$FONTE" clean -q -fd -- data/things src/framework/net
for p in "$BASE"/web/patches/*.patch; do
	git -C "$FONTE" apply "$p" || falha "patch $(basename "$p") nao aplicou"
done

log "configurando para o servidor $DOMINIO"
# 1) ponte WebSocket no mesmo dominio do site (o patch usa este endereco)
cat > "$FONTE/src/framework/net/jv_web_config.h" <<EOF
#pragma once
// Gerado pelo JV Baiak. O navegador conecta em wss://$DOMINIO/ws/<porta>.
#define JV_WS_BASE "wss://$DOMINIO/ws/"
EOF

# 2) servidor fixo na tela de login, sem download de assets modernos
INIT="$FONTE/init.lua"
grep -q '^g_app.setName("OTClient - Redemption");' "$INIT" || falha "formato inesperado do init.lua"
awk -v dom="$DOMINIO" -v nome="$NOME" '
	/^g_app.setName\("OTClient - Redemption"\);/ {
		print "-- JV Baiak: so o nosso servidor, protocolo 8.60"
		print "Servers_init = {"
		print "    [\"" dom "\"] = { port = 7171, protocol = 860, httpLogin = false, useAuthenticator = false }"
		print "}"
		print "Services.clientAssets.enabled = false"
		print "g_app.setName(\"" nome "\");"
		next
	}
	{ print }
' "$INIT" > "$INIT.novo" && mv "$INIT.novo" "$INIT"
grep -q "protocol = 860" "$INIT" || falha "init.lua nao foi ajustado"

# 3) ajustes recomendados pelo OTClient para TFS 1.x em 8.60
SETUP="$FONTE/data/setup.otml"
sed -i 's/^\(\s*force-new-walking-formula:\).*/\1 true/; s/^\(\s*item-ticks-per-frame:\).*/\1 500/' "$SETUP"
grep -q 'force-new-walking-formula: true' "$SETUP" || falha "setup.otml nao foi ajustado"

# 4) sprites 8.60 dentro do pacote do site
mkdir -p "$FONTE/data/things/860"
cp "$SPR/Tibia.dat" "$SPR/Tibia.spr" "$FONTE/data/things/860/"

# 5) memoria: 1 GB fixo costuma falhar no Safari do iPhone; 512 MB sobra para o 8.60
sed -i 's/INITIAL_MEMORY=1073741824/INITIAL_MEMORY=536870912/g' "$FONTE/Dockerfile.browser" "$FONTE/src/CMakeLists.txt"
grep -q 'INITIAL_MEMORY=536870912' "$FONTE/Dockerfile.browser" || falha "Dockerfile.browser com formato inesperado"

# 6) vcpkg em processador ARM (Oracle gratis) precisa das ferramentas do sistema
grep -q 'VCPKG_FORCE_SYSTEM_BINARIES' "$FONTE/Dockerfile.browser" \
	|| sed -i 's#^ENV VCPKG_ROOT=/opt/vcpkg$#ENV VCPKG_ROOT=/opt/vcpkg\nENV VCPKG_FORCE_SYSTEM_BINARIES=1#' "$FONTE/Dockerfile.browser"
grep -q 'VCPKG_FORCE_SYSTEM_BINARIES' "$FONTE/Dockerfile.browser" || falha "nao consegui ajustar o vcpkg"

if [ -n "${JVBAIAK_SO_PREPARAR:-}" ]; then log "fonte preparada em $FONTE (sem compilar)"; exit 0; fi

log "compilando (demora; o log completo fica em /var/log/jvbaiak-web-build.log)"
DOCKER_BUILDKIT=1 docker build --progress=plain -t jvbaiak/web-build:local -f "$FONTE/Dockerfile.browser" "$FONTE" \
	> /var/log/jvbaiak-web-build.log 2>&1 \
	|| { tail -n 60 /var/log/jvbaiak-web-build.log >&2; falha "a compilacao do cliente web falhou (log acima)"; }

log "publicando em /jogar"
TMP="$(mktemp -d)"
docker rm -f jvbaiak-web-tmp >/dev/null 2>&1 || true
docker create --name jvbaiak-web-tmp jvbaiak/web-build:local >/dev/null
docker cp jvbaiak-web-tmp:/otclient-web/. "$TMP/"
docker rm -f jvbaiak-web-tmp >/dev/null
[ -f "$TMP/otclient.html" ] && [ -f "$TMP/otclient.wasm" ] || falha "a compilacao nao gerou otclient.html/otclient.wasm"
cp "$TMP/otclient.html" "$TMP/index.html"
mkdir -p "$(dirname "$SITE")"
rm -rf "$SITE.novo"
mv "$TMP" "$SITE.novo"
chmod -R a+rX "$SITE.novo"
rm -rf "$SITE.antigo"
[ -d "$SITE" ] && mv "$SITE" "$SITE.antigo"
mv "$SITE.novo" "$SITE"
rm -rf "$SITE.antigo"
trap - ERR
log "pronto: https://$DOMINIO/jogar/"
