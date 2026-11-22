-- JV Baiak: MESTRE DAS CLASSES (templo de Thunder City)
-- Evolucao em 4 niveis, com level, outfit e velocidades; valores em jv_progressao.lua.
-- Cada nivel aumenta o ataque contra monstros e divide o dano que voce recebe:
--   nivel 1 = 2x | nivel 2 = 4x | nivel 3 = 7x | nivel 4 = 10x
-- O efeito no combate fica em data/scripts/custom/jv_evolucao.lua (mesma storage).
local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

function onCreatureAppear(cid)              npcHandler:onCreatureAppear(cid)            end
function onCreatureDisappear(cid)           npcHandler:onCreatureDisappear(cid)         end
function onCreatureSay(cid, type, msg)      npcHandler:onCreatureSay(cid, type, msg)    end
function onThink()                          npcHandler:onThink()                        end

local P = dofile('data/lib/jv_progressao.lua')
local STORAGE, MULT = P.storage, P.multiplicadores
local NOMES = {"Evolucao I", "Evolucao II", "Evolucao III", "Evolucao IV"}
local topico = {}

local function nivel(player)
	return math.max(0, math.min(#MULT, player:getStorageValue(STORAGE)))
end

-- paga com o dinheiro da mochila e, se faltar, com o do banco
local function pagar(player, valor)
	local mochila = player:getMoney()
	local banco = player:getBankBalance()
	if mochila + banco < valor then
		return false
	end
	local daMochila = math.min(mochila, valor)
	if daMochila > 0 and not player:removeMoney(daMochila) then
		return false
	end
	if valor > daMochila then
		player:setBankBalance(banco - (valor - daMochila))
	end
	return true
end

local function niveis(player)
	local partes = {}
	for i, m in ipairs(MULT) do
		partes[#partes + 1] = string.format('nivel %d = %dx, lv %d, %d gold, ataque %d ms, velocidade +%d', i, m, P.levels[i], P.precos[i], P.intervalo[i], P.movimento[i])
	end
	local n = nivel(player)
	return "Ataque contra monstros e defesa (dano recebido dividido): " .. table.concat(partes, ", ") ..
		". Voce esta no " ..
		(n == 0 and "nivel 0 (sem evolucao)." or string.format("%s (%dx).", NOMES[n], MULT[n]))
end

local function creatureSayCallback(cid, type, msg)
	if not npcHandler:isFocused(cid) then
		return false
	end
	local player = Player(cid)
	if not player then return false end
	local texto = msg:lower()
	local n = nivel(player)
	if not P.classes[player:getVocation():getClientId()] then npcHandler:say('Escolha uma vocacao primeiro.', cid); return true end
	if texto == "niveis" or texto == "nivel" or texto == "evolucao" then
		npcHandler:say(niveis(player) .. " Quer {evoluir}?", cid)
		topico[cid] = nil
	elseif texto == "evoluir" then
		if n >= #MULT then
			npcHandler:say(string.format("Voce ja tem a %s, a ultima: ataque e defesa %dx.", NOMES[n], MULT[n]), cid)
			topico[cid] = nil
		else
			npcHandler:say(string.format("Evoluir para a %s (ataque e defesa %dx) por %d gold, level %d? {sim} ou {nao}",
				NOMES[n + 1], MULT[n + 1], P.precos[n + 1], P.levels[n + 1]), cid)
			topico[cid] = n + 1
		end
	elseif texto == "sim" and topico[cid] then
		local alvo = topico[cid]
		topico[cid] = nil
		if alvo ~= n + 1 then
			npcHandler:say("Vamos de novo: diga {evoluir}.", cid)
		elseif player:getLevel() < P.levels[alvo] then
			npcHandler:say('Volte no level ' .. P.levels[alvo] .. '.', cid)
		elseif not pagar(player, P.precos[alvo]) then
			npcHandler:say('Voce precisa de ' .. P.precos[alvo] .. ' gold (mochila ou banco).', cid)
		else
			player:setStorageValue(STORAGE, alvo)
			if JV_EVOLUCAO and JV_EVOLUCAO.aplicar then JV_EVOLUCAO.aplicar(player) end
			player:getPosition():sendMagicEffect(CONST_ME_MAGIC_RED)
			player:getPosition():sendMagicEffect(CONST_ME_FIREWORK_YELLOW)
			npcHandler:say(string.format("Pronto! Agora voce tem a %s: ataque contra monstros e defesa %dx.%s",
				NOMES[alvo], MULT[alvo], alvo < #MULT and " Volte quando quiser a proxima." or " Essa e a ultima!"), cid)
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("[Evolucao] %s: ataque e defesa %dx.", NOMES[alvo], MULT[alvo]))
		end
	elseif texto == "nao" and topico[cid] then
		topico[cid] = nil
		npcHandler:say("Tudo bem. Quando quiser, diga {evoluir}.", cid)
	else
		return false
	end
	return true
end

npcHandler:setMessage(MESSAGE_GREET, "Ola |PLAYERNAME|! Eu evoluo sua classe em 4 niveis: com level, outfit, velocidade e hits mais fortes (ate 10x); quem ja comprou mantem sua evolucao. Diga {evoluir} ou {niveis}.")
npcHandler:setMessage(MESSAGE_FAREWELL, "Ate mais!")
npcHandler:setMessage(MESSAGE_WALKAWAY, "Ate mais!")
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
