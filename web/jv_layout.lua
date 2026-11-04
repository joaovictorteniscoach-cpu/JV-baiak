-- JV Baiak: TRES LAYOUTS NO CELULAR (jogo no navegador). Troca pelo menu: "Trocar layout".
--   livre    = Tela cheia: o mapa ocupa a tela toda e as janelas (equipamento, minimapa,
--              skills, combate, mochilas, battle...) abrem SOLTAS por cima do mapa: arraste
--              pela barra do titulo e feche no X.
--   classico = Como era antes: painel do lado direito com equipamento, minimapa e mochilas
--              (pode arrastar as janelas para fora do painel e fechar).
--   paginas  = Um painel por vez do lado (o menu escolhe qual) e ele fecha para o mapa crescer.
-- A escolha fica salva no aparelho. As melhorias (level, skills, NPC por toque, autoloot,
-- listas, auto ataque) funcionam nos tres.
JVLayout = JVLayout or {}
local L = JVLayout
L.ORDEM = {'livre', 'classico', 'paginas'}
L.NOMES = {livre = 'Tela cheia (janelas soltas)', classico = 'Classico (painel do lado)', paginas = 'Paginas (um painel por vez)'}
local TITULOS = {maininventorypanel = 'Equipamento', mainmappanel = 'Minimapa', mainoptionspanel = 'Opcoes',
    jvCombate = 'Combate', jvStatus = 'Skills'}

function L.modo()
    local v = JV_LAYOUT
    if not v then
        pcall(function() v = g_settings.get('jvLayout') end)
    end
    if not L.NOMES[v] then v = 'livre' end
    return v
end

local function gi() return modules.game_interface end

-- ------------------------------------------------------------- pagina de combate
local function botao(parent, id, text, x, y, fn)
    local b = g_ui.createWidget('Button', parent)
    b:setId(id)
    b:setSize({width = 48, height = 32})
    b:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    b:addAnchor(AnchorTop, 'parent', AnchorTop)
    b:setMarginLeft(x); b:setMarginTop(y)
    b:setText(text); b.onClick = fn
    return b
end

local function prepararCombate()
    local main = gi().getMainRightPanel()
    if not main or main:getChildById('jvCombate') then return end
    local panel = g_ui.createWidget('PhantomMiniWindow', main)
    panel:setId('jvCombate'); panel:setWidth(176); panel:setHeight(150)
    panel.jvAltura = 150; panel.panelHeight = 150
    local inv = modules.game_inventory
    local acoes = {
        {'Ataque', function() inv.selectCombat('attack') end},
        {'Equil.', function() inv.selectCombat('balanced') end},
        {'Defesa', function() inv.selectCombat('defense') end},
        {'Parado', function() inv.selectPosture('stand') end},
        {'Seguir', function() inv.selectPosture('follow') end},
        {'Seguro', function() g_game.setSafeFight(not g_game.isSafeFight()) end},
        {'Parar', function() g_game.cancelAttack(); g_game.cancelFollow() end}
    }
    for i, a in ipairs(acoes) do
        botao(panel, 'jvCombate' .. i, a[1], 8 + ((i - 1) % 3) * 54, 8 + math.floor((i - 1) / 3) * 46, a[2])
    end
    panel:hide()
end

-- ------------------------------------------------------------- janelas soltas
L.janelas = L.janelas or {}

local function raiz() return gi().getRootPanel() end

local function dentroDaTela(w)
    local r = raiz()
    if not r or not w then return end
    local x = math.max(0, math.min(w:getX(), r:getX() + r:getWidth() - w:getWidth()))
    local y = math.max(r:getY(), math.min(w:getY(), r:getY() + r:getHeight() - w:getHeight()))
    w:setPosition({x = x, y = y})
end

local function lugarLivre(largura)
    local r = raiz()
    local n = 0
    for _, j in pairs(L.janelas) do if not j.janela:isDestroyed() and j.janela:isVisible() then n = n + 1 end end
    n = (n + (L.soltas or 0)) % 5
    -- canto direito, abaixo do botao do menu; cada janela nova um pouco mais para a esquerda
    return {x = r:getX() + r:getWidth() - largura - 6 - n * 26, y = r:getY() + 48 + n * 18}
end

local function devolver(id)
    local j = L.janelas[id]
    if not j then return end
    local main = gi().getMainRightPanel()
    if j.pagina and main then
        pcall(function()
            j.pagina:breakAnchors()
            j.pagina:setParent(main, true)
            j.pagina:hide()
        end)
    end
    pcall(function() j.janela:destroy() end)
    L.janelas[id] = nil
end

local function criarJanela(id)
    local main = gi().getMainRightPanel()
    local pagina = main and main:getChildById(id)
    if not pagina then return nil end
    local largura = math.max(pagina:getWidth(), 176)
    local altura = pagina.jvAltura or pagina:getHeight()
    if altura < 40 then altura = 162 end
    local w = g_ui.createWidget('Window', raiz())
    w:setId('jvJanela_' .. id)
    w:setText(TITULOS[id] or id)
    w:setPaddingTop(28); w:setPaddingLeft(4); w:setPaddingRight(4); w:setPaddingBottom(4)
    w:setSize({width = largura + 8, height = altura + 32})
    w:setDraggable(true)
    pagina:setParent(w, true)
    pagina:breakAnchors()
    pagina:addAnchor(AnchorTop, 'parent', AnchorTop)
    pagina:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    pagina:setSize({width = largura, height = altura})
    pcall(function() pagina:setDraggable(false) end)
    pagina:show()
    local x = g_ui.createWidget('Button', w)
    x:setId('jvFechar'); x:setText('X'); x:setSize({width = 26, height = 22})
    x:addAnchor(AnchorTop, 'parent', AnchorTop); x:addAnchor(AnchorRight, 'parent', AnchorRight)
    x:setMarginTop(-26)
    x.onClick = function() w:hide() end
    w.onDragLeave = function(self) dentroDaTela(self); return true end
    L.janelas[id] = {janela = w, pagina = pagina}
    w:setPosition(lugarLivre(w:getWidth()))
    return L.janelas[id]
end

-- abre (ou fecha, se ja esta aberta) uma janela solta
function L.alternarSolta(id)
    if not g_game.isOnline() then return end
    if id == 'jvCombate' then prepararCombate() end
    if id == 'jvStatus' and JVStatus and JVStatus.criarPagina then pcall(JVStatus.criarPagina) end
    local j = L.janelas[id]
    if j and j.janela:isDestroyed() then L.janelas[id] = nil; j = nil end
    if j and j.janela:isVisible() then j.janela:hide(); return end
    if not j then j = criarJanela(id) end
    if not j then return end
    j.janela:show(); j.janela:raise(); dentroDaTela(j.janela)
end

function L.fecharSoltas()
    for _, j in pairs(L.janelas) do pcall(function() j.janela:hide() end) end
end

-- ------------------------------------------------------------- tela cheia
local function esconderPaineis()
    local g = gi()
    local mudou = false
    for _, p in ipairs({g.getMainRightPanel(), g.getRightPanel(), g.getRightExtraPanel and g.getRightExtraPanel(),
                        g.getLeftPanel(), g.getLeftExtraPanel and g.getLeftExtraPanel()}) do
        if p and (p:isVisible() or p:getWidth() > 0) then
            p:setWidth(0); p:setVisible(false); mudou = true
        end
    end
    if mudou then pcall(g.updateStretchShrink) end
end

-- mochilas, battle, skills... que o jogo abre num painel escondido viram janelas soltas
local function soltarDosPaineis()
    local g = gi()
    local r = raiz()
    for _, p in ipairs({g.getRightPanel(), g.getRightExtraPanel and g.getRightExtraPanel(),
                        g.getLeftPanel(), g.getLeftExtraPanel and g.getLeftExtraPanel()}) do
        if p then
            for _, w in ipairs(p:getChildren()) do
                if w:isVisible() and w.close and w:getId() == 'battleWindow' and os.time() - (L.entrou or 0) < 10 then
                    -- a lista de batalha abre sozinha ao entrar: fica fechada para nao cobrir o
                    -- mapa (abre de novo em Opcoes do jogo)
                    pcall(function() w:close(true) end)
                elseif w:isVisible() and w.close then
                    local largura = w:getWidth()
                    local pos = lugarLivre(largura)
                    w:setParent(r, true)
                    w.free = true
                    pcall(function() w:breakAnchors() end)
                    if w:getHeight() < 60 then pcall(function() w:setHeight(160) end) end
                    w:setPosition(pos)
                    L.soltas = (L.soltas or 0) + 1
                    pcall(function() w:raise() end)
                    dentroDaTela(w)
                end
            end
        end
    end
end

-- em pe a tela e estreita: ao girar, as janelas soltas encolhem (so a barra do titulo)
-- para nao tampar o mapa; e so tocar no + da barra para abrir de novo
local function aoGirar()
    local r = raiz()
    local retrato = r:getWidth() < r:getHeight()
    if L.retrato == retrato then return end
    L.retrato = retrato
    if not retrato then return end
    for _, j in pairs(L.janelas) do pcall(function() j.janela:hide() end) end
    for _, w in ipairs(r:getChildren()) do
        if w.free and w.minimize and w:isVisible() then pcall(function() w:minimize(true) end) end
    end
end

local function cuidarDaTelaCheia()
    if not g_game.isOnline() then return end
    pcall(esconderPaineis)
    pcall(soltarDosPaineis)
    pcall(aoGirar)
    for _, j in pairs(L.janelas) do
        if j.janela:isVisible() then pcall(dentroDaTela, j.janela) end
    end
end

-- ------------------------------------------------------------- classico
local function alternarNoPainel(id)
    local main = gi().getMainRightPanel()
    local p = main and main:getChildById(id)
    if not p then return end
    p:setVisible(not p:isVisible())
end

-- ------------------------------------------------------------- comandos do menu
function L.abrir(id)
    local modo = L.modo()
    if modo == 'paginas' then
        if JVToque and JVToque.selecionar then
            if id == 'jvStatus' and JVStatus and JVStatus.criarPagina then pcall(JVStatus.criarPagina) end
            JVToque.selecionar(id, true)
        end
    elseif modo == 'classico' and (id == 'maininventorypanel' or id == 'mainmappanel' or id == 'mainoptionspanel') then
        alternarNoPainel(id)
    else
        L.alternarSolta(id)
    end
end

function L.trocar()
    local atual, proximo = L.modo(), 'livre'
    for i, m in ipairs(L.ORDEM) do
        if m == atual then proximo = L.ORDEM[i % #L.ORDEM + 1] end
    end
    g_settings.set('jvLayout', proximo)
    pcall(g_settings.save)
    JV_LAYOUT = proximo
    g_logger.info('JV_LAYOUT ' .. proximo)
    if modules.game_textmessage and modules.game_textmessage.displayGameMessage then
        pcall(modules.game_textmessage.displayGameMessage, 'Layout: ' .. L.NOMES[proximo] .. '. Recarregando...')
    end
end

function L.iniciar()
    if L.ligado or not (g_platform and g_platform.isMobile and g_platform.isMobile()) then return end
    L.ligado = true
    local modo = L.modo()
    g_logger.info('JV_LAYOUT ' .. modo)
    g_keyboard.bindKeyDown('Ctrl+Shift+F3', L.trocar, rootWidget)
    -- "Voltar ao mapa" tambem fecha a janelinha de conversa com NPC
    g_keyboard.bindKeyDown('Ctrl+Shift+F12', function() if JVNpc and JVNpc.fechar then JVNpc.fechar() end end, rootWidget)
    if modo ~= 'paginas' then
        -- no modo paginas estes atalhos ja sao do JVToque (otclientrc-extra.lua)
        for key, pagina in pairs({F8 = 'maininventorypanel', F9 = 'mainmappanel', F10 = 'mainoptionspanel', F11 = 'jvCombate'}) do
            local destino = pagina
            g_keyboard.bindKeyDown('Ctrl+Shift+' .. key, function() L.abrir(destino) end, rootWidget)
        end
        g_keyboard.bindKeyDown('Ctrl+Shift+F12', L.fecharSoltas, rootWidget)
    end
    connect(g_game, {
        onGameStart = function()
            L.entrou = os.time()
            scheduleEvent(function() pcall(prepararCombate) end, 1600)
            if modo == 'livre' then
                if L.evento then removeEvent(L.evento) end
                L.evento = cycleEvent(cuidarDaTelaCheia, 400)
            end
        end,
        onGameEnd = function()
            if L.evento then removeEvent(L.evento) end
            L.evento = nil
            for id in pairs(L.janelas) do devolver(id) end
        end
    })
    if modo == 'livre' then
        connect(rootWidget, {onGeometryChange = function() scheduleEvent(cuidarDaTelaCheia, 150) end})
    end
end
