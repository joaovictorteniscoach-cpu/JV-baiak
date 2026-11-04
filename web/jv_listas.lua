-- JV Baiak: ESCOLHER O QUE VENDER E O QUE MANDAR AO DEPOT, SEM DIGITAR
-- Segure o dedo (ou clique com o botao direito) num item e escolha:
--   "Vender no !venderloot"  /  "Mandar no !depot"  /  "Tirar das listas"
-- O servidor guarda as listas do personagem. Lista vazia = vende/manda tudo.
-- Mesmo arquivo em web/ e em clientes/visual/mods/jv_listas/ (o teste confere).
JVListas = JVListas or {}
local L = JVListas

local function falar(texto)
    if g_game.isOnline() then pcall(g_game.talk, texto) end
end

local function ehItem(coisa)
    local ok, r = pcall(function()
        return coisa and coisa:isItem() and not coisa:isGround() and coisa:getId() > 0
    end)
    return ok and r
end

local OPCOES = {
    {'Vender no !venderloot', function(id) falar('!venderloot add, ' .. id) end},
    {'Mandar no !depot', function(id) falar('!depot add, ' .. id) end},
    {'Tirar das listas', function(id) falar('!venderloot remove, ' .. id); falar('!depot remove, ' .. id) end},
}

function L.iniciar()
    if L.ligado then return end
    local gi = modules.game_interface
    if not gi or not gi.addMenuHook then return end
    L.ligado = true
    for _, op in ipairs(OPCOES) do
        local acao = op[2]
        gi.addMenuHook('jvListas', op[1], function(pos, coisa, usar)
            local alvo = ehItem(coisa) and coisa or usar
            if ehItem(alvo) then acao(alvo:getId()) end
        end, function(pos, coisa, usar)
            return ehItem(coisa) or ehItem(usar)
        end)
    end
end

function L.parar()
    local gi = modules.game_interface
    if L.ligado and gi and gi.removeMenuHook then pcall(gi.removeMenuHook, 'jvListas') end
    L.ligado = false
end
