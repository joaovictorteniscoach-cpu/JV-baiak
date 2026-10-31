# Pedido do João: mapa principal Baiak com cidade Central

## Resultado da pesquisa e decisão

Família escolhida: **Baiak/Yurots com cidade Central**, semelhante à descrição do João. O mapa público BaiakChaito tem cidade Central, ID 1, templo (160,54,7). A base atual Baiak Thunder usa Thunder City, ID 1, templo (991,1210,7). Portanto, a troca muda efetivamente o centro do mundo e exige migração de posições e serviços.

Ainda NÃO trocar mapName na produção. A candidata foi registrada em mapas/principal-candidato.json, com origem fixa, hashes e bloqueios. Não existe publicação desse novo mapa na Oracle nesta entrega.

Não foi possível comprovar qual arquivo é o mais usado e mais jogado de todos os OTs brasileiros. Listas usam nomes autodeclarados e versões customizadas. A lista OTSLIST Baiak tinha Ilusion BR em primeiro na consulta, mas o arquivo observado dele é Baiak Ilusion.otbm; não foi encontrada uma distribuição oficial pública desse mapa exato. A listagem agregada otservers.online menciona Baiak Yurots em muitos servidores, mas sua página de detalhes apresentou números inconsistentes. Não usar esse agregado para anunciar liderança nacional.

Fontes consultadas em 31/10/2026:
- https://otslist.net/pt-BR/servers/type/baiak
- https://otslist.net/pt-BR/servers/baiak-ilusion-br-c54125e181
- https://otservers.online/pt-BR/servers/insights/maps
- https://otservers.online/servers/holiday.servegame.com
- https://github.com/otservme/baiak860
- https://github.com/tiroleivi/Baiak-8.60-Completo

## Comparação real dos arquivos

Auditados contra o datapack original moviebr/baiakthunder@265d45805c5d2204262ffd55b8fc67d97b829916. As extensões atuais do JV Baiak devem ser consideradas ao repetir na VPS.

| Verificação | BaiakChaito / Central | Baiak Yurots Completo |
|---|---:|---:|
| Posições de monstros | 7.915 | 18.680 |
| Espécies no mapa | 173 | 248 |
| Espécies ausentes no registro original | 14 | 62 |
| Posições de monstros sem tile | 0 | 0 |
| Templos sem tile | 0 | 2 |
| Tempos de spawn inválidos | 0 | 1 |
| IDs de casas sem definição XML | 67 | Ver JSON |
| Nomes de NPCs sem arquivo na base original | 17 | Ver JSON |

As auditorias completas estão em docs/mapas/central-auditoria.json e yurots-auditoria.json. O erro de codificação do Merlin é herdado da base original; não atribuí-lo ao mapa candidato. Dados de popularidade não são prova de qualidade desses downloads.

## Baixar a candidata de forma isolada

Na VPS, sem parar serviços ou tocar no mundo atual:

```bash
set -Eeuo pipefail
umask 077
BASE=/opt/jvbaiak
CANDIDATO=$(mktemp -d /tmp/jvbaiak-central.XXXXXX)
ORIGEM=https://raw.githubusercontent.com/otservme/baiak860/d0f85243747b8008552fd29b14de8752e770a652/data/world
for arquivo in BaiakChaito.otbm BaiakChaito-spawn.xml BaiakChaito-house.xml; do
  curl --fail --silent --show-error --retry 2 "$ORIGEM/$arquivo" -o "$CANDIDATO/$arquivo"
done
```

Comparar SHA256 com mapas/principal-candidato.json do checkout desta revisão. Não confiar no nome do arquivo ou trocar para a branch móvel main do fornecedor. Não executar executáveis do servidor antigo nem importar schema.sql/config.lua/credenciais desse pacote.

Repetir a auditoria usando o servidor REAL instalado e a ferramenta desta revisão (TOOL aponta para servidor-imagem/ferramentas/auditar_mapa.py no checkout):

```bash
TOOL=/caminho/do/checkout/servidor-imagem/ferramentas/auditar_mapa.py
python3 "$TOOL" "$BASE/servidor" --mundo "$CANDIDATO" --mapa BaiakChaito --exigir-aprovado > "$CANDIDATO/auditoria.json"
```

A candidata conhecida deve reprovar. O código de saída 2 indica bloqueios: não ignorar para publicar. A ferramenta é somente de leitura. “Aprovado” nessa flag significa apenas os testes estáticos implementados; não verifica todos os itens, sprites, scripts, quests ou caminhabilidade.

## Trabalho necessário para torná-la principal

1. Resolver os 14 monstros não cadastrados. Doze têm arquivos órfãos na base original, mas ainda precisam conferir atributos, ataques, loot, scripts e sprites; não basta adicionar nomes no monsters.xml. Training Monk e Demon (Goblin) precisam de definições compatíveis. Usar os relatórios de nomes.
2. Portar os 17 NPCs/serviços para as APIs do TFS atual, com comércio e destinos corretos. Não copiar scripts de TFS antigo sem portabilidade e testes. Não substituir NPCs por personagens vazios apenas para passar na auditoria.
3. Completar/corrigir as 67 casas referidas no OTBM. Conferir entradas reais, town ID, nomes, tamanho e propriedade; não inventar coordenadas para passar no teste.
4. Verificar cada server item ID do OTBM contra items.otb/items.xml do cliente/servidor atuais; conferir atributos únicos, action IDs, teleportes, portas, escadas, quests e scripts de movimento. Não substituir items.otb ou sprites completos sem comparação.
5. Adaptar coordenadas de eventos, trainers automáticos, barcos, bosses e teleports. O treino atual usa caixas do Thunder e não pode ficar ativado em áreas arbitrárias deste novo mundo. Conferir também cidades exibidas no portal.
6. Testar uma instância separada com banco separado. Inicialização sem erros; templo seguro, lojas, depot, saída da cidade, casas, hunts, retorno, morte/login e reinício. Testar no PC e celular com o cliente atual. Não usar a cópia de produção como banco dos testes.
7. Preparar backup completo dos dados e a migração. Contas e personagens devem ser preservados. House IDs de outro mapa não podem reutilizar proprietários/itens de casas antigas por coincidência; isso exige uma migração revisada. Reposicionar jogadores só com servidor parado, registrando posições e destino seguros. Fazer rollback restaurando mapa E banco correspondentes.
8. Só depois definir mapName e cidade inicial para o novo mapa; guardar o Thunder como alternativa recuperável. Alterar o perfil do instalador de forma idempotente e impedir que uma atualização comum do kit troque o mapa de instalações existentes.

Se a adaptação for desproporcional, procurar outra distribuição Baiak/Central com pacote completo, compatível e verificável. Não afirmar que ela é a do Ilusion ou a mais popular sem evidência. João autorizou a troca, mas quer o servidor funcional e preservação dos dados; os bloqueios acima são técnicos, não falta de autorização.

## Entrega esperada

Publicar o novo mapa somente após testes e migração. Informar o nome/fonte/hash do mapa instalado, evidências do templo e cidade, resultados de NPCs/casas/hunts, backup e rollback. Até lá, informar claramente que o mapa principal antigo continua ativo.
