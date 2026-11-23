-- ============================================================================
-- JV Baiak - EVOLUCAO DE CLASSE (efeito no combate)
--  Comprada no Mestre das Classes; levels, precos, outfits e velocidades em jv_progressao.lua.
--    nivel 1 = 2x | nivel 2 = 4x | nivel 3 = 7x | nivel 4 = 10x
--  * Ataque: o dano que voce (ou sua invocacao) causa em MONSTROS e multiplicado.
--    Contra jogadores o ataque continua normal.
--  * Defesa: todo dano que voce recebe (monstro ou jogador, vida e mana) e dividido.
--  !evolucao mostra o seu nivel.
--  Os monstros tem o dobro de vida (instalador: ferramentas/vida_monstros.py).
--  O evento de ataque e ligado no monstro quando um jogador o ataca
--  (data/events/scripts/creature.lua, Creature:onTargetCombat, colocado pelo instalador).
-- ============================================================================
JV_EVOLUCAO = JV_EVOLUCAO or {}
local E = JV_EVOLUCAO
local P = dofile('data/lib/jv_progressao.lua')
local STORAGE, MULT = P.storage, P.multiplicadores
E.aplicados = {}
local NOMES = {"Evolucao I", "Evolucao II", "Evolucao III", "Evolucao IV"}

function E.nivel(player)
	return math.max(0, math.min(#MULT, player:getStorageValue(STORAGE)))
end

function E.multiplicador(player)
	local n = E.nivel(player)
	return n > 0 and MULT[n] or 1
end

function E.maestria(player)
    return math.min(P.maxMaestria, math.floor(math.max(0, player:getStorageValue(P.storageAbates)) / P.abatesPorMaestria))
end

function E.nome(player)
    local c = P.classes[player:getVocation():getClientId()]
    local n = E.nivel(player)
    return c and n > 0 and c.nomes[n] or 'Sem evolucao'
end

function E.ataque(player,origin)
    if JV_ARSENAL and not JV_ARSENAL.equipamentoValido(player) then return 0 end
    local fator = 1 + E.maestria(player) * P.bonusMaestria
    -- Arcos/crossbows e wands/rods usam formulas proprias: o reforco tambem
    -- chega a essas classes; nao somar duas armas nem duplicar bonus melee.
    if player:getVocation():getClientId() ~= 1 then
        local poder = 1
        for _, slot in ipairs({CONST_SLOT_LEFT, CONST_SLOT_RIGHT}) do
            local item = player:getSlotItem(slot)
            if item then
                local novo=JV_ARSENAL and JV_ARSENAL.bonus(player,item,origin)
                poder=math.max(poder,novo or math.min(P.reforco[#P.reforco],tonumber(item:getCustomAttribute('jvAscensaoPoder')) or 1))
            end
        end
        fator = fator * poder
    end
    return E.multiplicador(player) * fator
end

function E.aplicar(player)
    local n = E.nivel(player)
    local classe = P.classes[player:getVocation():getClientId()]
    if n == 0 or not classe then return end
    local chave = table.concat({n, player:getVocation():getId(), player:getSex()}, ':')
    if E.aplicados[player:getId()] == chave then return end
    player:setAttackSpeed(math.max(200, math.min(player:getVocation():getAttackSpeed(), P.intervalo[n])))
    player:removeCondition(CONDITION_HASTE, CONDITIONID_DEFAULT, P.storage)
    local cond = Condition(CONDITION_HASTE, CONDITIONID_DEFAULT)
    cond:setParameter(CONDITION_PARAM_SUBID, P.storage)
    cond:setParameter(CONDITION_PARAM_TICKS, -1)
    cond:setParameter(CONDITION_PARAM_SPEED, P.movimento[n])
    player:addCondition(cond)
    local outfit = player:getOutfit()
    outfit.lookType = classe.outfits[player:getSex() == 0 and 1 or 2]
    outfit.lookAddons, outfit.lookBody = P.addons[n], P.cores[n]
    outfit.lookHead, outfit.lookLegs, outfit.lookFeet = 0, P.cores[n], 0
    if P.addons[n] > 0 then player:addOutfitAddon(outfit.lookType, P.addons[n]) end
    player:setOutfit(outfit)
    E.aplicados[player:getId()] = chave
end

-- Abates creditados uma vez por morte nas hunts de ascensao. Em party, quem
-- participa perto recebe progresso; personagens distantes ou mortos nao recebem.
function E.abate(player)
    local atual = math.max(0, player:getStorageValue(P.storageAbates))
    local antes = E.maestria(player)
    player:setStorageValue(P.storageAbates, math.min(P.abatesPorMaestria * P.maxMaestria, atual + 1))
    if E.maestria(player) > antes then
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, '[Maestria] Rank ' .. E.maestria(player) .. ': +' .. (E.maestria(player) * 2) .. '% de dano contra monstros.')
    end
end

local aplicar = GlobalEvent('JVEvolucaoAplicar')
function aplicar.onThink()
    for _, player in ipairs(Game.getPlayers()) do E.aplicar(player) end
    return true
end
aplicar:interval(1000); aplicar:register()
local sair = CreatureEvent('JVEvolucaoSair')
function sair.onLogout(player) E.aplicados[player:getId()] = nil; return true end
sair:register()

-- quem bateu: o jogador, ou o dono da invocacao
local function jogadorDe(attacker)
	if not attacker then return nil end
	if attacker:isPlayer() then return attacker end
	local dono = attacker:getMaster()
	if dono and dono:isPlayer() then return dono end
	return nil
end

local function dividir(valor, m)
	if valor == 0 or m <= 1 then return valor end
	local sinal = valor < 0 and -1 or 1
	return sinal * math.max(1, math.floor(math.abs(valor) / m))
end

-- ataque: ligado no monstro
local dano = CreatureEvent("JVEvolucaoDano")
function dano.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if primaryType == COMBAT_HEALING or not creature:isMonster() then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local player = jogadorDe(attacker)
	local m = player and E.ataque(player,origin) or 1
	if m==0 then return 0,primaryType,0,secondaryType end
	if m > 1 then
		return math.floor(primaryDamage * m), primaryType, math.floor(secondaryDamage * m), secondaryType
	end
	return primaryDamage, primaryType, secondaryDamage, secondaryType
end
dano:register()

-- defesa: ligada no jogador
local defesa = CreatureEvent("JVEvolucaoDefesa")
function defesa.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if primaryType == COMBAT_HEALING or not creature:isPlayer() then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local m = E.multiplicador(creature)
	local dono=jogadorDe(attacker)
	if dono and JV_ARSENAL and not JV_ARSENAL.equipamentoValido(dono) then return 0,primaryType,0,secondaryType end
	return dividir(primaryDamage, m), primaryType, dividir(secondaryDamage, m), secondaryType
end
defesa:register()

local defesaMana = CreatureEvent("JVEvolucaoMana")
function defesaMana.onManaChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if not creature:isPlayer() then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local m = E.multiplicador(creature)
	return dividir(primaryDamage, m), primaryType, dividir(secondaryDamage, m), secondaryType
end
defesaMana:register()

local entrar = CreatureEvent("JVEvolucaoLogin")
function entrar.onLogin(player)
	player:registerEvent("JVEvolucaoDefesa")
	player:registerEvent("JVEvolucaoMana")
	player:registerEvent("JVEvolucaoSair")
	E.aplicados[player:getId()] = nil
	E.aplicar(player)
	local n = E.nivel(player)
	if n > 0 then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("[Evolucao] %s: ataque e defesa %dx.", E.nome(player), MULT[n]))
	end
	return true
end
entrar:register()

local comando = TalkAction("!evolucao")
function comando.onSay(player, words, param)
	local n = E.nivel(player)
	local texto
	if n == 0 then
		texto = "[Evolucao] Voce ainda nao tem evolucao de classe. Fale com o Mestre das Classes no templo de Thunder City (a partir do level 200)."
	else
		texto = string.format("[Evolucao] %s: ataque contra monstros e defesa %dx.", E.nome(player), MULT[n])
		if n < #MULT then
			texto = texto .. string.format(" Proxima: %s (%dx) no Mestre das Classes (diga niveis).", NOMES[n + 1], MULT[n + 1])
		end
	end
	texto = texto .. string.format(' Maestria %d/%d. !ascensao lista as novas hunts; !arsenal mostra suas proximas armas.', E.maestria(player), P.maxMaestria)
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, texto)
	return false
end
comando:register()
