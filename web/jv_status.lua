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

local function criarPagina()
    if S.pagina then return end
    local main = modules.game_interface.getMainRightPanel and modules.game_interface.getMainRightPanel()
    if not main then return end
    local p = g_ui.createWidget('PhantomMiniWindow', main)
    p:setId('jvStatus'); p:setWidth(176)
    local texto = g_ui.createWidget('UILabel', p)
    texto:addAnchor(AnchorTop, 'parent', AnchorTop)
    texto:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    texto:addAnchor(AnchorRight, 'parent', AnchorRight)
    texto:setMarginTop(8); texto:setMarginLeft(8)
    texto:setTextAlign(AlignTopLeft)
    texto:setColor('#e8e8e8')
    pcall(function() texto:setFont('verdana-11px-rounded') end)
    texto:setTextWrap(true)
    p.jvAltura = 16 * 17 + 20
    p:setHeight(p.jvAltura); p.panelHeight = p.jvAltura
    p:hide()
    S.pagina, S.paginaTexto = p, texto
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
    if S.paginaTexto then
        local exp = pl:getExperience()
        local falta = math.max(0, expDoLevel(lv + 1) - exp)
        local linhas = {
            string.format('Level: %d (%d%%)', lv, pct),
            'Experiencia: ' .. formatar(exp),
            'Falta p/ subir: ' .. formatar(falta),
            string.format('Magic level: %d (%d%%)', pl:getMagicLevel(), pl:getMagicLevelPercent()),
        }
        for _, s in ipairs(NOMES) do
            local ok, v = pcall(function() return pl:getSkillLevel(s[2]) end)
            local ok2, pc = pcall(function() return pl:getSkillLevelPercent(s[2]) end)
            linhas[#linhas + 1] = string.format('%s: %s%s', s[1], ok and v or '?', ok2 and (' (' .. pc .. '%)') or '')
        end
        linhas[#linhas + 1] = string.format('Vida: %s / %s', formatar(pl:getHealth()), formatar(pl:getMaxHealth()))
        linhas[#linhas + 1] = string.format('Mana: %s / %s', formatar(pl:getMana()), formatar(pl:getMaxMana()))
        linhas[#linhas + 1] = 'Capacidade: ' .. formatar(pl:getFreeCapacity())
        linhas[#linhas + 1] = 'Soul: ' .. tostring(pl:getSoul())
        local st = pl:getStamina()
        linhas[#linhas + 1] = string.format('Stamina: %d:%02d', math.floor(st / 60), st % 60)
        linhas[#linhas + 1] = 'XP/h e lucro: !hunt'
        S.paginaTexto:setText(table.concat(linhas, '\n'))
        S.paginaTexto:setHeight(16 * #linhas)
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
