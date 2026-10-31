
-- JV Baiak: ajustes do jogo no navegador/celular (adicionado na montagem do cliente web)
-- Esconde o painel de baixo da tela de login (noticias e "boosted creature"):
-- ele depende de um servico web que o Baiak 8.60 nao tem e so mostrava aviso em ingles.
if modules.client_bottommenu and modules.client_bottommenu.hide then
    modules.client_bottommenu.show = function() end
    pcall(modules.client_bottommenu.hide)
end

-- Esconde o texto tecnico da versao no canto da tela de login
pcall(function()
    local rotulo = rootWidget:recursiveGetChildById('clientVersionLabel')
    if rotulo then rotulo:hide() end
end)
