-- ============================================================================
-- JV Baiak - Treino Automatico
--
-- Enquanto o jogador estiver dentro de uma sala de trainers, o servidor treina
-- sozinho a skill de ataque (arma equipada), a defesa (shielding, se estiver
-- com escudo) e o magic level. Funciona em qualquer aparelho, sem bot.
--
-- Os ganhos passam pelas rates do config.lua (rateSkill / rateMagic).
-- Comando no jogo: !treino  (GM: !treino on | !treino off)
-- Arquivo escrito sem acentos de proposito (o cliente 8.60 usa Latin-1).
-- ============================================================================

TREINO_AUTO = TREINO_AUTO or {}

local cfg = {
	ativo = true,
	intervalo = 2000,       -- ms entre cada ciclo de treino
	tentativasArma = 1,     -- tentativas na skill da arma por ciclo (x rateSkill)
	tentativasEscudo = 1,   -- tentativas de shielding por ciclo (x rateSkill)
	-- mana "gasta" por ciclo para subir magic level (x rateMagic),
	-- por vocacao base: 0 sem vocacao, 1 sorcerer, 2 druid, 3 paladin, 4 knight
	manaPorCiclo = {[0] = 10, [1] = 40, [2] = 40, [3] = 20, [4] = 5},
	evitarKickAfk = true,   -- dentro da sala o jogador nao cai por inatividade
	-- Salas de trainers do mapa Baiak Thunder (conferidas no mapa: sem spawns
	-- nem casas dentro destas caixas).
	areas = {
		{de = {x = 200, y = 1250, z = 8}, ate = {x = 376, y = 1378, z = 8}}, -- trainers
		{de = {x = 20, y = 1198, z = 4}, ate = {x = 190, y = 1270, z = 4}},  -- trainers premium
	},
}

TREINO_AUTO.cfg = cfg
TREINO_AUTO.jogadores = TREINO_AUTO.jogadores or {}

local MSG = MESSAGE_STATUS_CONSOLE_BLUE

local function vocacaoBase(player)
	local id = player:getVocation():getId()
	if id > 4 then
		return id - 4
	end
	return id
end

local function dentroDaArea(pos)
	for i = 1, #cfg.areas do
		local a = cfg.areas[i]
		if pos.z == a.de.z and pos.x >= a.de.x and pos.x <= a.ate.x and pos.y >= a.de.y and pos.y <= a.ate.y then
			return true
		end
	end
	return false
end
TREINO_AUTO.dentroDaArea = dentroDaArea

local SKILL_DA_ARMA = {
	[WEAPON_SWORD] = SKILL_SWORD,
	[WEAPON_CLUB] = SKILL_CLUB,
	[WEAPON_AXE] = SKILL_AXE,
	[WEAPON_DISTANCE] = SKILL_DISTANCE,
}

-- Retorna: skill de ataque (ou nil), se esta com escudo
local function equipamento(player)
	local skill, escudo, wand = nil, false, false
	local slots = {CONST_SLOT_LEFT, CONST_SLOT_RIGHT}
	for i = 1, #slots do
		local item = player:getSlotItem(slots[i])
		if item then
			local tipo = ItemType(item:getId()):getWeaponType()
			if SKILL_DA_ARMA[tipo] then
				skill = SKILL_DA_ARMA[tipo]
			elseif tipo == WEAPON_SHIELD then
				escudo = true
			elseif tipo == WEAPON_WAND then
				wand = true
			end
		end
	end

	if not skill and not wand then
		local base = vocacaoBase(player)
		-- knight / sem vocacao sem arma treinam fist; magos sem arma nao treinam melee
		if base == 0 or base == 4 then
			skill = SKILL_FIST
		end
	end
	return skill, escudo
end
TREINO_AUTO.equipamento = equipamento

local NOME_SKILL = {
	[SKILL_FIST] = "fist", [SKILL_CLUB] = "club", [SKILL_SWORD] = "sword",
	[SKILL_AXE] = "axe", [SKILL_DISTANCE] = "distance",
}

local function descricao(player)
	local skill, escudo = equipamento(player)
	local partes = {}
	if skill then
		partes[#partes + 1] = NOME_SKILL[skill] or "ataque"
	end
	if escudo then
		partes[#partes + 1] = "shielding"
	end
	if (cfg.manaPorCiclo[vocacaoBase(player)] or 0) > 0 then
		partes[#partes + 1] = "magic level"
	end
	if #partes == 0 then
		return "nada (equipe uma arma ou escudo)"
	end
	return table.concat(partes, " + ")
end

local function treinar(player)
	local skill, escudo = equipamento(player)
	if skill and cfg.tentativasArma > 0 then
		player:addSkillTries(skill, cfg.tentativasArma)
	end
	if escudo and cfg.tentativasEscudo > 0 then
		player:addSkillTries(SKILL_SHIELD, cfg.tentativasEscudo)
	end
	local mana = cfg.manaPorCiclo[vocacaoBase(player)] or 0
	if mana > 0 then
		player:addManaSpent(mana)
	end
	if cfg.evitarKickAfk and player.resetIdleTime then
		player:resetIdleTime()
	end
end
TREINO_AUTO.treinar = treinar

local function ciclo()
	if not cfg.ativo then
		return true
	end

	local agora = os.time()
	local limite = math.ceil(cfg.intervalo / 1000) * 3
	local jogadores = TREINO_AUTO.jogadores
	local players = Game.getPlayers()
	for i = 1, #players do
		local player = players[i]
		local guid = player:getGuid()
		if dentroDaArea(player:getPosition()) then
			if not jogadores[guid] then
				player:sendTextMessage(MSG, "[Treino Automatico] Ligado: treinando " .. descricao(player) .. ". Saia da sala para parar.")
			end
			jogadores[guid] = agora
			treinar(player)
		elseif jogadores[guid] then
			-- So avisa se acabou de sair (nao depois de relogar em outro lugar)
			if agora - jogadores[guid] <= limite then
				player:sendTextMessage(MSG, "[Treino Automatico] Pausado: voce saiu da sala de treino.")
			end
			jogadores[guid] = nil
		end
	end
	return true
end
TREINO_AUTO.ciclo = ciclo

local evento = GlobalEvent("TreinoAutomatico")
function evento.onThink(interval)
	return ciclo()
end
evento:interval(cfg.intervalo)
evento:register()

local comando = TalkAction("!treino")
function comando.onSay(player, words, param)
	param = (param or ""):lower()
	if player:getGroup():getAccess() and (param == "on" or param == "off") then
		cfg.ativo = (param == "on")
		player:sendTextMessage(MSG, "[Treino Automatico] Sistema " .. (cfg.ativo and "ligado" or "desligado") .. " para todos.")
		return false
	end

	if not cfg.ativo then
		player:sendTextMessage(MSG, "[Treino Automatico] O sistema esta desligado no momento.")
	elseif dentroDaArea(player:getPosition()) then
		player:sendTextMessage(MSG, "[Treino Automatico] Ativo agora: " .. descricao(player) .. ".")
	else
		player:sendTextMessage(MSG, "[Treino Automatico] Entre em uma sala de trainers e o treino comeca sozinho: " ..
			"arma equipada, shielding (com escudo) e magic level. Voce nao cai por inatividade la dentro.")
	end
	return false
end
comando:separator(" ")
comando:register()
