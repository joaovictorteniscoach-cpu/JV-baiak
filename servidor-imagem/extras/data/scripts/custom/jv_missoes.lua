-- Missao diaria de Ascensao: usa os mesmos abates validos e regras de party.
JV_MISSOES = JV_MISSOES or {}
local M = JV_MISSOES
local DIA, CONTAGEM, RESGATADO = 79800, 79801, 79802
local META, PREMIO = 50, 50000
local MSG = MESSAGE_STATUS_CONSOLE_BLUE

local function hoje() return math.floor(os.time() / 86400) end -- UTC
local function atualizar(player)
    local dia = hoje()
    if player:getStorageValue(DIA) ~= dia then
        player:setStorageValue(DIA, dia)
        player:setStorageValue(CONTAGEM, 0)
    end
    return dia
end

function M.abate(player)
    atualizar(player)
    local quantidade=math.max(0,player:getStorageValue(CONTAGEM))
    if quantidade < META then
        quantidade=quantidade+1
        player:setStorageValue(CONTAGEM,quantidade)
        if quantidade == META then
            player:sendTextMessage(MSG,'[Missao] Meta diaria concluida! Use !missao resgatar para receber 50000 no banco.')
        end
    end
end

local missao=TalkAction('!missao')
function missao.onSay(player, words, param)
    local dia=atualizar(player)
    local quantidade=math.max(0,player:getStorageValue(CONTAGEM))
    local resgatado=player:getStorageValue(RESGATADO)==dia
    if (param or ''):lower():match('^%s*resgatar%s*$') then
        if resgatado then player:sendTextMessage(MSG,'[Missao] Premio de hoje ja recebido.');return false end
        if quantidade<META then player:sendTextMessage(MSG,'[Missao] Derrote '..META..' monstros das hunts de Ascensao primeiro.');return false end
        player:setStorageValue(RESGATADO,dia)
        player:setBankBalance(player:getBankBalance()+PREMIO)
        player:sendTextMessage(MSG,'[Missao] Premio de 50000 enviado ao banco.')
        return false
    end
    player:sendTextMessage(MSG,'[Missao] Ascensao diaria: '..quantidade..'/'..META..'. Premio: 50000 no banco. '..(resgatado and 'Ja recebido hoje.' or 'Use !missao resgatar ao concluir.')..' Reinicia a meia-noite UTC.')
    return false
end
missao:separator(' ');missao:register()
