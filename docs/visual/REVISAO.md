# Acabamento visual do portal

Base: 973a4b44a2517bbbf7b203c3e552ea70d3d1e4eb.

Alterações somente de apresentação: CSS do portal, contêineres visuais nos templates e CSS da capa web. Login com painel de pergaminho e cavaleiro; botões vermelhos com bordas de metal; madeira e molduras uniformes; fundo com transição para facilitar leitura; campos, foco, opções, tabelas e filtros móveis refinados. Correção visual do espaçamento da confirmação de cadastro e acento em “Vocação”. As imagens existentes do Tibia foram reaproveitadas.

Não foram alterados app.py, banco, rotas, ações dos formulários, nomes/atributos dos campos, tokens CSRF, condições do Google, scripts JavaScript, canvas, toque, zoom ou regras do servidor. Mapa, criaturas e respawn ficaram fora desta revisão por orientação do usuário.

Validação: 27 testes existentes do portal aprovados; diff sem erros de whitespace; scripts JavaScript de web/shell.html comparados e idênticos à base. Inspeção visual de início, login, erro de login/Google, cadastro e ranking em desktop e quadros móveis de 390 px. Login, cadastro e ranking sem imagens quebradas ou overflow horizontal nos quadros móveis. Capa web inspecionada em uma exportação estática sem execução do jogo.

As capturas usam dados fictícios, inclusive rates e ranking. Nenhuma conta de produção foi criada. Google foi habilitado apenas no render de teste para verificar sua apresentação.

Publicação: esta branch não foi aplicada na Oracle. O portal precisa de reconstrução da imagem após integrar os arquivos. A capa web requer a etapa final de compilação do cliente web já existente. O fundo da capa usa o asset do mesmo domínio em /static/arte/mundo-tibia.jpg, com cor de fundo caso a imagem não carregue. Não trocar o banco, mapa ou sprites para publicar este acabamento.
