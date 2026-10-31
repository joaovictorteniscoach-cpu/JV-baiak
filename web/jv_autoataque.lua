-- JV Baiak: CACA AUTOMATICA, no estilo dos "Tibia idle" (jogo no navegador e apps PC/Android)
-- Ligada (botao de espada no menu; no celular ja comeca ligada):
--  * ataca sozinho o monstro mais perto (ate 7 quadrados, mesmo andar) e vai atras dele;
--  * cura sozinho: vida abaixo de 60% -> pocao de vida (se estiver numa mochila aberta)
--    ou a magia "exura"; mana abaixo de 35% -> pocao de mana;
--  * nunca ataca jogadores e nao faz nada em zona de protecao.
-- O loot de moedas vai sozinho para a mochila pelo autoloot do servidor.
-- Mesmo arquivo em web/ e em clientes/visual/mods/jv_autoataque/ (o teste confere).
JVAutoAtaque = JVAutoAtaque or {}
local A = JVAutoAtaque
local ALCANCE = 7
local INTERVALO = 400

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
A.ultimaCura = 0
A.ultimaMana = 0

local POCOES_VIDA = {8473, 7591, 7588, 7618}   -- ultimate, great, strong, health
local POCOES_MANA = {7590, 7589, 7620}         -- great, strong, mana

local function acharPocao(lista)
    for _, id in ipairs(lista) do
        local ok, item = pcall(function() return g_game.findPlayerItem(id, -1) end)
        if ok and item then return item end
    end
    return nil
end

local function cuidar(player)
    local agora = g_clock.millis()
    local vida = player:getHealth() / math.max(1, player:getMaxHealth())
    if vida < 0.6 and agora - A.ultimaCura > 1100 then
        local pocao = acharPocao(POCOES_VIDA)
        if pocao then
            g_game.useWith(pocao, player)
        elseif player:getMana() >= 20 then
            g_game.talk('exura')
        end
        A.ultimaCura = agora
        return
    end
    local mana = player:getMana() / math.max(1, player:getMaxMana())
    if mana < 0.35 and agora - A.ultimaMana > 1100 then
        local pocao = acharPocao(POCOES_MANA)
        if pocao then g_game.useWith(pocao, player) end
        A.ultimaMana = agora
    end
end

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
    pcall(cuidar, player)
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

function A.definir(ligado)
    A.ligado = ligado
    g_settings.set('jvAutoAtaque', ligado and 'true' or 'false')
    marcar(A.botao, ligado)
    if g_game.isOnline() then
        aviso(ligado and 'Caca automatica LIGADA (ataca e cura sozinho)' or 'Caca automatica DESLIGADA')
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
end

function A.parar()
    if A.evento then removeEvent(A.evento) end
    A.evento = nil
    if A.botao then pcall(function() A.botao:destroy() end) end
    A.botao = nil
end
