-- JV Baiak: CONVERSA COM NPC POR TOQUE (jogo no navegador e apps PC/Android)
-- Quando um NPC fala com voce, as palavras entre {chaves} viram botoes numa janelinha
-- ("Conversa com <NPC>"). Tocou no botao, o personagem fala aquela palavra para o NPC.
-- Sempre tem "Negociar" (abre a janela de compra/venda) e "Tchau".
-- A conversa comeca quando voce TOCA (ou clica) no NPC: perto, o personagem diz "hi";
-- longe, ele anda ate o NPC e cumprimenta ao chegar. Ninguem fala sozinho ao passar perto.
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

    -- no navegador do celular usa a janelinha fina e ajustavel (JVLayout); nos apps, a do jogo
    local compacta = JVLayout and JVLayout.novaJanela and true or false
    local largura, alturaBotao, espaco, topo = 190, 30, 4, 40
    if compacta then largura, alturaBotao, espaco, topo = 140, 22, 3, 0 end
    local maxBotoes = math.max(3, math.floor((raiz:getHeight() * 0.7 - topo - 30) / (alturaBotao + espaco)))
    local n = math.min(#lista, maxBotoes)
    local janela
    if compacta then
        local ok, w = pcall(JVLayout.novaJanela, 'jvConversaNpc', 'Conversa com ' .. nome, largura,
            n * (alturaBotao + espaco) - espaco, 'npc', fechar)
        if ok then janela = w else compacta = false; largura, alturaBotao, espaco, topo = 190, 30, 4, 40 end
    end
    if not janela then
        local ok, w = pcall(function() return g_ui.createWidget('MainWindow', raiz) end)
        if not ok or not w then return end
        janela = w
        pcall(function() janela:setText('Conversa com ' .. nome) end)
        janela:setWidth(largura + 30)
        janela:setHeight(topo + n * (alturaBotao + espaco) + 14)
    end
    N.janela = janela
    N.nomeConversa = nome
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
    if compacta then pcall(JVLayout.terminarJanela, janela) end
    -- canto esquerdo, abaixo da faixa do level (nao cobre o meio do mapa nem o chat).
    -- MainWindow vem presa no centro da tela: solta antes de posicionar.
    janela:breakAnchors()
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

-- ------------------------------------------------------------- tocar no NPC
local PERTO = 3

local function ehNpc(c)
    local ok, r = pcall(function() return c and c:isNpc() end)
    return ok and r
end

local function distancia(a, b)
    if not a or not b or a.z ~= b.z then return 99 end
    return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

local function atalhoLivre()
    -- no celular, se "olhar/usar/atacar/seguir" estiver escolhido, o toque e dessa acao
    local ok, atalho = pcall(function()
        local sc = modules.game_shortcuts
        if sc and sc.getShortcut then return sc.getShortcut() end
        local gi = modules.game_interface
        if gi and gi.getLeftAction then return gi.getLeftAction() end
    end)
    return not ok or atalho == nil or atalho == '' or atalho == false or atalho == 'none'
end

local function cumprimentar(npc)
    N.alvo = nil
    if N.janela and N.nomeConversa == npc:getName() then return end -- ja esta conversando
    pcall(g_game.talk, 'hi')
end

-- o NPC mais perto de mim (o servidor so deixa o mais perto responder ao "hi")
local function maisPerto(eu, npc)
    local ok, lista = pcall(function() return g_map.getSpectators(eu:getPosition(), false) end)
    if not ok or type(lista) ~= 'table' then return true end
    local p = eu:getPosition()
    local function d2(c) local q = c:getPosition(); return (q.x - p.x) ^ 2 + (q.y - p.y) ^ 2 + (q.z ~= p.z and 999 or 0) end
    local minha = d2(npc)
    for _, c in ipairs(lista) do
        if ehNpc(c) and c:getId() ~= npc:getId() and d2(c) < minha then return false end
    end
    return true
end

local function podeFalar(eu, npc)
    local d = distancia(eu:getPosition(), npc:getPosition())
    return d <= 1 or (d <= PERTO and maisPerto(eu, npc))
end

-- longe do NPC (mais de 4 quadrados), a janelinha da conversa fecha sozinha
local function conferirConversa()
    if not N.janela or not N.nomeConversa then return end
    local eu = g_game.getLocalPlayer()
    if not eu then return end
    local ok, lista = pcall(function() return g_map.getSpectators(eu:getPosition(), false) end)
    if not ok or type(lista) ~= 'table' then return end
    for _, c in ipairs(lista) do
        if ehNpc(c) and c:getName() == N.nomeConversa then
            if distancia(eu:getPosition(), c:getPosition()) > 4 then fechar() end
            return
        end
    end
    fechar() -- o NPC nem aparece mais na tela
end

local function conferirAlvo()
    pcall(conferirConversa)
    local a = N.alvo
    if not a then return end
    if os.time() > a.ate or not g_game.isOnline() then N.alvo = nil; return end
    local npc = g_map.getCreatureById(a.id)
    local eu = g_game.getLocalPlayer()
    if not npc or not eu then N.alvo = nil; return end
    if podeFalar(eu, npc) then cumprimentar(npc) end
end

local function andarAte(eu, npc)
    -- vai para o quadrado do lado do NPC que fica virado para mim
    local p, q = eu:getPosition(), npc:getPosition()
    local function passo(a, b) if a > b then return 1 elseif a < b then return -1 end return 0 end
    local destino = {x = q.x + passo(p.x, q.x), y = q.y + passo(p.y, q.y), z = q.z}
    local ok, r = pcall(function() return eu:autoWalk(destino) end)
    return ok and r ~= false
end

local function tocou(botao, npc)
    if botao ~= MouseLeftButton and botao ~= MouseTouch then return false end
    if not ehNpc(npc) or not atalhoLivre() then return false end
    if g_keyboard.getModifiers() ~= KeyboardNoModifier then return false end
    local eu = g_game.getLocalPlayer()
    if not eu then return false end
    if podeFalar(eu, npc) then
        cumprimentar(npc)
        return true -- nao anda: ja esta perto
    end
    if distancia(eu:getPosition(), npc:getPosition()) > 12 then return false end
    N.alvo = {id = npc:getId(), ate = os.time() + 15} -- anda ate ele e cumprimenta ao chegar
    return andarAte(eu, npc)
end

local function ligarToque()
    local gi = modules.game_interface
    if N.toqueLigado or not gi or type(gi.processMouseAction) ~= 'function' then return end
    N.toqueLigado = true
    local original = gi.processMouseAction
    gi.processMouseAction = function(menuPosition, mouseButton, autoWalkPos, lookThing, useThing, creatureThing, attackCreature, ...)
        local ok, tratou = pcall(tocou, mouseButton, ehNpc(creatureThing) and creatureThing or attackCreature)
        if ok and tratou then return true end
        return original(menuPosition, mouseButton, autoWalkPos, lookThing, useThing, creatureThing, attackCreature, ...)
    end
end

function N.iniciar()
    if N.ligado then return end
    N.ligado = true
    connect(g_game, { onTalk = aoFalar, onGameEnd = fechar, onOpenNpcTrade = fechar,
        onGameStart = function() pcall(ligarToque) end })
    pcall(ligarToque)
    N.eventoAlvo = cycleEvent(function() pcall(conferirAlvo) end, 300)
end

function N.parar()
    if not N.ligado then return end
    N.ligado = false
    disconnect(g_game, { onTalk = aoFalar, onGameEnd = fechar, onOpenNpcTrade = fechar })
    if N.eventoAlvo then removeEvent(N.eventoAlvo) end
    N.eventoAlvo = nil
    fechar()
end
