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

-- Pagina no formato da janela "Skills" do Tibia 8.60: nome a esquerda, valor a direita,
-- barra de progresso embaixo do Level, do Magic Level e de cada skill.
local LINHA = 15
local LINHAS = {
    {'exp', 'Experience'}, {'level', 'Level', 'vermelha'},
    {'-'},
    {'hp', 'Hit Points'}, {'mana', 'Mana'}, {'soul', 'Soul Points'}, {'cap', 'Capacity'}, {'stamina', 'Stamina'},
    {'-'},
    {'ml', 'Magic Level', 'vermelha'},
    {'-'},
    {'s0', 'Fist Fighting', 'verde'}, {'s1', 'Club Fighting', 'verde'}, {'s2', 'Sword Fighting', 'verde'},
    {'s3', 'Axe Fighting', 'verde'}, {'s4', 'Distance Fighting', 'verde'}, {'s5', 'Shielding', 'verde'},
    {'s6', 'Fishing', 'verde'},
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

local function criarPagina()
    if S.pagina then return end
    local main = modules.game_interface.getMainRightPanel and modules.game_interface.getMainRightPanel()
    if not main then return end
    local p = g_ui.createWidget('PhantomMiniWindow', main)
    p:setId('jvStatus'); p:setWidth(176)
    pcall(function() p:setText('Skills') end)
    S.valores, S.barras = {}, {}
    local y = 8
    for _, l in ipairs(LINHAS) do
        if l[1] == '-' then
            local sep = g_ui.createWidget('UIWidget', p)
            sep:addAnchor(AnchorTop, 'parent', AnchorTop); sep:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            sep:addAnchor(AnchorRight, 'parent', AnchorRight)
            sep:setMarginTop(y + 3); sep:setMarginLeft(6); sep:setMarginRight(6); sep:setHeight(1)
            sep:setBackgroundColor('#5a5a5a'); sep:setPhantom(true)
            y = y + 8
        else
            local nome = rotulo(p, l[2], AlignLeft)
            nome:addAnchor(AnchorTop, 'parent', AnchorTop); nome:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            nome:setMarginTop(y); nome:setMarginLeft(8); nome:setSize({width = 110, height = LINHA - 1})
            local valor = rotulo(p, '', AlignRight)
            valor:addAnchor(AnchorTop, 'parent', AnchorTop); valor:addAnchor(AnchorRight, 'parent', AnchorRight)
            valor:setMarginTop(y); valor:setMarginRight(8); valor:setSize({width = 70, height = LINHA - 1})
            S.valores[l[1]] = valor
            y = y + LINHA
            if l[3] then
                local fundo = g_ui.createWidget('UIWidget', p)
                fundo:addAnchor(AnchorTop, 'parent', AnchorTop); fundo:addAnchor(AnchorLeft, 'parent', AnchorLeft)
                fundo:addAnchor(AnchorRight, 'parent', AnchorRight)
                fundo:setMarginTop(y - 2); fundo:setMarginLeft(8); fundo:setMarginRight(8); fundo:setHeight(4)
                fundo:setBackgroundColor('#2a1a1a'); fundo:setPhantom(true)
                local barra = g_ui.createWidget('UIWidget', fundo)
                barra:addAnchor(AnchorTop, 'parent', AnchorTop); barra:addAnchor(AnchorLeft, 'parent', AnchorLeft)
                barra:addAnchor(AnchorBottom, 'parent', AnchorBottom)
                barra:setBackgroundColor(l[3] == 'vermelha' and '#c01010' or '#10a010'); barra:setPhantom(true)
                S.barras[l[1]] = {barra = barra, fundo = fundo}
                y = y + 5
            end
        end
    end
    -- botoes sem digitar: vender o loot, mandar ao depot e ver a hunt
    local acoes = {{'Vender', '!venderloot'}, {'Depot', '!depot'}, {'Hunt', '!hunt'}}
    for i, a in ipairs(acoes) do
        local b = g_ui.createWidget('Button', p)
        b:setText(a[1]); b:setSize({width = 52, height = 32})
        b:addAnchor(AnchorTop, 'parent', AnchorTop)
        b:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        b:setMarginTop(y + 6); b:setMarginLeft(4 + (i - 1) * 56)
        local fala = a[2]
        b.onClick = function() if g_game.isOnline() then pcall(g_game.talk, fala) end end
    end
    p.jvAltura = y + 6 + 32 + 8
    p:setHeight(p.jvAltura); p.panelHeight = p.jvAltura
    p:hide()
    S.pagina = p
end

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
        local w = b.fundo:getWidth()
        b.barra:setWidth(math.max(0, math.floor(w * math.min(100, pct) / 100)))
    end
end

local function atualizar()
    if not g_game.isOnline() then return end
    local pl = g_game.getLocalPlayer()
    if not pl then return end
    criarFaixa(); criarPagina()
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
        if JVToque and JVToque.selecionar then JVToque.selecionar('jvStatus', true) end
    end, rootWidget)
    connect(g_game, { onGameEnd = function()
        -- a interface do jogo e recriada no proximo login
        if S.faixa then pcall(function() S.faixa:destroy() end) end
        if S.pagina then pcall(function() S.pagina:destroy() end) end
        S.faixa, S.pagina = nil, nil
    end })
end
