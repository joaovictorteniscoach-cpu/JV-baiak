
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

-- Celular: tela do jogo mais limpa ao entrar. A janela do bot (vBot) fica fechada;
-- ela abre pelo botao "Bot" do menu quando o jogador quiser.
if g_platform.isMobile() then
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
    connect(g_game, {
        onGameStart = function()
            scheduleEvent(fecharBot, 1500)
            scheduleEvent(fecharBot, 4000)
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
