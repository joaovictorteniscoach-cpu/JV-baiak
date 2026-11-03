# JV Baiak — mapa, chat e toque no celular

## Como aplicar

1. Baixe `celular.sh` e envie pelo botão **Fazer upload do arquivo** no SSH.
2. Execute apenas:

```bash
bash celular.sh
```

3. Aguarde **ATUALIZACAO CONCLUIDA**, feche e reabra o jogo.
4. Confira `https://bayakjh.duckdns.org/jogar/versao-cliente.txt`: deve aparecer `toque-v5`.

O código no GitHub não altera o servidor automaticamente. O script é a etapa que publica a atualização. A revisão usada está fixada dentro de `celular.sh`.

## O que mudou

- **Em pé:** equipamento e outros painéis laterais começam recolhidos, deixando a largura disponível para o mapa. Abra pelo menu ☰ e use **Voltar ao mapa** para recolher novamente.
- **Chat e ações:** o chat fica acima de uma faixa própria para os quatro atalhos originais. Em paisagem, permanece o painel lateral tradicional.
- **Área segura:** a janela do jogo respeita as margens informadas pelo iPhone e acompanha a altura dinâmica da tela. Os botões do teclado também respeitam a margem superior.
- **Precisão:** o toque continua convertido a partir do retângulo real do canvas e do tamanho de renderização. O mapa mantém proporções de quadrados. Não há um deslocamento arbitrário adicionado ao clique.
- **Toque longo:** mantém a correção que abre o menu sem mandar caminhar primeiro.
- **Mostrar toque:** opção de diagnóstico desligada por padrão; azul é o dedo, amarelo é o quadrado recebido. Ela não captura cliques nem envia dados para terceiros.

## Conferência no aparelho

Teste em pé e deitado: caminhar para quadrados próximos, abrir uma mochila, abrir o equipamento e voltar ao mapa, digitar no chat e segurar o dedo para o menu. Os atalhos principais mantêm pelo menos 44 pixels CSS na escala mobile normal.

Se houver desvio, ative **☰ → Mostrar toque**, toque no chão e tire uma foto com as marcas visíveis. Se as marcas coincidirem, mas o personagem não alcançar o destino, precisamos distinguir a posição escolhida de obstáculos e regras de caminhada do mapa.

## Arquivos da atualização

- `web/shell.html`: área segura, altura dinâmica, versão do cache e botão Voltar ao mapa.
- `web/otclientrc-extra.lua`: painéis sob demanda e posição dos atalhos.
- `web/patches-final/0012-retrato-chat-acima-dos-atalhos.patch`: reserva da faixa inferior no cálculo do mapa e do chat.
- `web/instalar-correcao-toque-v5.sh`: migração das versões conhecidas, cópia de segurança e recompilação.
- `testes/`: testes Lua, JavaScript, instalação com restauração e teste dos quadrados nos navegadores.
- `.github/workflows/web-teste.yml`: uma montagem compartilhada; Chromium em Linux e WebKit em macOS.

## Cópia de segurança e recuperação

O script cria uma cópia do cliente e dos arquivos substituídos em `/opt/jvbaiak/backups/iphone-v5-DATA-HORA`. Uma falha de compilação ou verificação aciona a tentativa de restauração. Ele interrompe antes da cópia se encontrar arquivos de origem desconhecidos, uma compilação ativa ou espaço insuficiente.

O procedimento preserva banco de dados, contas, personagens, sprites e mapa. Caso o SSH desconecte, a execução continua no serviço que o próprio script informa; copie o comando de consulta mostrado no terminal para acompanhar depois.

## Testes e limites

A validação no aparelho real continua necessária. WebKit em macOS é uma verificação adicional e não reproduz todos os gestos, o teclado e as barras do Safari no iPhone. O teste de coordenadas usa os retângulos fornecidos pelo renderizador nativo, toca no centro deles e compara as posições mundiais recebidas. Também simula margens conhecidas para testar o canvas afastado da borda da página.

### Resultado registrado

Revisão fixada: `e5bc39a1984cf1217b601ec7bb119086aa72b547`.

- **61 testes locais aprovados**, além das verificações do C++ de entrada/realce e dos ajustes Lua.
- [Controles no GitHub: aprovado](https://github.com/joaovictorteniscoach-cpu/JV-baiak/actions/runs/41564493901).
- [Compilação completa: aprovada](https://github.com/joaovictorteniscoach-cpu/JV-baiak/actions/runs/41564493959).
- [Jogo nos dois motores: aprovado](https://github.com/joaovictorteniscoach-cpu/JV-baiak/actions/runs/41564494246): **25 toques corretos no Chromium e 25 no WebKit/macOS**, incluindo margens simuladas, rotação e abertura/fechamento do equipamento. No Chromium também foi conferido o toque longo sem caminhada indevida; o WebKit não executa os cenários que exigem CDP.
- No modo retrato testado, o mapa passou de 102 para **278 unidades lógicas de largura**, a largura disponível nesse perfil. O chat terminou em y=560 e a faixa de ações começou em y=560, sem interseção entre as duas áreas.

A validação confirma o cliente nesta configuração de teste; ainda é preciso executar `celular.sh` e conferir no iPhone. Na última consulta feita durante este trabalho, o servidor público ainda informava `login-v3`.
