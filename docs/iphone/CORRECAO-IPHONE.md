# Correção de chat, atalhos e toque no iPhone

Base: main 7a744b3a6fd83bec01b9d5c91c345f04db7d2d3e.

Causas encontradas no código:
- show() força o modo de visão estendido no celular. Esse modo preenche o fundo com o mapa e permite chat/barra flutuantes por cima dele.
- A posição de toque era multiplicada por uma escala calculada, enquanto o movimento do mouse usava coordenadas da janela. Não se levavam em conta o retângulo real do canvas e o arredondamento do buffer após resize/zoom.

Correções:
- No mobile, modo 2 (estendido) é convertido para modo 1 (acoplado), inclusive preferências antigas. Mapa termina acima da faixa inferior; chat fica na base da faixa, com hotbars acima dele. Não há deslocamento livre do chat nem do separador no celular.
- Altura inferior considera quantidade de hotbars e barra de status; desktop mantém seu comportamento.
- Mouse e toque usam clientX/clientY menos a origem real do canvas, multiplicados pela proporção real buffer/retângulo CSS. Depois se aplica a densidade da UI uma vez. A posição é copiada antes de entrar na fila de eventos.
- Clique de mouse tem sua própria posição, inclusive borda zero, sem depender do último mousemove.
- Nenhuma mudança em mapa, personagem, combate, banco, rates, sprites ou servidor de jogo.

Testes locais: 45 testes Python anteriores; controles JavaScript; função C++ real de toque com dependências mínimas; JavaScript real da ponte C++ para coordenadas (offset, 6 escalas, duas orientações, bordas e buffer arredondado); Lua real de layout com widgets simulados, variação de altura/hotbars e preferência de modo estendido. Conferência dos patches na fonte fixa do OTClient. Os testes não são renderização do jogo completo e não substituem Safari físico.

## Publicação pelo próprio João

Não é necessário usar o Claude. Sem acesso SSH à Oracle e sem Docker no ambiente do Codex, o build completo e a publicação devem rodar na VPS.

No SSH da Oracle, baixar esta revisão para uma pasta separada e executar o atualizador. Usar o SHA indicado na entrega para fixar o checkout. Não executar instalar.sh, jvbaiak atualizar nem trocar o mapa para aplicar esta correção.

```bash
git clone --branch codex/iphone-layout-toque --single-branch https://github.com/joaovictorteniscoach-cpu/JV-baiak.git /tmp/jvbaiak-correcao-iphone
sudo systemd-run --unit=jvbaiak-iphone-fix --description="JV Baiak: corrigir chat e toque no iPhone" /bin/bash /tmp/jvbaiak-correcao-iphone/web/instalar-correcao-iphone.sh bayakjh.duckdns.org
sudo journalctl -fu jvbaiak-iphone-fix
```

Se a pasta temporária ou a unidade já existir, usar outro nome em vez de apagar trabalho anterior. `Ctrl+C` sai da visualização do log sem encerrar a unidade de compilação. O script exige /opt/jvbaiak por padrão, comparação da base e dos cinco patches já instalados, backup do cliente antigo e espaço disponível. Adiciona apenas os patches 0006/0007 e chama o compilador web existente. Em falha de build/verificação tenta restaurar o cliente e os patches anteriores. O script teve sintaxe verificada; execução real na Oracle permanece pendente.

Ao terminar, fechar a aba antiga do jogo e abrir /jogar/ novamente. Validar no iPhone: chat na faixa inferior; botões fora do mapa; toque correto nos quatro cantos, chão, buraco/escadas, itens; arrastar, segurar, zoom e girar a tela. Se o script parar por divergência dos arquivos instalados, não ignorar a verificação: registrar o erro para comparar a instalação. Não divulgar .env, chaves ou senhas.
