-- JV Baiak: MESTRE DAS CLASSES (templo de Thunder City)
-- Evolucao de classe em 4 niveis, 100.000 gold cada (dinheiro da mochila e/ou do banco).
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

local STORAGE = 79500 -- 79300-79399 e a lista de ignorados do jv_loot
local PRECO = 100000
local MULT = {2, 4, 7, 10}
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
		partes[#partes + 1] = string.format("nivel %d = %dx", i, m)
	end
	local n = nivel(player)
	return "Ataque contra monstros e defesa (dano recebido dividido): " .. table.concat(partes, ", ") ..
		". Cada nivel custa 100.000 gold. Voce esta no " ..
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
	if texto == "niveis" or texto == "nivel" or texto == "evolucao" then
		npcHandler:say(niveis(player) .. " Quer {evoluir}?", cid)
		topico[cid] = nil
	elseif texto == "evoluir" then
		if n >= #MULT then
			npcHandler:say(string.format("Voce ja tem a %s, a ultima: ataque e defesa %dx.", NOMES[n], MULT[n]), cid)
			topico[cid] = nil
		else
			npcHandler:say(string.format("Evoluir para a %s (ataque e defesa %dx) por 100.000 gold? {sim} ou {nao}",
				NOMES[n + 1], MULT[n + 1]), cid)
			topico[cid] = n + 1
		end
	elseif texto == "sim" and topico[cid] then
		local alvo = topico[cid]
		topico[cid] = nil
		if alvo ~= n + 1 then
			npcHandler:say("Vamos de novo: diga {evoluir}.", cid)
		elseif not pagar(player, PRECO) then
			npcHandler:say("Voce precisa de 100.000 gold (na mochila ou no banco).", cid)
		else
			player:setStorageValue(STORAGE, alvo)
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

npcHandler:setMessage(MESSAGE_GREET, "Ola |PLAYERNAME|! Eu evoluo sua classe em 4 niveis: cada um custa 100.000 gold e aumenta seu ataque e sua defesa (ate 10x). Diga {evoluir} ou {niveis}.")
npcHandler:setMessage(MESSAGE_FAREWELL, "Ate mais!")
npcHandler:setMessage(MESSAGE_WALKAWAY, "Ate mais!")
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
