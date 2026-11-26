# Ascensão: classes, hunts e equipamentos

Guia das evoluções e hunts de Ascensão. Mantém auto pot, auto ataque, autoloot, poções infinitas, mapa existente e interface. As mudanças de outfit usam desenhos clássicos 8.60, sem arquivos de sprites novos.

## O que foi encontrado na versão atual

Base revisada: `74d60fa`, de 21/11/2026. O Mestre das Classes já oferece quatro evoluções (2×, 4×, 7× e 10×), antes por 100k cada e sem level mínimo. Os monstros base receberam vida em dobro e depois tiveram essa vida aumentada mais dez vezes pelo instalador. As quatro vocações têm três nomes de promoção na base, mas essas promoções mantêm os mesmos multiplicadores físicos.

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

| Hunt | Entrada | Principais criaturas | Vida do andar 1 ao 5 | Maior hit corporal do andar 1 ao 5 |
|---|---|---|---|---|
| Caverna Infernal | Lv 300, Evo I | Demônio Ascendido, Arauto das Brasas e Master Snoop | 38.889 → 138.889 | 180 → 550 |
| Forja Abissal | Lv 600, Evo II | Colosso Abissal, Cavaleiro do Abismo e Dr Dre | 77.778 → 277.778 | 350 → 1.000 |
| Cripta Ancestral | Lv 650, Evo II | Guardião Ancestral, Vigia da Cripta e Mr 420 | 111.111 → 416.667 | 500 → 1.450 |
| Covil dos Titãs | Lv 800, Evo III | Titã Profanado, Dragão das Ruínas e O.G Chef | 166.667 → 666.667 | 700 → 2.000 |
| Trono Infernal | Lv 1.000, Evo IV | Guardas e Soberano Infernal | 222.222 → 1.666.667 | 900 → 2.600 |

As quatro hunts comuns têm sete andares. O sexto e o sétimo usam variantes mais fortes, com respectivamente 20% e 40% mais vida e 15% e 30% mais dano corporal que as versões do quinto andar. O Trono Infernal tem oito andares. Cada área foi calibrada para tentativa solo com a evolução exigida, também podendo ser feita em dupla. O dano real depende de equipamento, evolução e resistência; estes são valores iniciais para validar em jogo, não uma garantia de sobrevivência. Os sprites existentes não mudam.

O portal de Ascensão é colocado em um tile vazio perto do templo de Thunder City e leva a um salão com nove portais de hunts identificados. Em cada andar, o portal à direita avança e o da esquerda volta ao anterior; há também retorno ao templo junto à entrada de cada andar. `!ascensao` lista as hunts e `!ascensao 1` até `!ascensao 9` permitem viajar a partir do templo/salão. Não são atalhos para fugir de qualquer local do mapa.

`!missao` mostra a tarefa diária da Ascensão: 50 abates válidos, com crédito para participantes vivos e próximos. `!missao resgatar` envia 50.000 moedas ao banco uma vez por dia; o progresso reinicia à meia-noite UTC. A tarefa usa as mesmas regras de participação e proteção contra invocações dos fragmentos.

**Vampirismo:** a partir do level 200, todas as vocações podem usar `utito vita sanguis` (250 de mana, duração de 20 segundos e recarga de 60 segundos). Recupera 10% do dano efetivo causado a monstros não invocados, limitado a 10% da vida máxima por acerto. Não funciona em PvP nem com dano de invocações. O valor é aplicado depois de defesas e limitado à vida restante do monstro. O balanceamento inicial deve ser acompanhado em jogo.

As salas são criadas no startup em áreas reservadas, com chão de mármore e paredes clássicas. O sistema confere todos os tiles antes de criar a sala; se houver colisão com mapa customizado, a área fica indisponível. Não substitui o mapa OTBM, casas ou hunts existentes. As hunts comuns têm 6, 8, 10, 12, 14, 16 e 18 monstros por andar. No quinto andar do Trono há dois Soberanos; nos três últimos andares há seis bosses por andar, dois de cada tipo, com respawn de 150 segundos. As demais hunts mantêm seus intervalos de respawn. Parte nasce a poucos quadrados da chegada e os demais ficam espalhados. Não há spawn forçado sobre jogadores. A chegada escolhe tile livre e evita o portal de retorno, inclusive para a segunda pessoa da dupla.

Das 67 entradas antigas identificadas como hunts no mapa fixado, dez tinham zero ou um monstro a até sete quadrados da chegada. Cada uma recebeu até dois monstros evoluídos da família daquela hunt, em posições acessíveis e fora de zonas protegidas, casas e teleportes. Entradas para templos, cidades, eventos e o boss Ashmunrah não recebem reforços. Se o portal da VPS tiver outro destino ou faltar posição segura, o reforço é ignorado e o servidor registra o motivo no log. As oito variantes usam o sprite original, aproximadamente 35% mais vida que a versão base já dobrada, 30% mais dano nos valores configurados e 30% mais experiência; conservam o loot da família e não concedem fragmentos da Ascensão. Os bônus não se aplicam a todos os ataques especiais que não usam valores numéricos no XML.

## Itens raros proporcionais

Além dos reforços abaixo, o [Arsenal de Ascensão](ARSENAL.md) adiciona 28 armas nomeadas por classe, com quatro patamares, dano real crescente, drops e conquista garantida por fragmentos. Use `!arsenal` para consultar a coleção e escolher a próxima arma.

Os drops especiais usam itens existentes: Magic Sword, Magic Longsword, Thunder Hammer, Solar Axe, Royal Crossbow, Warsinger Bow, Wand of Voodoo, Hailstorm Rod, Magic Plate Armor, Golden Helmet, Demon Legs, Great Shield e Golden Boots.

| Reforço | Atributos base | Chance de um item especial por tentativa |
|---|---:|---:|
| I | +10% | Caverna: 0,5% |
| II | +20% | Forja: 0,8%; Cripta: 1% |
| III | +35% | Covil: 1,2% |
| IV | +50% | Soberano: 15% |

São oito tentativas independentes por abate para escolher um dos treze itens; em cada tentativa, a chance de um item específico é a chance da tabela dividida por treze. Essas tentativas especiais não são multiplicadas pelo rate global nem por boosters. A partir do sexto andar, a chance da tabela cresce 10% do valor-base por andar.

Ataque, defesa e armadura são atributos reais da instância; itens normais do mesmo ID não são alterados. Por exemplo: Magic Sword 48/35 → 72/53 no reforço IV; Magic Plate Armor 17 → 26. Não se multiplica novamente um item já reforçado. O desenho é o mesmo, com descrição nativa do reforço.

Wands/rods e distância recebem poder proporcional nas suas fórmulas de dano, usando o melhor bônus equipado, sem somar duas armas. No Knight, o aumento já entra pelos atributos da arma, sem duplicar esse bônus.

O item nasce no corpo, preserva o dono do loot e é reconhecido como raro pelo autoloot. A regra de ignorar continua tendo precedência. A venda geral considera apenas loot identificado desse personagem; a venda por lista permite escolher itens. O patamar IV e raros de chefes reconhecidos permanecem protegidos até uma venda explícita. Veja as condições em [Arsenal de Ascensão](ARSENAL.md).

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

O portal antigo `Bosses` de Premia fica na sala de portais ao sair do templo. Ele leva ao salao das hunts novas; os quatro portais de bosses ficam na fileira inferior, identificados por modelos de Orshabaal, Ferumbras, Morgaroth e Ghazbaran. Exigem level 300 e cada sala tem dois bosses e um portal de retorno ao templo. Os monstros usam as estatisticas e drops originais, com reaparecimento de 150 segundos apos a morte. No mapa original, o portal antes tinha sido ligado por engano a sala de NPCs; a correcao preserva destinos personalizados diferentes desse erro conhecido.

Os portais **Spot 2** são áreas independentes para Caverna Infernal, Forja Abissal, Cripta Ancestral e Covil dos Titãs. Cada um tem sete andares, os mesmos monstros, requisitos e probabilidades do spot original. Os fragmentos e a garantia de loot são compartilhados com a hunt correspondente.

Os spawns registrados de bosses do mapa e de Juggernaut também têm o intervalo reduzido à metade, uma única vez em cada posição; a regra não altera os monstros comuns. As salas dos quatro bosses e do Soberano usam 150 segundos.

### Novas criaturas e andares finais

A partir do quinto andar da Caverna Infernal e seu Spot 2 aparecem **Batedor das Cinzas** (100.000 de vida, hit corporal até 400) e **Carrasco das Cinzas** (180.556, até 700). A partir do quinto andar do Covil dos Titãs e seu Spot 2 aparecem **Guardião das Ruínas** (472.222, até 1.400) e **Devastador das Ruínas** (833.333, até 2.500). Esses valores são antes das defesas e da evolução.

No Trono Infernal, o portal da direita do quinto andar leva ao sexto: há dois **Reis das Cinzas** (2.166.667 de vida cada), dois **Lordes do Abismo** (2.333.333) e dois **Imperadores Infernais** (2.500.000). Os andares sete e oito têm versões com 20% e 40% mais vida e 15% e 30% mais dano corporal. Eles nascem separados e voltam após 150 segundos. Os portais avançam e retornam entre andares; acima da entrada há retorno ao templo. Entrada: level 1.000 e Evolução IV. A dificuldade solo precisa de observação em jogo.

As criaturas novas deixam somente moedas e peças valiosas no loot normal. Os bosses dos três últimos andares podem deixar Magic Plate Armor e Great Shield; as outras criaturas novas podem deixar Demon Armor e Demon Helmet. Os drops especiais e as garantias de armas de Ascensão continuam, independentes do loot global. As chances do loot normal variam com o rate e os bônus do servidor. A limpeza de itens inúteis aplica-se às criaturas novas; os itens possíveis nos drops anteriores foram preservados.

Depois do aumento anterior de vida, a vida atual de animais e monstros foi dividida por 1,8 uma única vez; o multiplicador de vida não altera dano nem experiência por abate. As novas variantes dos últimos andares recebem seus próprios bônus de dano e experiência. O aumento é aplicado uma única vez por arquivo e inclui as variantes geradas, as hunts e os bosses.

O loot normal e as recompensas dos bosses têm oito rolagens independentes por morte, usando as chances e os boosts já existentes. O resultado é em média oito vezes a quantidade anterior, não uma garantia de oito itens específicos em cada morte. Quando o corpo enche, bolsas dentro dele guardam o excedente; o autoloot continua respeitando as exclusões de cada item.

### Hunts no mapa original

Os portais **Groove Perdido** (level 600, Evolução II) e **Domínio da Fumaça** (level 1000, Evolução IV) ficam no salão de hunts. As áreas usam pisos do mapa original, com 12 monstros cada, retorno ao salão e loot de moedas e itens raros. Se a área ou o portal estiverem ocupados em um mapa personalizado, a hunt correspondente fica desativada e o motivo aparece no log.
