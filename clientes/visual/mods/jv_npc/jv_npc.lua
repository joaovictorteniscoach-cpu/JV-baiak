-- JV Baiak: CONVERSA COM NPC POR TOQUE (jogo no navegador e apps PC/Android)
-- Quando um NPC fala com voce, as palavras entre {chaves} viram botoes numa janelinha
-- ("Conversa com <NPC>"). Tocou no botao, o personagem fala aquela palavra para o NPC.
-- Sempre tem "Negociar" (abre a janela de compra/venda) e "Tchau".
-- Mesmo arquivo em web/ e em clientes/visual/mods/jv_npc/ (o teste confere).
JVNpc = JVNpc or {}
local N = JVNpc

local function falar(texto)
    if not g_game.isOnline() then return end
    local ok = pcall(function() g_game.talkChannel(MessageModes.NpcTo, 0, texto) end)
    if not ok then pcall(g_game.talk, texto) end
end

local function fechar()
    if N.janela then
        pcall(function() N.janela:destroy() end)
        N.janela = nil
    end
    if N.evento then removeEvent(N.evento) end
    N.evento = nil
end
N.fechar = fechar

local function palavras(texto)
    local lista, visto = {}, {}
    for p in texto:gmatch("{([^}]+)}") do
        local chave = p:lower()
        if not visto[chave] then
            visto[chave] = true
            lista[#lista + 1] = p
        end
    end
    return lista
end

local function mostrar(nome, opcoes)
    fechar()
    local raiz = rootWidget
    if not raiz then return end
    local lista = {}
    for _, o in ipairs(opcoes) do lista[#lista + 1] = {o, o} end
    lista[#lista + 1] = {'Negociar', 'trade'}
    lista[#lista + 1] = {'Tchau', 'bye'}

    local ok, janela = pcall(function() return g_ui.createWidget('MainWindow', raiz) end)
    if not ok or not janela then return end
    N.janela = janela
    pcall(function() janela:setText('Conversa com ' .. nome) end)
    local largura, alturaBotao, espaco, topo = 190, 30, 4, 40
    local maxBotoes = math.max(3, math.floor((raiz:getHeight() * 0.7 - topo) / (alturaBotao + espaco)))
    local n = math.min(#lista, maxBotoes)
    janela:setWidth(largura + 30)
    janela:setHeight(topo + n * (alturaBotao + espaco) + 14)
    for i = 1, n do
        local rotulo, fala = lista[i][1], lista[i][2]
        if i == n and n < #lista then rotulo, fala = 'Tchau', 'bye' end
        local b = g_ui.createWidget('Button', janela)
        b:setText(rotulo)
        b:setWidth(largura)
        b:setHeight(alturaBotao)
        b:addAnchor(AnchorTop, 'parent', AnchorTop)
        b:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        b:setMarginTop((i - 1) * (alturaBotao + espaco))
        b.onClick = function()
            falar(fala)
            if fala == 'bye' or fala == 'trade' then fechar() end
        end
    end
    -- canto esquerdo, um pouco abaixo do topo (nao cobre o meio do mapa nem o chat)
    janela:setPosition({x = 8, y = math.floor(raiz:getHeight() * 0.12)})
    pcall(function() janela:raise() end)
    N.evento = scheduleEvent(fechar, 60000) -- some sozinha se ninguem tocar
end

local function aoFalar(nome, nivel, modo, texto)
    if modo ~= MessageModes.NpcFrom and modo ~= MessageModes.NpcFromStartBlock then return end
    if type(texto) ~= 'string' then return end
    local baixo = texto:lower()
    if baixo:find('tchau') or baixo:find('good bye') or baixo:find('farewell') then
        fechar()
        return
    end
    local opcoes = palavras(texto)
    if #opcoes > 0 or not N.janela then
        mostrar(nome or 'NPC', opcoes)
    end
end

function N.iniciar()
    if N.ligado then return end
    N.ligado = true
    connect(g_game, { onTalk = aoFalar, onGameEnd = fechar, onOpenNpcTrade = fechar })
end

function N.parar()
    if not N.ligado then return end
    N.ligado = false
    disconnect(g_game, { onTalk = aoFalar, onGameEnd = fechar, onOpenNpcTrade = fechar })
    fechar()
end
