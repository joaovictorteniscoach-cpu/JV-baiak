-- ============================================================================
-- JV Baiak - MAGIAS SEM COMPRAR
--  * Chegou no level de uma magia da sua vocacao: voce ja aprende sozinho (as que
--    precisavam ser compradas no NPC tambem).
--  * O jogo do navegador recebe a lista das magias que voce pode usar e coloca cada
--    magia nova na barra de atalhos (e so tocar). Opcode 77 (cliente OTClient).
-- ============================================================================
JV_APRENDER = JV_APRENDER or {}
local A = JV_APRENDER
local OPCODE = 77
local MSG = MESSAGE_EVENT_ADVANCE

-- le data/spells/spells.xml uma vez: nome, palavras, level, grupo, vocacoes
local function carregar()
	if A.magias then return A.magias end
	A.magias = {}
	local f = io.open("data/spells/spells.xml", "r")
	if not f then return A.magias end
	local texto = f:read("*a")
	f:close()
	for abre, corpo in texto:gmatch("<instant(.-)>(.-)</instant>") do
		local function attr(n) return abre:match(n .. '="([^"]*)"') end
		local m = {
			nome = attr("name"), palavras = attr("words"), grupo = attr("group") or "support",
			level = tonumber(attr("level") or attr("lvl") or "1") or 1,
			aprender = attr("needlearn") == "1", vocacoes = {},
		}
		for v in corpo:gmatch('<vocation name="([^"]+)"') do m.vocacoes[v:lower()] = true end
		if m.nome and m.palavras then A.magias[#A.magias + 1] = m end
	end
	table.sort(A.magias, function(a, b) return a.level < b.level end)
	return A.magias
end

local function daVocacao(player, m)
	local voc = player:getVocation()
	if not voc then return false end
	local nome = voc:getName():lower()
	if m.vocacoes[nome] then return true end
	-- promovido / reborn: confere a vocacao de baixo tambem
	local base = voc:getDemotion()
	return base and m.vocacoes[base:getName():lower()] or false
end

-- aprende as que precisavam de NPC; devolve os nomes aprendidos agora
local function aprender(player)
	local novas = {}
	for _, m in ipairs(carregar()) do
		if m.aprender and m.level <= player:getLevel() and daVocacao(player, m) and not player:hasLearnedSpell(m.nome) then
			player:learnSpell(m.nome)
			novas[#novas + 1] = m.palavras
		end
	end
	return novas
end

-- manda para o jogo: "palavras;grupo;level" de cada magia que ja pode usar (separadas por |)
function A.enviarLista(player)
	if not player:isUsingOtClient() then return end
	local itens = {}
	for _, m in ipairs(carregar()) do
		if m.level <= player:getLevel() and daVocacao(player, m) and (not m.aprender or player:hasLearnedSpell(m.nome)) then
			-- magias com nome de alvo (exiva "nome", utevo res ina "...") ficam de fora da barra
			if not m.palavras:find('"') then
				itens[#itens + 1] = m.palavras .. ";" .. m.grupo .. ";" .. m.level
			end
		end
	end
	player:sendExtendedOpcode(OPCODE, table.concat(itens, "|"))
end

local entrar = CreatureEvent("JVAprenderLogin")
function entrar.onLogin(player)
	player:registerEvent("JVAprenderLevel")
	player:registerEvent("JVAprenderPedido")
	local novas = aprender(player)
	if #novas > 0 then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "[Magias] Voce ja sabe: " .. table.concat(novas, ", ") .. ". Estao na barra de atalhos.")
	end
	local cid = player:getId()
	addEvent(function()
		local p = Player(cid)
		if p then A.enviarLista(p) end
	end, 3000)
	return true
end
entrar:register()

local subir = CreatureEvent("JVAprenderLevel")
function subir.onAdvance(player, skill, oldLevel, newLevel)
	if skill ~= SKILL_LEVEL or newLevel <= oldLevel then return true end
	local novas = aprender(player)
	-- magias que ficaram liberadas agora (com ou sem NPC)
	local liberadas = {}
	for _, m in ipairs(carregar()) do
		if m.level > oldLevel and m.level <= newLevel and daVocacao(player, m) then
			liberadas[#liberadas + 1] = m.palavras
		end
	end
	if #liberadas > 0 then
		player:sendTextMessage(MSG, "Magia nova: " .. table.concat(liberadas, ", ") .. " (ja na barra de atalhos).")
	end
	if #liberadas > 0 or #novas > 0 then A.enviarLista(player) end
	return true
end
subir:register()

-- o jogo pede a lista de novo (ao abrir a barra): opcode 77 vindo do cliente
local pedido = CreatureEvent("JVAprenderPedido")
function pedido.onExtendedOpcode(player, opcode, buffer)
	if opcode == OPCODE then A.enviarLista(player) end
	return true
end
pedido:register()
