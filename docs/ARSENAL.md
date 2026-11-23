# Arsenal de Ascensão

28 armas com nomes próprios, requisitos e atributos individuais, em sete famílias e quatro patamares. Cada etapa acompanha o título de Ascensão da classe. Os sprites, IDs 8.60, itens comuns e mapa existente continuam iguais. As armas novas são variantes nomeadas dos itens clássicos, reconhecidas pelo nome, descrição e atributos; não precisam de outro cliente.

## Poder e requisitos

| Patamar | Level | Evolução mínima | Origem | Fragmentos para escolher uma arma |
|---|---:|---:|---|---:|
| I | 400 | I | Caverna Infernal | 200 |
| II | 600 | II | Forja Abissal / Cripta Ancestral | 250 |
| III | 800 | III | Covil dos Titãs | 300 |
| IV | 1000 | IV | Soberano Infernal | 12 |

A evolução pode ser comprada antes desses levels; a arma é outra conquista. As variantes exigem a classe, level e evolução para equipar e atacar. Podem ser guardadas na mochila e negociadas entre jogadores. Os requisitos também são conferidos a cada ataque, inclusive após perda de level.

| Família / classe | I | II | III | IV |
|---|---|---|---|---|
| Espadas / Knight | Atk 65 / Def 40 | 78 / 44 | 94 / 48 | 112 / 54 |
| Machados / Knight | Atk 72 / Def 35 | 87 / 39 | 105 / 44 | 126 / 50 |
| Martelos / Knight | Atk 69 / Def 39 | 83 / 43 | 100 / 48 | 120 / 54 |
| Arcos / Paladin | Atk 10 | 18 | 28 | 42 |
| Bestas / Paladin | Atk 12 | 21 | 32 | 48 |
| Cetros / Sorcerer | Dano base 98–140 | 129–185 | 168–240 | 217–310 |
| Bastões / Druid | Dano base 94–135 | 126–180 | 164–235 | 210–300 |

Arco e besta somam o ataque à munição. Armas de Paladin também concedem +15% / +30% / +45% / +65% ao dano de distância e magias contra monstros. Cetros e bastões têm a faixa de ataque básico aplicada no motor e os mesmos percentuais nas magias ofensivas PvE. Não aumentam cura. O melhor bônus equipado prevalece; não se somam duas armas e o ataque básico mágico não recebe o percentual de magia novamente. No Knight, o ganho já entra no ataque/defesa reais.

Esses valores precedem skills, magic level, resistências, evolução e maestria. Não representam um hit final garantido nem um teste de equilíbrio concluído. Os bônus de evolução/maestria/poder continuam exclusivos do dano contra monstros; os atributos físicos da arma valem nas fórmulas normais.

## Coleção

| Família | I | II | III | IV |
|---|---|---|---|---|
| Espada | Lâmina do Despertar | Espada do Guardião de Ferro | Lâmina do Cavaleiro Abissal | Espada do Titã da Guerra |
| Machado | Machado do Despertar | Machado do Guardião de Ferro | Cutelo Abissal | Machado do Titã da Guerra |
| Martelo | Martelo do Despertar | Martelo do Guardião de Ferro | Quebraosso Abissal | Martelo do Titã da Guerra |
| Arco | Arco do Atirador Desperto | Arco da Sentinela Real | Arco do Rastreador Astral | Arco do Executor Divino |
| Besta | Besta do Atirador Desperto | Besta da Sentinela Real | Besta do Rastreador Astral | Besta do Executor Divino |
| Cetro | Cetro do Canalizador | Cetro do Piromante | Cetro do Arcanista | Cetro do Arquimago |
| Bastão | Bastão do Naturalista | Bastão do Guardião das Raízes | Bastão do Xamã Ancestral | Bastão do Avatar da Natureza |

Os nomes no protocolo usam letras sem acento, compatíveis com o cliente existente. Espada usa Magic Sword (2400), machado Solar Axe (8925), martelo Thunder Hammer (2421), arco Warsinger Bow (8854), besta Royal Crossbow (8851), cetro Wand of Voodoo (8922) e bastão Hailstorm Rod (2183). Cada instância guarda `jvarmaid=familia:patamar`; não altera o cadastro global do item base.

## Conquista por drop e por fragmentos

Uma segunda rolagem, independente dos treze raros reforçados existentes, pode criar uma arma da coleção no corpo:

| Hunt | Chance de uma arma | Patamar |
|---|---:|---|
| Caverna Infernal | 0,35% | I |
| Forja Abissal | 0,50% | II |
| Cripta Ancestral | 0,75% | II |
| Covil dos Titãs | 1% | III |
| Soberano Infernal | 12% | IV |
| Demon comum | 2% | I |
| Juggernaut comum | 5% | II |

A rolagem escolhe uma das sete famílias com igual chance e não é multiplicada pelo loot global de 100×. Pode cair arma de outra classe para troca. O drop no corpo respeita as regras existentes de dono e coleta.

As armas de Demon e Juggernaut seguem os requisitos da tabela: por exemplo, uma arma I pode cair antes do level 400, mas só pode ser equipada a partir do level 400 e Evolução I. Essas mortes não dão fragmentos de hunt. Invocações de jogadores não dão o drop especial.

Cada abate qualificado também dá um fragmento individual do patamar da hunt. Participantes vivos da party a até 20 tiles e no mesmo andar recebem progresso; líder duplicado e personagens distantes não recebem duas vezes. Não é necessário shared experience. Monstros invocados por jogadores não concedem progresso. O patamar IV é conquistado exclusivamente no Soberano. Fragmentos ficam salvos em storages separadas (79610–79613), não ocupam mochila e não são convertidos entre patamares.

`!arsenal` abre o catálogo nativo da própria classe, com saldo, requisitos, origem, poder e comando de cada arma. Exemplo: `!arsenal resgatar, cetro, 4`. Famílias: `espada`, `machado`, `martelo`, `arco`, `besta`, `cetro`, `bastao`. O resgate exige os fragmentos, requisitos e mochila equipada com espaço/capacidade; cobra somente após entregar a arma, sem jogá-la no chão. Assim há uma meta de conquista mesmo quando o drop não vem.

O autoloot reconhece as armas como raras; a venda protege o patamar IV e variantes com marca antiga de raridade. A lista de ignorados prevalece. Como os sprites/IDs são compartilhados, filtros por ID e hotkeys identificam a família clássica, não distinguem cada nome/patamar. Para trocar a variante equipada, use a mochila normalmente.

## Venda por lista

`!venderloot tudo mochila` ou `!venderloot tudo depot` vende em lote apenas itens marcados pelo autoloot desse personagem após esta atualização, sem exigir lista. Itens equipados, recipientes, moeda, loot de outro jogador e itens sem marca não são vendidos na venda geral. Loot identificado sem preço cadastrado vale 100.000 moedas por unidade. Itens do patamar IV e drops raros reconhecidos de chefes continuam protegidos; itens raros com marcas antigas também são preservados porque não registravam a origem. Não é possível incluí-los na venda geral. Itens antigos ou apanhados manualmente podem não ter identificação e continuam guardados; a venda por lista permite selecionar itens com preço cadastrado. Raros protegidos selecionados podem ser vendidos pelo preço cadastrado ou, se não houver preço, por 100.000 moedas cada.

Adicione itens com `!venderloot add, nome` ou pelo menu do item; `!venderloot lista` mostra a seleção e `!venderloot remover, nome` a altera. `!venderloot mochila` e `!venderloot depot` vendem apenas os itens selecionados e com preço do Mercador Ze, inclusive dentro de bolsas aninhadas; depot usa o da cidade do personagem. A lista vazia não vende nada. O dinheiro vai para o banco, com intervalo de 60 segundos entre vendas bem-sucedidas.

Itens de patamar IV e raros protegidos ficam guardados mesmo se o ID estiver na lista. Para incluí-los apenas na venda atual, o jogador pode escrever `!venderloot mochila raros` ou `!venderloot depot raros`. Esses itens recebem o preço base do Mercador ou 100.000 moedas se não houver preço, sem valor adicional pelos bônus. Itens antigos não necessariamente têm marca de raridade: mantenha-os fora da lista se não quiser vendê-los. A lista identifica o ID base compartilhado, não cada variante individual.

## Validação e atualização

Regras editáveis: `data/lib/jv_arsenal.lua`. Comandos/resgate: `data/scripts/custom/jv_arsenal.lua`. O patch nativo 0007 valida equipamentos e faz wands/rods usarem a faixa de dano da variante, mantendo as armas normais com suas fórmulas originais. Inclui leitura/remoção compatível com chaves de atributos antigos em caixa mista. A atualização exige recompilar o servidor pelo instalador; copiar apenas Lua é insuficiente.

Testes executáveis:

```bash
python -m pip install lupa==2.6
python -c "from pathlib import Path; from lupa.lua51 import LuaRuntime; LuaRuntime().execute(Path('testes/teste_arsenal.lua').read_text())"
python testes/preparar_servidor_testes.py /tmp/servidor-progressao
python testes/teste_arsenal_motor.py /tmp/servidor-progressao
python testes/teste_ascensao_arquivos.py /tmp/servidor-progressao
```

Os testes cobrem as 28 variantes, requisitos, bônus por origem de dano, perda de level, resgate sem duplicação, falhas de capacidade/criação, fragmentos por patamar, dupla e proteção da venda em lote. O teste C++ compila as funções reais extraídas do código com os patches e confere o dano básico de wand/rod, requisitos e atributos. Também conferimos os IDs/tipos no XML da base fixada. Esses checks não substituem uma hunt real com personagens e equipamentos representativos para ajustar a dificuldade final.
