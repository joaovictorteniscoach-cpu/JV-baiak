# JV Baiak — arquivo único para testes e publicação na Oracle

João autoriza executar esta atualização. Objetivo: publicar o acabamento visual e os controles móveis mantendo a experiência do Tibia 8.60. Este documento pode ser enviado integralmente ao Claude que já tem acesso SSH à Oracle.

## Versão exata

- Repositório: https://github.com/joaovictorteniscoach-cpu/JV-baiak
- Código aprovado para esta entrega: **8a824e1f127bb2be31dc62ec598952496cba8748**.
- Branch: `codex/jogabilidade-mobile`. O commit já contém os arquivos do visual do PR #3 e os controles do PR #4. Não aplicar os dois como patches por cima desta cópia.
- PR #3: https://github.com/joaovictorteniscoach-cpu/JV-baiak/pull/3
- PR #4: https://github.com/joaovictorteniscoach-cpu/JV-baiak/pull/4
- Código conferido contra main `973a4b44a2517bbbf7b203c3e552ea70d3d1e4eb`. Se a VPS ou main tiver recebido trabalho posterior, comparar antes e preservar essas mudanças. Não fazer reset de uma instalação com dados ou alterações locais.

## O que publicar

1. `portal/static/classico.css` e os templates de login, cadastro, personagem e confirmação: pergaminho, cavaleiro, molduras, botões, foco e adaptação móvel. Arte existente de Tibia reutilizada.
2. `web/shell.html`: capa visual, botões HTML, zoom com limites, restauração por orientação, tela cheia quando suportada, foco devolvido ao jogo, proteção contra iniciar duas vezes e pinça cancelada.
3. `web/patches-final/0005-toque-cancelado-nao-clica.patch`: cancelar um toque, inclusive sem pontos, solta o botão fora do mapa e não abre o menu nem faz clique acidental.
4. Testes em `testes/teste_controles_web.cjs`, `testes/teste_toque_web.py` e `.github/workflows/controles-web.yml`.

Preservar clique/toque, arrastar, segurar como botão direito, inventário, alvo, hotkeys e janelas do OTClient. Não criar joystick, botões de combate por cima do mapa ou atalhos de ações automáticas. Não modificar mapa, monstros, sprites, respawn, rates, experiência, loot, banco, credenciais ou contas nesta publicação. Os pedidos anteriores de novos monstros/respawn são outra etapa e NÃO foram incluídos nesta entrega.

## O que já foi testado pelo Codex

- 45 testes Python existentes: aprovados (portal e robô Oracle com mocks; não provam conectividade à VPS).
- JavaScript real do shell executado em isolamento: zoom inválido/limites/passos/reset, orientações independentes, storage indisponível, início único, painel, teclado/Backspace, foco, teclas de botões, aborto do runtime, fullscreen indisponível e cancelamento da pinça: aprovados.
- Os 5 patches finais aplicaram sequencialmente na fonte OTClient fixada em `1fcea26f23ef1d1857103ef446c0190955523ca8`.
- A função real de tradução de toque dessa fonte, com patches, foi compilada por g++ com `-Wall -Wextra -Werror` e passou em toque curto, segurar, arrastar, cancelamento com zero/um ponto, pinça cancelada e coordenadas escaladas.
- No navegador: abrir a prévia sem WASM, iniciar uma vez, abrir opções, aumentar de 100% para 115% e restaurar 100%: conferidos.
- GitHub Actions `Controles web (sem conta ou rede de jogo)`, run 41227148228, SHA do código acima: sucesso.

Não há acesso SSH Oracle ou Docker neste ambiente do Codex. O WASM completo NÃO foi compilado aqui. Não houve teste desta versão em combate, caminhada, latência, queda de rede ou Safari/iPhone físico. A varredura completa criada pelo Claude para a main anterior não valida automaticamente esta nova entrega. Não declarar “tudo testado” só porque um job terminou verde: conferir relatórios e cenários.

## 1. Obter o código sem tocar na instalação

Execute como root na VPS que hospeda bayakjh.duckdns.org. Use a mesma sessão de shell nas etapas abaixo para manter as variáveis. Se a instalação não for /opt/jvbaiak, ajuste BASE para o caminho identificado. Não cole credenciais em logs ou no chat.

```bash
set -Eeuo pipefail
umask 077
BASE=/opt/jvbaiak
DOMINIO=bayakjh.duckdns.org
REV=8a824e1f127bb2be31dc62ec598952496cba8748
FONTE=$(mktemp -d /tmp/jvbaiak-revisao.XXXXXX)
git clone --quiet https://github.com/joaovictorteniscoach-cpu/JV-baiak.git "$FONTE/kit"
git -C "$FONTE/kit" checkout --detach "$REV"
test "$(git -C "$FONTE/kit" rev-parse HEAD)" = "$REV"
SRC="$FONTE/kit"
test -f "$BASE/.env"
test -f "$BASE/docker-compose.yml"
test -f "$BASE/docker-compose.web.yml"
test -f "$BASE/web/versao-base.env"
test -f "$BASE/web/compilar-web.sh"
cd "$BASE"
docker compose config --quiet
docker compose ps
PORTAL_ID=$(docker compose ps -q portal)
test -n "$PORTAL_ID"
test -d "$BASE/web/www/jogar"
test -f "$BASE/web/www/jogar/otclient.wasm"
df -h "$BASE" /var/lib/docker
```

Conferir o domínio e os arquivos Compose ativos, inclusive `COMPOSE_FILE` no .env, sem expor o conteúdo completo do .env. Os comandos docker compose abaixo dependem dessa configuração já existente. Se os serviços ativos não forem os da instalação esperada, corrigir a seleção do projeto antes de prosseguir.

Comparar o portal instalado com o código obtido, incluindo app.py, infos.py, requirements, Dockerfile, templates e CSS. Comparar também web/shell.html, web/Dockerfile.final, web/compilar-web.sh, web/versao-base.env, web/patches-final e web/otclientrc-extra.lua. A entrega não muda o backend: se houver backend mais novo/customizado na VPS, preservá-lo e aplicar somente o diff visual. Se o backend for compatível com a main base indicada, a cópia integral de portal abaixo é apropriada.

## 2. Testes antes da publicação

No checkout descartável, em ambiente Python isolado:

```bash
cd "$SRC"
python3 -m venv "$FONTE/venv"
"$FONTE/venv/bin/pip" install -r portal/requirements.txt
"$FONTE/venv/bin/python" -m unittest discover -s testes -p 'teste_*.py'
node testes/teste_controles_web.cjs
bash -n web/compilar-web.sh
```

Node 22 ou superior e g++ são usados na validação nova. Se faltarem, instalar pela distribuição/rotina já adotada na VPS ou executar esses testes no GitHub Actions do SHA indicado. Não instalar binários de clientes ou DLLs de fontes novas.

A conferência dos patches pode ser repetida sem compilar o cliente inteiro:

```bash
TOQUE=$(mktemp -d /tmp/jvbaiak-toque.XXXXXX)
git -C "$TOQUE" init -q
for arquivo in src/framework/platform/browserwindow.cpp src/framework/ui/uitextedit.cpp src/client/protocolgame.cpp modules/client_locales/locales.lua; do
  mkdir -p "$TOQUE/$(dirname "$arquivo")"
  curl --fail --silent --show-error --retry 2 "https://raw.githubusercontent.com/opentibiabr/otclient/1fcea26f23ef1d1857103ef446c0190955523ca8/$arquivo" -o "$TOQUE/$arquivo"
done
for patch in "$SRC"/web/patches-final/*.patch; do
  git -C "$TOQUE" apply --check "$patch"
  git -C "$TOQUE" apply "$patch"
done
"$FONTE/venv/bin/python" "$SRC/testes/teste_toque_web.py" "$TOQUE"
```

Não executar os scripts de varredura que criam contas no site público sem revisar seu destino. Para testes completos, preferir instância temporária e banco separado; nunca apontar testes de limpeza de contas para o banco real.

## 3. Backup recuperável

```bash
cd "$BASE"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$BASE/backups/visual-controles-$STAMP"
mkdir -p "$BACKUP"
chmod 700 "$BACKUP"
PORTAL_ANTIGO=$(docker inspect --format '{{.Image}}' "$PORTAL_ID")
docker image tag "$PORTAL_ANTIGO" "jvbaiak/portal:antes-$STAMP"
printf '%s\n' "$REV" > "$BACKUP/revisao-nova.txt"
printf '%s\n' "$PORTAL_ANTIGO" > "$BACKUP/imagem-portal-anterior.txt"
tar -C "$BASE" -czf "$BACKUP/codigo-anterior.tgz" portal web/shell.html web/patches-final
cp -a "$BASE/web/www/jogar" "$BACKUP/jogar"
printf '%s\n' "$BACKUP" > "$BASE/backups/ultimo-backup-visual-controles.txt"
```

Conferir espaço disponível para o backup, imagem e compilação. Não usar limpeza global de imagens/volumes para liberar espaço. O banco não será alterado. Manter a rotina de backup de dados existente na VPS.

## 4. Atualizar somente os componentes necessários

Se a comparação da etapa 1 confirmou o portal compatível com a base:

```bash
cp -a "$SRC/portal/." "$BASE/portal/"
cp -a "$SRC/web/shell.html" "$BASE/web/shell.html"
cp -a "$SRC/web/patches-final/." "$BASE/web/patches-final/"
cd "$BASE"
docker compose build portal
docker compose up -d --no-deps --force-recreate portal
curl --fail --silent --show-error --retry 5 --retry-delay 2 "https://$DOMINIO/saude"
```

Se a saúde falhar, investigar o log do portal e restaurar o portal antes de continuar. Não alterar regras do banco para contornar falha. Não executar instalar.sh nem jvbaiak atualizar para esta troca, pois isso pode aplicar ajustes de outras áreas.

Gerar o cliente web com o compilador já usado pelo projeto. Não trocar a base, SDK ou sprites:

```bash
cd "$BASE"
BASE="$BASE" bash "$BASE/web/compilar-web.sh" "$DOMINIO"
test -s "$BASE/web/www/jogar/otclient.wasm"
test -s "$BASE/web/www/jogar/index.html"
grep -q 'zoom-restaurar' "$BASE/web/www/jogar/index.html"
grep -q 'jogoIniciado' "$BASE/web/www/jogar/index.html"
curl --fail --silent --show-error -I "https://$DOMINIO/jogar/"
curl --fail --silent --show-error -I "https://$DOMINIO/jogar/otclient.wasm"
curl --fail --silent --show-error "https://$DOMINIO/jogar/" | grep -q 'zoom-restaurar'
```

A compilação usa os 5 patches finais no binário WASM; alterar só o HTML publicado NÃO aplica a correção C++ do toque. O compilador publica em web/www/jogar quando termina. Ele mantém o cliente anterior servindo durante a compilação, mas altera arquivos de andamento. Se falhar depois de iniciar a troca de pastas, usar o backup externo acima. Não reiniciar servidor, banco, pontes ou Caddy por rotina; o Caddy já monta a pasta pai web/www.

Confirmar COOP `same-origin` e COEP `require-corp` na resposta /jogar/; os WebSockets de login e jogo devem continuar acessíveis. Não expor novas portas nem enfraquecer HTTPS.

## 5. Aceitação no jogo completo

Usar uma conta de teste em ambiente separado quando possível. Rodar os testes de navegador do projeto contra o cliente recém-compilado; revisar os parâmetros de destino e o código desses scripts antes. A ferramenta Playwright WebKit emulando iPhone é útil, mas não substitui um aparelho físico.

Conferir no PC com mouse/teclado, Android por toque e Safari em iPhone:

- Login/logout e troca de personagem; clique repetido em Jogar inicia só uma vez.
- Caminhar por toque, autowalk e minimapa; bordas e cantos sem desvio de posição.
- Tocar para selecionar/usar; arrastar item entre mochila/chão/equipamento; segurar para menu direito. Cancelar o gesto não pode andar nem abrir menu.
- Abrir mochila, inventário, skills, chat, hotkeys e botões originais sem sobreposição de ferramentas novas.
- Digitar conta, senha, chat e apagar; Enter uma vez; fechar teclado e voltar a mover/clicar.
- Pinça, A+/A− e restauração; girar em pé/deitado; tamanho legível e coordenadas corretas em ambos.
- Tela cheia quando disponível; no iPhone sem suporte, Adicionar à Tela de Início. Recusa de fullscreen não trava o cliente.
- Cancelamento de toque pelo sistema, bloquear/desbloquear, alternar app e Wi-Fi/dados: nenhum botão preso; reconexão existente sem duplicação.
- Caminhar e combater por pelo menos 10 minutos em hunt comum e área movimentada; medir FPS/tempo de frame e uso de memória no mesmo aparelho antes/depois. Verificar aquecimento e latência. Não prometer desempenho sem medição.
- Confirmar que os controles nativos de PC e APK continuam iguais; esta entrega altera apenas o cliente web e o portal.

Se houver regressão, corrigir/retestar antes de concluir. Evitar controles inventados e modificar somente a ponte de entrada/renderização necessária ao celular. Tirar capturas e guardar logs sem senhas. Não trocar o mapa para mascarar problema de desempenho.

## 6. Rollback

Na mesma sessão, as variáveis BASE, BACKUP e PORTAL_ANTIGO ainda estão definidas. Em outra sessão, recuperar BACKUP lendo `$BASE/backups/ultimo-backup-visual-controles.txt` e conferir o diretório antes de usar. Recuperar a imagem antiga de `$BACKUP/imagem-portal-anterior.txt`.

```bash
cd "$BASE"
test -s "$BACKUP/codigo-anterior.tgz"
test -s "$BACKUP/jogar/index.html"
tar -C "$BASE" -xzf "$BACKUP/codigo-anterior.tgz"
# O tar restaura arquivos antigos, mas não remove arquivos novos: retirar o patch novo.
if [ -f "$BASE/web/patches-final/0005-toque-cancelado-nao-clica.patch" ]; then
  mv "$BASE/web/patches-final/0005-toque-cancelado-nao-clica.patch" "$BACKUP/patch-novo-retirado.patch"
fi
docker image tag "$PORTAL_ANTIGO" jvbaiak/portal:local
docker compose up -d --no-deps --force-recreate portal
# Preservar o cliente que falhou para diagnóstico, e recolocar a pasta antiga.
FALHOU="$BASE/web/www/jogar-falhou-$(date +%Y%m%d-%H%M%S)"
if [ -d "$BASE/web/www/jogar" ]; then mv "$BASE/web/www/jogar" "$FALHOU"; fi
cp -a "$BACKUP/jogar" "$BASE/web/www/jogar"
curl --fail --silent --show-error "https://$DOMINIO/saude"
curl --fail --silent --show-error -I "https://$DOMINIO/jogar/"
```

Parar qualquer compilação ainda em andamento antes do rollback para ela não publicar por cima da restauração. Usar a imagem exata anterior, não reconstruir arquivos possivelmente diferentes. Para remover o patch novo, conferir que ele não existia no tar anterior; se já existia antes, restaurar a versão do backup em vez de movê-la.

## 7. Entrega ao João

Informar: SHA publicado; URL; saúde do portal; resultado da compilação; testes e aparelhos realmente usados; medidas de desempenho; pendências reais; local do backup. Explicar explicitamente se faltou teste em iPhone físico. Não afirmar que mapa/monstros/respawn foram atualizados, pois não fazem parte deste pacote.

Os PRs continuam separados para revisão: #4 tem base na branch do visual. Se for integrar no GitHub, integrar #4 em codex/acabamento-visual e depois #3 em main, conferindo SHA e conflitos antes. A publicação por commit fixo acima já contém as duas revisões; não depende de executar um instalador completo.
