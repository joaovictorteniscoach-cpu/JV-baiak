# Opção 2 — janelas flutuantes e autoloot (v7)

A disposição escolhida usa o cenário por trás das janelas, uma única faixa inferior de atalhos e uma barra sempre visível para Equipamento, Bolsas, Combate, Minimapa, Chat, Autoloot, Opções e Atalhos. Em retrato, a barra ocupa duas linhas para manter os oito botões acessíveis.

Equipamento, chat e minimapa mantêm os widgets reais do cliente, dentro de janelas móveis com fechar e minimizar. As bolsas mantêm as janelas nativas de contêiner: abrir, fechar, mover itens, arrastar e abrir bolsas internas continuam no protocolo do jogo. As posições são salvas por personagem e orientação e as janelas são mantidas dentro da tela ao girar. O chat começa minimizado e pode ser expandido pelo título ou reaberto na barra.

Vida e mana usam duas barras compactas com valores atualizados pelos eventos reais do jogador. O zoom inicial do cenário passa de uma referência de 15×11 para até 17×13 tiles: o personagem fica aproximadamente 12% menor em largura nas telas deitadas testadas, sem diminuir a escala dos botões. A área visível continua limitada pelo mapa recebido do servidor 8.60. O mapa preenche sua janela com recorte uniforme, mantendo tiles quadrados.

## Autoloot

A janela consulta o servidor e permite buscar por nome/ID e escolher Recolher ou Ignorar. Usa as storages já existentes de autoloot do personagem. Itens fora da lista não são coletados. Fechar a janela não desativa a coleta. A lista é confirmada pelo servidor, não presumida pelo cliente.

O novo comando interno `!jvloot` responde apenas ao próprio jogador via extended opcode 204. Valida nomes/IDs, lista cheia e duplicação. Ignorar uma moeda desliga o modo antigo de depósito automático de todas as moedas no banco, para que a moeda ignorada não continue sendo coletada por essa regra paralela. As outras preferências de coleta permanecem na lista. Não cria itens, não muda loot rate, não altera a rotina de cadáveres, propriedade, capacidade ou transporte dos itens.

Não há migração de banco. Os comandos antigos `!autoloot` continuam disponíveis e usam as mesmas storages.

## Instalação na VPS existente

Usar uma cópia separada desta revisão do repositório e executar:

```bash
sudo bash web/instalar-correcao-toque-v7.sh bayakjh.duckdns.org
```

O instalador faz backup e restauração automática em caso de falha; reconhece os arquivos anteriores conhecidos e recusa alterações locais não reconhecidas. Atualiza o cliente e copia somente o novo script de configuração do autoloot para `servidor/data/scripts/custom/jv_autoloot_ui.lua`. O script fica legível pelo usuário do processo TFS.

Para ativar esse novo comando no servidor, é necessário `/reload scripts` com GM ou `jvbaiak reiniciar` em uma janela de manutenção. O instalador não reinicia o servidor automaticamente. O servidor confirma suporte ao entrar com o personagem. Até ativar o script e reconectar, a janela avisa que a configuração não está disponível e não envia comandos ao chat. A atualização não troca mapa, contas, personagens, config.lua nem a rotina de coleta existente.

O ambiente desta tarefa não tem SSH para a VPS; alterações no GitHub não publicam o cliente no endereço do jogo.

## Validação

- JavaScript do shell: zoom, limites, área segura, oito atalhos e entrada/saída da barra.
- Lua real das janelas: fechar, reabrir, minimizar, posições por personagem, reconexão e confirmação do estado de autoloot.
- Seis testes do configurador real do servidor com storages isoladas: seleção persistente, personagens independentes, duplicação, lista cheia, entradas inválidas, escape JSON e prioridade de ignorar moedas sobre depósito no banco.
- 25 testes dos instaladores, incluindo cópia/restauração do script de autoloot, recusa de arquivo customizado e permissão de leitura pelo TFS.
- Os 15 patches finais aplicados em sequência sobre a fonte fixada. Regressões C++ de toque/scroll, conversão de coordenadas, login e HUD.
- Prévia nativa local conectada ao servidor com a conta de QA autorizada, utilizando WASM publicado e Lua atualizado: controles nas duas orientações e fechar/reabrir/minimizar janelas. O transporte do painel autoloot é substituído por uma resposta local somente nessa prévia; não foi feita alteração da lista de loot no servidor publicado.

O configurador novo ainda precisa de validação dentro da VPS após ser carregado. Os testes isolados não comprovam coleta de um cadáver em hunt real, nem todos os gestos em Safari/Android físicos. A compilação completa é verificada pelo GitHub Actions do PR.
