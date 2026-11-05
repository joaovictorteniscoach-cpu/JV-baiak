-- JV Baiak: LEVEL E ESTATISTICAS SEMPRE A MAO NO CELULAR (jogo no navegador)
--  * Faixa fixa no canto do mapa: "Lv 152  37%" (sobe a cada level) e a barra de XP.
--  * Pagina "Status" no menu (botao Status): level, experiencia, quanto falta,
--    magic level, todas as skills, vida, mana, capacidade, soul e stamina.
JVStatus = JVStatus or {}
local S = JVStatus

local function formatar(n)
    n = math.floor(tonumber(n) or 0)
    if n >= 1e9 then return string.format('%.2fkkk', n / 1e9) end
    if n >= 1e6 then return string.format('%.2fkk', n / 1e6) end
    if n >= 1e4 then return string.format('%.1fk', n / 1e3) end
    return tostring(n)
end

local function expDoLevel(l)
    l = l - 1
    return math.floor((50 * l * l * l - 150 * l * l + 400 * l) / 3)
end

local NOMES = {
    {'Fist', 0}, {'Club', 1}, {'Sword', 2}, {'Axe', 3}, {'Distance', 4}, {'Shielding', 5}, {'Fishing', 6},
}

local function criarFaixa()
    if S.faixa then return end
    local mapa = modules.game_interface and modules.game_interface.getMapPanel and modules.game_interface.getMapPanel()
    if not mapa then return end
    local faixa = g_ui.createWidget('UIWidget', mapa)
    faixa:setId('jvFaixaLevel')
    faixa:setSize({width = 150, height = 26})
    faixa:addAnchor(AnchorTop, 'parent', AnchorTop)
    faixa:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    faixa:setMarginTop(4); faixa:setMarginLeft(4)
    faixa:setBackgroundColor('#00000099')
    faixa:setPhantom(true)
    local texto = g_ui.createWidget('UILabel', faixa)
    texto:fill('parent')
    texto:setMarginBottom(6)
    texto:setTextAlign(AlignCenter)
    texto:setColor('#ffffff')
    pcall(function() texto:setFont('verdana-11px-rounded') end)
    texto:setPhantom(true)
    local barra = g_ui.createWidget('UIWidget', faixa)
    barra:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    barra:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    barra:setHeight(4); barra:setMarginLeft(3); barra:setMarginBottom(2)
    barra:setBackgroundColor('#f0c000')
    barra:setPhantom(true)
    S.faixa, S.faixaTexto, S.faixaBarra = faixa, texto, barra
end

-- Vida e mana pequenas em volta do personagem (dos dois lados), meio transparentes para
-- ver o mapa atraves. Substituem os arcos grandes de vida/mana do jogo.
local ALT_BARRA, LARG_BARRA = 26, 4
local function criarBarras()
    if S.vida then return end
    local mapa = modules.game_interface and modules.game_interface.getMapPanel and modules.game_interface.getMapPanel()
    if not mapa then return end
    local function barra(id, cor)
        local fundo = g_ui.createWidget('UIWidget', mapa)
        fundo:setId(id)
        fundo:setSize({width = LARG_BARRA + 2, height = ALT_BARRA + 2})
        fundo:setBackgroundColor('#00000080')
        fundo:setOpacity(0.75)
        fundo:setPhantom(true)
        local cheio = g_ui.createWidget('UIWidget', fundo)
        cheio:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        cheio:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        cheio:setMarginBottom(1); cheio:setMarginLeft(1)
        cheio:setWidth(LARG_BARRA); cheio:setHeight(ALT_BARRA)
        cheio:setBackgroundColor(cor)
        cheio:setPhantom(true)
        fundo.cheio = cheio
        return fundo
    end
    S.vida = barra('jvBarraVida', '#20d020')
    S.mana = barra('jvBarraMana', '#3070ff')
    -- tira os arcos grandes de vida/mana do jogo (ficavam por cima do mapa)
    pcall(function() modules.game_healthcircle.setHealthCircle(false) end)
    pcall(function() modules.game_healthcircle.setManaCircle(false) end)
end

local function posicionarBarras()
    if not S.vida then return end
    local pl = g_game.getLocalPlayer()
    local mapa = modules.game_interface.getMapPanel()
    if not pl or not mapa then return end
    -- o personagem fica sempre no meio do mapa; o tamanho do quadrado vem do proprio mapa
    local ok, r = pcall(function() return mapa:getTileRect(pl:getPosition()) end)
    local lado = (ok and r and r.width > 0) and r.width or 32
    local cx = mapa:getX() + math.floor(mapa:getWidth() / 2)
    local cy = mapa:getY() + math.floor(mapa:getHeight() / 2)
    local meio = cy - math.floor(ALT_BARRA / 2) - math.floor(lado / 6)
    local nova = cx .. ',' .. meio .. ',' .. lado
    if S.barrasEm == nova then return end
    S.barrasEm = nova
    S.vida:setPosition({x = cx - math.floor(lado / 2) - LARG_BARRA - 4, y = meio})
    S.mana:setPosition({x = cx + math.floor(lado / 2) + 2, y = meio})
end

local function pintarBarras()
    if not S.vida then return end
    local pl = g_game.getLocalPlayer()
    if not pl then return end
    local function encher(b, atual, maximo)
        local pct = maximo > 0 and math.max(0, math.min(1, atual / maximo)) or 0
        b.cheio:setHeight(math.max(0, math.floor(ALT_BARRA * pct)))
        return pct
    end
    local pv = encher(S.vida, pl:getHealth(), pl:getMaxHealth())
    S.vida.cheio:setBackgroundColor(pv > 0.6 and '#20d020' or (pv > 0.3 and '#e0c020' or '#e02020'))
    encher(S.mana, pl:getMana(), pl:getMaxMana())
end
S.posicionarBarras, S.pintarBarras = posicionarBarras, pintarBarras

-- Pagina no formato da janela "Skills" do Tibia 8.60: nome a esquerda, valor a direita,
-- barra de progresso embaixo do Level, do Magic Level e de cada skill. Compacta para
-- caber no celular deitado sem passar por baixo dos atalhos.
local LINHA = 12
-- cada linha: lista de celulas {id, nome, barra}; 1 celula = largura toda, 2 = duas colunas
local LINHAS = {
    {{'exp', 'Experience'}},
    {{'level', 'Level', 'vermelha'}},
    {{'hp', 'HP'}, {'mana', 'Mana'}},
    {{'soul', 'Soul'}, {'cap', 'Cap'}},
    {{'stamina', 'Stam.'}, {'ml', 'Magic', 'vermelha'}},
    {{'s0', 'Fist', 'verde'}, {'s1', 'Club', 'verde'}},
    {{'s2', 'Sword', 'verde'}, {'s3', 'Axe', 'verde'}},
    {{'s4', 'Distance', 'verde'}, {'s5', 'Shielding', 'verde'}},
    {{'s6', 'Fishing', 'verde'}},
}

local function rotulo(pai, texto, alinhar)
    local l = g_ui.createWidget('UILabel', pai)
    l:setText(texto)
    l:setColor('#c0c0c0')
    pcall(function() l:setFont('verdana-11px-antialised') end)
    l:setTextAlign(alinhar)
    l:setPhantom(true)
    return l
end

local function celula(p, c, x, largura, y)
    local nome = rotulo(p, c[2], AlignLeft)
    nome:addAnchor(AnchorTop, 'parent', AnchorTop); nome:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    nome:setMarginTop(y); nome:setMarginLeft(x); nome:setSize({width = largura, height = LINHA})
    local valor = rotulo(p, '', AlignRight)
    valor:addAnchor(AnchorTop, 'parent', AnchorTop); valor:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    valor:setMarginTop(y); valor:setMarginLeft(x); valor:setSize({width = largura, height = LINHA})
    S.valores[c[1]] = valor
    if c[3] then
        local fundo = g_ui.createWidget('UIWidget', p)
        fundo:addAnchor(AnchorTop, 'parent', AnchorTop); fundo:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        fundo:setMarginTop(y + LINHA); fundo:setMarginLeft(x); fundo:setSize({width = largura, height = 3})
        fundo:setBackgroundColor('#2a1a1a'); fundo:setPhantom(true)
        local barra = g_ui.createWidget('UIWidget', fundo)
        barra:addAnchor(AnchorTop, 'parent', AnchorTop); barra:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        barra:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        barra:setBackgroundColor(c[3] == 'vermelha' and '#c01010' or '#10a010'); barra:setPhantom(true)
        S.barras[c[1]] = {barra = barra, fundo = fundo, largura = largura}
        return true
    end
    return false
end

local function criarPagina()
    if S.pagina then return end
    local main = modules.game_interface.getMainRightPanel and modules.game_interface.getMainRightPanel()
    if not main then return end
    local p = g_ui.createWidget('PhantomMiniWindow', main)
    p:setId('jvStatus'); p:setWidth(176)
    pcall(function() p:setText('Skills') end)
    S.valores, S.barras = {}, {}
    -- botoes no alto (abaixo do botao do menu), sem digitar: vender, depot e hunt
    local acoes = {{'Vender', '!venderloot'}, {'Depot', '!depot'}, {'Hunt', '!hunt'}}
    for i, a in ipairs(acoes) do
        local b = g_ui.createWidget('Button', p)
        b:setText(a[1]); b:setSize({width = 52, height = 24})
        b:addAnchor(AnchorTop, 'parent', AnchorTop)
        b:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        b:setMarginTop(30); b:setMarginLeft(4 + (i - 1) * 56)
        local fala = a[2]
        b.onClick = function() if g_game.isOnline() then pcall(g_game.talk, fala) end end
    end
    local y = 58
    for _, linha in ipairs(LINHAS) do
        local temBarra = false
        if #linha == 1 then
            temBarra = celula(p, linha[1], 6, 162, y)
        else
            temBarra = celula(p, linha[1], 6, 78, y)
            temBarra = celula(p, linha[2], 90, 78, y) or temBarra
        end
        y = y + LINHA + (temBarra and 4 or 1)
    end
    p.jvAltura = y + 4
    p:setHeight(p.jvAltura); p.panelHeight = p.jvAltura
    p:hide()
    S.pagina = p
end
S.criarPagina = criarPagina

local function milhar(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local r = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return (r:gsub('^,', ''))
end

local function por(id, valor, pct)
    local v = S.valores and S.valores[id]
    if v then v:setText(valor) end
    local b = S.barras and S.barras[id]
    if b and pct then
        -- a janela pode estar maior ou menor (alca de tamanho): usa a largura de agora
        local largura = b.fundo:getWidth() > 0 and b.fundo:getWidth() or b.largura
        b.barra:setWidth(math.max(0, math.floor(largura * math.min(100, pct) / 100)))
    end
end

local function atualizar()
    if not g_game.isOnline() then return end
    local pl = g_game.getLocalPlayer()
    if not pl then return end
    criarFaixa(); criarPagina(); criarBarras()
    posicionarBarras(); pintarBarras()
    local lv, pct = pl:getLevel(), pl:getLevelPercent()
    if S.faixaTexto then
        S.faixaTexto:setText(string.format('Lv %d   %d%%', lv, pct))
        S.faixaBarra:setWidth(math.max(1, math.floor(144 * pct / 100)))
    end
    if S.pagina and S.pagina:isVisible() then
        por('exp', milhar(pl:getExperience()))
        por('level', tostring(lv), pct)
        por('hp', milhar(pl:getHealth()))
        por('mana', milhar(pl:getMana()))
        por('soul', tostring(pl:getSoul()))
        por('cap', milhar(pl:getFreeCapacity()))
        local st = pl:getStamina()
        por('stamina', string.format('%02d:%02d', math.floor(st / 60), st % 60))
        por('ml', tostring(pl:getMagicLevel()), pl:getMagicLevelPercent())
        for i = 0, 6 do
            local ok, v = pcall(function() return pl:getSkillLevel(i) end)
            local ok2, pc = pcall(function() return pl:getSkillLevelPercent(i) end)
            por('s' .. i, ok and tostring(v) or '?', ok2 and pc or 0)
        end
    end
end

function S.iniciar()
    if S.evento then return end
    if not (g_platform and g_platform.isMobile and g_platform.isMobile()) then return end
    S.evento = cycleEvent(function() pcall(atualizar) end, 1000)
    g_keyboard.bindKeyDown('Ctrl+Shift+F4', function()
        pcall(criarPagina)
        if JVLayout and JVLayout.abrir then JVLayout.abrir('jvStatus')
        elseif JVToque and JVToque.selecionar then JVToque.selecionar('jvStatus', true) end
    end, rootWidget)
    connect(g_game, { onGameEnd = function()
        -- a interface do jogo e recriada no proximo login
        if S.faixa then pcall(function() S.faixa:destroy() end) end
        if S.pagina then pcall(function() S.pagina:destroy() end) end
        if S.vida then pcall(function() S.vida:destroy(); S.mana:destroy() end) end
        S.faixa, S.pagina, S.vida, S.mana = nil, nil, nil, nil
    end })
    -- vida/mana mudam na hora; a posicao acompanha o personagem (andar, girar a tela, zoom)
    connect(LocalPlayer, { onHealthChange = function() pcall(pintarBarras) end,
        onManaChange = function() pcall(pintarBarras) end,
        onPositionChange = function() pcall(posicionarBarras) end })
    connect(rootWidget, { onGeometryChange = function() S.barrasEm = nil; scheduleEvent(function() pcall(posicionarBarras) end, 200) end })
end
