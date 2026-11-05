-- JV Baiak: MAGIAS NA BARRA DE ATALHOS SOZINHAS (jogo no navegador)
-- O servidor manda (opcode 77) a lista das magias que o personagem ja pode usar; cada magia
-- nova vai para um espaco vazio da barra de baixo. E so tocar para lancar (as palavras
-- aparecem em cima do personagem). Se voce tirar uma magia da barra, ela nao volta.
-- HOTKEYS SALVAS NA HORA: o jogo original so grava a barra (e o minimapa) ao fechar o
-- programa; no navegador a pagina nunca "fecha" (o celular congela/recarrega a aba), entao
-- a barra voltava vazia toda vez. Agora cada mudanca na barra e gravada em seguida, e o
-- minimapa a cada 3 minutos e ao sair.
JVBarra = JVBarra or {}
local B = JVBarra
local OPCODE = 77
local ORDEM = {healing = 1, attack = 2, support = 3}

local function chaveDoPersonagem()
    local ok, nome = pcall(g_game.getCharacterName)
    return 'jvBarra_' .. ((ok and nome) or ''):gsub('[^%w]', '_')
end

local function jaPostas()
    local ok, t = pcall(function() return g_settings.getNode(chaveDoPersonagem()) end)
    return (ok and type(t) == 'table') and t or {}
end

local function textoDoBotao(Api, barId, btnId)
    local ok, m = pcall(Api.getMapping, barId, btnId)
    local a = ok and m and m.actionsetting
    return a and a.chatText
end

-- coloca as magias da lista nos espacos vazios da barra 1; devolve quantas colocou (nil = barra nao pronta)
local function colocar(lista)
    local AB = modules.game_actionbar
    if not AB or not AB.ApiJson or not AB.actionBars or not AB.updateButton then return nil end
    local Api = AB.ApiJson
    local barra = AB.actionBars[1]
    if not barra or not barra.tabBar or #barra.tabBar:getChildren() == 0 then return nil end
    local naBarra, livres = {}, {}
    for barId = 1, 9 do
        local b = AB.actionBars[barId]
        if b and b.tabBar then
            for _, botao in ipairs(b.tabBar:getChildren()) do
                local bi, ki = botao:getId():match('^(%d+)%.(%d+)$')
                if bi then
                    local texto = textoDoBotao(Api, tonumber(bi), tonumber(ki))
                    if texto then
                        naBarra[texto:lower()] = true
                    elseif barId == 1 then
                        local ok, m = pcall(Api.getMapping, tonumber(bi), tonumber(ki))
                        local vazio = not (ok and m) and botao.item and botao.item:getItemId() == 0
                        if vazio then livres[#livres + 1] = {botao = botao, bar = tonumber(bi), id = tonumber(ki)} end
                    end
                end
            end
        end
    end
    table.sort(livres, function(a, b) return a.id < b.id end)
    table.sort(lista, function(a, b)
        local oa, ob = ORDEM[a.grupo] or 4, ORDEM[b.grupo] or 4
        if oa ~= ob then return oa < ob end
        return a.level > b.level
    end)
    local postas = jaPostas()
    local n = 0
    for _, m in ipairs(lista) do
        if #livres == 0 then break end
        local p = m.palavras:lower()
        if not naBarra[p] and not postas[p] then
            local l = table.remove(livres, 1)
            pcall(Api.createOrUpdateText, l.bar, l.id, m.palavras, true)
            pcall(AB.updateButton, l.botao)
            postas[p] = true
            naBarra[p] = true
            n = n + 1
        end
    end
    if n > 0 then
        pcall(Api.saveData)
        pcall(function() g_settings.setNode(chaveDoPersonagem(), postas); g_settings.save() end)
    end
    return n
end

local function receber(texto)
    local lista = {}
    for parte in tostring(texto or ''):gmatch('[^|]+') do
        local palavras, grupo, level = parte:match('^(.-);(.-);(%d+)$')
        if palavras and palavras ~= '' then lista[#lista + 1] = {palavras = palavras, grupo = grupo, level = tonumber(level)} end
    end
    B.ultima = lista
    local tentativas = 0
    local function tentar()
        tentativas = tentativas + 1
        local ok, n = pcall(colocar, lista)
        if ok and n ~= nil then
            g_logger.info(string.format('JV_BARRA %d de %d magias', n, #lista))
        elseif tentativas < 6 then
            scheduleEvent(tentar, 2000)
        end
    end
    tentar()
end

-- grava a barra logo depois de qualquer mudanca (colocar, tirar, arrastar, trocar o conjunto)
local function salvarBarraJa()
    local AB = modules.game_actionbar
    local Api = AB and AB.ApiJson
    if not Api or not Api.saveData then return end
    if B.salvar then removeEvent(B.salvar) end
    B.salvar = scheduleEvent(function()
        B.salvar = nil
        if pcall(Api.saveData) then g_logger.info('JV_BARRA_SALVA') end
    end, 700)
end
B.salvarBarraJa = salvarBarraJa

local function vigiarBarra()
    local AB = modules.game_actionbar
    local Api = AB and AB.ApiJson
    if not Api or Api.jvVigiada then return end
    Api.jvVigiada = true
    for _, nome in ipairs({'createOrUpdateText', 'createOrUpdateAction', 'createOrUpdatePassive',
                           'createOrUpdateSpecialAction', 'createOrUpdateMultiAction', 'removeAction',
                           'setCurrentHotkeySetName', 'createHotkeySet', 'renameHotkeySet', 'removeHotkeySet'}) do
        local original = Api[nome]
        if type(original) == 'function' then
            Api[nome] = function(...)
                local r = {original(...)}
                salvarBarraJa()
                return unpack(r)
            end
        end
    end
end

local function salvarMinimapa()
    pcall(function()
        local m = modules.game_minimap
        local c = m and m.mapController
        if c and c.onGameEnd and g_game.isOnline() then
            -- o mesmo que o jogo faz ao sair (minimapa explorado e marcas)
            c:onGameEnd()
        end
    end)
end

function B.iniciar()
    if B.ligado then return end
    if not ProtocolGame or not ProtocolGame.registerExtendedOpcode then return end
    B.ligado = true
    pcall(ProtocolGame.registerExtendedOpcode, OPCODE, function(protocol, opcode, buffer) receber(buffer) end)
    -- voltou ao jogo (reconectou): pede a lista de novo
    pcall(vigiarBarra)
    connect(g_game, { onGameEnd = function()
        local AB = modules.game_actionbar
        if AB and AB.ApiJson and AB.ApiJson.saveData then pcall(AB.ApiJson.saveData) end
        if B.minimapa then removeEvent(B.minimapa) end
        B.minimapa = nil
    end })
    connect(g_game, { onGameStart = function()
        pcall(vigiarBarra)
        if B.minimapa then removeEvent(B.minimapa) end
        B.minimapa = cycleEvent(salvarMinimapa, 180000)
        scheduleEvent(function()
            local p = g_game.getProtocolGame and g_game.getProtocolGame()
            if p and p.sendExtendedOpcode then pcall(function() p:sendExtendedOpcode(OPCODE, '') end) end
        end, 6000)
    end })
end
