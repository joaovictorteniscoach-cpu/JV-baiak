#!/usr/bin/env bash
# Investiga uma queda do servidor ("corrupted size vs. prev_size") vista no teste:
# repete a sequencia em variacoes, reiniciando o servidor entre elas.
# Uso (na maquina de teste, depois do instalar.sh): experimento_crash.sh <pasta-saida>
OUT="$1"; mkdir -p "$OUT"; R="$OUT/experimentos.txt"; : > "$R"
cd /opt/jvbaiak
reiniciar() {
	sudo docker compose restart servidor >/dev/null 2>&1
	for i in $(seq 1 60); do (exec 3<>/dev/tcp/127.0.0.1/7171) 2>/dev/null && return 0; sleep 3; done
	return 1
}
nova_conta() { # imprime "conta senha"
	python3 "$GITHUB_WORKSPACE/testes/varredura_site.py" http://127.0.0.1 "$OUT/tmp-site" >/dev/null 2>&1
	jq -r '"\(.conta) \(.senha)"' "$OUT/tmp-site/conta.json"; rm -rf "$OUT/tmp-site"
}
jogador() { python3 "$GITHUB_WORKSPACE/testes/protocolo_860.py" 127.0.0.1 "$@" >> "$OUT/protocolo.txt" 2>&1; echo "--" >> "$OUT/protocolo.txt"; }
caiu() {
	local desde="$1"
	sudo docker compose logs --no-color --since "$desde" servidor 2>&1 | grep -E "corrupted|Segmentation|double free|malloc|Aborted|core dumped" | head -n 3
	(exec 3<>/dev/tcp/127.0.0.1/7171) 2>/dev/null || echo "porta 7171 fechada"
}
experimento() { # nome comandos...
	local nome="$1"; shift
	reiniciar || { echo "$nome: servidor nao voltou" >> "$R"; return; }
	local desde; desde="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
	echo "== $nome" >> "$OUT/protocolo.txt"
	"$@"
	sleep 5
	local q; q="$(caiu "$desde")"
	echo "$nome: ${q:-OK (servidor vivo)}" >> "$R"
}
e1() { read -r c s < <(nova_conta); jogador "$c" "$s"; jogador "$c" "$s"; }
e2() { jogador robogm Robo12345 --gm --sem-clonar; read -r c s < <(nova_conta); jogador "$c" "$s"; }
e3() { jogador robogm Robo12345 --gm; read -r c s < <(nova_conta); jogador "$c" "$s"; }
e4() { read -r c s < <(nova_conta); jogador "$c" "$s"; read -r c2 s2 < <(nova_conta); jogador "$c2" "$s2"; jogador "$c" "$s"; }
experimento "1-jogador novo entra 2x" e1
experimento "2-gm sem clonar + jogador novo" e2
experimento "3-gm com clonar + jogador novo" e3
experimento "4-tres logins de jogadores" e4
cat "$R"
