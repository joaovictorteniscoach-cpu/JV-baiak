# Controles do cliente web

Revisão construída sobre o acabamento visual do PR #3 (22e7b8a), preservando sua arte.

- Impede iniciar duas vezes o runtime com cliques/toques repetidos em Jogar.
- Valida os valores salvos de zoom e limita a escala a 60–200%. A+/A− escolhem o próximo passo correto, inclusive depois de ajustar por pinça.
- Restaura o padrão da orientação atual: 80% em pé, 100% deitado. Mantém preferências separadas.
- Usa botões nativos e um único evento click para evitar a dupla ativação touchend/click. O bloqueio de gestos do jogo permite os toques desses botões.
- Ao fechar o teclado, devolve o foco ao canvas; abrir o teclado fecha o painel.
- Encerra a pinça ao receber touchcancel e ignora distância inicial zero.
- Tela cheia nos navegadores com requestFullscreen. Sem suporte, o botão não aparece. Se o pedido for recusado, mostra uma orientação breve.
- Painel com estado acessível, áreas de toque mínimas e rolagem em telas baixas. O primeiro toque no canvas fecha o painel.
- Após aborto do runtime, esconde Jogar para não reiniciar uma instância inválida.

Validação: `node testes/teste_controles_web.cjs` executa a lógica real do shell num ambiente isolado, cobrindo limites/passos/reset do zoom, orientação, início único, painel, teclado, ausência de fullscreen e cancelamento da pinça. Navegador: abrir Jogar, abrir opções e A+ de 100% para 115% conferidos numa fixture sem WASM ou conexão ao jogo.

Não houve teste de combate, caminhada, latência, reconexão ou teclado físico/iOS com o runtime compilado. É necessário reconstruir a etapa final web e testar no Safari e Android reais antes de anunciar essas funções como validadas em produção. Mapa, respawn, experiência, loot, combate, backend e clientes nativos não foram alterados. Não publicado na Oracle.

Integração: PR de jogabilidade baseado na branch do PR #3; integrar primeiro nesta branch e depois integrar o PR #3 em main, ou rebasear sobre main após a integração do visual.

Revisão adicional: corrigido TOUCHCANCEL no tradutor C++ (inclusive evento sem pontos e pinça cancelada). Os cinco patches foram aplicados sequencialmente ao OTClient fixado em 1fcea26f. A função real handleTouchCallback, extraída dessa fonte com os patches, foi compilada com g++ e passou em cenários de toque curto, segurar, arrastar, cancelamento, pinça e coordenadas. Não equivale a compilar o WASM completo. Os 45 testes Python existentes passaram. CI separado adicionado para controles e tradutor de toque.
