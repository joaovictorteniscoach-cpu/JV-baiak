# Ascensão: classes, hunts e equipamentos

Implementação para revisão antes de atualizar a VPS. Mantém auto pot, auto ataque, autoloot, poções infinitas, mapa existente e interface. As mudanças de outfit solicitadas usam desenhos clássicos 8.60, sem arquivos de sprites novos.

## O que foi encontrado na versão atual

Base revisada: `74d60fa`, de 21/11/2026. O Mestre das Classes já oferece quatro evoluções (2×, 4×, 7× e 10×), antes por 100k cada e sem level mínimo. Os monstros base recebem vida em dobro pelo instalador. As quatro vocações têm três nomes de promoção na base, mas essas promoções mantêm os mesmos multiplicadores físicos.

As promoções originais continuam: Knight → Elite Knight → Rageful Knight; Paladin → Royal Paladin → Glorious Paladin; Sorcerer → Master Sorcerer → Masterful Sorcerer; Druid → Elder Druid → Ancient Druid. A Ascensão funciona em paralelo e não troca a vocação, evitando perder magias, equipamentos ou compatibilidade do cliente.

## Evoluções

| Evolução | Level para comprar | Gold | Hit contra monstro | Ataque básico | Bônus de movimento |
|---|---:|---:|---:|---:|---:|
| I | 200 | 100k | 2× | 320 ms | +20 |
| II | 400 | 300k | 4× | 285 ms | +40 |
| III | 600 | 700k | 7× | 250 ms | +60 |
| IV | 800 | 1,5kk | 10× | 220 ms | +80 |

O gold pode vir da mochila e do banco. A confirmação verifica o level antes de cobrar. Quem já tem evolução mantém sua compra, mesmo abaixo do novo level mínimo. O bônus de movimento é em unidades internas de velocidade, não porcentagem. As magias mantêm seus cooldowns; a velocidade afeta os ataques básicos. Os intervalos consideram a vocação e nunca passam do limite de 200 ms.

O motor base consulta ataques periódicos a cada segundo. O patch 0006 cria uma única verificação por jogador com intervalo configurado, preservando `lastAttack`, pacificação e parada do combate. Isso torna a velocidade efetiva, sem múltiplos temporizadores sobrepostos. Por isso os multiplicadores da tabela são por hit, não uma promessa de DPS total.

`!evolucao` mostra o título e a maestria. No Mestre das Classes, use `niveis` e `evoluir`.

| Classe | I | II | III | IV |
|---|---|---|---|---|
| Knight | Cavaleiro Desperto | Guardião de Ferro | Cavaleiro Abissal | Titã da Guerra |
| Paladin | Atirador Desperto | Sentinela Real | Rastreador Astral | Executor Divino |
| Sorcerer | Canalizador | Piromante | Arcanista | Arquimago |
| Druid | Naturalista | Guardião das Raízes | Xamã Ancestral | Avatar da Natureza |

Cada classe usa seu outfit clássico masculino/feminino. As etapas mudam a cor e os addons (0, 1, 2 e 3); o addon é liberado no personagem. O topo tem cor dourada. O bônus não se acumula a cada login e não substitui as outras condições de velocidade.

Após evoluir, subir level e treinar skills/magic level continuam aumentando o dano pelas fórmulas originais. Além disso, cada 50 abates nas hunts novas concede uma maestria de +2% de dano PvE, até dez ranks (+20%). Em dupla/party, participantes vivos próximos recebem progresso, sem duplicar o líder ou premiar personagens distantes. Invocações de jogadores não servem para farmar maestria ou raros.

Exemplo: um hit que causaria 1.000 contra o mesmo monstro passa a 2.000, 4.000, 7.000 e 10.000 pelas evoluções. Com maestria máxima, chega a 12.000 antes de considerar alterações de equipamento/crítico. Não é uma medição de personagem real. O bônus de ataque não se aplica contra jogadores; a defesa existente continua funcionando.

## Hunts depois do Demon

| Hunt | Entrada | Monstro | HP final | Modalidade sugerida |
|---|---|---|---:|---|
| Caverna Infernal | Lv 400, Evo I | Demônio Ascendido | 50.000 | Solo |
| Forja Abissal | Lv 600, Evo II | Colosso Abissal | 120.000 | Solo |
| Cripta Ancestral | Lv 650, Evo II | Guardião Ancestral | 220.000 | Dupla; solo no topo |
| Covil dos Titãs | Lv 800, Evo III | Titã Profanado | 500.000 | Dupla; solo no topo |
| Trono Infernal | Lv 1.000, Evo IV | Soberano Infernal | 3.000.000 | Chefe solo no topo |

O Demon base tem 8.200 HP, ou 16.400 após a migração 2×. Todas as novas criaturas têm mais HP e ataques maiores. A vida da tabela já é final: não é dobrada novamente. As duas hunts de dupla não obrigam party nem duas pessoas para entrar; todo conteúdo permite tentativa solo com evolução máxima, level e equipamentos adequados. Estes são valores iniciais para balancear em jogo, não uma garantia de sobrevivência com qualquer personagem.

O portal de Ascensão é colocado em um tile vazio perto do templo de Thunder City e leva a um salão com cinco portais identificados. Cada hunt tem volta ao templo na entrada. `!ascensao` lista as hunts e `!ascensao 1` até `!ascensao 5` permitem viajar a partir do templo/salão. Não são atalhos para fugir de qualquer local do mapa.

As salas são criadas no startup em coordenadas reservadas 30000–30516, com chão de mármore e paredes clássicas. O sistema confere todos os tiles antes de criar a sala; se houver colisão com mapa customizado, a área fica indisponível. Não substitui o mapa OTBM, casas ou hunts existentes. Os monstros têm limite por sala e respawn entre 45 e 90 segundos; o chefe tem 300 segundos. Não há spawn forçado sobre jogadores. A chegada escolhe tile livre e evita o portal de retorno, inclusive para a segunda pessoa da dupla.

## Itens raros proporcionais

Os drops especiais usam itens existentes: Magic Sword, Magic Longsword, Thunder Hammer, Solar Axe, Royal Crossbow, Warsinger Bow, Wand of Voodoo, Hailstorm Rod, Magic Plate Armor, Golden Helmet, Demon Legs, Great Shield e Golden Boots.

| Reforço | Atributos base | Chance de um item especial por abate |
|---|---:|---:|
| I | +10% | Caverna: 0,5% |
| II | +20% | Forja: 0,8%; Cripta: 1% |
| III | +35% | Covil: 1,2% |
| IV | +50% | Soberano: 15% |

É uma rolagem para escolher um dos treze itens; a chance de cada item específico é a chance da tabela dividida por treze. O sorteio não é multiplicado pelo loot global de 100× ou por boosters. Assim um raro não passa a ser garantido por causa da configuração do servidor.

Ataque, defesa e armadura são atributos reais da instância; itens normais do mesmo ID não são alterados. Por exemplo: Magic Sword 48/35 → 72/53 no reforço IV; Magic Plate Armor 17 → 26. Não se multiplica novamente um item já reforçado. O desenho é o mesmo, com descrição nativa do reforço.

Wands/rods e distância recebem poder proporcional nas suas fórmulas de dano, usando o melhor bônus equipado, sem somar duas armas. No Knight, o aumento já entra pelos atributos da arma, sem duplicar esse bônus.

O item nasce no corpo, preserva o dono do loot e é reconhecido como raro pelo autoloot. A regra de ignorar continua tendo precedência. `!venderloot` preserva equipamentos reforçados, evitando vendê-los pelo preço base em uma venda em lote. Itens normais continuam sendo vendidos.

## Instalação e testes

Todas as regras estão em `servidor-imagem/extras/data/lib/jv_progressao.lua`. A storage de evolução continua 79500; a maestria usa 79600, sem reutilizar autoloot, cura ou hunt.

O instalador registra os novos XMLs sem duplicação, aplica o patch nativo e reinicia o servidor quando os scripts mudam. É necessário compilar o servidor; não basta copiar os arquivos Lua. Faça backup antes de atualizar. Esta versão deve ser revisada/testada antes de integrar à main e atualizar a VPS.

```bash
python -m pip install lupa==2.6
python -c "from pathlib import Path; from lupa.lua51 import LuaRuntime; LuaRuntime().execute(Path('testes/teste_progressao.lua').read_text())"
python testes/preparar_servidor_testes.py /tmp/servidor-progressao
python testes/teste_intervalo_evolucao.py /tmp/servidor-progressao
python testes/teste_ascensao_arquivos.py /tmp/servidor-progressao
```

Os testes executam o Lua real, compilam as funções C++ reais do ataque e conferem os dados da versão fixada. Ainda é necessário conferir o combate, sprites, teleporte e dificuldade no cliente/servidor em execução antes de declarar o balanceamento final.
