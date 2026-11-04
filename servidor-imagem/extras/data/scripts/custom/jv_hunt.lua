-- ============================================================================
-- JV Baiak - ANALISADOR DE HUNT e LOOT QUE VIRA DINHEIRO (estilo "Tibia idle")
--
--   !hunt          XP/h, gold/h, monstros mortos e tempo desde que voce entrou
--   !hunt reset    zera a contagem (ex.: ao chegar numa hunt nova)
--   !venderloot    vende de onde estiver os itens da mochila que o Mercador Ze compra;
--                  o dinheiro vai para o banco (espera 1 minuto entre uma venda e outra)
--   !depot         manda itens da mochila para o seu depot (1 vez por hora)
--
--   ESCOLHER OS ITENS (sem lista = vende/manda tudo que puder):
--   !venderloot add, nome   (ou so "!venderloot add" com o item na mao)
--   !venderloot remove, nome | !venderloot lista | !venderloot limpar
--   !depot add, nome | !depot remove, nome | !depot lista | !depot limpar
--   No jogo: segure o dedo no item -> "Vender no !venderloot" / "Mandar no !depot".
--
-- Tambem: o dinheiro do loot vai direto para o banco para todo mundo (uma vez por
-- personagem liga o "!autoloot gold"; quem quiser desliga com !autoloot gold).
-- ============================================================================
JV_HUNT = JV_HUNT or {sessao = {}}
local H = JV_HUNT
local MSG = MESSAGE_STATUS_CONSOLE_BLUE
local MARCA_OURO = 79004
local ESPERA_VENDA = 79005
local ESPERA_DEPOT = 79006

local function agora() return os.time() end

local function formatar(n)
	n = math.floor(n or 0)
	if n >= 1e9 then return string.format("%.2fkkk", n / 1e9) end
	if n >= 1e6 then return string.format("%.2fkk", n / 1e6) end
	if n >= 1e4 then return string.format("%.1fk", n / 1e3) end
	return tostring(n)
end

local function zerar(player)
	-- o lucro e medido pelo dinheiro (banco + mochila): o autoloot e as vendas vao para o banco
	H.sessao[player:getGuid()] = {inicio = agora(), exp = player:getExperience(), ouro = 0, mortes = 0, venda = 0,
		dinheiro = player:getBankBalance() + player:getMoney()}
end

local function sessao(player)
	local s = H.sessao[player:getGuid()]
	if not s then zerar(player); s = H.sessao[player:getGuid()] end
	return s
end

function H.somarOuro(player, valor)
	local s = sessao(player)
	s.ouro = s.ouro + valor
end

-- ---------------------------------------------------------------- eventos
local entrar = CreatureEvent("JVHuntLogin")
function entrar.onLogin(player)
	zerar(player)
	player:registerEvent("JVHuntKill")
	if AUTOLOOT_STORAGE_GOLD and player:getStorageValue(MARCA_OURO) ~= 1 then
		player:setStorageValue(MARCA_OURO, 1)
		player:setStorageValue(AUTOLOOT_STORAGE_GOLD, 1)
		player:sendTextMessage(MSG, "[JV Baiak] O dinheiro do loot agora vai direto para o seu banco. " ..
			"Comandos: !hunt (XP/h e lucro), !venderloot (vende o loot de onde estiver), !depot (manda a mochila para o depot).")
	end
	return true
end
entrar:register()

local matar = CreatureEvent("JVHuntKill")
function matar.onKill(player, target)
	if target and target:isMonster() then
		local s = sessao(player)
		s.mortes = s.mortes + 1
	end
	return true
end
matar:register()

-- ---------------------------------------------------------------- !hunt
local hunt = TalkAction("!hunt")
function hunt.onSay(player, words, param)
	if (param or ""):lower():find("reset") then
		zerar(player)
		player:sendTextMessage(MSG, "[Hunt] Contagem zerada. Boa caca!")
		return false
	end
	local s = sessao(player)
	local seg = math.max(1, agora() - s.inicio)
	local horas = seg / 3600
	local exp = math.max(0, player:getExperience() - s.exp)
	local lucro = math.max(0, player:getBankBalance() + player:getMoney() - (s.dinheiro or 0))
	player:sendTextMessage(MSG, string.format(
		"[Hunt] Tempo: %dh%02d | XP: %s (%s/h) | Gold: %s (%s/h) | Monstros: %d (%d/h) | Level %d. Use !hunt reset para zerar.",
		math.floor(seg / 3600), math.floor(seg % 3600 / 60), formatar(exp), formatar(exp / horas),
		formatar(lucro), formatar(lucro / horas), s.mortes, math.floor(s.mortes / horas), player:getLevel()))
	return false
end
hunt:separator(" ")
hunt:register()

-- ---------------------------------------------------------------- listas
local LISTAS = {venda = {inicio = 79100, tamanho = 30, nome = "venda"}, depot = {inicio = 79130, tamanho = 30, nome = "depot"}}

local function itensDaLista(player, qual)
	local l, set = LISTAS[qual], {}
	local n = 0
	for s = l.inicio, l.inicio + l.tamanho - 1 do
		local v = player:getStorageValue(s)
		if v > 0 then set[v] = true; n = n + 1 end
	end
	return set, n
end

local function acharTipo(player, texto)
	texto = (texto or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if texto == "" then
		local mao = player:getSlotItem(CONST_SLOT_RIGHT) or player:getSlotItem(CONST_SLOT_LEFT)
		return mao and ItemType(mao:getId()) or nil
	end
	local t = ItemType(tonumber(texto) or texto)
	if t and t:getId() ~= 0 then return t end
	return nil
end

-- devolve true se o comando era de lista (e ja respondeu)
local function comandoDeLista(player, qual, param, comando)
	local acao, resto = (param or ""):match("^%s*(%a+)%s*,?%s*(.-)%s*$")
	acao = (acao or ""):lower()
	local l = LISTAS[qual]
	if acao == "lista" or acao == "list" then
		local set, n = itensDaLista(player, qual)
		if n == 0 then
			player:sendTextMessage(MSG, "[" .. comando .. "] Lista vazia: " .. (qual == "venda" and "vende tudo que o Mercador Ze compra." or "manda tudo da mochila."))
		else
			local nomes = {}
			for id in pairs(set) do nomes[#nomes + 1] = ItemType(id):getName() end
			table.sort(nomes)
			player:sendTextMessage(MSG, "[" .. comando .. "] So estes itens: " .. table.concat(nomes, ", "))
		end
		return true
	elseif acao == "limpar" or acao == "clear" then
		for s = l.inicio, l.inicio + l.tamanho - 1 do player:setStorageValue(s, -1) end
		player:sendTextMessage(MSG, "[" .. comando .. "] Lista limpa.")
		return true
	elseif acao == "add" or acao == "remove" or acao == "tirar" then
		local tipo = acharTipo(player, resto)
		if not tipo then
			player:sendTextMessage(MSG, "[" .. comando .. "] Item nao encontrado. Use o nome do item ou segure ele na mao.")
			return true
		end
		local id = tipo:getId()
		local livre
		for s = l.inicio, l.inicio + l.tamanho - 1 do
			local v = player:getStorageValue(s)
			if v == id then
				if acao ~= "add" then
					player:setStorageValue(s, -1)
					player:sendTextMessage(MSG, "[" .. comando .. "] " .. tipo:getName() .. " saiu da lista.")
				else
					player:sendTextMessage(MSG, "[" .. comando .. "] " .. tipo:getName() .. " ja esta na lista.")
				end
				return true
			end
			if v <= 0 and not livre then livre = s end
		end
		if acao ~= "add" then
			player:sendTextMessage(MSG, "[" .. comando .. "] " .. tipo:getName() .. " nao estava na lista.")
		elseif not livre then
			player:sendTextMessage(MSG, "[" .. comando .. "] Lista cheia (30 itens).")
		else
			player:setStorageValue(livre, id)
			player:sendTextMessage(MSG, "[" .. comando .. "] " .. tipo:getName() .. " entrou na lista.")
		end
		return true
	end
	return false
end

-- ---------------------------------------------------------------- !venderloot
local function venderDe(container, total, so)
	for i = container:getSize() - 1, 0, -1 do
		local item = container:getItem(i)
		if item then
			local preco = JV_PRECOS and JV_PRECOS[item:getId()]
			if preco and preco > 0 and (not so or so[item:getId()]) and (not item:isContainer() or item:getSize() == 0) then
				total.ouro = total.ouro + preco * math.max(1, item:getCount())
				total.itens = total.itens + 1
				item:remove()
			elseif item:isContainer() then
				venderDe(item, total, so)
			end
		end
	end
end

local vender = TalkAction("!venderloot")
function vender.onSay(player, words, param)
	if comandoDeLista(player, "venda", param, "Venda") then return false end
	if player:getStorageValue(ESPERA_VENDA) > agora() then
		player:sendTextMessage(MSG, "[Venda] Espere um pouco para vender de novo.")
		return false
	end
	local mochila = player:getSlotItem(CONST_SLOT_BACKPACK)
	if not mochila or not mochila:isContainer() then
		player:sendTextMessage(MSG, "[Venda] Voce precisa de uma mochila.")
		return false
	end
	local total = {ouro = 0, itens = 0}
	local set, n = itensDaLista(player, "venda")
	venderDe(mochila, total, n > 0 and set or nil)
	player:setStorageValue(ESPERA_VENDA, agora() + 60)
	if total.itens == 0 then
		player:sendTextMessage(MSG, "[Venda] Nada para vender na mochila (o Mercador Ze compra armas, escudos, armaduras, capacetes, calcas, botas, aneis e amuletos).")
		return false
	end
	player:setBankBalance(player:getBankBalance() + total.ouro)
	sessao(player).venda = sessao(player).venda + total.ouro
	player:getPosition():sendMagicEffect(CONST_ME_MAGIC_GREEN)
	player:sendTextMessage(MSG, string.format("[Venda] %d item(ns) vendidos por %s gold. O dinheiro foi para o banco (saldo: %s).",
		total.itens, formatar(total.ouro), formatar(player:getBankBalance())))
	return false
end
vender:separator(" ")
vender:register()

-- ---------------------------------------------------------------- !depot
local function mandar(container, caixa, so, n)
	for i = container:getSize() - 1, 0, -1 do
		local item = container:getItem(i)
		if item and item:getWorth() == 0 then
			if not so or so[item:getId()] then
				if item:moveTo(caixa) then n = n + 1 end
			elseif item:isContainer() then
				n = mandar(item, caixa, so, n)
			end
		end
	end
	return n
end

local depot = TalkAction("!depot")
function depot.onSay(player, words, param)
	if comandoDeLista(player, "depot", param, "Depot") then return false end
	local espera = player:getStorageValue(ESPERA_DEPOT) - agora()
	if espera > 0 then
		player:sendTextMessage(MSG, string.format("[Depot] Voce pode mandar de novo em %d min.", math.ceil(espera / 60)))
		return false
	end
	local mochila = player:getSlotItem(CONST_SLOT_BACKPACK)
	local caixa = player:getDepotChest(player:getTown():getId(), true)
	if not mochila or not mochila:isContainer() or not caixa then
		player:sendTextMessage(MSG, "[Depot] Nao foi possivel agora.")
		return false
	end
	local set, qtd = itensDaLista(player, "depot")
	local n = mandar(mochila, caixa, qtd > 0 and set or nil, 0)
	if n > 0 then
		player:setStorageValue(ESPERA_DEPOT, agora() + 3600)
		player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
	end
	player:sendTextMessage(MSG, n > 0 and string.format("[Depot] %d item(ns) enviados para o depot de %s.", n, player:getTown():getName())
		or "[Depot] Nada para mandar (dinheiro fica com voce).")
	return false
end
depot:separator(" ")
depot:register()
