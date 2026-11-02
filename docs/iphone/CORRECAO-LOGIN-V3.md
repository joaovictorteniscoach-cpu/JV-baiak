# Login responsivo no iPhone — v3

O formulario do OTClient de servidor unico tem largura nativa de 380 pixels. O
perfil mobile original aplica HUD Scale 1,5 com atraso de 250 ms. Na v2 o canvas
mobile usava fator 0,72 para aumentar os controles: as duas escalas tambem
ampliavam o login, que podia ultrapassar 790 pontos CSS e ficar cortado.

A v3 separa as fases: canvas mobile em resolucao CSS, HUD 1 no login e HUD 1,4
no jogo. As preferencias antigas de HUD nao ampliam mais o login; o callback
atrasado consulta o estado atual da conexao para nao reduzir o HUD depois de
entrar no mundo. Os controles de jogo de 32 pixels logicos ocupam 44,8 pontos CSS.
A conversao de toque continua baseada no tamanho real do renderizador.

O formulario tem largura ate 360 pontos, limitada a tela menos 24. Conta, Senha e
Entrar tem altura 44. O layout curto oculta temporariamente as duas preferencias
quando a altura disponivel e menor que 360, sem desmarcar seus valores nem apagar
conta/senha salvas. O formulario mantem os campos nativos e o fluxo de autenticacao.

Aplicar por upload de `login.sh`, depois `bash login.sh`. O instalador aceita os
hashes das versoes anteriores conhecidas, faz backup e tenta restaurar em erro.
A versao publicada passa a `login-v3` em `/jogar/versao-cliente.txt`. Todas as URLs
de JS/WASM/dados recebem a versao nova para evitar misturar arquivos antigos.

Validacao: testes Lua do formulario e do callback real de HUD, regressao de toque,
testes do instalador e compilacao final do cliente. O teste de navegador mede os
retangulos nativos dos campos, verifica se cabem em retrato e paisagem e exige a
entrada efetiva no jogo. Falhas desse teste agora fazem o workflow falhar.
A confirmacao do teclado e do toque no Safari fisico continua necessaria.
