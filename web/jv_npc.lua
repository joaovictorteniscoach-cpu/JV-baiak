-- JV Baiak: CONVERSA COM NPC POR TOQUE (jogo no navegador e apps PC/Android)
-- Quando um NPC fala com voce, as palavras entre {chaves} viram botoes numa janelinha
-- ("Conversa com <NPC>"). Tocou no botao, o personagem fala aquela palavra para o NPC.
-- Sempre tem "Negociar" (abre a janela de compra/venda) e "Tchau".
-- A conversa comeca quando voce TOCA (ou clica) no NPC: perto, o personagem diz "hi";
-- longe, ele anda ate o NPC e cumprimenta ao chegar. Ninguem fala sozinho ao passar perto.
-- No celular: dois toques atacam, abrem ou usam; segurar mostra a acao secundaria.
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

local caminhar
local function andarAte(eu, npc)
    -- vai para o quadrado do lado do NPC que fica virado para mim
    local p, q = eu:getPosition(), npc:getPosition()
    local function passo(a, b) if a > b then return 1 elseif a < b then return -1 end return 0 end
    local destino = {x = q.x + passo(p.x, q.x), y = q.y + passo(p.y, q.y), z = q.z}
    return caminhar(destino)
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

-- ------------------------------------------------------------- gestos no celular
-- Em monstros e NPCs: dois toques para atacar/conversar; segurar segue.
-- Em jogadores: 2 toques abrem o menu, segurar segue (1 toque nao ataca ninguem sem querer).
-- Em objetos de mapa: dois toques abrem ou usam o item.
local DOIS_TOQUES = 800 -- ms
local function confirmou(chave)
    local agora=g_clock.millis();local anterior=N.ultimoToque
    if anterior and anterior.id==chave and agora-anterior.t<=DOIS_TOQUES then
        N.ultimoToque=nil;return true
    end
    N.ultimoToque={id=chave,t=agora};return false
end

local function celular()
    local ok, r = pcall(function()
        if g_platform and g_platform.isMobile then return g_platform.isMobile() end
        if g_app and g_app.isMobile then return g_app.isMobile() end
        return false
    end)
    return ok and r
end

local function abrirMenu(menuPosition, lookThing, useThing, criatura)
    local gi = modules.game_interface
    if gi and gi.createThingMenu then pcall(gi.createThingMenu, menuPosition, lookThing, useThing, criatura) end
end

caminhar = function(destino)
    local eu=g_game.getLocalPlayer()
    if not eu or not destino then return false end
    local a=JVAutoAtaque or (modules.jv_autoataque and modules.jv_autoataque.JVAutoAtaque)
    if a and a.andarManual then pcall(a.andarManual,destino) end
    -- OTClientV8 precisa do modulo que permite atravessar campos. No cliente
    -- web ele nao existe e o proprio motor de caminho ja trata esses campos.
    local caminho=modules.jv_caminho
    if caminho and type(caminho.caminhar)=='function' then
        local ok,feito=pcall(caminho.caminhar,eu,destino)
        if ok and feito then return true end
    end
    local ok, resultado=pcall(function() return eu:autoWalk(destino) end)
    return ok and resultado ~= false
end

local function gesto(menuPosition, mouseButton, lookThing, useThing, criatura)
    if not celular() or not criatura or not atalhoLivre() then return false end
    local eu = g_game.getLocalPlayer()
    if not eu or criatura:getId() == eu:getId() then return false end -- o proprio personagem: menu normal
    local ok, monstro = pcall(function() return criatura:isMonster() end)
    monstro = ok and monstro
    local ok2, jogador = pcall(function() return criatura:isPlayer() end)
    jogador = ok2 and jogador
    if mouseButton == MouseRightButton then
        -- segurar o dedo
        if monstro or jogador then
            pcall(g_game.follow, criatura)
            g_logger.info('JV_GESTO seguir ' .. criatura:getName())
            return true
        end
        return false
    end
    if mouseButton ~= MouseLeftButton and mouseButton ~= MouseTouch and mouseButton ~= MouseTouch2 and mouseButton ~= MouseTouch3 then return false end
    if not confirmou('criatura:'..criatura:getId()) then return true end
    if monstro then
        local atual = g_game.getAttackingCreature()
        if not atual or atual:getId() ~= criatura:getId() then pcall(g_game.attack, criatura) end
        g_logger.info('JV_GESTO atacar ' .. criatura:getName())
        return true
    elseif jogador then
        abrirMenu(menuPosition, lookThing, useThing, criatura)
        return true
    end
    return false
end

local function ligarToque()
    local gi = modules.game_interface
    if N.toqueLigado or not gi or type(gi.processMouseAction) ~= 'function' then return end
    N.toqueLigado = true
    local original = gi.processMouseAction
    gi.processMouseAction = function(menuPosition, mouseButton, autoWalkPos, lookThing, useThing, creatureThing, attackCreature, ...)
        local criatura = creatureThing or attackCreature
        local toque = mouseButton == MouseLeftButton or mouseButton == MouseTouch or mouseButton == MouseTouch2 or mouseButton == MouseTouch3
        if celular() and toque and ehNpc(criatura) and atalhoLivre() then
            if not confirmou('npc:'..criatura:getId()) then return true end
            local ok, tratou=pcall(tocou,MouseLeftButton,criatura)
            if ok and tratou then return true end
        elseif not ehNpc(criatura) then
            local ok2, feito = pcall(gesto, menuPosition, mouseButton, lookThing, useThing, criatura)
            if ok2 and feito then return true end
        end
        if celular() and toque and not criatura and useThing and atalhoLivre() then
            local ok, ehItem, posicao = pcall(function()
                local p=useThing:getPosition()
                local function flag(nome)
                    local sucesso,valor=pcall(function()return useThing[nome] and useThing[nome](useThing)end)
                    return sucesso and valor
                end
                local pode=(flag('isContainer') or flag('isLyingCorpse') or flag('isUsable'))
                return pode,p
            end)
            if ok and ehItem and posicao and posicao.x~=65535 then
                local chave='item:'..posicao.x..':'..posicao.y..':'..posicao.z..':'..useThing:getId()
                if not confirmou(chave) then
                    if autoWalkPos then caminhar(autoWalkPos) end
                    return true
                end
                local abriu=pcall(function()
                    local c=useThing.isContainer and useThing:isContainer()
                    local corpse=useThing.isLyingCorpse and useThing:isLyingCorpse()
                    if c or corpse then g_game.open(useThing)
                    else g_game.use(useThing) end
                end)
                if abriu then return true end
            end
        end
        if celular() and autoWalkPos and toque and not criatura and atalhoLivre() and g_keyboard.getModifiers()==KeyboardNoModifier then
            if caminhar(autoWalkPos) then return true end
        elseif autoWalkPos and toque and not criatura then
            local a=JVAutoAtaque or (modules.jv_autoataque and modules.jv_autoataque.JVAutoAtaque)
            if a and a.andarManual then pcall(a.andarManual,autoWalkPos) end
        end
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
