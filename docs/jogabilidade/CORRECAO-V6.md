# Correção v6 — proporção, zoom e controles

A versão anterior bloqueava zoom abaixo de 100% no celular, mantinha a coluna lateral aberta em paisagem e não permitia fechá-la nessa orientação. O chat também reservava espaço para os quatro atalhos apenas em retrato.

## Comportamento

- Zoom mínimo de 60%; início em 70% deitado e 80% em pé. O limite máximo considera a área real do canvas, incluindo os recortes da tela, até 200%.
- A− e A+ alcançam os dois limites e ficam desabilitados ao alcançá-los. A pinça respeita os mesmos limites. As preferências continuam separadas por orientação e funcionam durante a sessão se o armazenamento local estiver bloqueado.
- A preferência móvel usa uma nova chave para não reaplicar automaticamente a escala grande da versão anterior. As preferências do desktop permanecem iguais.
- Equipamento, minimapa e combate abrem pelo menu; “Voltar ao mapa” fecha a coluna tanto em pé quanto deitado. Girar não reabre o painel.
- Chat compacto em janelas baixas e faixa exclusiva para os atalhos em ambas as orientações. A razão de aspecto do mapa continua preservada pelo cliente.
- Scroll usa a posição atual do ponteiro, aceita coordenada zero e copia os dados antes de enfileirar a ação. Evita usar o evento temporário do navegador depois do callback.
- Revisão `toque-v6` no HTML e nos recursos. O instalador versiona também o carregamento de `otclient.js`.

## Validação

- Controles reais do shell executados em Node: zoom, armazenamento bloqueado, limites entre passos, área segura, orientação, menu, atalhos, teclado e cancelamento da pinça.
- C++ real extraído da fonte fixada, compilado com `g++ -Wall -Wextra -Werror`: toque curto, toque longo sem caminhada, arraste, cancelamento, pinça, coordenadas e scroll com evento reutilizado antes de executar a fila.
- Lua real executado com Lupa: reserva de chat/atalhos, estabilidade do layout, painéis sob demanda nas duas orientações, login e aplicação atrasada da escala HUD.
- Conversão de coordenadas e realce do tile conferidos com offsets do canvas, buffer DOM obsoleto, diferentes zooms e densidades.
- 20 testes de instaladores, incluindo instalação v6, rejeição de fonte incompatível e restauração dos arquivos e do cliente após falha.
- Todos os 14 patches finais aplicados em sequência à fonte fixada do OTClient.
- Prévia local no Chromium com o WASM publicado e os Lua atualizados: login em 844×390 e 390×844, A− de 70% a 60%, restauração e rotação. A geometria nativa mudou de 1205×557 para 1406×650 ao reduzir e para 487×1055 ao girar; a imagem não foi apenas esticada por CSS. Essa prévia não inclui a recompilação da correção C++ de scroll. Os assets publicados registram erros preexistentes em shaders opcionais; não foram alterados nesta correção.

A compilação completa do WASM é verificada pelo workflow `Validar compilacao final do cliente web`, agora também em pull requests. Os testes isolados não substituem teste de caminhada, combate e inventário com um personagem conectado em Safari/Android reais.

## Aplicar no servidor existente

Usar uma cópia separada deste repositório contendo a correção e executar nela:

```bash
sudo bash web/instalar-correcao-toque-v6.sh bayakjh.duckdns.org
```

O instalador valida a versão instalada, cria backup em `/opt/jvbaiak/backups/iphone-v6-*`, recompila o cliente e restaura a versão anterior se falhar. Ele exige a instalação existente em `/opt/jvbaiak`; `BASE` permite outro caminho. Não há migração de banco.

Após instalar: recarregar o jogo e conferir A−/A+, pinça, rotação, abrir/fechar equipamento, mapa sem deformação, toque no tile central e nos cantos, toque longo sem caminhada, chat e ações sem sobreposição. Os ícones também diminuem ao reduzir o zoom da interface; A+ permite recuperar um tamanho confortável.

A correção no GitHub não publica automaticamente na VPS. É necessário executar o instalador no servidor.
