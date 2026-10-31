#!/usr/bin/env bash
# JV Baiak - monta o cliente WEB (OTClient Redemption em WebAssembly) para
# jogar pelo navegador, inclusive no iPhone.
#
# Uso (o "jvbaiak web" chama este script em segundo plano):
#   bash compilar-web.sh <dominio>
#
# Caminho rapido (~10 min): baixa do GitHub a BASE ja compilada pelo GitHub Actions
# (bibliotecas + OTClient, sem sprites e sem dominio) e aqui so junta o dominio e as
# sprites 8.60 (Dockerfile.final). Se a base nao existir, compila tudo aqui (horas).
set -Eeuo pipefail
shopt -u patsub_replacement 2>/dev/null || true  # bash 5.2: "&" na troca de texto e literal

BASE="${BASE:-/opt/jvbaiak}"
DOMINIO="${1:?informe o dominio, ex.: meubaiak.duckdns.org}"
WEB="$BASE/web"
# shellcheck source=web/versao-base.env
. "$WEB/versao-base.env"
TAG="web-base-${OTC_COMMIT:0:7}-emsdk${EMSDK_VERSION}-r${BASE_REV}"
IMG="jvbaiak/web-base:$TAG"
URL_BASE="${JV_URL_BASE:-https://github.com/$KIT_GITHUB/releases/download/$TAG}"
FONTE="$WEB/fonte"
# Caddy monta web/www; a pasta jogar/ e trocada inteira quando fica pronta
SITE="$WEB/www/jogar"
SPR="$BASE/clientes-cache/sprites860"
DAT_SHA256="38e4e23ee550503842388e3aa3119125692316facf5adf97f4c24385735ddaee"
SPR_SHA256="672351b1a3dd0f45da7c76bca35a1d8f7fbf1db3be65e080aeb1d8789c61a575"
LOG=/var/log/jvbaiak-web-build.log

# Andamento visivel no celular em https://<dominio>/jogar/status.txt (sem terminal)
STATUS="$SITE/status.txt"
anota() { [ -d "$(dirname "$STATUS")" ] && [ ! -f "$SITE/otclient.wasm" ] && printf '%s\n' "$*" >> "$STATUS" || true; }
log() { printf '[web %s] %s\n' "$(date +%H:%M:%S)" "$*"; anota "$(date '+%d/%m %H:%M') $*"; }
falha() {
	trap - ERR
	printf '[web] ERRO: %s\n' "$*" >&2
	anota "ERRO: $*"
	if [ -f "$LOG" ]; then
		anota "--- fim do log da compilacao ---"
		anota "$(tail -n 40 "$LOG")"
	fi
	exit 1
}
trap 'falha "parou na linha $LINENO: $BASH_COMMAND"' ERR

[[ "$DOMINIO" =~ ^[a-z0-9.-]+\.[a-z]{2,}$ ]] || falha "dominio invalido: $DOMINIO"
[ -f "$STATUS" ] && : > "$STATUS"
: > "$LOG"
NOME="$(grep -E '^NOME_SERVIDOR=' "$BASE/.env" | tail -n1 | cut -d= -f2-)"
NOME="${NOME:-JV Baiak}"

confere() { [ "$(sha256sum "$1" | awk '{print $1}')" = "$2" ] || falha "arquivo $1 diferente do esperado"; }
[ -f "$SPR/Tibia.spr" ] || falha "sprites 8.60 nao encontrados; rode antes: jvbaiak clientes"
confere "$SPR/Tibia.dat" "$DAT_SHA256"
confere "$SPR/Tibia.spr" "$SPR_SHA256"

livre_gb() { local v; v="$(df -BG --output=avail /var/lib/docker 2>/dev/null | tail -n1 | tr -dc '0-9')"; echo "${v:-999}"; }
abre_espaco() { # sobras de compilacoes antigas do cliente web
	if [ "$(livre_gb)" -lt "${1:-12}" ]; then
		log "pouco espaco em disco ($(livre_gb) GB livres); limpando sobras de compilacoes antigas"
		docker image rm -f jvbaiak/web-build:local >/dev/null 2>&1 || true
		docker images --format '{{.Repository}}:{{.Tag}}' | grep '^jvbaiak/web-base:' | grep -vx "$IMG" \
			| xargs -r docker image rm -f >/dev/null 2>&1 || true
		docker builder prune -af >/dev/null 2>&1 || true
	fi
}

# ------------------------------------------------------------- 1) base pronta
obter_base_pronta() {
	docker image inspect "$IMG" >/dev/null 2>&1 && { log "base ja estava nesta maquina ($TAG)"; return 0; }
	local tmp lista
	tmp="$(mktemp -d /var/tmp/jvweb.XXXXXX)"
	if ! curl -fsSL --retry 3 "$URL_BASE/SHA256SUMS" -o "$tmp/SHA256SUMS" 2>>"$LOG"; then
		rm -rf "$tmp"
		return 1
	fi
	command -v zstd >/dev/null || { apt-get install -y -qq zstd >>"$LOG" 2>&1 || { apt-get update -qq >>"$LOG" 2>&1 && apt-get install -y -qq zstd >>"$LOG" 2>&1; }; }
	abre_espaco 14
	lista="$(awk '{print $2}' "$tmp/SHA256SUMS" | tr -d '*' | grep -E '^base\.tar\.zst\.part[0-9]+$' | sort)"
	[ -n "$lista" ] || { rm -rf "$tmp"; falha "lista de arquivos da base vazia em $URL_BASE"; }
	log "baixando a base pronta do GitHub ($TAG, $(echo "$lista" | wc -l) parte(s))"
	for p in $lista; do
		curl -fsSL --retry 5 --retry-delay 5 "$URL_BASE/$p" -o "$tmp/$p" 2>>"$LOG" || { rm -rf "$tmp"; falha "download de $p falhou"; }
	done
	(cd "$tmp" && sha256sum --quiet -c SHA256SUMS) >>"$LOG" 2>&1 || { rm -rf "$tmp"; falha "a base baixada nao confere (sha256)"; }
	log "carregando a base no Docker"
	# shellcheck disable=SC2086
	(cd "$tmp" && cat $lista) | zstd -dc | docker load >>"$LOG" 2>&1 || { rm -rf "$tmp"; falha "docker load da base falhou"; }
	rm -rf "$tmp"
	docker image inspect "$IMG" >/dev/null 2>&1 || falha "a base carregada nao tem a tag $IMG"
}

compilar_base_aqui() {
	log "base pronta nao encontrada; compilando tudo nesta maquina (demora horas)"
	abre_espaco 20
	bash "$WEB/preparar-fonte.sh" "$FONTE" >>"$LOG" 2>&1 || falha "nao consegui preparar o codigo do OTClient"
	DOCKER_BUILDKIT=1 docker build --progress=plain --build-arg EMSDK_VERSION="$EMSDK_VERSION" \
		-t "$IMG" -f "$WEB/Dockerfile.base" "$FONTE" >>"$LOG" 2>&1 \
		|| falha "a compilacao da base falhou (log acima)"
}

# A base ainda esta sendo compilada no GitHub? Espera ela (em vez de passar horas compilando aqui).
espera_base_github() {
	local fim primeira=1
	fim=$(( $(date +%s) + ${JV_ESPERA_BASE_MIN:-300} * 60 ))
	while [ "$(date +%s)" -lt "$fim" ]; do
		curl -fsSL --retry 2 -o /dev/null "$URL_BASE/SHA256SUMS" 2>/dev/null && return 0
		if [ "$primeira" = 1 ]; then
			log "esperando o GitHub terminar a versao pronta (costuma levar 1 a 2 horas; depois segue sozinho)"
			primeira=0
		fi
		sleep "${JV_ESPERA_INTERVALO_S:-180}"
	done
	return 1
}

obter_base_pronta || { espera_base_github && obter_base_pronta; } || compilar_base_aqui

# ------------------------------------------------- 2) dominio + sprites + link
log "juntando o dominio $DOMINIO e as sprites 8.60 (etapa final, poucos minutos)"
CTX="$(mktemp -d /var/tmp/jvweb-final.XXXXXX)"
cp "$WEB/Dockerfile.final" "$CTX/Dockerfile"
cp "$SPR/Tibia.dat" "$SPR/Tibia.spr" "$CTX/"
cat > "$CTX/jv_web_config.h" <<H
#pragma once
// Gerado pelo JV Baiak. O navegador conecta em wss://$DOMINIO/ws/<porta>.
#define JV_WS_BASE "wss://$DOMINIO/ws/"
H
# tela de login: so o nosso servidor, protocolo 8.60, sem download de assets modernos
docker run --rm --entrypoint cat "$IMG" /workspace/init.lua > "$CTX/init.lua.orig"
grep -q '^g_app.setName("OTClient - Redemption");' "$CTX/init.lua.orig" || falha "formato inesperado do init.lua"
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
' "$CTX/init.lua.orig" > "$CTX/init.lua"
rm -f "$CTX/init.lua.orig"
grep -q "protocol = 860" "$CTX/init.lua" || falha "init.lua nao foi ajustado"

# ajustes do JV Baiak para celular: tela nitida e toque (patches), pagina do jogo,
# esconder paineis que dependem de servico web, fundo da tela de login
mkdir -p "$CTX/jv/patches"
cp "$WEB"/patches-final/*.patch "$CTX/jv/patches/" 2>/dev/null || true
NOME_HTML="${NOME//&/&amp;}"; NOME_HTML="${NOME_HTML//</&lt;}"; NOME_HTML="${NOME_HTML//>/&gt;}"; NOME_HTML="${NOME_HTML//\"/&quot;}"
pagina="$(cat "$WEB/shell.html")"
printf '%s\n' "${pagina//__JV_NOME__/$NOME_HTML}" > "$CTX/jv/shell.html"
cp "$WEB/otclientrc-extra.lua" "$CTX/jv/"
[ -f "$WEB/visual/fundo-login.png" ] && cp "$WEB/visual/fundo-login.png" "$CTX/jv/"
if ls "$WEB"/imagens-jogo/*.png >/dev/null 2>&1; then
	mkdir -p "$CTX/jv/imagens" && cp "$WEB"/imagens-jogo/*.png "$CTX/jv/imagens/"
fi

DOCKER_BUILDKIT=1 docker build --progress=plain --build-arg BASE_IMG="$IMG" \
	-t jvbaiak/web-build:local "$CTX" >>"$LOG" 2>&1 \
	|| { rm -rf "$CTX"; tail -n 60 "$LOG" >&2; falha "a etapa final do cliente web falhou (log acima)"; }
rm -rf "$CTX"

log "publicando em /jogar"
TMP="$(mktemp -d)"
docker rm -f jvbaiak-web-tmp >/dev/null 2>&1 || true
docker create --name jvbaiak-web-tmp jvbaiak/web-build:local >/dev/null
docker cp jvbaiak-web-tmp:/otclient-web/. "$TMP/"
docker rm -f jvbaiak-web-tmp >/dev/null
[ -f "$TMP/otclient.html" ] && [ -f "$TMP/otclient.wasm" ] || falha "a compilacao nao gerou otclient.html/otclient.wasm"
cp "$TMP/otclient.html" "$TMP/index.html"
# icone e "app" para Adicionar a Tela de Inicio (abre em tela cheia)
cp "$WEB"/jogar-extra/*.png "$TMP/" 2>/dev/null || true
if [ -f "$WEB/jogar-extra/manifest.webmanifest" ]; then
	NOME_JSON="${NOME//\\/\\\\}"; NOME_JSON="${NOME_JSON//\"/\\\"}"
	manifesto="$(cat "$WEB/jogar-extra/manifest.webmanifest")"
	printf '%s\n' "${manifesto//__JV_NOME__/$NOME_JSON}" > "$TMP/manifest.webmanifest"
fi
printf '%s pronto: https://%s/jogar/\n' "$(date '+%d/%m %H:%M')" "$DOMINIO" > "$TMP/status.txt"
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
