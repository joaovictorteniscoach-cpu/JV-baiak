-- JV Baiak: BOTOES RAPIDOS NA TELA (jogo no navegador, celular)
-- Ao lado do Lv/XP, em cima do mapa:
--   espada  = caca automatica (ataca sozinho e usa magias de ataque) liga/desliga
--   pocao   = CURA AUTOMATICA liga/desliga tudo: magia de cura (vida < 70%) e AUTO POCAO
--             (pocao de vida < 50%, pocao de mana < 30%); feita pelo servidor, com a espada
--             ligada ou nao. Na janela Comandos da para ligar so a magia ou so a pocao.
--   ankh    = volta para o templo da sua cidade (de qualquer hunt)
--   papel   = janela Comandos: AOL, bless, vender loot, depot, autoloot... sem digitar
-- Aceso = ligado; apagado = desligado. O servidor guarda a cura (opcode 79).
JVRapido = JVRapido or {}
local R = JVRapido
local OPCODE = 79
local TAM, ESPACO = 28, 3

local function aviso(texto)
    pcall(function() modules.game_textmessage.displayStatusMessage(texto) end)
end

local function falar(texto)
    if g_game.isOnline() then pcall(g_game.talk, texto) end
end

local function mandar(texto)
    local p = g_game.getProtocolGame and g_game.getProtocolGame()
    if p and p.sendExtendedOpcode then pcall(function() p:sendExtendedOpcode(OPCODE, texto or '') end) end
end

local function acender(b, ligado)
    if not b or b:isDestroyed() then return end
    b:setOpacity(ligado == nil and 0.65 or (ligado and 1 or 0.45))
    b:setBorderWidth(ligado and 1 or 0)
    b:setBorderColor(ligado and '#80ff80' or '#00000000')
end

local function linha(b, texto, valor)
    if not b or b:isDestroyed() then return end
    b:setText(texto .. ': ' .. (valor == nil and '...' or (valor and 'SIM' or 'nao')))
    b:setColor(valor ~= false and '#80ff80' or '#c0c0c0')
end

function R.pintar()
    if R.botoes then
        acender(R.botoes.caca, JVAutoAtaque and JVAutoAtaque.ligado)
        local confirmado = R.cura ~= nil and R.pocao ~= nil and not R.pendente
        local estado
        if confirmado then estado = R.cura or R.pocao end
        acender(R.botoes.cura, estado)
        acender(R.botoes.templo, true)
        acender(R.botoes.comandos, true)
    end
    if R.janela and not R.janela:isDestroyed() then
        linha(R.linhaCura, 'Magia de cura', R.cura)
        linha(R.linhaPocao, 'Pocao automatica', R.pocao)
    end
end

-- ------------------------------------------------------------- janela Comandos
local COMANDOS = {
    {'Voltar ao templo', function() falar('!templo') end},
    {'Magia de cura', function() mandar('cura') end, 'cura'},
    {'Pocao automatica', function() mandar('pocao') end, 'pocao'},
    {'Comprar AOL (10k)', function() falar('!aol') end},
    {'Comprar bless', function() falar('!bless') end},
    {'Vender o loot', function() falar('!venderloot') end},
    {'Mandar pro depot', function() falar('!depot') end},
    {'Lucro da hunt', function() falar('!hunt') end},
    {'Autoloot...', function() if JVAutoLoot and JVAutoLoot.alternar then pcall(JVAutoLoot.alternar) end end},
    {'Quem esta online', function() falar('!online') end},
}

local function criarJanela()
    if R.janela and not R.janela:isDestroyed() then return R.janela end
    if not (JVLayout and JVLayout.novaJanela) then return nil end
    local largura, altura, espaco = 170, 22, 3
    local w = JVLayout.novaJanela('jvJanelaComandos', 'Comandos', largura, #COMANDOS * (altura + espaco) - espaco, 'comandos')
    for i, c in ipairs(COMANDOS) do
        local b = g_ui.createWidget('Button', w)
        b:setSize({width = largura, height = altura})
        b:addAnchor(AnchorTop, 'parent', AnchorTop); b:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        b:setMarginTop((i - 1) * (altura + espaco))
        b:setText(c[1])
        local acao = c[2]
        b.onClick = function() pcall(acao) end
        if c[3] == 'cura' then R.linhaCura = b end
        if c[3] == 'pocao' then R.linhaPocao = b end
    end
    JVLayout.terminarJanela(w)
    R.janela = w
    return w
end

function R.comandos()
    if not g_game.isOnline() then return end
    local w = criarJanela()
    if not w then return end
    if w:isVisible() and R.aberta then w:hide(); R.aberta = false; return end
    local r = w:getParent()
    w:show(); w:raise(); R.aberta = true
    if r then w:setPosition({x = r:getX() + 8, y = r:getY() + 48}) end
    R.pintar()
    mandar('')
    g_logger.info('JV_COMANDOS aberta')
end

-- ------------------------------------------------------------- botoes na tela
local function botao(pai, id, icone, x, fn)
    local b = g_ui.createWidget('UIButton', pai)
    b:setId(id)
    b:setSize({width = TAM, height = TAM})
    b:addAnchor(AnchorTop, 'parent', AnchorTop)
    b:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    b:setMarginTop(3); b:setMarginLeft(x)
    b:setBackgroundColor('#00000099')
    b:setImageSource(icone)
    pcall(function() b:setImageSize({width = TAM - 4, height = TAM - 4}) end)
    pcall(function() b:setImageOffset({x = 2, y = 2}) end)
    b.onClick = function() pcall(fn) end
    return b
end

local function criarBotoes()
    if R.painel and not R.painel:isDestroyed() then return end
    local mapa = modules.game_interface and modules.game_interface.getMapPanel and modules.game_interface.getMapPanel()
    if not mapa then return end
    local x0 = 160 -- logo depois da faixa do Lv/XP (150 + margens)
    local p = g_ui.createWidget('UIWidget', mapa)
    p:setId('jvBotoesRapidos')
    p:setSize({width = 4 * (TAM + ESPACO) + 4, height = TAM + 6})
    p:addAnchor(AnchorTop, 'parent', AnchorTop)
    p:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    p:setMarginTop(1); p:setMarginLeft(x0)
    p:setPhantom(true)
    R.painel = p
    R.botoes = {}
    R.botoes.caca = botao(p, 'jvRapidoCaca', '/images/game/mobile/caca', 0, function()
        if JVAutoAtaque and JVAutoAtaque.definir then JVAutoAtaque.definir(not JVAutoAtaque.ligado) end
        R.pintar()
    end)
    R.botoes.cura = botao(p, 'jvRapidoCura', '/images/game/mobile/cura', TAM + ESPACO, function()
        if R.cura == nil or R.pocao == nil or R.pendente then
            mandar('')
            aviso('Aguardando o servidor confirmar a cura e a auto pocao.')
            return
        end
        R.pendente = true
        R.pintar()
        mandar('tudo')
        local sessao = R.sessao
        scheduleEvent(function()
            if R.sessao ~= sessao or not R.pendente then return end
            R.pendente = false
            R.cura, R.pocao = nil, nil
            R.pintar()
            mandar('')
        end, 2500)
    end)
    R.botoes.templo = botao(p, 'jvRapidoTemplo', '/images/game/mobile/templo', 2 * (TAM + ESPACO), function()
        falar('!templo')
    end)
    R.botoes.comandos = botao(p, 'jvRapidoComandos', '/images/game/mobile/comandos', 3 * (TAM + ESPACO), R.comandos)
    R.pintar()
    -- a posicao so existe depois de o jogo montar a tela: registra um pouco depois
    scheduleEvent(function()
        if p:isDestroyed() then return end
        local r, s = p:getRect(), rootWidget:getSize()
        g_logger.info(string.format('JV_RAPIDO root=%d,%d rect=%d,%d,%d,%d', s.width, s.height, r.x, r.y, r.width, r.height))
    end, 400)
end

function R.iniciar()
    if R.ligado then return end
    if not ProtocolGame or not ProtocolGame.registerExtendedOpcode then return end
    R.ligado = true
    pcall(ProtocolGame.registerExtendedOpcode, OPCODE, function(protocol, opcode, buffer)
        local cura, ataque, pocao = tostring(buffer or ''):match('^([01]),([01]),([01])$')
        if not cura then return end
        R.cura, R.pocao, R.pendente = cura == '1', pocao == '1', false
        g_logger.info('JV_CURA ' .. tostring(buffer))
        R.pintar()
    end)
    g_keyboard.bindKeyDown('Ctrl+Shift+F1', function() pcall(R.comandos) end, rootWidget)
    local mobile = g_platform and g_platform.isMobile and g_platform.isMobile()
    connect(g_game, {
        onGameStart = function()
            R.sessao = (R.sessao or 0) + 1
            R.cura, R.pocao, R.pendente = nil, nil, false
            R.pintar()
            if mobile then scheduleEvent(function() pcall(criarBotoes) end, 1500) end
            scheduleEvent(function() mandar('') end, 5000)
        end,
        onGameEnd = function()
            R.sessao = (R.sessao or 0) + 1
            R.cura, R.pocao, R.pendente = nil, nil, false
            R.pintar()
            if R.janela and not R.janela:isDestroyed() then pcall(function() R.janela:destroy() end) end
            R.janela, R.aberta, R.linhaCura, R.linhaPocao = nil, false, nil, nil
        end
    })
    -- a espada pode mudar por outro caminho (menu de opcoes): repinta de vez em quando
    cycleEvent(function() if R.painel and not R.painel:isDestroyed() then R.pintar() end end, 1500)
end
