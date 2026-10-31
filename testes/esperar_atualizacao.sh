#!/usr/bin/env bash
# Espera a atualizacao da VPS terminar (servidor + jogo do navegador) antes de testar.
# Pronto = o arquivo de andamento ja tem a etapa das contas de administrador e, depois
# dela, "jogo do navegador: pronto". Desiste de esperar depois de 45 minutos.
SITE="${1:?site}"
for i in $(seq 1 90); do
	txt="$(curl -fsS --max-time 20 "$SITE/jogar/atualizacao.txt?v=$(date +%s)" 2>/dev/null || true)"
	if printf '%s\n' "$txt" | awk '/Contas de administrador/ {a=1} a && /jogo do navegador: pronto/ {p=1} END {exit !p}'; then
		echo "atualizacao da VPS terminada:"; printf '%s\n' "$txt" | tail -n 4; exit 0
	fi
	if printf '%s\n' "$txt" | grep -q "ERRO"; then
		echo "a atualizacao da VPS deu erro:"; printf '%s\n' "$txt" | tail -n 6; exit 0
	fi
	[ $((i % 6)) -eq 1 ] && { echo "esperando a atualizacao ($((i / 2)) min):"; printf '%s\n' "$txt" | tail -n 2; }
	sleep 30
done
echo "a VPS nao terminou de atualizar em 45 min; testando assim mesmo"
