# Atualização de jogabilidade — visual preservado

Esta atualização mantém os sprites, o mapa, os ícones e a organização da interface.

- **Parar**, na janela Combate, desliga a caça e as magias automáticas de ataque antes de cancelar ataque/perseguição. O personagem não volta a atacar sozinho no próximo ciclo. Para retomar, ligue a espada. Auto cura e auto pot continuam independentes.
- **Cura/auto pot**: o botão usa o estado confirmado pelo servidor, aguarda a resposta ao clicar e limpa o estado ao trocar de personagem. Cliques repetidos durante a espera não enviam outra alternância.
- **Autoloot**: exclusões por item ficam salvas no personagem e prevalecem sobre dinheiro, raros, caros, lista e envio ao depot. As categorias e a lista antiga continuam funcionando.
- **Poções infinitas**: a atualização define `removeChargesFromPotions = false` uma vez na instalação existente. Vale para uso manual e auto pot, mantendo a necessidade de possuir a poção, os requisitos de vocação/nível e os intervalos. Não altera regras de runas ou munição.

## Atualizar pelo SSH

Na VPS que já está instalada em `/opt/jvbaiak`, execute:

```bash
sudo jvbaiak atualizar
```

O comando existente faz backup e atualiza a partir da `main` do GitHub. O servidor precisa reiniciar para carregar os scripts novos, e o cliente web é recompilado em segundo plano. A instalação preserva contas, personagens e o mapa existente. Não use os arquivos antigos `jv8.txt` ou `opcao2.txt`: eles apontam para outras revisões.

Andamento: https://bayakjh.duckdns.org/jogar/atualizacao.txt

## Ignorar e permitir itens

Use o chat existente; nenhuma janela foi redesenhada:

```text
!loot ignorar, royal helmet
!loot ignorar, 2498
!loot ignorados
!loot permitir, royal helmet
```

Os dois primeiros são alternativas para o mesmo item. `permitir` retira a exclusão; a coleta volta a depender das categorias e da sua lista. A lista de ignorados aceita até 100 itens por personagem. `!autoloot remove` continua retirando apenas da lista antiga e não cria uma exclusão.

## Conferência após atualizar

Reabra o jogo para carregar o cliente novo. Com auto ataque ligado, use Combate > Parar e confira que ele não volta a atacar; religue a espada para retomar. Confira que auto pot continua ativo se já estava ativo. Troque de personagem e aguarde o estado confirmado do botão de cura. Ignore um item caro/raro, confira que fica no corpo e use `permitir` para restaurar a regra anterior. Teste uma poção manualmente e outra pelo auto pot; a quantidade não deve diminuir.

## Testes do código

```bash
lua5.1 testes/teste_jogabilidade.lua
python -m unittest discover -s testes -p 'teste_instalador_*.py'
node testes/teste_controles_web.cjs
```

Os testes de jogabilidade executam os módulos Lua reais com dependências controladas. Não substituem a conferência no aparelho e no servidor depois da atualização.
