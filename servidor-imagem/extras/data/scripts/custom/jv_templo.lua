-- ============================================================================
-- JV Baiak - TEMPLO, VOLTAR PARA CASA E TELEPORTES
--  * No templo (zona de protecao perto do templo de qualquer cidade) a vida e a mana
--    enchem rapido: 10% por segundo.
--  * !templo (ou !temple): volta para o templo da sua cidade de qualquer lugar
--    (nao funciona logo depois de atacar outro jogador). No celular: botao do templo.
--  * Em cada hunt da Guia Lia tem um teleporte de volta ao templo da sua cidade.
--  * Teleportes do mapa que nao levavam a lugar nenhum (sem destino ou destino fora do
--    mapa) agora levam para o templo mais perto.
-- ============================================================================
JV_TEMPLO = JV_TEMPLO or {usou = {}}
local T = JV_TEMPLO
local RAIO = 12            -- quadrados em volta do templo que contam como "templo"
local CURA = 0.10          -- 10% da vida/mana por segundo
local AID_VOLTA = 47100    -- teleporte de volta (hunts da Lia)
local ESPERA = 5           -- segundos entre um !templo e outro
local MSG = MESSAGE_STATUS_CONSOLE_BLUE

local function templos()
	if not T.lista then
		T.lista = {}
		for _, town in ipairs(Game.getTowns()) do
			T.lista[#T.lista + 1] = town:getTemplePosition()
		end
	end
	return T.lista
end

function T.noTemplo(player)
	local pos = player:getPosition()
	local tile = Tile(pos)
	if not tile or not tile:hasFlag(TILESTATE_PROTECTIONZONE) then return false end
	for _, t in ipairs(templos()) do
		if t.z == pos.z and math.abs(t.x - pos.x) <= RAIO and math.abs(t.y - pos.y) <= RAIO then
			return true
		end
	end
	return false
end

-- volta para o templo da cidade do personagem; devolve true se foi
function T.voltar(player)
	if player:isPzLocked() then
		player:sendTextMessage(MSG, "[Templo] Voce atacou um jogador: espere o tempo de batalha acabar.")
		player:getPosition():sendMagicEffect(CONST_ME_POFF)
		return false
	end
	local cid = player:getId()
	if (T.usou[cid] or 0) + ESPERA > os.time() then
		player:sendCancelMessage("Espere um pouco para usar de novo.")
		return false
	end
	local town = player:getTown()
	local destino = town and town:getTemplePosition()
	if not destino then return false end
	T.usou[cid] = os.time()
	player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
	player:teleportTo(destino)
	destino:sendMagicEffect(CONST_ME_TELEPORT)
	player:sendTextMessage(MSG, "[Templo] Voce voltou para o templo de " .. town:getName() .. ".")
	return true
end

-- ------------------------------------------------------------ vida e mana no templo
local cura = GlobalEvent("JVTemploCura")
function cura.onThink(interval)
	for _, p in ipairs(Game.getPlayers()) do
		local falta = p:getHealth() < p:getMaxHealth() or p:getMana() < p:getMaxMana()
		if falta and p:getHealth() > 0 and T.noTemplo(p) then
			if p:getHealth() < p:getMaxHealth() then
				p:addHealth(math.max(20, math.floor(p:getMaxHealth() * CURA)))
			end
			if p:getMana() < p:getMaxMana() then
				p:addMana(math.max(20, math.floor(p:getMaxMana() * CURA)))
			end
			p:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
		end
	end
	return true
end
cura:interval(1000)
cura:register()

-- ------------------------------------------------------------ !templo
for _, palavra in ipairs({"!templo", "!temple"}) do
	local t = TalkAction(palavra)
	function t.onSay(player, words, param)
		T.voltar(player)
		return false
	end
	t:register()
end

local sair = CreatureEvent("JVTemploSair")
function sair.onLogout(player)
	T.usou[player:getId()] = nil
	return true
end
sair:register()

-- ------------------------------------------------------------ teleporte de volta
local volta = MoveEvent()
volta:type("stepin")
function volta.onStepIn(creature, item, position, fromPosition)
	local player = creature and creature:getPlayer()
	if not player then return true end
	if player:isPzLocked() then
		player:sendTextMessage(MSG, "[Templo] Voce atacou um jogador: espere o tempo de batalha acabar.")
		player:teleportTo(fromPosition, true)
		return true
	end
	T.usou[player:getId()] = nil
	T.voltar(player)
	return true
end
volta:aid(AID_VOLTA)
volta:register()

-- teleporte de volta ao lado de onde a Guia Lia deixa voce em cada hunt
local VOLTAS = {
	{977, 1215, 8}, -- Rotworm
	{1065, 1190, 7}, -- Swamp Troll
	{1562, 1634, 7}, -- Minotaur
	{1676, 1367, 4}, -- Cyclops
	{1030, 1753, 7}, -- Orc Berserker
	{1924, 1686, 7}, -- Mummy
	{1968, 1873, 7}, -- Pirate
	{1790, 1377, 5}, -- Dragon
	{505, 1957, 7}, -- Ancient Scarab
	{538, 1217, 8}, -- Bog Raider
	{1150, 331, 7}, -- Wyvern
	{401, 1596, 7}, -- Dragon Lord
	{218, 1700, 6}, -- Hydra
	{56, 1822, 7}, -- Frost Dragon
	{1022, 811, 7}, -- Warlock
	{188, 1815, 7}, -- Medusa
	{1049, 258, 6}, -- Destroyer
	{1711, 1460, 5}, -- Nightmare
	{67, 1585, 7}, -- Demon
	{49, 1918, 7}, -- Grim Reaper
	{1148, 258, 7}, -- Hellhound
	{1153, 382, 7}, -- Juggernaut
}

-- teleportes do mapa sem destino (ou com destino fora do mapa): levam ao templo mais perto
local CONSERTOS = {
	-- com nome no chao e sem destino: Premia "NPCs" e "Bosses" (mesmo lugar dos de Thunder City)
	-- e "Bhark" na sala das cidades
	{destino = Position(633, 1239, 5), lugares = {{473, 1379, 6}}},
	{destino = Position(583, 1242, 7), lugares = {{478, 1379, 6}}},
	{destino = Position(1238, 1307, 3), lugares = {{827, 1408, 7}}},
	{destino = Position(474, 1364, 7), lugares = {
		{22, 1429, 6}, {31, 1182, 4}, {62, 1410, 7}, {81, 1956, 7}, {192, 1000, 7}, {193, 1865, 7}, {198, 1444, 8},
		{204, 636, 7}, {229, 1612, 7}, {251, 759, 7}, {273, 739, 7}, {303, 1063, 7}, {312, 755, 7}, {315, 647, 7},
		{375, 1493, 7}, {399, 1061, 7}, {400, 1256, 5}, {400, 1256, 6}, {402, 1241, 5}, {402, 1241, 6},
		{404, 1262, 5}, {404, 1262, 6}, {404, 1262, 7}, {405, 1238, 5}, {405, 1238, 6}, {405, 1238, 7},
		{409, 1241, 5}, {409, 1241, 6}, {410, 1261, 5}, {410, 1261, 6}, {413, 1255, 5}, {413, 1255, 6},
		{413, 1255, 7}, {418, 953, 7}, {435, 675, 7}, {461, 1232, 6}, {461, 1245, 6}, {461, 1253, 6},
		{461, 1260, 6}, {466, 1219, 6}, {466, 1235, 6}, {466, 1256, 6}, {471, 1219, 6}, {471, 1235, 6},
		{471, 1256, 6}, {476, 1232, 6}, {476, 1245, 6}, {476, 1253, 6}, {476, 1260, 6}, {488, 673, 7},
		{560, 1700, 5},
	}},
	{destino = Position(725, 1388, 7), lugares = {
		{821, 1424, 7}, {823, 1424, 7}, {825, 1424, 7}, {845, 1543, 7}, {863, 1692, 7},
	}},
	{destino = Position(815, 1089, 7), lugares = {
		{527, 1104, 7}, {553, 584, 7}, {590, 726, 7}, {609, 595, 7}, {693, 739, 7}, {693, 906, 7}, {709, 578, 7},
		{727, 651, 7}, {783, 940, 7}, {798, 747, 7}, {812, 1088, 7}, {909, 932, 7}, {919, 720, 7},
	}},
	{destino = Position(980, 1413, 8), lugares = {
		{956, 1594, 7},
	}},
	{destino = Position(991, 1210, 7), lugares = {
		{964, 1267, 8}, {969, 1260, 9}, {972, 1264, 7}, {1000, 715, 7}, {1030, 1216, 8},
	}},
	{destino = Position(1071, 1296, 7), lugares = {
		{1134, 1645, 7}, {1231, 1729, 7}, {1304, 1256, 8}, {1348, 1880, 7}, {1537, 2084, 7}, {1538, 2084, 7},
		{1590, 1286, 7}, {1641, 1876, 7}, {1682, 1931, 7}, {1740, 1804, 7}, {1791, 1370, 7}, {1812, 1914, 7},
		{1930, 1740, 7}, {1983, 1485, 7}, {2083, 1676, 7}, {2084, 1676, 7}, {2088, 1870, 7},
	}},
	{destino = Position(1312, 1011, 6), lugares = {
		{1156, 1033, 8}, {1526, 1227, 7}, {1540, 1203, 7}, {1808, 1192, 8}, {1808, 1194, 8}, {1808, 1196, 8},
		{1811, 1183, 7}, {1811, 1186, 7}, {1811, 1189, 7}, {1811, 1192, 7}, {1811, 1195, 7}, {1812, 1192, 8},
		{1812, 1194, 8}, {1812, 1196, 8}, {1818, 1183, 7}, {1818, 1186, 7}, {1818, 1189, 7}, {1818, 1192, 7},
		{1818, 1195, 7}, {1852, 881, 7},
	}},
}

local TELEPORTES = {[1387] = true, [12509] = true}

-- "Castle 48H" no templo: o teleporte nunca teve destino (o evento do Baiak usa outra entrada).
-- Agora explica quando abre em vez de nao fazer nada.
local AID_CASTELO = 47101
local castelo = MoveEvent()
castelo:type("stepin")
function castelo.onStepIn(creature, item, position, fromPosition)
	local player = creature and creature:getPlayer()
	if not player then return true end
	player:sendTextMessage(MSG, "[Castle 48H] Evento de guild (level 100+): domingo, terca, quinta, sexta e sabado as 20h." ..
		" Fique de olho no aviso no chat quando abrir.")
	player:teleportTo(fromPosition, true)
	fromPosition:sendMagicEffect(CONST_ME_POFF)
	return true
end
castelo:aid(AID_CASTELO)
castelo:register()

local inicio = GlobalEvent("JVTemploInicio")
inicio:type("startup")
function inicio.onStartup()
	local criados, consertados = 0, 0
	for _, v in ipairs(VOLTAS) do
		local pos = Position(v[1], v[2], v[3])
		local tile = Tile(pos)
		if tile and not tile:getItemById(1387) then
			local item = Game.createItem(1387, 1, pos)
			if item then
				item:setActionId(AID_VOLTA)
				criados = criados + 1
			end
		end
	end
	for _, grupo in ipairs(CONSERTOS) do
		for _, l in ipairs(grupo.lugares) do
			local tile = Tile(Position(l[1], l[2], l[3]))
			for _, item in ipairs(tile and tile:getItems() or {}) do
				if TELEPORTES[item:getId()] then
					local tp = item.setDestination and item or Teleport(item:getUniqueId())
					local atual = tp and tp:getDestination()
					local quebrado = not atual or (atual.x == 0 and atual.y == 0) or not Tile(atual)
						or Tile(atual):hasFlag(TILESTATE_BLOCKSOLID)
					if tp and quebrado then
						tp:setDestination(grupo.destino)
						consertados = consertados + 1
					end
				end
			end
		end
	end
	local tileCastelo = Tile(Position(997, 1203, 7))
	local tpCastelo = tileCastelo and tileCastelo:getItemById(1387)
	if tpCastelo and tpCastelo:getActionId() == 0 then tpCastelo:setActionId(AID_CASTELO) end
	print(string.format(">> JV Templo: %d teleportes de volta nas hunts, %d teleportes consertados", criados, consertados))
	return true
end
inicio:register()
