-- JV Baiak: GUIA DE HUNTS. Diga (ou toque) o nivel da hunt e depois a hunt:
-- o guia te leva direto para la. Cada hunt tem um level minimo.
local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

function onCreatureAppear(cid)              npcHandler:onCreatureAppear(cid)            end
function onCreatureDisappear(cid)           npcHandler:onCreatureDisappear(cid)         end
function onCreatureSay(cid, type, msg)      npcHandler:onCreatureSay(cid, type, msg)    end
function onThink()                          npcHandler:onThink()                        end

local HUNTS = {
	iniciante = {
		{nome = "Rotworm", level = 8, pos = Position(983, 1219, 8)},
		{nome = "Swamp Troll", level = 8, pos = Position(1061, 1189, 7)},
		{nome = "Minotaur", level = 15, pos = Position(1632, 1598, 7)},
	},
	medio = {
		{nome = "Cyclops", level = 30, pos = Position(1677, 1368, 4)},
		{nome = "Orc Berserker", level = 30, pos = Position(1418, 1304, 7)},
		{nome = "Mummy", level = 30, pos = Position(1924, 1683, 7)},
		{nome = "Pirate", level = 40, pos = Position(2004, 1915, 7)},
	},
	forte = {
		{nome = "Dragon", level = 80, pos = Position(402, 1599, 7)},
		{nome = "Ancient Scarab", level = 80, pos = Position(506, 1960, 7)},
		{nome = "Bog Raider", level = 100, pos = Position(848, 1949, 7)},
		{nome = "Wyvern", level = 80, pos = Position(1147, 328, 7)},
	},
	elite = {
		{nome = "Dragon Lord", level = 200, pos = Position(402, 1599, 7)},
		{nome = "Hydra", level = 200, pos = Position(221, 1701, 6)},
		{nome = "Frost Dragon", level = 200, pos = Position(59, 1822, 7)},
		{nome = "Warlock", level = 250, pos = Position(1024, 806, 7)},
		{nome = "Medusa", level = 250, pos = Position(191, 1816, 7)},
		{nome = "Destroyer", level = 250, pos = Position(1053, 260, 6)},
		{nome = "Nightmare", level = 250, pos = Position(1745, 1508, 2)},
	},
	lendario = {
		{nome = "Demon", level = 400, pos = Position(72, 1588, 7)},
		{nome = "Grim Reaper", level = 400, pos = Position(49, 1920, 7)},
		{nome = "Hellhound", level = 500, pos = Position(1149, 266, 7)},
		{nome = "Juggernaut", level = 600, pos = Position(1153, 384, 7)},
	},
}
local ORDEM = {"iniciante", "medio", "forte", "elite", "lendario"}

local function listar(chave)
	local partes = {}
	for _, hunt in ipairs(HUNTS[chave]) do
		partes[#partes + 1] = string.format("{%s} (lv %d+)", hunt.nome, hunt.level)
	end
	return table.concat(partes, ", ")
end

local function creatureSayCallback(cid, type, msg)
	if not npcHandler:isFocused(cid) then
		return false
	end
	local player = Player(cid)
	local texto = msg:lower()
	for _, chave in ipairs(ORDEM) do
		if texto == chave or texto == chave:gsub("medio", "m\233dio") then
			npcHandler:say("Hunts " .. chave .. ": " .. listar(chave) .. ". Qual delas?", cid)
			return true
		end
	end
	for _, chave in ipairs(ORDEM) do
		for _, hunt in ipairs(HUNTS[chave]) do
			if texto == hunt.nome:lower() then
				if player:getLevel() < hunt.level then
					npcHandler:say(string.format("%s e perigoso demais para voce. Volte no level %d.", hunt.nome, hunt.level), cid)
					return true
				end
				if player:isPzLocked() then
					npcHandler:say("Voce esta em batalha. Espere um pouco.", cid)
					return true
				end
				npcHandler:say("Boa caca! Ligue a espada (caca automatica) quando chegar.", cid)
				npcHandler:releaseFocus(cid)
				player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
				player:teleportTo(hunt.pos)
				hunt.pos:sendMagicEffect(CONST_ME_TELEPORT)
				return true
			end
		end
	end
	return false
end

npcHandler:setMessage(MESSAGE_GREET, "Ola |PLAYERNAME|! Te levo para uma hunt do seu nivel. Escolha: {iniciante}, {medio}, {forte}, {elite} ou {lendario}.")
npcHandler:setMessage(MESSAGE_FAREWELL, "Ate mais!")
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
