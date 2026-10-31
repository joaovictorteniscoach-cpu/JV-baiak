# Portal clássico · revisão de 31/10/2026

Base: `e7389be002293fc112d605c0456e62feb1ff682a` (última versão de main consultada).

## O que foi mantido do trabalho do Claude

Conta e sessão, login Google, criação de personagens, rankings, jogadores online, guilds, casas, mortes, leitura de rates e eventos. O cliente web, a compilação WASM e a infraestrutura Oracle não foram alterados.

## Alterações

- Cabeçalho com arte de Tibia, navegação lateral tradicional, ícones locais, painéis de pergaminho e quatro vocações. O menu se reorganiza em telas pequenas; não exige JavaScript.
- Textos da home reduzidos, mantendo eventos, ranking e informações dinâmicas. A disponibilidade dos clientes é consultada em Downloads.
- Nome corrigido para **Carnacini Soubihe** no padrão da aplicação. Se uma instalação personalizou `FAMILIA` no ambiente, ela prevalece.
- Bloqueios de criação/login agora retornam HTTP 429, `Retry-After` em segundos e os minutos restantes na mensagem. Expiração liberada no instante exato do fim da janela.
- Mantida a correção anterior: erros de validação não consomem a cota de criações; senhas erradas usam outro contador. Os limites continuam por IP e em memória, conforme a arquitetura atual de um processo Gunicorn.

## Validação

`python -m unittest discover -s testes -p 'teste_portal.py'` — 27 testes aprovados.

Prévia renderizada pelo Flask com SQLite e dados fictícios; inspeção visual de desktop e de início, cadastro e ranking em quadros de 390 px. As capturas não representam jogadores/dados de produção. Formulários da exportação estática não gravam contas; o comportamento do backend foi verificado pelos testes.

O site público foi consultado sem criar contas. O cliente `/jogar/` chegou à tela Start neste navegador; isso não comprova login nem jogabilidade em Safari/iPhone. A sessão de trabalho do Claude não é acessível por este repositório; apenas seus commits foram comparados.

## Publicação

Esta revisão está em branch própria, para comparar e integrar com main sem sobrescrever trabalho simultâneo. Não foi aplicada na Oracle. Após integrar o PR, o responsável pela VPS deve fazer backup, atualizar os arquivos de `portal/` para o commit aprovado e reconstruir/recriar somente o serviço `portal`, usando os mesmos arquivos Compose ativos na instalação (inclusive o override HTTPS, se existir). Não é necessário substituir o banco, mapa, downloads ou reconstruir o cliente web.

Validar depois: `/saude`, cadastro, login, criação de personagem, páginas públicas, downloads e Google caso configurado. Em caso de falha, restaurar os arquivos/imagem anteriores do portal. Não executar o instalador completo apenas para trocar este tema.
