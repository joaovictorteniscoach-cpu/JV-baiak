# iPhone: correção de toque e proporção v2

A primeira atualização não resolveu o toque. A versão publicada usa OffscreenCanvas:
o elemento HTML pode permanecer em 300 x 150 enquanto o renderizador desenha com
outras dimensões. A correção anterior lia `canvas.width/height` no DOM; isso era
uma referência incorreta nesse modo. O JavaScript publicado confirmou essa fórmula.

Agora o DOM fornece somente a posição relativa no retângulo visível. O C++ usa
`m_size`, a mesma dimensão passada ao redimensionamento do jogo, e aplica a escala
HUD uma vez. Mouse e toque seguem essa conversão. A função auxiliar de movimento
copia os valores antes de enfileirar o evento, sem reter o ponteiro do navegador.

O mapa mantém a proporção e ajusta quantas linhas/colunas mostra, com limites de
15 x 11 e dimensões ímpares. O chat permanece acoplado; a coluna vazia da esquerda
fica oculta. A escala inicial mobile independe do DPR, com slots de 32 px ocupando
44,4 pontos CSS e os quatro atalhos ocupando 47,2 pontos CSS, em uma faixa de 42 pixels logicos. O zoom mobile não
reduz abaixo dessa escala. Equipamento, minimapa, combate e opcoes sao paginas laterais exclusivas, acessiveis pelo menu HTML. Os botoes novos de combate/minimapa e os icones de opcoes usam pelo menos 32 pixels logicos (44,4 pontos CSS); controles pequenos do equipamento ficam na pagina Combate. Esses tamanhos não comprovam que todos os botões
auxiliares das janelas antigas já tenham 44 pontos: ainda precisam de auditoria
visual no aparelho. Os controles HTML têm área mínima de 44 pontos.

A atualização também troca as URLs dos assets para impedir a mistura de JavaScript,
WASM e dados antigos com o HTML novo. Não apaga contas nem preferências salvas.

## Aplicar

Envie `toque.sh` pelo botão Fazer upload do arquivo no SSH. Execute:

```bash
bash toque.sh
```

O iniciador baixa uma revisão fixa do repositório e roda o instalador v2 em um
serviço independente do SSH. O instalador confere a base, os patches anteriores
e o hash do shell instalado. Faz backup do cliente e dos arquivos alterados;
em falha da compilação, tenta restaurá-los. A instalação esperada é `/opt/jvbaiak`.

Espere `ATUALIZACAO CONCLUIDA`. A versão pública pode ser conferida em
`https://bayakjh.duckdns.org/jogar/versao-cliente.txt`: deve mostrar
`toque-v2-offscreen`. Feche e reabra o jogo antes de testar. No menu ☰, use Equipamento, Minimapa, Combate e Opções do jogo para alternar a coluna lateral. Os atalhos Atacar/Seguir/Olhar/Usar ficam em uma linha reservada abaixo dela.

## Validação

- Testes executam o JavaScript real do helper com DOM 300 x 150, offsets, retrato,
  paisagem e várias escalas. Esse caso estava ausente na primeira validação.
- Teste C++ compila o helper real, substituindo somente a chamada ao navegador,
  e verifica densidades HUD e captura das coordenadas no toque.
- Teste Lua executa o layout real para tamanhos e barras diferentes, idempotência,
  proporção, chat fixo e comportamento de desktop.
- Workflow de compilação final baixa a base publicada, aplica todos os patches
  e gera WASM com sprites fictícias. É teste de compilação, não de jogabilidade.
- Ainda é indispensável validar no iPhone físico: cantos, slots, poções, atalhos,
  buracos/escadas, rotação e teclado. Não houve acesso SSH direto ao servidor.
