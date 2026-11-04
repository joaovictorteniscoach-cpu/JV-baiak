-- ============================================================================
-- JV Baiak - ANALISADOR DE HUNT e LOOT QUE VIRA DINHEIRO (estilo "Tibia idle")
--
--   !hunt          XP/h, gold/h, monstros mortos e tempo desde que voce entrou
--   !hunt reset    zera a contagem (ex.: ao chegar numa hunt nova)
--   !venderloot    vende de onde estiver os itens da mochila que o Mercador Ze compra;
--                  o dinheiro vai para o banco (espera 1 minuto entre uma venda e outra)
--   !depot         manda tudo que esta dentro da mochila para o seu depot (1 vez por hora)
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
	H.sessao[player:getGuid()] = {inicio = agora(), exp = player:getExperience(), ouro = 0, mortes = 0, venda = 0}
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
	local lucro = s.ouro + s.venda
	player:sendTextMessage(MSG, string.format(
		"[Hunt] Tempo: %dh%02d | XP: %s (%s/h) | Gold: %s (%s/h) | Monstros: %d (%d/h) | Level %d. Use !hunt reset para zerar.",
		math.floor(seg / 3600), math.floor(seg % 3600 / 60), formatar(exp), formatar(exp / horas),
		formatar(lucro), formatar(lucro / horas), s.mortes, math.floor(s.mortes / horas), player:getLevel()))
	return false
end
hunt:separator(" ")
hunt:register()

-- ---------------------------------------------------------------- !venderloot
local function venderDe(container, total)
	for i = container:getSize() - 1, 0, -1 do
		local item = container:getItem(i)
		if item then
			local preco = JV_PRECOS and JV_PRECOS[item:getId()]
			if preco and preco > 0 and (not item:isContainer() or item:getSize() == 0) then
				total.ouro = total.ouro + preco * math.max(1, item:getCount())
				total.itens = total.itens + 1
				item:remove()
			elseif item:isContainer() then
				venderDe(item, total)
			end
		end
	end
end

local vender = TalkAction("!venderloot")
function vender.onSay(player, words, param)
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
	venderDe(mochila, total)
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
vender:register()

-- ---------------------------------------------------------------- !depot
local depot = TalkAction("!depot")
function depot.onSay(player, words, param)
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
	local n = 0
	for i = mochila:getSize() - 1, 0, -1 do
		local item = mochila:getItem(i)
		if item and item:getWorth() == 0 then
			if item:moveTo(caixa) then n = n + 1 end
		end
	end
	if n > 0 then
		player:setStorageValue(ESPERA_DEPOT, agora() + 3600)
		player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
	end
	player:sendTextMessage(MSG, n > 0 and string.format("[Depot] %d item(ns) enviados para o depot de %s.", n, player:getTown():getName())
		or "[Depot] Nada para mandar (dinheiro fica com voce).")
	return false
end
depot:register()
