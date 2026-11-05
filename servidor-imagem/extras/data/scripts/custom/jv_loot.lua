-- ============================================================================
-- JV Baiak - AUTOLOOT COM ESCOLHAS (substitui o autoloot antigo do Baiak)
--   Ligado/desligado e o que pegar de cada monstro que VOCE matou:
--     dinheiro  -> vai direto para o banco
--     caros     -> itens que valem 2.000 gold ou mais (preco do Mercador Ze)
--     raros     -> itens que o monstro solta pouco (1% ou menos no loot original)
--     lista     -> sua lista do !autoloot (add/remove como antes)
--   Mandar direto para o depot (em vez da mochila): raros e/ou caros.
--
--   Comandos: !loot (mostra) | !loot on | !loot off
--             !loot dinheiro | caros | raros | lista | depot raros | depot caros  (liga/desliga)
--   No celular (navegador): menu > Autoloot (janela com botoes). Opcode 78.
-- ============================================================================
JV_LOOT = JV_LOOT or {raros = {}, avisos = {}}
local L = JV_LOOT
local OPCODE = 78
local MSG = MESSAGE_STATUS_CONSOLE_BLUE
local CARO = 2000
local RARO = 1000 -- chance de 100000 (= 1%)

local CAMPOS = {"ligado", "dinheiro", "caros", "raros", "lista", "depotRaros", "depotCaros"}
local ST = {ligado = 79200, dinheiro = 79201, caros = 79202, raros = 79203, lista = 79204, depotRaros = 79205, depotCaros = 79206}
local PADRAO = {ligado = true, dinheiro = true, caros = true, raros = true, lista = true, depotRaros = false, depotCaros = false}
local NOMES = {ligado = "Autoloot", dinheiro = "Dinheiro", caros = "Itens caros", raros = "Itens raros",
	lista = "Minha lista", depotRaros = "Raros vao pro depot", depotCaros = "Caros vao pro depot"}

local function opcao(player, k)
	local v = player:getStorageValue(ST[k])
	if v == -1 then return PADRAO[k] end
	return v == 1
end

local function estado(player)
	local t = {}
	for _, k in ipairs(CAMPOS) do t[#t + 1] = opcao(player, k) and "1" or "0" end
	return table.concat(t, ",")
end

local function enviarEstado(player)
	if player:isUsingOtClient() then player:sendExtendedOpcode(OPCODE, estado(player)) end
end

local function resumo(player)
	local t = {}
	for _, k in ipairs(CAMPOS) do t[#t + 1] = NOMES[k] .. ": " .. (opcao(player, k) and "sim" or "nao") end
	return "[Loot] " .. table.concat(t, " | ")
end

local function alternar(player, k)
	if not ST[k] then return false end
	player:setStorageValue(ST[k], opcao(player, k) and 0 or 1)
	return true
end

local function raros(nomeMonstro)
	local r = L.raros[nomeMonstro]
	if r then return r end
	r = {}
	local mt = MonsterType(nomeMonstro)
	if mt then
		local function ver(lista)
			for _, l in ipairs(lista or {}) do
				if l.itemId and l.chance and l.chance <= RARO then r[l.itemId] = true end
				if l.childLoot then ver(l.childLoot) end
			end
		end
		pcall(function() ver(mt:getLoot()) end)
	end
	L.raros[nomeMonstro] = r
	return r
end

local function naLista(player, id)
	if not AUTOLOOT_STORAGE_START then return false end
	for s = AUTOLOOT_STORAGE_START, AUTOLOOT_STORAGE_END do
		if player:getStorageValue(s) == id then return true end
	end
	return false
end

local function coletar(player, container, c)
	for i = container:getSize() - 1, 0, -1 do
		local item = container:getItem(i)
		if item then
			local id = item:getId()
			if item:isContainer() and item:getSize() > 0 then
				coletar(player, item, c)
			elseif item:getWorth() > 0 then
				if c.dinheiro then
					c.ouro = c.ouro + item:getWorth()
					item:remove()
				end
			else
				local raro = c.raros[id] and true or false
				local caro = (JV_PRECOS and (JV_PRECOS[id] or 0) or 0) * math.max(1, item:getCount()) >= CARO
				local pegar = (raro and c.pegaRaros) or (caro and c.pegaCaros) or (c.lista and naLista(player, id))
				if pegar then
					local depot = (raro and c.depotRaros) or (caro and c.depotCaros)
					if depot and c.caixa and item:moveTo(c.caixa) then
						c.noDepot = c.noDepot + 1
					elseif item:moveTo(player) then
						c.itens = c.itens + 1
					else
						c.ficou = c.ficou + 1
					end
				end
			end
		end
	end
end

local function abrirCorpo(cid, posicao, nomeMonstro)
	local player = Player(cid)
	if not player or not opcao(player, "ligado") then return end
	local tile = Tile(posicao)
	local corpo = tile and tile:getTopDownItem()
	if not corpo or not corpo:getType():isCorpse() or corpo:getAttribute(ITEM_ATTRIBUTE_CORPSEOWNER) ~= cid then return end
	local c = {ouro = 0, itens = 0, ficou = 0, noDepot = 0, raros = raros(nomeMonstro),
		dinheiro = opcao(player, "dinheiro"), pegaCaros = opcao(player, "caros"), pegaRaros = opcao(player, "raros"),
		lista = opcao(player, "lista"), depotRaros = opcao(player, "depotRaros"), depotCaros = opcao(player, "depotCaros")}
	if c.depotRaros or c.depotCaros then
		local ok, caixa = pcall(function() return player:getDepotChest(player:getTown():getId(), true) end)
		if ok then c.caixa = caixa end
	end
	coletar(player, corpo, c)
	if c.ouro > 0 then
		player:setBankBalance(player:getBankBalance() + c.ouro)
		if JV_HUNT and JV_HUNT.somarOuro then JV_HUNT.somarOuro(player, c.ouro) end
	end
	if c.noDepot > 0 then
		player:sendTextMessage(MESSAGE_STATUS_SMALL, "[Loot] " .. c.noDepot .. " item(ns) foram direto para o seu depot.")
	end
	if c.ficou > 0 and (L.avisos[cid] or 0) + 60 <= os.time() then
		L.avisos[cid] = os.time()
		player:sendTextMessage(MESSAGE_STATUS_SMALL, "[Loot] Mochila cheia: " .. c.ficou .. " item(ns) ficaram no corpo. Use !venderloot ou !depot.")
	end
end

local matar = CreatureEvent("JVLootKill")
function matar.onKill(player, target)
	if target and target:isMonster() then
		addEvent(abrirCorpo, 100, player:getId(), target:getPosition(), target:getName())
	end
	return true
end
matar:register()

local entrar = CreatureEvent("JVLootLogin")
function entrar.onLogin(player)
	player:registerEvent("JVLootKill")
	player:registerEvent("JVLootPedido")
	local cid = player:getId()
	addEvent(function() local p = Player(cid); if p then enviarEstado(p) end end, 3500)
	return true
end
entrar:register()

-- o jogo do navegador: opcode 78 vazio = mandar o estado; com o nome do campo = liga/desliga
local pedido = CreatureEvent("JVLootPedido")
function pedido.onExtendedOpcode(player, opcode, buffer)
	if opcode ~= OPCODE then return true end
	if buffer and buffer ~= "" then alternar(player, buffer) end
	enviarEstado(player)
	return true
end
pedido:register()

local comando = TalkAction("!loot")
function comando.onSay(player, words, param)
	local p = (param or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local mapa = {on = "ligado", off = "ligado", dinheiro = "dinheiro", gold = "dinheiro", caros = "caros",
		raros = "raros", lista = "lista", ["depot raros"] = "depotRaros", ["depot caros"] = "depotCaros"}
	if p == "on" or p == "off" then
		player:setStorageValue(ST.ligado, p == "on" and 1 or 0)
	elseif mapa[p] then
		alternar(player, mapa[p])
	elseif p ~= "" then
		player:sendTextMessage(MSG, "[Loot] Use: !loot on | off | dinheiro | caros | raros | lista | depot raros | depot caros")
	end
	player:sendTextMessage(MSG, resumo(player))
	enviarEstado(player)
	return false
end
comando:separator(" ")
comando:register()
