-- JV Baiak: JANELA DO AUTOLOOT (jogo no navegador). Menu > Autoloot.
-- Liga/desliga e escolhe o que pegar (dinheiro, itens caros, itens raros, sua lista) e o
-- que vai direto para o depot. O servidor guarda as escolhas (opcode 78).
JVAutoLoot = JVAutoLoot or {}
local A = JVAutoLoot
local OPCODE = 78
local CAMPOS = {
    {'ligado', 'Autoloot'},
    {'dinheiro', 'Dinheiro (vai pro banco)'},
    {'caros', 'Itens caros (2.000+)'},
    {'raros', 'Itens raros'},
    {'lista', 'Minha lista (!autoloot)'},
    {'depotRaros', 'Raros direto pro depot'},
    {'depotCaros', 'Caros direto pro depot'},
}

local function mandar(texto)
    local p = g_game.getProtocolGame and g_game.getProtocolGame()
    if p and p.sendExtendedOpcode then pcall(function() p:sendExtendedOpcode(OPCODE, texto or '') end) end
end

local function pintar()
    if not A.janela or A.janela:isDestroyed() then return end
    for i, c in ipairs(CAMPOS) do
        local b = A.botoes[c[1]]
        local ligado = A.estado and A.estado[i] == '1'
        if b then
            -- ate o servidor responder mostra "..." (nao "nao", que confundia)
            b:setText(c[2] .. ': ' .. (not A.estado and '...' or (ligado and 'SIM' or 'nao')))
            b:setColor(ligado and '#80ff80' or '#c0c0c0')
        end
    end
end

local function criar()
    if A.janela and not A.janela:isDestroyed() then return A.janela end
    if not (JVLayout and JVLayout.novaJanela) then return nil end
    local largura, altura, espaco = 170, 22, 3
    local w = JVLayout.novaJanela('jvJanelaAutoloot', 'Autoloot', largura, #CAMPOS * (altura + espaco) - espaco, 'autoloot')
    A.botoes = {}
    for i, c in ipairs(CAMPOS) do
        local b = g_ui.createWidget('Button', w)
        b:setSize({width = largura, height = altura})
        b:addAnchor(AnchorTop, 'parent', AnchorTop); b:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        b:setMarginTop((i - 1) * (altura + espaco))
        local campo = c[1]
        b.onClick = function() mandar(campo) end
        A.botoes[campo] = b
    end
    JVLayout.terminarJanela(w)
    A.janela = w
    return w
end

function A.alternar()
    if not g_game.isOnline() then return end
    local w = criar()
    if not w then return end
    if w:isVisible() and A.aberta then w:hide(); A.aberta = false; return end
    local r = w:getParent()
    w:show(); w:raise(); A.aberta = true
    if r then w:setPosition({x = r:getX() + 8, y = r:getY() + 48}) end
    pintar()
    mandar('') -- pede o estado atual
end

function A.iniciar()
    if A.ligado then return end
    if not ProtocolGame or not ProtocolGame.registerExtendedOpcode then return end
    A.ligado = true
    pcall(ProtocolGame.registerExtendedOpcode, OPCODE, function(protocol, opcode, buffer)
        local t = {}
        for v in tostring(buffer or ''):gmatch('[^,]+') do t[#t + 1] = v end
        A.estado = t
        g_logger.info('JV_LOOT ' .. tostring(buffer))
        pintar()
    end)
    g_keyboard.bindKeyDown('Ctrl+Shift+F5', function() pcall(A.alternar) end, rootWidget)
    connect(g_game, { onGameEnd = function()
        if A.janela and not A.janela:isDestroyed() then pcall(function() A.janela:destroy() end) end
        A.janela, A.aberta = nil, false
    end })
end
