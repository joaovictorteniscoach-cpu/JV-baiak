-- ============================================================================
-- JV Baiak - MAGIAS AUTOMATICAS (auto cast + auto cura), feito no servidor:
-- funciona igual no navegador, no app do Android, no PC e em qualquer cliente 8.60.
--
--  * Cura (CURA AUTOMATICA, botao do coracao/pocao no celular, comeca ligada):
--    vida abaixo de 70% -> a melhor magia de cura que o personagem tem (exura vita /
--    exura san / exura gran / exura); vida abaixo de 50% -> pocao de vida; mana abaixo
--    de 30% -> pocao de mana (qualquer pocao da mochila, a melhor que a vocacao/level usa).
--  * Ataque: enquanto voce ataca um MONSTRO, usa a melhor magia de ataque que o
--    personagem ja pode usar (level, magic level, vocacao e mana). Com 2 ou mais
--    monstros perto usa a magia em area (exori, exevo gran mas ..., exevo mas san).
--  * Nunca usa magia em jogadores e nao faz nada em zona de protecao.
--  * Guarda mana para a cura antes de gastar com ataque.
--
-- Comandos: !automagia on | off  (magias de ATAQUE; o botao de espada liga/desliga junto)
--           !autocura on | off   (cura: magias e pocoes; separado da espada)
-- Opcode 79 (jogo do navegador): "" = pede o estado, "cura" / "ataque" = liga/desliga.
--   Resposta: "cura,ataque" com 1/0 (ex.: "1,0").
-- Precisa do player:castSpell (patch 0003 do JV Baiak).
-- ============================================================================
JV_MAGIAS = JV_MAGIAS or {proximo = {}, bloqueada = {}}
local M = JV_MAGIAS
local STORAGE = 79003      -- magias de ataque
local STORAGE_CURA = 79004 -- cura automatica (magias de cura e pocoes)
local OPCODE = 79
local INTERVALO = 500
local CURA_ABAIXO = 0.70
local MSG = MESSAGE_STATUS_CONSOLE_BLUE

-- prioridade = ordem (a primeira que o personagem puder usar e escolhida)
local CURAS = {"exura vita", "exura san", "exura gran", "exura ico", "exura"}
local AREA = {"exevo gran mas vis", "exevo gran mas flam", "exevo gran mas frigo", "exevo gran mas tera",
	"exori gran", "exevo mas san", "exori mas", "exori"}
local ALVO = {"exori san", "exori con", "exori gran ico", "exori ico", "exori hur",
	"exori mort", "exori vis", "exori flam", "exori frigo", "exori tera"}
local CORPO_A_CORPO = {["exori"] = true, ["exori gran"] = true, ["exori mas"] = true}

local function ligado(player)
	return player:getStorageValue(STORAGE) ~= 0
end

local function curaLigada(player)
	return player:getStorageValue(STORAGE_CURA) ~= 0
end

local function enviarEstado(player)
	if player:isUsingOtClient() then
		player:sendExtendedOpcode(OPCODE, (curaLigada(player) and "1" or "0") .. "," .. (ligado(player) and "1" or "0"))
	end
end
M.enviarEstado = enviarEstado

local function fora(player)
	return JV_AUSENTE and JV_AUSENTE.fora and JV_AUSENTE.fora(player) or false
end

-- pocoes (mesmos valores de data/actions/scripts/other/potions.lua). classe = clientid da
-- vocacao: 1 knight, 2 paladin, 3 sorcerer, 4 druid (vale para promovidos e reborn)
local POCOES_VIDA = {
	{id = 8473, vida = {650, 850}, classes = {[1] = true}, level = 130},
	{id = 7591, vida = {425, 575}, classes = {[1] = true}, level = 80},
	{id = 8472, vida = {250, 350}, mana = {100, 200}, classes = {[2] = true}, level = 80},
	{id = 7588, vida = {250, 350}, classes = {[1] = true, [2] = true}, level = 50},
	{id = 7618, vida = {125, 175}},
	{id = 8704, vida = {60, 90}},
}
local POCOES_MANA = {
	{id = 7590, mana = {150, 250}, classes = {[3] = true, [4] = true}, level = 80},
	{id = 8472, vida = {250, 350}, mana = {100, 200}, classes = {[2] = true}, level = 80},
	{id = 7589, mana = {115, 185}, classes = {[2] = true, [3] = true, [4] = true}, level = 50},
	{id = 7620, mana = {75, 125}},
}
local POCAO_ABAIXO, MANA_ABAIXO, ESPERA_POCAO = 0.50, 0.30, 1000

local function podeBeber(player, p)
	if p.level and player:getLevel() < p.level then return false end
	if p.classes then
		local voc = player:getVocation()
		local ok, classe = pcall(function() return voc:getClientId() end)
		if not ok or not p.classes[classe] then return false end
	end
	return player:getItemCount(p.id) > 0
end

local function beber(player, lista)
	for _, p in ipairs(lista) do
		if podeBeber(player, p) then
			if p.vida then player:addHealth(math.random(p.vida[1], p.vida[2])) end
			if p.mana then player:addMana(math.random(p.mana[1], p.mana[2])) end
			player:say("Aaaah...", TALKTYPE_MONSTER_SAY)
			player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
			if configManager.getBoolean(configKeys.REMOVE_POTION_CHARGES) then
				player:removeItem(p.id, 1)
			end
			return true
		end
	end
	return false
end

local function infoMagia(words)
	M.info = M.info or {}
	if M.info[words] == nil then
		local s = Spell(words)
		if s then
			local ok1, cd = pcall(function() return s:cooldown() end)
			local ok2, gcd = pcall(function() return s:groupCooldown() end)
			local ok3, alcance = pcall(function() return s:range() end)
			M.info[words] = {
				espera = math.max(ok1 and cd or 0, ok2 and gcd or 0, 1000),
				alcance = (ok3 and alcance and alcance > 0) and alcance or 3,
			}
		else
			M.info[words] = false
		end
	end
	return M.info[words]
end

-- magias que este personagem pode usar agora: words -> {mana, level, mlevel}
local function minhasMagias(player)
	local lista = {}
	local ok, spells = pcall(function() return player:getInstantSpells() end)
	if not ok or not spells then return lista end
	local lvl, ml = player:getLevel(), player:getMagicLevel()
	for i = 1, #spells do
		local s = spells[i]
		if lvl >= (s.level or 0) and ml >= (s.mlevel or 0) then
			lista[s.words] = s
		end
	end
	return lista
end

local function podeAgora(player, words, tipo)
	local cid = player:getId()
	local agora = os.mtime and os.mtime() or os.time() * 1000
	local b = M.bloqueada[cid]
	if b and b[words] and b[words] > agora then return false end
	local p = M.proximo[cid]
	return not (p and p[tipo] and p[tipo] > agora)
end

local function lancar(player, words, tipo)
	local cid = player:getId()
	local agora = os.mtime and os.mtime() or os.time() * 1000
	local info = infoMagia(words)
	if not info then return false end
	if player:castSpell(words) then
		-- mostra as palavras da magia em cima do personagem, como quando o jogador fala
		local tipo_fala = configManager.getBoolean(configKeys.EMOTE_SPELLS) and TALKTYPE_MONSTER_SAY or TALKTYPE_SAY
		pcall(function() player:say(words, tipo_fala) end)
		M.proximo[cid] = M.proximo[cid] or {}
		M.proximo[cid][tipo] = agora + info.espera
		return true
	end
	-- nao saiu (sem arma, sem alvo valido, exausto...): deixa essa de lado por 30 s
	M.bloqueada[cid] = M.bloqueada[cid] or {}
	M.bloqueada[cid][words] = agora + 30000
	return false
end

local function escolher(lista, minhas, mana, reserva)
	for i = 1, #lista do
		local s = minhas[lista[i]]
		if s and mana - (s.mana or 0) >= reserva then
			return lista[i], s
		end
	end
	return nil
end

local function monstrosPerto(pos, raio)
	local n = 0
	local perto = Game.getSpectators(pos, false, false, raio, raio, raio, raio)
	for i = 1, #perto do
		if perto[i]:isMonster() and perto[i]:getHealth() > 0 then n = n + 1 end
	end
	return n
end

local function distancia(a, b)
	return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

local function cuidar(player)
	local tile = Tile(player:getPosition())
	if not tile or tile:hasFlag(TILESTATE_PROTECTIONZONE) then return end
	local minhas = minhasMagias(player)
	local mana = player:getMana()

	-- 1) cura
	local menorCura = 0
	for i = #CURAS, 1, -1 do
		local s = minhas[CURAS[i]]
		if s then menorCura = s.mana or 0 break end
	end
	local cid = player:getId()
	local agora = os.mtime and os.mtime() or os.time() * 1000
	if curaLigada(player) and podeAgora(player, "", "pocao") then
		local bebeu = false
		if player:getHealth() < player:getMaxHealth() * POCAO_ABAIXO then
			bebeu = beber(player, POCOES_VIDA)
		end
		if not bebeu and player:getMana() < player:getMaxMana() * MANA_ABAIXO then
			bebeu = beber(player, POCOES_MANA)
		end
		if bebeu then
			M.proximo[cid] = M.proximo[cid] or {}
			M.proximo[cid].pocao = agora + ESPERA_POCAO
			mana = player:getMana()
		end
	end
	if curaLigada(player) and player:getHealth() < player:getMaxHealth() * CURA_ABAIXO and podeAgora(player, "", "cura") then
		for i = 1, #CURAS do
			local w = CURAS[i]
			local s = minhas[w]
			if s and mana >= (s.mana or 0) and podeAgora(player, w, "cura") then
				if lancar(player, w, "cura") then mana = player:getMana() end
				break
			end
		end
	end

	-- 2) ataque (so em monstro que voce esta atacando; nunca com o jogo fora da tela)
	if not ligado(player) or fora(player) then return end
	local alvo = player:getTarget()
	if not alvo or not alvo:isMonster() or alvo:getHealth() <= 0 then return end
	local pos, pAlvo = player:getPosition(), alvo:getPosition()
	if pos.z ~= pAlvo.z or not podeAgora(player, "", "ataque") then return end
	local reserva = player:getHealth() < player:getMaxHealth() * 0.9 and menorCura or 0
	local d = distancia(pos, pAlvo)

	if monstrosPerto(pos, 1) >= 2 or monstrosPerto(pos, 3) >= 3 then
		for i = 1, #AREA do
			local w = AREA[i]
			local s = minhas[w]
			if s and mana - (s.mana or 0) >= reserva and podeAgora(player, w, "ataque")
				and (not CORPO_A_CORPO[w] or d <= 1) then
				if lancar(player, w, "ataque") then return end
			end
		end
	end
	for i = 1, #ALVO do
		local w = ALVO[i]
		local s = minhas[w]
		local info = s and infoMagia(w)
		if info and mana - (s.mana or 0) >= reserva and d <= info.alcance and podeAgora(player, w, "ataque") then
			if lancar(player, w, "ataque") then return end
		end
	end
end

local evento = GlobalEvent("JVMagiasAutomaticas")
function evento.onThink(interval)
	if not Player.castSpell then return true end
	local players = Game.getPlayers()
	for i = 1, #players do
		local p = players[i]
		if ligado(p) or curaLigada(p) then
			local ok, erro = pcall(cuidar, p)
			if not ok and not M.avisou then
				M.avisou = true
				print("[JV Magias] " .. tostring(erro))
			end
		end
	end
	return true
end
evento:interval(INTERVALO)
evento:register()

local sair = CreatureEvent("JVMagiasSair")
function sair.onLogout(player)
	M.proximo[player:getId()] = nil
	M.bloqueada[player:getId()] = nil
	return true
end
sair:register()

local function comando(player, words, param)
	param = (param or ""):lower():gsub("%s+", "")
	if param == "on" or param == "off" then
		player:setStorageValue(STORAGE, param == "on" and 1 or 0)
	end
	local magias = {}
	for w in pairs(minhasMagias(player)) do
		if w:find("^exori") or w:find("^exura") or w:find("^exevo gran mas") or w == "exevo mas san" then
			magias[#magias + 1] = w
		end
	end
	table.sort(magias)
	player:sendTextMessage(MSG, "[Magias automaticas] " .. (ligado(player) and "LIGADAS" or "DESLIGADAS") ..
		". Usa magias de ataque no monstro que voce estiver atacando (a cura e separada: !autocura). Magias que voce ja tem: " ..
		(#magias > 0 and table.concat(magias, ", ") or "nenhuma ainda") .. ". Use !automagia on / off")
	return false
end

for _, palavra in ipairs({"!automagia", "!autocast"}) do
	local t = TalkAction(palavra)
	t.onSay = function(player, words, param)
		local r = comando(player, words, param)
		enviarEstado(player)
		return r
	end
	t:separator(" ")
	t:register()
end

local function avisarCura(player)
	player:sendTextMessage(MSG, "[Cura automatica] " .. (curaLigada(player) and "LIGADA" or "DESLIGADA") ..
		": magia de cura com vida abaixo de 70%, pocao de vida abaixo de 50% e pocao de mana abaixo de 30%." ..
		" Use !autocura on / off")
end

for _, palavra in ipairs({"!autocura", "!autoheal"}) do
	local t = TalkAction(palavra)
	function t.onSay(player, words, param)
		param = (param or ""):lower():gsub("%s+", "")
		if param == "on" or param == "off" then
			player:setStorageValue(STORAGE_CURA, param == "on" and 1 or 0)
		end
		avisarCura(player)
		enviarEstado(player)
		return false
	end
	t:separator(" ")
	t:register()
end

-- jogo do navegador: botoes de cura e magias (opcode 79)
local pedido = CreatureEvent("JVMagiasPedido")
function pedido.onExtendedOpcode(player, opcode, buffer)
	if opcode ~= OPCODE then return true end
	if buffer == "cura" then
		player:setStorageValue(STORAGE_CURA, curaLigada(player) and 0 or 1)
		avisarCura(player)
	elseif buffer == "ataque" then
		player:setStorageValue(STORAGE, ligado(player) and 0 or 1)
	end
	enviarEstado(player)
	return true
end
pedido:register()

local entrar = CreatureEvent("JVMagiasLogin")
function entrar.onLogin(player)
	player:registerEvent("JVMagiasPedido")
	local cid = player:getId()
	addEvent(function() local p = Player(cid); if p then enviarEstado(p) end end, 4000)
	return true
end
entrar:register()
