-- ============================================================================
-- JV Baiak - MAGIAS AUTOMATICAS (auto cast + auto cura), feito no servidor:
-- funciona igual no navegador, no app do Android, no PC e em qualquer cliente 8.60.
--
--  * Cura: vida abaixo de 70% -> usa a melhor magia de cura que o personagem tem
--    (exura vita / exura san / exura gran / exura), se tiver mana.
--  * Ataque: enquanto voce ataca um MONSTRO, usa a melhor magia de ataque que o
--    personagem ja pode usar (level, magic level, vocacao e mana). Com 2 ou mais
--    monstros perto usa a magia em area (exori, exevo gran mas ..., exevo mas san).
--  * Nunca usa magia em jogadores e nao faz nada em zona de protecao.
--  * Guarda mana para a cura antes de gastar com ataque.
--
-- Comando: !automagia (mostra) | !automagia on | !automagia off  (comeca ligado)
-- O botao de espada (caca automatica) do jogo liga/desliga junto.
-- Precisa do player:castSpell (patch 0003 do JV Baiak).
-- ============================================================================
JV_MAGIAS = JV_MAGIAS or {proximo = {}, bloqueada = {}}
local M = JV_MAGIAS
local STORAGE = 79003
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
	if player:getHealth() < player:getMaxHealth() * CURA_ABAIXO and podeAgora(player, "", "cura") then
		for i = 1, #CURAS do
			local w = CURAS[i]
			local s = minhas[w]
			if s and mana >= (s.mana or 0) and podeAgora(player, w, "cura") then
				if lancar(player, w, "cura") then mana = player:getMana() end
				break
			end
		end
	end

	-- 2) ataque (so em monstro que voce esta atacando)
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
		if ligado(p) then
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
		". Cura abaixo de 70% de vida e ataca o monstro que voce estiver atacando. Magias que voce ja tem: " ..
		(#magias > 0 and table.concat(magias, ", ") or "nenhuma ainda") .. ". Use !automagia on / off")
	return false
end

for _, palavra in ipairs({"!automagia", "!autocast"}) do
	local t = TalkAction(palavra)
	t.onSay = comando
	t:separator(" ")
	t:register()
end
