-- JV Baiak: TRES LAYOUTS NO CELULAR (jogo no navegador). Troca pelo menu: "Trocar layout".
--   livre    = Tela cheia: o mapa ocupa a tela toda e as janelas (equipamento, minimapa,
--              skills, combate, mochilas, battle...) abrem SOLTAS por cima do mapa: arraste
--              pela barra do titulo, feche no X, encolha no "-" e mude o tamanho puxando
--              a alca "<>" do canto de baixo (o tamanho fica salvo).
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
        {'Parar', function()
            if JVAutoAtaque and JVAutoAtaque.pararCombate then JVAutoAtaque.pararCombate()
            else g_game.cancelAttack(); g_game.cancelFollow() end
        end}
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
    -- nao deixa a janela entrar embaixo dos botoes Attack/Follow/Look/Use (eles ficam por cima
    -- e roubavam o toque no "-", no X e na alca)
    local limite = r:getY() + r:getHeight()
    pcall(function()
        local sc = modules.game_shortcuts.getPanel()
        if sc and sc:isVisible() and x + w:getWidth() > sc:getX() and x < sc:getX() + sc:getWidth() then
            limite = math.min(limite, sc:getY())
        end
    end)
    local y = math.max(r:getY(), math.min(w:getY(), limite - w:getHeight()))
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

-- ------------------------------------------------------------- escala da janela inteira
-- Puxar a alca "<>" do canto AUMENTA ou DIMINUI a janela toda na mesma proporcao:
-- titulo, letras, itens, botoes e espacos encolhem juntos (nada e cortado).
-- o tamanho original fica guardado no proprio widget (w.jvOrig): o Lua recebe um objeto novo
-- a cada getChildren(), entao uma tabela indexada pelo objeto nao reconhece o mesmo widget
local MINF, MAXF = 0.5, 1.4
local function arred(n) return math.floor(n + 0.5) end

local function original(w)
    local o = w.jvOrig
    if o then return o end
    o = {w = w:getWidth(), h = w:getHeight(),
         m = {w:getMarginTop(), w:getMarginRight(), w:getMarginBottom(), w:getMarginLeft()},
         p = {w:getPaddingTop(), w:getPaddingRight(), w:getPaddingBottom(), w:getPaddingLeft()}}
    pcall(function() local t = w:getTextOffset(); if t and (t.x ~= 0 or t.y ~= 0) then o.to = {x = t.x, y = t.y} end end)
    pcall(function() local fo = w:getFont(); if type(fo) == 'string' and fo ~= '' then o.fonte = fo end end)
    pcall(function() local z = w:getImageSize(); if z and z.width > 0 and z.height > 0 then o.is = {width = z.width, height = z.height} end end)
    pcall(function()
        local lay = w:getLayout()
        if lay and lay.isUIGridLayout and lay:isUIGridLayout() then
            local c = lay:getCellSize()
            o.cel = {width = c.width, height = c.height}
            o.esp = lay:getCellSpacing()
        end
    end)
    w.jvOrig = o
    return o
end

local function escalarArvore(w, f, topo)
    if w.jvNaoEscalar then return end
    local o = original(w)
    if w ~= topo then
        w:setMarginTop(arred(o.m[1] * f)); w:setMarginRight(arred(o.m[2] * f))
        w:setMarginBottom(arred(o.m[3] * f)); w:setMarginLeft(arred(o.m[4] * f))
        if o.w > 0 then w:setWidth(math.max(1, arred(o.w * f))) end
        if o.h > 0 then w:setHeight(math.max(1, arred(o.h * f))) end
    end
    w:setPaddingTop(arred(o.p[1] * f)); w:setPaddingRight(arred(o.p[2] * f))
    w:setPaddingBottom(arred(o.p[3] * f)); w:setPaddingLeft(arred(o.p[4] * f))
    -- letras: o "font scale" do jogo estraga o desenho no celular (escala da tela), entao a
    -- letra diminui trocando para a mesma fonte num tamanho menor
    if o.fonte then
        local nova = o.fonte
        if f < 0.6 then nova = 'cipsoftFont'
        elseif f < 0.72 then nova = 'Verdana-8px-antialiased'
        elseif f < 0.85 then nova = 'Verdana-9px-antialiased'
        elseif f < 0.95 then nova = 'Verdana-10px-antialiased' end
        if w.jvFonte ~= nova then
            w.jvFonte = nova
            pcall(function() w:setFont(nova) end)
        end
    end
    if o.to then pcall(function() w:setTextOffset({x = arred(o.to.x * f), y = arred(o.to.y * f)}) end) end
    if o.is then pcall(function() w:setImageSize({width = arred(o.is.width * f), height = arred(o.is.height * f)}) end) end
    if o.cel then
        pcall(function()
            local lay = w:getLayout()
            lay:setCellSize({width = arred(o.cel.width * f), height = arred(o.cel.height * f)})
            if o.esp then lay:setCellSpacing(arred(o.esp * f)) end
        end)
    end
    for _, c in ipairs(w:getChildren()) do escalarArvore(c, f, topo) end
end

-- aplica a escala f na janela inteira (w) e guarda para a proxima vez
local function escalar(w, f, chave)
    f = math.max(MINF, math.min(MAXF, f))
    local o = original(w)
    w.jvEscala = f
    escalarArvore(w, f, w)
    if not w.jvEncolhida then
        w:setSize({width = arred(o.w * f), height = arred(o.h * f)})
    else
        w:setSize({width = arred(o.w * f), height = arred(w.jvAlturaEncolhida * f)})
    end
    if chave then pcall(function() g_settings.set('jvEscala_' .. chave, string.format('%.2f', f)) end) end
end

local function escalaSalva(chave)
    local v = tonumber(g_settings.get('jvEscala_' .. chave) or '')
    if v and v >= MINF and v <= MAXF then return v end
    return nil
end

-- alca "<>" no canto de baixo: arraste para a esquerda/cima diminui, para a direita/baixo aumenta
local function colocarAlca(w, chave)
    if w:getChildById('jvAlca') then return end
    local alca = g_ui.createWidget('UIButton', w)
    alca:setId('jvAlca')
    alca.jvNaoEscalar = true
    alca:setSize({width = 18, height = 18})
    alca:addAnchor(AnchorBottom, 'parent', AnchorBottom); alca:addAnchor(AnchorRight, 'parent', AnchorRight)
    alca:setMarginBottom(-(w:getPaddingBottom())); alca:setMarginRight(-(w:getPaddingRight()))
    alca:setBackgroundColor('#00000066')
    alca:setBorderWidth(1); alca:setBorderColor('#c0a060')
    alca:setText('<>'); alca:setColor('#f0d890')
    pcall(function() alca:setFont('cipsoftFont') end)
    alca:setDraggable(true)
    alca.onDragEnter = function(self, pos)
        self.ini = {x = pos.x, y = pos.y, f = w.jvEscala or 1, w = w:getWidth(), h = w:getHeight()}
        return true
    end
    alca.onDragMove = function(self, pos)
        local i = self.ini
        if not i then return true end
        -- a distancia na diagonal decide o tamanho novo
        local d = ((pos.x - i.x) + (pos.y - i.y)) / 2
        escalar(w, i.f * (i.w + d) / i.w)
        return true
    end
    alca.onDragLeave = function(self)
        self.ini = nil
        escalar(w, w.jvEscala or 1, chave)
        dentroDaTela(w)
        g_logger.info(string.format('JV_JANELA_TAMANHO %d,%d escala=%.2f', w:getWidth(), w:getHeight(), w.jvEscala or 1))
        -- o primeiro item da janela (mochila/equipamento) tem que diminuir junto
        local function primeiroItem(x)
            for _, c in ipairs(x:getChildren()) do
                if c:getClassName() == 'UIItem' and c:getWidth() > 0 then return c end
                local achou = primeiroItem(c)
                if achou then return achou end
            end
        end
        local it = primeiroItem(w)
        if it then
            local o = it.jvOrig
            g_logger.info(string.format('JV_ITEM %s %d,%d orig=%d,%d', w:getId(), it:getWidth(), it:getHeight(),
                o and o.w or 0, o and o.h or 0))
        end
        return true
    end
    alca:raise()
end

-- barra do titulo no tamanho do Tibia (fina): nome, "-" (encolher) e X (fechar)
local function botaoTitulo(w, topo, id, clipX, depois)
    local b = g_ui.createWidget('UIButton', topo)
    b:setId(id)
    b:setSize({width = 14, height = 14})
    b:setImageSource('/images/ui/miniwindow_buttons')
    b:setImageClip({x = clipX, y = 0, width = 14, height = 14})
    b:addAnchor(AnchorTop, 'parent', AnchorTop)
    if depois then b:addAnchor(AnchorRight, depois, AnchorLeft); b:setMarginRight(2)
    else b:addAnchor(AnchorRight, 'parent', AnchorRight); b:setMarginRight(2) end
    b:setMarginTop(1)
    return b
end

-- Janela solta no estilo das janelinhas do Tibia: barra fina com o nome, "-" (encolher)
-- e X (fechar), arrasta pela barra e muda de tamanho inteira pela alca "<>".
-- Devolve a janela; o conteudo vai dentro dela (ja com as margens certas).
function L.novaJanela(id, texto, largura, altura, chave, aoFechar)
    local TOPO = 16
    local w = g_ui.createWidget('UIWindow', raiz() or rootWidget)
    w:setId(id)
    w:setImageSource('/images/ui/miniwindow_body'); w:setImageBorder(4)
    w:setPaddingTop(TOPO + 2); w:setPaddingLeft(3); w:setPaddingRight(3); w:setPaddingBottom(3)
    w:setSize({width = largura + 6, height = altura + TOPO + 5})
    w:setDraggable(true)
    local topo = g_ui.createWidget('UIWidget', w)
    topo:setId('jvTopo')
    topo:addAnchor(AnchorTop, 'parent', AnchorTop); topo:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    topo:addAnchor(AnchorRight, 'parent', AnchorRight)
    topo:setMarginTop(-(TOPO + 2)); topo:setMarginLeft(-3); topo:setMarginRight(-3)
    topo:setHeight(TOPO)
    topo:setImageSource('/images/ui/miniwindow_header'); topo:setImageBorder(4)
    -- a barra e "fantasma": tocar e arrastar nela move a janela; so o X e o "-" recebem o toque
    topo:setPhantom(true)
    local titulo = g_ui.createWidget('UILabel', topo)
    titulo:setId('jvTitulo')
    titulo:setText(texto)
    pcall(function() titulo:setFont('verdana-11px-antialised') end)
    titulo:setColor('#c0c0c0')
    titulo:setTextAutoResize(true)
    titulo:addAnchor(AnchorLeft, 'parent', AnchorLeft); titulo:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
    titulo:setMarginLeft(5)
    titulo:setPhantom(true)
    local x = botaoTitulo(w, topo, 'jvFechar', 28)
    x.onClick = function() if aoFechar then aoFechar() else w:hide() end end
    local menos = botaoTitulo(w, topo, 'jvEncolher', 0, 'jvFechar')
    menos.onClick = function()
        local f = w.jvEscala or 1
        local encolher = not w.jvEncolhida
        w.jvEncolhida = encolher
        for _, c in ipairs(w:getChildren()) do
            if c ~= topo then c:setVisible(not encolher) end
        end
        if encolher then
            w.jvAlturaEncolhida = TOPO + 2
            w:setHeight(arred((TOPO + 2) * f))
        else
            w:setHeight(arred(original(w).h * f))
        end
    end
    w.onDragLeave = function(self) dentroDaTela(self); return true end
    w.jvChave = chave
    return w
end

-- depois de colocar o conteudo: alca de tamanho e a escala que a pessoa deixou
-- tamanho de quem ainda nao mexeu na janela: um pouco menor que o normal (cabe melhor no celular)
local ESCALA_PADRAO = 0.8

function L.terminarJanela(w)
    colocarAlca(w, w.jvChave)
    escalar(w, (w.jvChave and escalaSalva(w.jvChave)) or ESCALA_PADRAO)
end

local function criarJanela(id)
    local main = gi().getMainRightPanel()
    local pagina = main and main:getChildById(id)
    if not pagina then return nil end
    local largura = math.max(pagina:getWidth(), 176)
    local altura = pagina.jvAltura or pagina:getHeight()
    if altura < 40 then altura = 162 end
    local w = L.novaJanela('jvJanela_' .. id, TITULOS[id] or id, largura, altura, id)
    pagina:setParent(w, true)
    pagina:breakAnchors()
    pagina:addAnchor(AnchorTop, 'parent', AnchorTop)
    pagina:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    pagina:setSize({width = largura, height = altura})
    pcall(function() pagina:setDraggable(false) end)
    pagina:show()
    L.janelas[id] = {janela = w, pagina = pagina}
    L.terminarJanela(w)
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
    if j and j.janela:isVisible() then j.janela:hide(); g_logger.info('JV_JANELA_FECHADA ' .. id); return end
    if not j then j = criarJanela(id) end
    if not j then return end
    j.janela:show(); j.janela:raise(); dentroDaTela(j.janela)
    local r, t = j.janela:getRect(), rootWidget:getSize()
    g_logger.info(string.format('JV_JANELA root=%d,%d rect=%d,%d,%d,%d', t.width, t.height, r.x, r.y, r.width, r.height))
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
                -- o painel esta escondido: isVisible() da falso para tudo dentro dele; o que vale e
                -- se a propria janela esta aberta (isExplicitlyVisible)
                local aberta = w.isExplicitlyVisible and w:isExplicitlyVisible() or w:isVisible()
                local id = w:getId()
                if aberta and w.close and (id == 'battleWindow' or id == 'vipWindow') and os.time() - (L.entrou or 0) < 10 then
                    -- a lista de batalha e a de amigos (VIP) abrem sozinhas ao entrar: ficam fechadas
                    -- para nao cobrir o mapa (abrem de novo em Opcoes do jogo)
                    pcall(function() w:close(true) end)
                elseif aberta and w.close then
                    local pos = lugarLivre(math.max(w:getWidth(), 176))
                    w:setParent(r, true)
                    w.free = true
                    pcall(function() w:breakAnchors() end)
                    -- dentro do painel escondido (largura 0) a janela tambem fica com largura 0
                    if w:getWidth() < 100 then pcall(function() w:setWidth(176) end) end
                    if w:getHeight() < 60 then pcall(function() w:setHeight(160) end) end
                    w:setPosition(pos)
                    L.soltas = (L.soltas or 0) + 1
                    -- mesma alca de tamanho das outras janelas (mochilas usam a mesma escala)
                    local chave = w:getId():match('^container') and 'mochila' or w:getId()
                    pcall(colocarAlca, w, chave)
                    pcall(escalar, w, escalaSalva(chave) or ESCALA_PADRAO)
                    pcall(function() w:raise() end)
                    dentroDaTela(w)
                    local r = w:getRect()
                    g_logger.info(string.format('JV_SOLTA %s rect=%d,%d,%d,%d', w:getId(), r.x, r.y, r.width, r.height))
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

-- ------------------------------------------------------------- mochila
-- botao "Mochila" do menu: abre a mochila principal (ou fecha, se ja estiver aberta)
function L.mochila()
    if not g_game.isOnline() then return end
    local pl = g_game.getLocalPlayer()
    local bp = pl and pl:getInventoryItem(InventorySlotBack)
    if not bp then
        pcall(modules.game_textmessage.displayFailureMessage, 'Voce nao esta usando mochila.')
        return
    end
    local fechou = false
    pcall(function()
        for _, c in pairs(g_game.getContainers()) do
            local item = c:getContainerItem()
            if not fechou and not c:hasParent() and item and item:getId() == bp:getId() then
                g_game.close(c); fechou = true
            end
        end
    end)
    if not fechou then g_game.open(bp) end
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

-- ------------------------------------------------------------- botoes de baixo
-- Atacar / Seguir / Olhar / Usar com icones nitidos (imagens 128px) e o botao Mochila.
-- Os que nao estao escolhidos ficam bem visiveis (antes ficavam apagados, 60%).
local function prepararAtalhos()
    local sc = modules.game_shortcuts
    local painel = sc and sc.getPanel and sc.getPanel()
    local icones = painel and painel:getChildById('shortcutIcons')
    if not icones then return end
    for _, b in ipairs(icones:getChildren()) do
        if b.image and not b.jvBrilho then
            b.jvBrilho = true
            local img = b.image
            local function clarear() if not img:isChecked() then img:setOpacity(0.92) end end
            connect(img, {onCheckChange = function() scheduleEvent(clarear, 1) end})
            clarear()
        end
    end
    if icones:getChildById('mochila') then return end
    local ok, m = pcall(function() return g_ui.createWidget('GameAction', icones) end)
    if not ok or not m then return end
    m:setId('mochila')
    m:addAnchor(AnchorTop, 'parent', AnchorTop); m:addAnchor(AnchorLeft, 'look', AnchorRight)
    m:setMarginTop(4); m:setMarginLeft(6)
    if m.image then
        m.image:setImageSource('/images/game/mobile/mochila')
        m.image:setOpacity(0.92)
    end
    m.onClick = function() pcall(L.mochila) end
    local usar = icones:getChildById('use')
    if usar then
        usar:breakAnchors()
        usar:addAnchor(AnchorTop, 'parent', AnchorTop); usar:addAnchor(AnchorLeft, 'mochila', AnchorRight)
        usar:setMarginTop(4); usar:setMarginLeft(6)
    end
    painel:setWidth(202)
end

function L.iniciar()
    if L.ligado or not (g_platform and g_platform.isMobile and g_platform.isMobile()) then return end
    L.ligado = true
    local modo = L.modo()
    g_logger.info('JV_LAYOUT ' .. modo)
    g_keyboard.bindKeyDown('Ctrl+Shift+F3', L.trocar, rootWidget)
    g_keyboard.bindKeyDown('Ctrl+Shift+F2', function() pcall(L.mochila) end, rootWidget)
    -- "Voltar ao mapa" tambem fecha a janelinha de conversa com NPC
    g_keyboard.bindKeyDown('Ctrl+Shift+F12', function() if JVNpc and JVNpc.fechar then JVNpc.fechar() end end, rootWidget)
    if modo ~= 'paginas' then
        -- no modo paginas estes atalhos ja sao do JVToque (otclientrc-extra.lua)
        for key, pagina in pairs({F8 = 'maininventorypanel', F9 = 'mainmappanel', F10 = 'mainoptionspanel', F11 = 'jvCombate'}) do
            local destino = pagina
            g_keyboard.bindKeyDown('Ctrl+Shift+' .. key, function() L.abrir(destino) end, rootWidget)
        end
        -- "Voltar ao mapa": fecha as janelas soltas, a conversa com NPC, Comandos e Autoloot
        g_keyboard.bindKeyDown('Ctrl+Shift+F12', function()
            L.fecharSoltas()
            if JVNpc and JVNpc.fechar then pcall(JVNpc.fechar) end
            for _, m in ipairs({JVRapido, JVAutoLoot}) do
                if m and m.janela and not m.janela:isDestroyed() then pcall(function() m.janela:hide() end); m.aberta = false end
            end
        end, rootWidget)
    end
    connect(g_game, {
        onGameStart = function()
            L.entrou = os.time()
            scheduleEvent(function() pcall(prepararAtalhos) end, 1200)
            scheduleEvent(function() pcall(prepararCombate) end, 1600)
            if modo == 'livre' then
                if L.evento then removeEvent(L.evento) end
                L.evento = cycleEvent(cuidarDaTelaCheia, 1000)
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
        -- mochila/corpo aberto: solta na hora (sem esperar a volta do relogio)
        pcall(function() connect(Container, {onOpen = function() scheduleEvent(cuidarDaTelaCheia, 30) end}) end)
    end
end
