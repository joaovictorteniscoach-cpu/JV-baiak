#!/usr/bin/env bash
# =============================================================================
# JV Baiak - instalador em um comando (VPS Ubuntu 22.04/24.04, x86_64 ou arm64)
#
#   curl -fsSL https://raw.githubusercontent.com/joaovictorteniscoach-cpu/JV-baiak/main/instalar.sh | sudo bash
#
# Tambem roda sozinho no primeiro boot da VPS (script cloud-init), sem terminal.
# Opcional (variaveis antes do comando):
#   NOME_SERVIDOR="Meu Baiak"    ENDERECO_SERVIDOR=1.2.3.4
#   GM_SENHA=minhasenha          senha da conta GM "admin" (senao, uma aleatoria)
#   DOMINIO=x.duckdns.org DUCKDNS_TOKEN=...   ja liga o modo web (iPhone) no fim
# Pode ser rodado de novo a qualquer momento: ele repara/atualiza sem apagar
# contas, personagens, mapa ou configuracoes ja feitas.
# =============================================================================
set -Eeuo pipefail

KIT_REPO="${KIT_REPO:-https://github.com/joaovictorteniscoach-cpu/JV-baiak.git}"
KIT_REF="${KIT_REF:-main}"
BASE="${BASE:-/opt/jvbaiak}"
NOME_PASSADO="${NOME_SERVIDOR:-}"
NOME_SERVIDOR="${NOME_SERVIDOR:-JV Baiak}"
GM_SENHA_PASSADA="${GM_SENHA:-}"
DOMINIO_PASSADO="${DOMINIO:-}"
DUCKDNS_TOKEN="${DUCKDNS_TOKEN:-}"
# Campos do script de exemplo que ficaram sem trocar sao ignorados
case "$GM_SENHA_PASSADA" in *TROQUE*) GM_SENHA_PASSADA="" ;; esac
case "$DOMINIO_PASSADO" in *SEUNOME* | "") DOMINIO_PASSADO="" ;; esac
case "$DUCKDNS_TOKEN" in *COLE-O-TOKEN*) DUCKDNS_TOKEN="" ;; esac
export HOME="${HOME:-/root}"

BAIAK_REPO="https://github.com/moviebr/baiakthunder.git"
BAIAK_COMMIT="265d45805c5d2204262ffd55b8fc67d97b829916"
LOG="/var/log/jvbaiak-instalacao.log"

cor() { printf '\033[%sm%s\033[0m\n' "$1" "$2"; }
etapa() {
	cor "1;33" ">> $*"
	if [ -d "$BASE/web/www/jogar" ]; then printf '%s %s\n' "$(date '+%d/%m %H:%M')" "$*" >> "$BASE/web/www/jogar/atualizacao.txt" 2>/dev/null || true; fi
}
ok() { cor "1;32" "   $*"; }
# Sem terminal (instalacao pelo celular): em caso de erro, mostra o fim do log
# em http://IP-DA-VPS para dar print. Linhas com senha/token sao omitidas.
pagina_erro() {
	command -v python3 >/dev/null 2>&1 || return 0
	if ss -ltn 2>/dev/null | grep -q ':80 '; then return 0; fi
	local dir=/run/jvbaiak-erro
	mkdir -p "$dir"
	{
		echo '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
		echo '<title>JV Baiak - erro</title><body style="font:14px monospace;background:#111;color:#eee;padding:12px">'
		echo "<h2>A instalacao parou com erro ($(date '+%d/%m %H:%M'))</h2><p>Tire um print e envie no chat.</p><pre style=\"white-space:pre-wrap\">"
		tail -n 60 "$LOG" 2>/dev/null | sed -E 's/\x1b\[[0-9;]*m//g' | grep -viE 'senha|token|password|pwd' \
			| sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' || true
		echo '</pre>'
	} > "$dir/index.html"
	iptables -I INPUT 1 -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
	systemd-run --unit=jvbaiak-erro --collect python3 -m http.server 80 --directory "$dir" >/dev/null 2>&1 || true
}
falha() {
	trap - ERR
	cor "1;31" "ERRO: $*"
	if [ -d "$BASE/web/www/jogar" ]; then printf 'ERRO: %s\n' "$*" >> "$BASE/web/www/jogar/atualizacao.txt" 2>/dev/null || true; fi
	echo "Detalhes em $LOG. Envie as ultimas linhas desse arquivo para o suporte." >&2
	pagina_erro
	exit 1
}
# Espera outros processos do apt terminarem (no primeiro boot a VPS se atualiza sozinha)
espera_apt() {
	local i
	for i in $(seq 1 180); do
		# so processos que seguram o apt/dpkg (o servico unattended-upgrades fica
		# rodando para sempre esperando o desligamento e nao conta)
		if ! pgrep -x 'apt|apt-get|dpkg' >/dev/null 2>&1 \
			&& ! pgrep -f '/usr/bin/unattended-upgrade( |$)' >/dev/null 2>&1; then
			return 0
		fi
		[ "$i" -eq 1 ] && echo "   aguardando a atualizacao automatica do sistema terminar..."
		sleep 5
	done
}
trap 'falha "a etapa falhou na linha $LINENO (comando: $BASH_COMMAND)"' ERR

# Tudo dentro de main(): o bash le o script inteiro antes de executar
# (necessario quando o instalador chega por "curl | bash").
main() {
	# Pelo SSH do celular: roda em segundo plano (o celular pode dormir ou fechar o SSH
	# no meio sem estragar a atualizacao). O andamento aparece em https://<dominio>/jogar/atualizacao.txt
	if [ -z "${JV_PLANO:-}" ] && [ -t 1 ] && command -v systemd-run >/dev/null \
		&& [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ] && [ "$(id -u)" -eq 0 ]; then
		local eu
		eu="$(readlink -f "${BASH_SOURCE[0]}")"
		if systemctl is-active --quiet jvbaiak-atualizar; then
			echo "Ja existe uma atualizacao rodando. Mostrando o andamento (Ctrl+C sai; ela continua):"
		else
			systemctl reset-failed jvbaiak-atualizar >/dev/null 2>&1 || true
			local vars=() v
			for v in NOME_SERVIDOR ENDERECO_SERVIDOR GM_SENHA DOMINIO DUCKDNS_TOKEN KIT_REPO KIT_REF; do
				[ -n "${!v:-}" ] && vars+=("--setenv=$v=${!v}")
			done
			systemd-run --unit=jvbaiak-atualizar --description="JV Baiak: atualizacao" \
				--setenv=JV_PLANO=1 "${vars[@]}" /bin/bash "$eu" >/dev/null
			echo "Atualizacao rodando em segundo plano. PODE FECHAR o SSH ou bloquear o celular."
			echo "Andamento no celular: https://$(grep -E '^DOMINIO=' "$BASE/.env" 2>/dev/null | cut -d= -f2- | tail -n1)/jogar/atualizacao.txt"
			echo "Mostrando aqui tambem (Ctrl+C sai; a atualizacao continua):"
		fi
		exec journalctl -u jvbaiak-atualizar -f -n 50 -o cat
	fi
	exec > >(tee -a "$LOG") 2>&1
	if [ -d "$BASE/web/www/jogar" ]; then echo "== atualizacao iniciada ==" > "$BASE/web/www/jogar/atualizacao.txt" 2>/dev/null || true; fi
	systemctl stop jvbaiak-erro >/dev/null 2>&1 || true
	echo "==== instalacao iniciada em $(date) ===="

	# ----------------------------------------------------------------- verificacoes
	etapa "Verificando a maquina"
	[ "$(id -u)" -eq 0 ] || falha "rode como root (use sudo)."
	case "$(uname -m)" in
		x86_64) ok "processador x86_64" ;;
		aarch64) ok "processador arm64 (ex.: Oracle Cloud gratis)" ;;
		*) falha "processador $(uname -m) nao suportado (use x86_64 ou arm64)." ;;
	esac
	. /etc/os-release
	case "${ID}:${VERSION_ID}" in
		ubuntu:22.04 | ubuntu:24.04) ok "Ubuntu ${VERSION_ID}" ;;
		*) cor "1;35" "   Aviso: testado em Ubuntu 22.04/24.04; este sistema e ${PRETTY_NAME}. Continuando." ;;
	esac
	RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
	LIVRE_GB=$(df -Pk / | awk 'NR==2 {print int($4/1024/1024)}')
	MINIMO_GB=12
	if [ -f "${BASE:-/opt/jvbaiak}/.instalado" ]; then
		# atualizacao: o que ja esta instalado conta; antes, limpa sobras de compilacoes antigas
		MINIMO_GB=4
		if [ "$LIVRE_GB" -lt 15 ] && command -v docker >/dev/null; then
			docker image rm -f jvbaiak/web-build:local >/dev/null 2>&1 || true
			docker builder prune -af >/dev/null 2>&1 || true
			docker image prune -f >/dev/null 2>&1 || true
			LIVRE_GB=$(df -Pk / | awk 'NR==2 {print int($4/1024/1024)}')
		fi
	fi
	ok "RAM ${RAM_MB} MB, disco livre ${LIVRE_GB} GB"
	[ "$LIVRE_GB" -ge "$MINIMO_GB" ] || falha "pouco espaco em disco (${LIVRE_GB} GB). Sao necessarios pelo menos ${MINIMO_GB} GB livres."
	[ "$RAM_MB" -ge 1800 ] || falha "pouca memoria (${RAM_MB} MB). Use uma VPS com pelo menos 2 GB (recomendado 4 GB ou mais)."
	[[ "$NOME_SERVIDOR" =~ ^[A-Za-z0-9\ ]{3,30}$ ]] || falha "NOME_SERVIDOR deve ter 3-30 letras, numeros ou espacos (sem acentos)."
	if [ -n "$GM_SENHA_PASSADA" ] && ! [[ "$GM_SENHA_PASSADA" =~ ^[A-Za-z0-9._@#%+=-]{6,29}$ ]]; then
		falha "GM_SENHA deve ter 6 a 29 letras, numeros ou . _ @ # % + = - (sem espacos)."
	fi

	export DEBIAN_FRONTEND=noninteractive

	# ------------------------------------------------------------------- pacotes
	etapa "Instalando pacotes do sistema"
	espera_apt
	apt-get -o DPkg::Lock::Timeout=900 update -qq
	apt-get -o DPkg::Lock::Timeout=900 install -y -qq --no-install-recommends ca-certificates curl git openssl ufw fail2ban \
		unattended-upgrades cron gzip >/dev/null
	systemctl enable --now fail2ban >/dev/null 2>&1 || true
	systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true
	ok "pacotes ok (fail2ban protege o SSH; atualizacoes de seguranca automaticas ligadas)"

	if ! command -v docker >/dev/null 2>&1; then
		etapa "Instalando Docker (script oficial get.docker.com)"
		espera_apt
		for tentativa in 1 2 3; do
			if curl -fsSL https://get.docker.com | sh >/dev/null; then break; fi
			[ "$tentativa" -lt 3 ] || falha "nao consegui instalar o Docker"
			sleep 30
			espera_apt
		done
	fi
	systemctl enable --now docker >/dev/null 2>&1 || true
	docker compose version >/dev/null 2>&1 || falha "Docker Compose v2 nao encontrado."
	ok "$(docker --version)"

	# ----------------------------------------------------------------------- swap
	if [ "$(swapon --show --noheadings | wc -l)" -eq 0 ] && [ "$RAM_MB" -lt 6000 ]; then
		etapa "Criando 2 GB de swap (protege contra falta de memoria)"
		fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none
		chmod 600 /swapfile
		mkswap /swapfile >/dev/null
		swapon /swapfile
		grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
		ok "swap ativo"
	fi

	# ------------------------------------------------------------------------- kit
	etapa "Copiando o kit para $BASE"
	ORIGEM=""
	if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/docker-compose.yml" ]; then
		ORIGEM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	else
		case "$KIT_REPO" in __*) falha "KIT_REPO nao definido. Rode o instalador de dentro da pasta do kit." ;; esac
		TMPKIT="$(mktemp -d)"
		git clone -q --depth 1 --branch "$KIT_REF" "$KIT_REPO" "$TMPKIT/kit" || falha "nao consegui baixar o kit de $KIT_REPO"
		ORIGEM="$TMPKIT/kit"
	fi
	mkdir -p "$BASE"
	for item in docker-compose.yml docker-compose.web.yml jvbaiak servidor-imagem portal clientes web LEIA-ME.md; do
		[ -e "$ORIGEM/$item" ] || continue
		if [ "$ORIGEM" != "$BASE" ]; then
			rm -rf "${BASE:?}/$item.novo"
			cp -a "$ORIGEM/$item" "$BASE/$item.novo"
			# fonte/ (codigo baixado) e preservado entre atualizacoes
			if [ "$item" = "servidor-imagem" ] && [ -d "$BASE/servidor-imagem/fonte" ]; then
				mv "$BASE/servidor-imagem/fonte" "$BASE/servidor-imagem.novo/fonte"
			fi
			# no modo web, preserva o codigo e o site ja compilados
			if [ "$item" = "web" ]; then
				for sub in fonte www; do
					if [ -d "$BASE/web/$sub" ]; then mv "$BASE/web/$sub" "$BASE/web.novo/$sub"; fi
				done
			fi
			rm -rf "${BASE:?}/$item"
			mv "$BASE/$item.novo" "$BASE/$item"
		fi
	done
	chmod +x "$BASE/jvbaiak"
	ln -sf "$BASE/jvbaiak" /usr/local/bin/jvbaiak
	mkdir -p "$BASE/downloads" "$BASE/clientes-cache" "$BASE/backups"
	ok "kit em $BASE (comando de administracao: jvbaiak)"

	# ------------------------------------------------------------------ endereco
	descobre_ip() {
		local url ip
		for url in https://api.ipify.org https://ifconfig.me/ip https://icanhazip.com; do
			ip="$(curl -4 -fsS --max-time 8 "$url" 2>/dev/null | tr -d '[:space:]' || true)"
			if [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
				echo "$ip"
				return 0
			fi
		done
		return 1
	}

	ENV="$BASE/.env"
	le_env() { grep -E "^$1=" "$ENV" 2>/dev/null | tail -n1 | cut -d= -f2- || true; }
	grava_env() { # chave valor
		local tmp
		tmp="$(mktemp)"
		grep -vE "^$1=" "$ENV" > "$tmp" 2>/dev/null || true
		printf '%s=%s\n' "$1" "$2" >> "$tmp"
		install -m 600 "$tmp" "$ENV"
		rm -f "$tmp"
	}
	aleatorio() { openssl rand -hex "${1:-24}"; }

	etapa "Configurando senhas e endereco"
	touch "$ENV"
	chmod 600 "$ENV"
	for chave in DB_SENHA DB_SENHA_ROOT PORTAL_SEGREDO APK_SENHA; do
		[ -n "$(le_env "$chave")" ] || grava_env "$chave" "$(aleatorio)"
	done
	if [ -n "${ENDERECO_SERVIDOR:-}" ]; then
		grava_env ENDERECO_SERVIDOR "$ENDERECO_SERVIDOR"
	elif [ -z "$(le_env ENDERECO_SERVIDOR)" ]; then
		grava_env ENDERECO_SERVIDOR "$(descobre_ip || falha "nao consegui descobrir o IP publico. Rode de novo com ENDERECO_SERVIDOR=SEU.IP")"
	fi
	if [ -n "$NOME_PASSADO" ] || [ -z "$(le_env NOME_SERVIDOR)" ]; then
		grava_env NOME_SERVIDOR "$NOME_SERVIDOR"
	fi
	# Com dominio do DuckDNS: aponta para esta maquina ja agora e usa o dominio como
	# endereco do jogo (se o IP mudar um dia, basta atualizar o DNS).
	if [ -n "$DOMINIO_PASSADO" ] && [ -n "$DUCKDNS_TOKEN" ] && [[ "$DOMINIO_PASSADO" == *.duckdns.org ]]; then
		grava_env DUCKDNS_TOKEN "$DUCKDNS_TOKEN"
		etapa "Apontando $DOMINIO_PASSADO para esta maquina (DuckDNS)"
		if "$BASE/jvbaiak" atualizar-ip "$DOMINIO_PASSADO" </dev/null; then
			[ -n "${ENDERECO_SERVIDOR:-}" ] || grava_env ENDERECO_SERVIDOR "$DOMINIO_PASSADO"
		else
			cor "1;35" "   Aviso: nao consegui usar o DuckDNS agora; o jogo fica pelo IP."
		fi
	fi
	ENDERECO="$(le_env ENDERECO_SERVIDOR)"
	NOME="$(le_env NOME_SERVIDOR)"
	ok "servidor \"$NOME\" no endereco $ENDERECO (senhas em $ENV, so o root le)"

	# ------------------------------------------------------------ codigo do Baiak
	etapa "Baixando o Baiak Thunder 8.60 (commit ${BAIAK_COMMIT:0:7})"
	FONTE="$BASE/servidor-imagem/fonte"
	if [ "$(git -C "$FONTE" rev-parse HEAD 2>/dev/null || true)" != "$BAIAK_COMMIT" ]; then
		rm -rf "$FONTE"
		mkdir -p "$FONTE"
		git -C "$FONTE" init -q
		git -C "$FONTE" remote add origin "$BAIAK_REPO"
		for tentativa in 1 2 3; do
			git -C "$FONTE" fetch -q --depth 1 origin "$BAIAK_COMMIT" && break
			[ "$tentativa" -lt 3 ] || falha "nao consegui baixar o Baiak Thunder do GitHub"
			sleep 10
		done
		git -C "$FONTE" -c advice.detachedHead=false checkout -q FETCH_HEAD
	fi
	git -C "$FONTE" checkout -q -- src
	for patch in "$BASE"/servidor-imagem/patches/*.patch; do
		git -C "$FONTE" apply "$patch" || falha "patch $(basename "$patch") nao aplicou"
	done
	ok "codigo pronto ($(ls "$BASE"/servidor-imagem/patches/*.patch | wc -l) melhoria(s) do JV Baiak aplicada(s))"

	# --------------------------------------------------- dados do servidor (mapa etc)
	etapa "Preparando mapa, scripts e config.lua"
	SRV="$BASE/servidor"
	if [ ! -f "$SRV/config.lua" ]; then
		mkdir -p "$SRV"
		cp -a "$FONTE/data" "$SRV/data"
		cp "$FONTE/key.pem" "$FONTE/config.lua" "$SRV/"
		mkdir -p "$SRV/data/logs"
		ok "dados copiados (primeira instalacao)"
	else
		ok "dados existentes preservados"
	fi
	cp "$FONTE/schema.sql" "$SRV/schema.sql"
	# Arquivos proprios do JV Baiak (sempre atualizados)
	cp -a "$BASE/servidor-imagem/extras/." "$SRV/"

	lua_define() { # chave valor_lua
		LC_ALL=C awk -v k="$1" -v v="$2" '
			BEGIN { feito = 0 }
			$0 ~ "^" k "[ \t]*=" { print k " = " v; feito = 1; next }
			{ print }
			END { if (!feito) print k " = " v }
		' "$SRV/config.lua" > "$SRV/config.lua.tmp" && mv "$SRV/config.lua.tmp" "$SRV/config.lua"
	}
	lua_define ip "\"$ENDERECO\""
	lua_define mysqlHost '"db"'
	lua_define mysqlUser '"jvbaiak"'
	lua_define mysqlPass "\"$(le_env DB_SENHA)\""
	lua_define mysqlDatabase '"jvbaiak"'
	lua_define mysqlPort 3306
	lua_define serverName "\"$NOME\""
	lua_define url "\"http://$ENDERECO\""
	if [ ! -f "$SRV/.jvbaiak-config-inicial" ]; then
		# Ajustes de jogo, so na primeira vez (depois e voce quem manda no config.lua)
		lua_define motd "\"Bem-vindo ao $NOME! Digite !treino para ver o treino automatico.\""
		lua_define antiBot false          # bot liberado (sem perguntas/punicao anti-bot)
		lua_define freePremium true       # todos com premium: libera todas as areas
		lua_define spoofEnabled false     # nunca mostrar jogadores falsos online
		lua_define ownerName "\"$NOME\""
		touch "$SRV/.jvbaiak-config-inicial"
	fi
	# Ajustes pedidos depois (cada um roda uma vez so; depois e voce quem manda)
	AJUSTES="$SRV/.jvbaiak-ajustes"
	REINICIAR_SERVIDOR=0
	touch "$AJUSTES"
	if ! grep -qx 'exp-800-fixo' "$AJUSTES"; then
		# Baiak com 800x de experiencia em todos os levels
		LC_ALL=C awk '
			/^experienceStages[ \t]*=[ \t]*\{/ { pula = 1; print "experienceStages = {"; print "\t{ minlevel = 1, multiplier = 800 },"; print "}"; next }
			pula && /^\}/ { pula = 0; next }
			pula { next }
			{ print }
		' "$SRV/config.lua" > "$SRV/config.lua.tmp" && mv "$SRV/config.lua.tmp" "$SRV/config.lua"
		lua_define rateExp 800
		echo 'exp-800-fixo' >> "$AJUSTES"
		ok "experiencia: 800x fixo"
		REINICIAR_SERVIDOR=1
	fi
	if ! grep -qx 'criaturas-novas' "$AJUSTES" && command -v python3 >/dev/null; then
		# Cobras, Falcons e Spectres (ideia do Styller-Baiak) com visual do 8.60:
		# registra os monstros e troca parte das hunts parecidas por eles
		python3 - "$SRV/data/monster/monsters.xml" "$SRV"/data/world/*-spawn.xml <<-'PY' && echo 'criaturas-novas' >> "$AJUSTES" && REINICIAR_SERVIDOR=1
			import re, sys
			NOVOS = ["Cobra Assassin", "Cobra Scout", "Cobra Vizier", "Falcon Knight", "Falcon Paladin",
			         "Burster Spectre", "Gazer Spectre", "Ripper Spectre"]
			lista = sys.argv[1]
			txt = open(lista, encoding="latin-1").read()
			linhas = "".join('\t<monster name="%s" file="JV/%s.xml"/>\n' % (n, n.lower()) for n in NOVOS if ('name="%s"' % n) not in txt)
			if linhas:
			    txt = txt.replace("</monsters>", linhas + "</monsters>")
			    open(lista, "w", encoding="latin-1").write(txt)
			TROCAS = {  # monstro do mapa: (a cada quantos, criaturas novas em rodizio)
			    "serpent spawn": (3, ["Cobra Assassin", "Cobra Scout", "Cobra Vizier"]),
			    "hero": (3, ["Falcon Knight", "Falcon Paladin"]),
			    "grim reaper": (4, ["Burster Spectre", "Gazer Spectre", "Ripper Spectre"]),
			}
			conta = {k: 0 for k in TROCAS}
			def troca(m):
			    tag = m.group(0)
			    nome = re.search(r'name="([^"]+)"', tag)
			    chave = nome.group(1).lower() if nome else ""
			    if chave not in TROCAS:
			        return tag
			    cada, novos = TROCAS[chave]
			    conta[chave] += 1
			    if conta[chave] % cada:
			        return tag
			    novo = novos[(conta[chave] // cada) % len(novos)]
			    return tag.replace(nome.group(0), 'name="%s"' % novo)
			for arq in sys.argv[2:]:
			    t = open(arq, encoding="latin-1").read()
			    open(arq, "w", encoding="latin-1").write(re.sub(r"<monster\b[^>]*>", troca, t))
		PY
		ok "criaturas novas: cobras, falcons e spectres nas hunts parecidas"
	fi
	if ! grep -qx 'respawn-rapido-v2' "$AJUSTES" && command -v python3 >/dev/null; then
		# Respawn mais rapido: comuns 60s -> 40s; bosses e raros (lista do GPT, ~110 lugares) -> 50s
		python3 - "$SRV"/data/world/*-spawn.xml <<-'PY' && echo 'respawn-rapido-v2' >> "$AJUSTES" && REINICIAR_SERVIDOR=1
			import re, sys
			RAROS = {"the old widow", "orshabaal", "laravel", "diabolic imp", "hand of cursed fate", "orc warlord",
			         "black knight", "werewolf", "elder beholder", "massive fire elemental", "pirate ghost",
			         "spectre", "blightwalker", "juggernaut", "rotworm queen", "vampire bride", "undead dragon",
			         "ashmunrah", "morgaroth", "ghazbaran", "ferumbras", "demodras", "necropharus", "the horned fox",
			         "the evil eye", "zulazza the corruptor", "the handmaiden", "the imperor", "the plasmother",
			         "dracola", "massacre", "mr. punish", "countess sorrow", "the count", "grorlam"}
			def troca(m):
			    tag = m.group(0)
			    nome = re.search(r'name="([^"]+)"', tag)
			    nome = nome.group(1).lower() if nome else ""
			    if nome in RAROS:
			        return re.sub(r'spawntime="(60|40)"', 'spawntime="50"', tag)
			    return re.sub(r'spawntime="60"', 'spawntime="40"', tag)
			for arq in sys.argv[1:]:
			    t = open(arq, encoding="latin-1").read()
			    open(arq, "w", encoding="latin-1").write(re.sub(r"<monster\b[^>]*>", troca, t))
		PY
		ok "respawn: 40s nos comuns e 50s nos bosses e raros"
	fi
	if ! grep -qx 'admin-total' "$AJUSTES" && command -v python3 >/dev/null; then
		# Administrador (grupo 5) com capacidade infinita: criar/clonar item sem limite de peso
		python3 - "$SRV/data/XML/groups.xml" <<-'PY' && echo 'admin-total' >> "$AJUSTES" && REINICIAR_SERVIDOR=1
			import re, sys
			arq = sys.argv[1]
			t = open(arq, encoding="latin-1").read()
			def grupo(m):
			    return m.group(0).replace('hasinfinitecapacity="0"', 'hasinfinitecapacity="1"')
			t = re.sub(r'<group id="5".*?</group>', grupo, t, flags=re.S)
			open(arq, "w", encoding="latin-1").write(t)
		PY
		ok "administradores com capacidade infinita"
	fi
	chown -R 1000:1000 "$SRV"
	chmod 640 "$SRV/config.lua"
	ok "config.lua ajustado (ip, banco, nome, bot liberado, premium gratis)"

	# ------------------------------------------------------------------- firewall
	etapa "Configurando firewall"
	PORTAS_SSH="$(sshd -T 2>/dev/null | awk '/^port / {print $2}' | sort -u)"
	[ -n "$PORTAS_SSH" ] || PORTAS_SSH=22
	for p in $PORTAS_SSH; do ufw allow "$p/tcp" >/dev/null; done
	ufw allow 80/tcp >/dev/null
	ufw allow 7171/tcp >/dev/null
	ufw allow 7172/tcp >/dev/null
	if [ -n "$(le_env DOMINIO)" ]; then
		ufw allow 443/tcp >/dev/null
		ufw allow 443/udp >/dev/null
	fi
	ufw default deny incoming >/dev/null
	ufw default allow outgoing >/dev/null
	ufw --force enable >/dev/null
	ok "abertas: SSH ($(echo $PORTAS_SSH)), 80 (site), 7171-7172 (jogo). Banco de dados fica fechado."
	if [ -f /etc/iptables/rules.v4 ] && grep -q 'REJECT' /etc/iptables/rules.v4 && curl -fs --max-time 2 -H 'Authorization: Bearer Oracle' http://169.254.169.254/opc/v2/instance/ >/dev/null 2>&1; then
		cor "1;35" "   Oracle Cloud detectada: libere TCP 80, 7171 e 7172 na Security List da VCN (painel da Oracle), senao ninguem conecta."
	fi

	# ------------------------------------------------------------ subir servicos
	cd "$BASE"
	etapa "Compilando o servidor (primeira vez leva de 5 a 15 minutos)"
	docker compose build servidor portal || falha "a compilacao falhou"
	etapa "Ligando banco, servidor e site"
	docker compose up -d --remove-orphans db servidor portal
	if [ "${REINICIAR_SERVIDOR:-0}" = 1 ]; then
		docker compose restart servidor >/dev/null && ok "servidor reiniciado para aplicar os ajustes de jogo"
	fi

	etapa "Aguardando o servidor abrir (carregar o mapa leva alguns minutos)"
	for i in $(seq 1 120); do
		if (exec 3<>/dev/tcp/127.0.0.1/7171) 2>/dev/null; then
			ok "servidor online na porta 7171"
			break
		fi
		if [ "$i" -eq 120 ]; then
			docker compose logs --tail 80 servidor || true
			falha "o servidor nao abriu em 10 minutos (log acima)"
		fi
		sleep 5
	done

	# ---------------------------------------------------------------- conta GM
	CRED="/root/jvbaiak-credenciais.txt"
	if [ ! -f "$CRED" ] || [ -n "$GM_SENHA_PASSADA" ]; then
		etapa "Criando sua conta de administrador (GM)"
		GM_SENHA="${GM_SENHA_PASSADA:-$(aleatorio 6)}"
		"$BASE/jvbaiak" criar-gm admin "$GM_SENHA" "Administrador" >/dev/null
		cat > "$CRED" <<-EOF
	JV Baiak - credenciais (guarde em lugar seguro)
	Site:            http://$ENDERECO
	Conta GM:        admin
	Senha GM:        $GM_SENHA
	Personagem GM:   Administrador
	Senhas internas: $ENV
	EOF
		chmod 600 "$CRED"
		ok "conta GM criada (detalhes em $CRED)"
	fi
	if ! grep -qx 'admins-jv-v1' "$AJUSTES" 2>/dev/null; then
		etapa "Contas de administrador do Joao e do Henrique"
		if "$BASE/jvbaiak" admins-kit; then
			echo 'admins-jv-v1' >> "$AJUSTES"
			ok "administradores prontos (tudo liberado)"
		else
			echo "aviso: nao consegui criar as contas de administrador agora (rode: sudo jvbaiak admins-kit)"
		fi
	fi

	# --------------------------------------------------------------- clientes
	etapa "Gerando os clientes Windows e Android"
	docker compose --profile ferramentas build clientes
	docker compose --profile ferramentas run --rm -T clientes </dev/null || cor "1;35" "   Aviso: os clientes nao foram gerados agora. Rode depois: jvbaiak clientes"

	# --------------------------------------------------------------- backups
	etapa "Agendando backup diario (05:30, guarda 14 dias)"
	cat > /etc/cron.d/jvbaiak <<-'EOF'
	# JV Baiak: backup diario antes do server save das 05:55
	30 5 * * * root /usr/local/bin/jvbaiak backup >> /var/log/jvbaiak-backup.log 2>&1
	EOF
	if [ -n "$(le_env DUCKDNS_TOKEN)" ]; then
		echo '@reboot root sleep 90 && /usr/local/bin/jvbaiak atualizar-ip >> /var/log/jvbaiak-ip.log 2>&1' >> /etc/cron.d/jvbaiak
	fi
	chmod 644 /etc/cron.d/jvbaiak
	"$BASE/jvbaiak" backup >/dev/null && ok "primeiro backup feito em $BASE/backups"

	# ------------------------------------------------- modo web (iPhone), opcional
	if [ -n "$DOMINIO_PASSADO" ]; then
		if [ "$(le_env DOMINIO)" != "$DOMINIO_PASSADO" ] || [ ! -f "$BASE/web/www/jogar/otclient.wasm" ]; then
			etapa "Ligando HTTPS e o jogo no navegador em $DOMINIO_PASSADO"
			if ! systemctl is-active --quiet jvbaiak-web; then
				"$BASE/jvbaiak" web "$DOMINIO_PASSADO" "$DUCKDNS_TOKEN" </dev/null \
					|| cor "1;35" "   Aviso: o modo web nao ligou agora (veja acima). O servidor do jogo esta funcionando."
			fi
		fi
	elif [ -n "$(le_env DOMINIO)" ] && grep -q 'docker-compose.web.yml' "$ENV"; then
		# atualizacao de quem ja usa o modo web: remonta o jogo do navegador com a versao nova
		etapa "Atualizando o jogo do navegador (iPhone) em segundo plano"
		"$BASE/jvbaiak" web "$(le_env DOMINIO)" </dev/null \
			|| cor "1;35" "   Aviso: nao consegui atualizar o jogo do navegador agora. O servidor do jogo esta funcionando."
	fi

	touch "$BASE/.instalado"
	trap - ERR
	echo
	cor "1;32" "================ PRONTO! ================"
	if [ -d "$BASE/web/www/jogar" ]; then printf '%s PRONTO: servidor e site atualizados (o jogo do navegador termina em ~10 min)\n' "$(date '+%d/%m %H:%M')" >> "$BASE/web/www/jogar/atualizacao.txt" 2>/dev/null || true; fi
	if [ -n "$(le_env DOMINIO)" ]; then
		echo "Site (criar conta e baixar o jogo):  https://$(le_env DOMINIO)"
		echo "Jogar no iPhone (quando compilar):   https://$(le_env DOMINIO)/jogar/"
	else
		echo "Site (criar conta e baixar o jogo):  http://$ENDERECO"
	fi
	echo "Servidor no cliente:                 $ENDERECO  porta 7171  versao 8.60"
	echo "Conta GM e senha:                    cat $CRED"
	echo "Administrar:                         jvbaiak ajuda"
	echo "========================================="
}

main "$@"
