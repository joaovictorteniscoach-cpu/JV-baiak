# Atualização de toque — JV Baiak

Envie `toque4.sh` pelo botão **Fazer upload do arquivo** no SSH. Execute:

```bash
bash toque4.sh
```

Aguarde **ATUALIZACAO CONCLUIDA**. O processo continua mesmo se o SSH desconectar. O próprio comando mostra como consultar o andamento depois.

## Alterações

- O realce do mapa usa a mesma posição lógica do clique, sem dividir e multiplicar novamente a escala e acumular arredondamentos.
- Segurar o dedo por 450 ms abre o menu sem mandar o personagem caminhar antes. Toques mais curtos continuam sendo cliques comuns.
- No menu ☰, **Mostrar toque** desenha um círculo azul no ponto do dedo e um retângulo amarelo no quadrado recebido pelo cliente. Os marcadores não capturam toques, ficam desligados por padrão e não enviam dados a terceiros.
- Os arquivos do cliente usam a identificação `toque-v4`, para separar o cache desta atualização.

## Conferência no iPhone

Feche e reabra o jogo. Confira um toque curto em um quadrado próximo, depois segure o dedo para abrir o menu e gire o aparelho.

Se o desvio persistir, ative **☰ → Mostrar toque**, toque uma vez no chão e tire uma foto enquanto as duas marcas estiverem visíveis. Essa foto permite comparar o ponto exato do dedo, o quadrado calculado e a imagem do mapa. É necessária uma validação no aparelho real: testes automatizados não substituem o Safari do iPhone.

## Instalação e restauração

O instalador confere os arquivos existentes, cria uma cópia do cliente anterior em `/opt/jvbaiak/backups/iphone-v4-DATA-HORA` e recompila o cliente web. Se a compilação ou a verificação falhar, tenta restaurar os arquivos e o cliente anterior. Alterações desconhecidas feitas por outra ferramenta interrompem a instalação antes de substituir arquivos.

A atualização não troca o banco de dados, mapa, personagens ou sprites. Ela só modifica o cliente web.

## Testes

A suíte de controles executa o código C++ de entrada e de realce, os ajustes Lua e a instalação com restauração simulada. O teste com navegador usa os retângulos de quadrados fornecidos pelo renderizador nativo, toca no centro deles e compara as posições mundiais recebidas pelo jogo. Também verifica orientação, zoom e o menu de toque longo. Os cenários disponíveis diferem entre Chromium e WebKit.

A correção de arredondamento do realce, isoladamente, não demonstra a causa de um deslocamento grande no iPhone. Os marcadores servem para medir esse caso se ele continuar ocorrendo.

### Resultado desta revisão

Código fixado no instalador: `59b97b392c04da50bbf65709d5844a6bea44d3a9`.

- Controles e instalação: aprovados no [workflow de controles](https://github.com/joaovictorteniscoach-cpu/JV-baiak/actions/runs/41561706054).
- Compilação completa do código do cliente: aprovada no [workflow de compilação](https://github.com/joaovictorteniscoach-cpu/JV-baiak/actions/runs/41561485247). A revisão posterior só alterou os testes.
- Chromium: 15 toques nos quadrados desenhados, cobrindo paisagem, zoom e retrato; menu de toque longo sem clique de caminhada; marcadores conferidos. O [workflow com os dois motores](https://github.com/joaovictorteniscoach-cpu/JV-baiak/actions/runs/41561706046) mostra esse job aprovado.
- WebKit: falhou antes de obter as medidas nativas do login; a imagem ficou preta. Esse resultado não valida o Safari do iPhone. O job continua registrado como falha, sem esconder a limitação.

As fotos e os registros estão nos ramos `testes-chromium` e `testes-webkit` do repositório. Os marcadores e a foto no aparelho ainda são necessários se o deslocamento grande persistir.
