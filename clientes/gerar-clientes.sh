#!/usr/bin/env bash
# JV Baiak - gera os clientes do jogo ja apontados para o seu servidor:
#   - JVBaiak-Windows.zip  (OTClientV8 para PC)
#   - JVBaiak-Android.apk  (OTClientV8 para celular Android)
#
# Tudo vem de fontes fixas (commit exato) e cada arquivo e conferido por SHA-256.
# Variaveis: ENDERECO_SERVIDOR, NOME_SERVIDOR, APK_SENHA [, SAIDA, CACHE, SIGNER]
set -euo pipefail

: "${ENDERECO_SERVIDOR:?informe ENDERECO_SERVIDOR (IP ou dominio do servidor)}"
: "${NOME_SERVIDOR:?informe NOME_SERVIDOR}"
: "${APK_SENHA:?informe APK_SENHA (senha da assinatura do APK)}"
SAIDA="${SAIDA:-/saida}"
CACHE="${CACHE:-/cache}"
SIGNER="${SIGNER:-/opt/uber-apk-signer.jar}"

# Cliente OTClientV8 (binarios prontos: Windows + Android)
OTCV8_REPO="https://github.com/OTCv8/otclientv8.git"
OTCV8_COMMIT="aacfe3f1fe4bcadb5a34ff1f36263e1c96b3dd32"
APK_SHA256="6d3e45e4af46f0dbb9c546f0f7619481c5eee3c6e3837dedcd24c8acc289e854"
EXE_DX_SHA256="b1abccb8e5e43afd4dce5abaaec217dee4751c67d590a8f493cd9fbe57d766ae"
EXE_GL_SHA256="4fe15929fb412362841ee13ec87bb5993e127742fd7111b8a5087e60be7716dd"

# Sprites do Tibia 8.60 (Tibia.dat assinatura 0x4C28B721, Tibia.spr 0x4C220594)
SPR_REPO="https://github.com/vinisdl/tibia-client-860-linux.git"
SPR_COMMIT="9e896e2fff662e8b2629b0bfad29ec199bfe72a9"
DAT_SHA256="38e4e23ee550503842388e3aa3119125692316facf5adf97f4c24385735ddaee"
SPR_SHA256="672351b1a3dd0f45da7c76bca35a1d8f7fbf1db3be65e080aeb1d8789c61a575"

PORTA_LOGIN=7171
VERSAO_CLIENTE=860

log() { printf '[clientes] %s\n' "$*"; }
falha() { printf '[clientes] ERRO: %s\n' "$*" >&2; exit 1; }

confere() { # arquivo sha256
	local atual
	atual="$(sha256sum "$1" | awk '{print $1}')"
	[ "$atual" = "$2" ] || falha "arquivo $1 diferente do esperado (sha256 $atual)"
}

# Baixa um commit exato de um repositorio, so com os caminhos pedidos.
busca_commit() { # repo commit pasta padrao...
	local repo="$1" commit="$2" pasta="$3"
	shift 3
	if [ -d "$pasta/.git" ] && [ "$(git -C "$pasta" rev-parse HEAD 2>/dev/null)" = "$commit" ]; then
		log "usando cache de $(basename "$pasta")"
		return
	fi
	rm -rf "$pasta"
	mkdir -p "$pasta"
	git -C "$pasta" init -q
	git -C "$pasta" remote add origin "$repo"
	git -C "$pasta" sparse-checkout set --no-cone "$@"
	local tentativa
	for tentativa in 1 2 3; do
		if git -C "$pasta" fetch -q --depth 1 --filter=blob:none origin "$commit" \
			&& git -C "$pasta" -c advice.detachedHead=false checkout -q FETCH_HEAD; then
			return
		fi
		log "download falhou (tentativa $tentativa), tentando de novo..."
		sleep 5
	done
	falha "nao consegui baixar $repo"
}

[ -f "$SIGNER" ] || falha "assinador de APK nao encontrado em $SIGNER"
[[ "$ENDERECO_SERVIDOR" =~ ^[A-Za-z0-9.-]+$ ]] || falha "ENDERECO_SERVIDOR invalido: $ENDERECO_SERVIDOR"
[[ "$NOME_SERVIDOR" =~ ^[A-Za-z0-9\ ]{3,30}$ ]] || falha "NOME_SERVIDOR deve ter 3-30 letras/numeros/espacos"

APP_ID="$(printf '%s' "$NOME_SERVIDOR" | tr -cd 'A-Za-z0-9' | tr 'A-Z' 'a-z')"
ARQ_BASE="$(printf '%s' "$NOME_SERVIDOR" | tr -cd 'A-Za-z0-9')"
mkdir -p "$CACHE" "$SAIDA"

log "baixando OTClientV8 (commit ${OTCV8_COMMIT:0:7})"
busca_commit "$OTCV8_REPO" "$OTCV8_COMMIT" "$CACHE/otclientv8" '/*' '!/otclient_mac' '!/otclient_linux'
confere "$CACHE/otclientv8/otclientv8.apk" "$APK_SHA256"
confere "$CACHE/otclientv8/otclient_dx.exe" "$EXE_DX_SHA256"
confere "$CACHE/otclientv8/otclient_gl.exe" "$EXE_GL_SHA256"

log "baixando sprites do Tibia 8.60"
busca_commit "$SPR_REPO" "$SPR_COMMIT" "$CACHE/sprites860" '/Tibia.dat' '/Tibia.spr'
confere "$CACHE/sprites860/Tibia.dat" "$DAT_SHA256"
confere "$CACHE/sprites860/Tibia.spr" "$SPR_SHA256"

TRAB="$(mktemp -d)"
trap 'rm -rf "$TRAB"' EXIT

# ---- monta a pasta do cliente -------------------------------------------------
CLI="$TRAB/$NOME_SERVIDOR"
mkdir -p "$CLI"
for item in data modules layouts mods LICENSE otclient_dx.exe otclient_gl.exe \
	libEGL.dll libGLESv2.dll d3dcompiler_47.dll; do
	cp -a "$CACHE/otclientv8/$item" "$CLI/"
done
mkdir -p "$CLI/data/things/$VERSAO_CLIENTE"
cp "$CACHE/sprites860/Tibia.dat" "$CACHE/sprites860/Tibia.spr" "$CLI/data/things/$VERSAO_CLIENTE/"

# Cara do JV Baiak: fundo do dragao (o mesmo do site e do jogo no navegador),
# tudo em portugues desde a primeira vez e o nome do servidor no canto da tela.
if [ -f /opt/jv/fundo.png ]; then
	for fundo in "$CLI/data/images/background.png" "$CLI"/layouts/*/images/background.png; do
		[ -f "$fundo" ] && cp /opt/jv/fundo.png "$fundo"
	done
fi
# Mods do JV Baiak (auto ataque)
if [ -d /opt/jv/mods ]; then mkdir -p "$CLI/mods" && cp -a /opt/jv/mods/. "$CLI/mods/"; fi
sed -i "s/^local defaultLocaleName = 'en'/local defaultLocaleName = 'pt'/" "$CLI/modules/client_locales/locales.lua"
# Visual classico do Tibia tambem no Android: mesmo layout "retro" do PC (em vez do
# layout de celular) e o joystick comeca escondido (anda tocando no mapa, como no
# Tibia; o botao do joystick continua no menu de cima para quem quiser).
sed -i 's/^  layout = "mobile"$/  layout = DEFAULT_LAYOUT -- JV Baiak: visual classico tambem no celular/' "$CLI/init.lua"
sed -i 's/^  keypadButton:setChecked(true)$/  keypadButton:setChecked(false)/' "$CLI/modules/client_mobile/mobile.lua"
grep -q 'layout = DEFAULT_LAYOUT -- JV Baiak' "$CLI/init.lua" || log "aviso: nao consegui trocar o layout do Android"
sed -i "s|clientVersionLabel:setText('OTClientV8 ' .. g_app.getVersion()|clientVersionLabel:setText('$NOME_SERVIDOR - Tibia $VERSAO_CLIENTE\\\\nOTClientV8 ' .. g_app.getVersion()|" \
	"$CLI/modules/client_background/background.lua"

# init.lua: troca o bloco de configuracao pelo do seu servidor.
# Servicos externos (updater, crash, feedback) ficam desligados: nada e enviado a terceiros.
CONFIG="$TRAB/config.lua"
cat > "$CONFIG" <<EOF
-- CONFIG
APP_NAME = "$APP_ID"  -- nome da pasta de configuracao do cliente
APP_VERSION = 1341
DEFAULT_LAYOUT = "retro" -- no Android o layout "mobile" e forcado automaticamente

Services = {
  website = "http://$ENDERECO_SERVIDOR",
  updater = "",
  stats = "",
  crash = "",
  feedback = "",
  status = ""
}

Servers = {
  ["$NOME_SERVIDOR"] = "$ENDERECO_SERVIDOR:$PORTA_LOGIN:$VERSAO_CLIENTE"
}

ALLOW_CUSTOM_SERVERS = false

g_app.setName("$NOME_SERVIDOR")
-- CONFIG END
EOF
awk -v cfg="$CONFIG" '
	BEGIN { dentro = 0; feito = 0 }
	/^-- CONFIG END/ { dentro = 0; next }
	/^-- CONFIG$/ && !feito {
		while ((getline linha < cfg) > 0) print linha
		dentro = 1; feito = 1; next
	}
	!dentro { print }
	END { if (!feito) exit 3 }
' "$CACHE/otclientv8/init.lua" > "$CLI/init.lua" || falha "formato inesperado do init.lua"
grep -q "\"$ENDERECO_SERVIDOR:$PORTA_LOGIN:$VERSAO_CLIENTE\"" "$CLI/init.lua" || falha "init.lua sem o endereco do servidor"

cat > "$CLI/LEIA-ME.txt" <<EOF
$NOME_SERVIDOR - cliente para Windows

1. Extraia esta pasta inteira (nao rode de dentro do .zip).
2. Abra otclient_dx.exe. Se a tela ficar preta ou travar, use otclient_gl.exe.
3. Entre com a conta criada em http://$ENDERECO_SERVIDOR

Se aparecer erro de DLL, instale o Visual C++ 2019 (x86):
https://aka.ms/vs/16/release/vc_redist.x86.exe
EOF

# ---- Windows -------------------------------------------------------------------
log "gerando cliente Windows"
ZIP_WIN="$TRAB/${ARQ_BASE}-Windows.zip"
(cd "$TRAB" && zip -q -r -9 "$ZIP_WIN" "$NOME_SERVIDOR")

# ---- Android -------------------------------------------------------------------
log "gerando APK Android"
PACOTE="$TRAB/pacote"
mkdir -p "$PACOTE/assets"
(cd "$CLI" && zip -q -r -6 "$PACOTE/assets/data.zip" init.lua data modules layouts mods)
APK="$TRAB/app.apk"
cp "$CACHE/otclientv8/otclientv8.apk" "$APK"
zip -q -d "$APK" 'META-INF/*'
(cd "$PACOTE" && zip -q -0 "$APK" assets/data.zip)

KS="$CACHE/apk-assinatura.jks"
if [ ! -f "$KS" ]; then
	log "criando chave de assinatura do APK (guardada para as proximas atualizacoes)"
	keytool -genkeypair -noprompt -keystore "$KS" -storetype PKCS12 -alias jvbaiak \
		-keyalg RSA -keysize 2048 -validity 10000 \
		-storepass "$APK_SENHA" -keypass "$APK_SENHA" \
		-dname "CN=$NOME_SERVIDOR, O=$NOME_SERVIDOR, C=BR" >/dev/null 2>&1 \
		|| falha "nao consegui criar a chave do APK"
fi
# O zipalign embutido no assinador so existe para x86_64. Em arm64 (Oracle gratis)
# o alinhamento e pulado: o app tem targetSdk 25 e o Android nao exige alinhamento.
ALINHAR=()
if [ "$(uname -m)" != "x86_64" ]; then
	ALINHAR=(--skipZipAlign)
	log "processador $(uname -m): APK sem zipalign (nao e exigido para este app)"
fi
mkdir -p "$TRAB/assinado"
java -jar "$SIGNER" --apks "$APK" --out "$TRAB/assinado" "${ALINHAR[@]}" \
	--ks "$KS" --ksAlias jvbaiak --ksPass "$APK_SENHA" --ksKeyPass "$APK_SENHA" \
	> "$TRAB/assinatura.log" 2>&1 || { cat "$TRAB/assinatura.log" >&2; falha "falha ao assinar o APK"; }
APK_FINAL="$(find "$TRAB/assinado" -name '*.apk' | head -n 1)"
[ -n "$APK_FINAL" ] || falha "APK assinado nao encontrado"
java -jar "$SIGNER" --apks "$APK_FINAL" --onlyVerify "${ALINHAR[@]}" > "$TRAB/verificacao.log" 2>&1 \
	|| { cat "$TRAB/verificacao.log" >&2; falha "APK nao passou na verificacao de assinatura"; }

# ---- publica ---------------------------------------------------------------------
cp "$ZIP_WIN" "$SAIDA/.${ARQ_BASE}-Windows.zip.tmp"
cp "$APK_FINAL" "$SAIDA/.${ARQ_BASE}-Android.apk.tmp"
mv -f "$SAIDA/.${ARQ_BASE}-Windows.zip.tmp" "$SAIDA/${ARQ_BASE}-Windows.zip"
mv -f "$SAIDA/.${ARQ_BASE}-Android.apk.tmp" "$SAIDA/${ARQ_BASE}-Android.apk"
(cd "$SAIDA" && sha256sum "${ARQ_BASE}-Windows.zip" "${ARQ_BASE}-Android.apk" > SHA256SUMS.txt)
cat > "$SAIDA/versao.json" <<EOF
{"gerado_em": "$(date -u +%Y-%m-%dT%H:%M:%SZ)", "servidor": "$ENDERECO_SERVIDOR", "windows": "${ARQ_BASE}-Windows.zip", "android": "${ARQ_BASE}-Android.apk"}
EOF
log "pronto: $(du -h "$SAIDA/${ARQ_BASE}-Windows.zip" | cut -f1) Windows, $(du -h "$SAIDA/${ARQ_BASE}-Android.apk" | cut -f1) Android"
