
-- JV Baiak: ajustes do jogo no navegador/celular (adicionado na montagem do cliente web)
-- Esconde o painel de baixo da tela de login (noticias e "boosted creature"):
-- ele depende de um servico web que o Baiak 8.60 nao tem e so mostrava aviso em ingles.
if modules.client_bottommenu and modules.client_bottommenu.hide then
    modules.client_bottommenu.show = function() end
    pcall(modules.client_bottommenu.hide)
end

-- Esconde o texto tecnico da versao no canto da tela de login
pcall(function()
    local rotulo = rootWidget:recursiveGetChildById('clientVersionLabel')
    if rotulo then rotulo:hide() end
end)

-- Tela do jogo como no Tibia original ao entrar: a janela do bot (vBot) fica fechada
-- (abre pelo botao "Bot" do menu quando o jogador quiser) e, no celular, o joystick
-- comeca escondido: anda tocando no mapa, como no Tibia.
do
    local function fecharBot()
        local bot = modules.game_bot
        if not bot then return end
        pcall(function()
            if bot.botWindow and bot.botWindow:isVisible() then
                bot.botWindow:close()
            end
            if bot.botButton then bot.botButton:setOn(false) end
        end)
    end
    local function esconderJoystick()
        local j = modules.game_joystick
        if g_platform.isMobile() and j and j.hide then pcall(j.hide) end
    end
    connect(g_game, {
        onGameStart = function()
            scheduleEvent(function() fecharBot(); esconderJoystick() end, 1500)
            scheduleEvent(function() fecharBot(); esconderJoystick() end, 4000)
        end
    })
end

-- Botao "Trocar roupa": abre a janela de outfits a qualquer hora (como "Set Outfit"
-- ao segurar o dedo no proprio personagem). Mostra os outfits e addons liberados.
pcall(function()
    local painel = modules.game_mainpanel
    if painel and painel.addToggleButton then
        local botao
        botao = painel.addToggleButton('jvRoupaButton', tr('Trocar roupa (outfit)'), '/images/options/jv_roupa',
            function()
                if g_game.isOnline() then g_game.requestOutfit() end
                if botao then botao:setOn(false) end
            end, false, 5)
    end
end)

-- Fundo da tela de login: arte inteira em pe e deitado (troca ao girar o celular)
pcall(function()
    local function ajustarFundo()
        local fundo = rootWidget:recursiveGetChildById('background')
        if not fundo then return end
        local tam = g_window.getSize()
        if tam.height > tam.width and g_resources.fileExists('/images/background-em-pe.png') then
            fundo:setImageSource('/images/background-em-pe')
        else
            fundo:setImageSource('/images/background')
        end
    end
    -- confere a cada segundo (barato) se o celular girou
    local ultimo = nil
    cycleEvent(function()
        local tam = g_window.getSize()
        local emPe = tam.height > tam.width
        if emPe ~= ultimo then
            ultimo = emPe
            ajustarFundo()
        end
    end, 1000)
end)

-- Celular: se a conexao cair (tela bloqueada, troca de Wi-Fi/4G), entra de novo sozinho
if g_platform.isMobile() and g_settings.get('autoReconnect', 'nunca-definido') == 'nunca-definido' then
    g_settings.set('autoReconnect', true)
end

-- Interface de toque: uma pagina lateral por vez e atalhos fora do equipamento.
-- Os widgets continuam sendo os do Tibia; os menus HTML so enviam atalhos locais.
if g_platform.isMobile() then
    JVToque = {pagina = 'maininventorypanel'}
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
    local function prepararMapa(panel)
        if panel.jvPreparado then return end
        panel.jvPreparado = true
        for _, child in ipairs(panel:getChildren()) do child:hide() end
        local border = panel:getChildById('minimapBorder')
        if border then border:show(); border:setWidth(160); border:setHeight(70); border:setMarginTop(40) end
        local m = modules.game_minimap
        local comandos = {{'+', m.zoomIn}, {'-', m.zoomOut}, {'Centro', m.resetMap}, {'Acima', m.upLayer}, {'Abaixo', m.downLayer}}
        for i, c in ipairs(comandos) do
            botao(panel, 'jvMapa' .. i, c[1], 8 + ((i - 1) % 3) * 54, 116 + math.floor((i - 1) / 3) * 38, c[2])
        end
        panel.jvAltura = 192
    end
    local function prepararEquipamento(panel)
        if panel.jvPreparado then return end
        panel.jvPreparado = true
        if not panel:isOn() then modules.game_inventory.changeInventorySize() end
        -- Os controles pequenos de combate passam para a pagina Combate.
        local function esconderPequenos(w)
            for _, child in ipairs(w:getChildren()) do
                local class = child:getClassName()
                if (class == 'UIButton' or class == 'UICheckBox') and
                    (child:getWidth() < 32 or child:getHeight() < 32) then child:hide()
                else esconderPequenos(child) end
            end
        end
        esconderPequenos(panel)
        panel.jvAltura = 162
    end
    local function prepararOpcoes(panel)
        local on = panel:getChildById('onPanel')
        local off = panel:getChildById('offPanel')
        panel:setOn(true); on:show(); off:hide()
        local options, specials, store = on.options, on.specials, on.store
        local counts = {}
        for i, group in ipairs({options, specials}) do
            group:getLayout():setCellSize({width = 32, height = 32})
            local count = 0
            for _, child in ipairs(group:getChildren()) do
                child:setSize({width = 32, height = 32})
                child:setImageRepeated(false)
                if child:isVisible() then count = count + 1 end
            end
            counts[i] = count
        end
        for _, child in ipairs(store:getChildren()) do child:setHeight(32); child:setImageRepeated(false) end
        store:setHeight(32)
        local resizer = on:getChildById('resizer')
        if resizer then resizer:hide() end
        panel.jvAltura = 50 + math.max(math.ceil(counts[1] / 3), counts[2]) * 34
    end
    function JVToque.selecionar(pagina, abrir)
        if not g_game.isOnline() then return end
        local main = modules.game_interface.getMainRightPanel()
        if not main then return end
        local escolhido = main:getChildById(pagina)
        if not escolhido then return end
        local root = modules.game_interface.getRootPanel()
        local retrato = root:getWidth() < root:getHeight()
        if JVToque.retrato ~= retrato then
            JVToque.retrato = retrato
            JVToque.aberto = not retrato
        end
        if abrir then JVToque.aberto = true end
        JVToque.pagina = pagina
        escolhido:show()
        escolhido:setDraggable(false)
        if pagina == 'maininventorypanel' then prepararEquipamento(escolhido)
        elseif pagina == 'mainmappanel' then prepararMapa(escolhido)
        elseif pagina == 'mainoptionspanel' then prepararOpcoes(escolhido) end
        for _, child in ipairs(main:getChildren()) do child:setVisible(child == escolhido) end
        escolhido:setHeight(escolhido.jvAltura or 162)
        main:setHeight(JVToque.aberto and escolhido:getHeight() + 1 or 0)
        main:setWidth(JVToque.aberto and 176 or 0)
        main:setVisible(JVToque.aberto)
        main:setClipping(true)
        -- Em pe, o equipamento abre pelo menu; fechado, devolve a largura ao mapa.
        local right = modules.game_interface.getRightPanel()
        if right then
            right:setClipping(true)
            right:setWidth(JVToque.aberto and 176 or 0)
            right:setVisible(JVToque.aberto)
        end
        local shortcuts = modules.game_shortcuts.getPanel()
        if shortcuts then
            shortcuts:breakAnchors()
            shortcuts:addAnchor(AnchorBottom, 'parent', AnchorBottom)
            shortcuts:addAnchor(retrato and AnchorHorizontalCenter or AnchorRight, 'parent', retrato and AnchorHorizontalCenter or AnchorRight)
        end
        modules.game_interface.updateStretchShrink()
    end
    function JVToque.fechar()
        local root = modules.game_interface.getRootPanel()
        if root:getWidth() >= root:getHeight() then return end
        JVToque.aberto = false
        JVToque.selecionar(JVToque.pagina)
    end
    local function prepararCombate()
        local main = modules.game_interface.getMainRightPanel()
        if main:getChildById('jvCombate') then return end
        local panel = g_ui.createWidget('PhantomMiniWindow', main)
        panel:setId('jvCombate'); panel:setHeight(184); panel.jvAltura = 184; panel.panelHeight = 184
        -- O contenedor usa verticalBox; ele posiciona a janela lateral.
        panel:setWidth(176)
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
        for i, a in ipairs(acoes) do botao(panel, 'jvCombate' .. i, a[1], 8 + ((i - 1) % 3) * 54, 44 + math.floor((i - 1) / 3) * 46, a[2]) end
        panel:hide()
    end
    for key, pagina in pairs({F8='maininventorypanel', F9='mainmappanel', F10='mainoptionspanel', F11='jvCombate'}) do
        local destino = pagina
        g_keyboard.bindKeyDown('Ctrl+Shift+' .. key, function() JVToque.selecionar(destino, true) end, rootWidget)
    end
    g_keyboard.bindKeyDown('Ctrl+Shift+F12', JVToque.fechar, rootWidget)
    connect(rootWidget, {onGeometryChange = function()
        scheduleEvent(function() JVToque.selecionar(JVToque.pagina) end, 100)
    end})
    connect(g_game, {onGameStart = function()
        scheduleEvent(function() prepararCombate(); JVToque.selecionar('maininventorypanel') end, 1600)
        scheduleEvent(function() JVToque.selecionar(JVToque.pagina) end, 4200)
    end})
end

-- A escala de combate nao pode ampliar o formulario de entrada.
if g_platform.isMobile() then
    JVLogin = {}
    local function posicionar(widget, leftId, topId, topEdge, top, height)
        widget:breakAnchors()
        widget:addAnchor(AnchorLeft, leftId, AnchorLeft)
        widget:addAnchor(AnchorRight, 'parent', AnchorRight)
        widget:addAnchor(AnchorTop, topId, topEdge)
        widget:setMarginTop(top); widget:setHeight(height)
    end
    function JVLogin.ajustar()
        if g_game.isOnline() then return end
        if math.abs(g_window.getDisplayDensity() - 1) > 0.001 then g_app.setHUDScale(1) end
        local win = rootWidget:recursiveGetChildById('enterGame')
        if not win or not win:isVisible() then return end
        local width, height = rootWidget:getWidth(), rootWidget:getHeight()
        local compact = height < 360
        win:setText('Entrar no JV Baiak')
        win:setWidth(math.max(160, math.min(360, width - 24)))
        win:setHeight(compact and 200 or 304)
        local accountLabel, passwordLabel = win.emailLabel, win.passwordLabel
        local account, password = win.accountNameTextEdit, win.accountPasswordTextEdit
        local remember, auto, login = win.rememberEmailBox, win.autoLoginBox, win.jvLoginButton
        if not (accountLabel and passwordLabel and account and password and remember and auto and login) then return end
        local keep = {emailLabel=true,passwordLabel=true,accountNameTextEdit=true,accountPasswordTextEdit=true,rememberEmailBox=true,autoLoginBox=true,jvLoginButton=true}
        for _, child in ipairs(win:getChildren()) do if not keep[child:getId()] then child:hide() end end
        accountLabel:breakAnchors(); accountLabel:addAnchor(AnchorLeft,'parent',AnchorLeft); accountLabel:addAnchor(AnchorTop,'parent',AnchorTop)
        accountLabel:setText('Conta'); accountLabel:setWidth(62); accountLabel:setHeight(44)
        passwordLabel:breakAnchors(); passwordLabel:addAnchor(AnchorLeft,'parent',AnchorLeft); passwordLabel:addAnchor(AnchorTop,'emailLabel',AnchorBottom)
        passwordLabel:setMarginTop(8); passwordLabel:setText('Senha'); passwordLabel:setWidth(62); passwordLabel:setHeight(44)
        for _, row in ipairs({{account,'emailLabel'}, {password,'passwordLabel'}}) do
            local input, label = row[1], row[2]
            input:breakAnchors(); input:addAnchor(AnchorLeft,label,AnchorRight); input:addAnchor(AnchorRight,'parent',AnchorRight); input:addAnchor(AnchorTop,label,AnchorTop)
            input:setMarginLeft(8); input:setHeight(44)
            for _, child in ipairs(input:getChildren()) do
                if child:getClassName() == 'UIButton' then child:setSize({width=44,height=44}); child:setImageRepeated(false); input:setPaddingRight(48) end
            end
        end
        remember:setText('Salvar conta'); auto:setText('Entrar automaticamente')
        remember:setVisible(not compact); auto:setVisible(not compact)
        posicionar(remember,'parent','passwordLabel',AnchorBottom,8,44)
        posicionar(auto,'parent','rememberEmailBox',AnchorBottom,4,44)
        posicionar(login,'parent',compact and 'passwordLabel' or 'autoLoginBox',AnchorBottom,8,44)
        login:setText('Entrar'); login:show()
        win:setPosition({x=math.floor((width-win:getWidth())/2),y=math.floor((height-win:getHeight())/2)})
        win:bindRectToParent()
        -- Diagnostico local de geometria; nao registra texto, conta nem senha.
        local assinatura = width .. ':' .. height .. ':' .. win:getWidth() .. ':' .. win:getHeight()
        if JVLogin.ultimaGeometria ~= assinatura and g_logger and g_logger.info then
            JVLogin.ultimaGeometria = assinatura
            scheduleEvent(function()
                local function rect(w) return string.format('%d,%d,%d,%d',w:getX(),w:getY(),w:getWidth(),w:getHeight()) end
                g_logger.info(string.format('JV_LOGIN_LAYOUT root=%d,%d win=%s account=%s password=%s login=%s',
                    rootWidget:getWidth(),rootWidget:getHeight(),rect(win),rect(account),rect(password),rect(login)))
            end, 100)
        end
    end
    -- As opcoes antigas aplicam HUD Scale com atraso de 250 ms. Conferir somente
    -- fora do jogo evita que esse atraso volte a cortar a tela de login.
    cycleEvent(JVLogin.ajustar, 300)
    connect(g_app, {onRun=function() addEvent(JVLogin.ajustar) end})
    connect(g_game, {onGameEnd=function() addEvent(JVLogin.ajustar) end, onGameStart=function()
        if g_logger and g_logger.info then g_logger.info('JV_WEB_GAME_READY') end
    end})
end

-- Marcadores opcionais para conferir o toque no proprio aparelho, sem enviar dados.
if g_platform.isMobile() then
    local mostrarToque = false
    g_keyboard.bindKeyDown('Ctrl+Shift+F6', function() mostrarToque = not mostrarToque end, rootWidget)
    connect(g_game, {onGameStart=function()
        scheduleEvent(function()
            local map = modules.game_interface.getMapPanel()
            if not map or map.jvToqueObservado then return end
            map.jvToqueObservado = true
            local original = map.onMousePress
            map.onMousePress = function(self, point, button)
                if mostrarToque then
                    local target = self:getPosition(point)
                    local rect = target and self:getTileRect(target)
                    if rect and rect.width > 0 and rect.height > 0 then
                        local size = rootWidget:getSize()
                        g_logger.info(string.format('JV_TOUCH_TARGET root=%d,%d rect=%d,%d,%d,%d', size.width,size.height,rect.x,rect.y,rect.width,rect.height))
                    end
                end
                return original(self, point, button)
            end
        end, 500)
    end})
end
