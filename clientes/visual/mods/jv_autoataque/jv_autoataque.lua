-- JV Baiak: CACA AUTOMATICA, no estilo dos "Tibia idle" (jogo no navegador e apps PC/Android)
-- Ligada (botao de espada no menu; no celular ja comeca ligada):
--  * ataca sozinho o monstro mais perto (ate 7 quadrados, mesmo andar) e vai atras dele;
--  * magias de ataque: feitas pelo SERVIDOR (!automagia), que o botao liga junto;
--  * a CURA (magias de cura e pocoes) e separada e tambem fica no servidor (!autocura,
--    botao da pocao no celular): funciona com a espada ligada ou desligada;
--  * nunca ataca jogadores e nao faz nada em zona de protecao.
-- O loot de moedas vai sozinho para a mochila pelo autoloot do servidor.
-- Sinal "estou na tela" (opcode 80) a cada 2 s: com o jogo fora da tela (outro app, tela
-- bloqueada) o sinal para e o servidor protege o personagem dos monstros (jv_ausente.lua).
-- Mesmo arquivo em web/ e em clientes/visual/mods/jv_autoataque/ (o teste confere).
JVAutoAtaque = JVAutoAtaque or {}
local A = JVAutoAtaque
local ALCANCE = 7
local INTERVALO = 400
local SINAL = 80

local function mobile()
    if g_platform and g_platform.isMobile then return g_platform.isMobile() end
    if g_app and g_app.isMobile then return g_app.isMobile() end
    return false
end

local function aviso(texto)
    pcall(function()
        if modules.game_textmessage and modules.game_textmessage.displayStatusMessage then
            modules.game_textmessage.displayStatusMessage(texto)
        end
    end)
end

local function lerLigado()
    local v = g_settings.get('jvAutoAtaque', 'padrao')
    if v == 'padrao' or v == '' then return mobile() end
    return v == 'true' or v == true
end

local function naProtecao(player)
    local ok, pz = pcall(function() return player:hasState(PlayerStates.Pz) end)
    return ok and pz
end

local function marcar(botao, ligado)
    if not botao then return end
    pcall(function() botao:setOn(ligado) end)
    pcall(function() botao:setChecked(ligado) end)
end

A.ignorar = {}
A.tentativa = nil
local function maisPerto(player)
    local pos = player:getPosition()
    if not pos then return nil end
    local agora = g_clock.millis()
    local melhor, melhorDist
    local criaturas = g_map.getSpectators(pos, false) or {}
    for _, c in ipairs(criaturas) do
        if c:isMonster() and c:getHealthPercent() > 0 then
            local p = c:getPosition()
            local id = c:getId()
            if p and p.z == pos.z and not (A.ignorar[id] and A.ignorar[id] > agora) then
                local d = math.max(math.abs(p.x - pos.x), math.abs(p.y - pos.y))
                if d <= ALCANCE and (not melhor or d < melhorDist) then
                    melhor, melhorDist = c, d
                end
            end
        end
    end
    return melhor
end

local function ciclo()
    if not A.ligado or not g_game.isOnline() then return end
    local player = g_game.getLocalPlayer()
    if not player or naProtecao(player) then return end
    if g_game.isAttacking() then
        A.tentativa = nil -- deu certo: esta atacando
        return
    end
    local alvo = maisPerto(player)
    if not alvo then return end
    local id = alvo:getId()
    if A.tentativa == id then
        -- o servidor recusou (sem caminho, fora de alcance...): deixa esse de lado por 10 s
        A.ignorar[id] = g_clock.millis() + 10000
        A.tentativa = nil
        return
    end
    A.tentativa = id
    pcall(function() g_game.setChaseMode(1) end) -- vai atras do monstro
    g_game.attack(alvo)
end

local function avisarServidor()
    -- as magias automaticas (ataque e cura) ficam no servidor: liga/desliga junto
    if g_game.isOnline() then pcall(g_game.talk, A.ligado and '!automagia on' or '!automagia off') end
end

function A.definir(ligado)
    A.ligado = ligado
    g_settings.set('jvAutoAtaque', ligado and 'true' or 'false')
    avisarServidor()
    marcar(A.botao, ligado)
    if g_game.isOnline() then
        aviso(ligado and 'Caca automatica LIGADA (ataca e usa magias de ataque sozinho)' or 'Caca automatica DESLIGADA')
    end
end

function A.iniciar()
    if A.evento then return end
    A.ligado = lerLigado()
    local function alternar() A.definir(not A.ligado) end
    pcall(function()
        local menu = modules.client_topmenu
        local painel = modules.game_mainpanel
        if menu and menu.addLeftGameToggleButton then -- aplicativos PC/Android (OTClientV8)
            A.botao = menu.addLeftGameToggleButton('jvAutoAtaque', tr('Caca automatica'),
                '/images/topbuttons/combatcontrols', alternar)
        elseif painel and painel.addToggleButton then -- navegador
            A.botao = painel.addToggleButton('jvAutoAtaqueButton', tr('Caca automatica'),
                '/images/options/jv_autoataque', alternar, false, 6)
        end
        marcar(A.botao, A.ligado)
    end)
    A.evento = cycleEvent(ciclo, INTERVALO)
    connect(g_game, { onGameStart = function() scheduleEvent(avisarServidor, 3000) end })
    -- sinal "estou na tela" para o servidor; a resposta prova que a conexao esta viva
    pcall(ProtocolGame.registerExtendedOpcode, SINAL, function(protocol, opcode, buffer)
        local agora = g_clock.millis()
        -- avisa a pagina (shell.html) so quando volta depois de um tempo sem resposta
        if agora - (A.ultimoEco or 0) > 6000 then g_logger.info('JV_VIVO') end
        A.ultimoEco = agora
    end)
    A.sinal = cycleEvent(function()
        if not g_game.isOnline() then return end
        local p = g_game.getProtocolGame and g_game.getProtocolGame()
        if p and p.sendExtendedOpcode then pcall(function() p:sendExtendedOpcode(SINAL, 'v') end) end
    end, 2000)
end

function A.parar()
    if A.evento then removeEvent(A.evento) end
    A.evento = nil
    if A.sinal then removeEvent(A.sinal) end
    A.sinal = nil
    pcall(ProtocolGame.unregisterExtendedOpcode, SINAL)
    if A.botao then pcall(function() A.botao:destroy() end) end
    A.botao = nil
end
