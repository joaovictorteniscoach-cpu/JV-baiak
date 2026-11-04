-- JV Baiak: AUTOLOOT melhorado (substitui o do Baiak Thunder, mesmo nome de arquivo)
--  * dinheiro do corpo vai direto para o BANCO (ligado para todos; !autoloot gold desliga)
--  * le tambem as bolsas que estiverem dentro do corpo
--  * pega os itens da sua lista (!autoloot add, nome) - agora ate 20 itens
--  * avisa quando nao coube na mochila (falta capacidade ou espaco)
-- Tambem soma o dinheiro na conta do !hunt.

local function coletar(player, container, ganhos)
	for i = container:getSize() - 1, 0, -1 do
		local item = container:getItem(i)
		if item then
			if item:isContainer() then
				coletar(player, item, ganhos)
			elseif player:getStorageValue(AUTOLOOT_STORAGE_GOLD) == 1 and item:getWorth() > 0 then
				ganhos.ouro = ganhos.ouro + item:getWorth()
				item:remove()
			else
				for s = AUTOLOOT_STORAGE_START, AUTOLOOT_STORAGE_END do
					if player:getStorageValue(s) == item:getId() then
						if item:moveTo(player) then
							ganhos.itens = ganhos.itens + 1
						else
							ganhos.ficou = ganhos.ficou + 1
						end
						break
					end
				end
			end
		end
	end
end

local function scanContainer(cid, position)
	local player = Player(cid)
	if not player then
		return
	end
	local tile = Tile(position)
	local corpse = tile and tile:getTopDownItem()
	if not corpse or not corpse:getType():isCorpse() or corpse:getAttribute(ITEM_ATTRIBUTE_CORPSEOWNER) ~= cid then
		return
	end
	local ganhos = {ouro = 0, itens = 0, ficou = 0}
	coletar(player, corpse, ganhos)
	if ganhos.ouro > 0 then
		player:setBankBalance(player:getBankBalance() + ganhos.ouro)
		if JV_HUNT and JV_HUNT.somarOuro then JV_HUNT.somarOuro(player, ganhos.ouro) end
		player:sendTextMessage(MESSAGE_STATUS_SMALL, "[Auto Loot] +" .. ganhos.ouro .. " gold no banco.")
	end
	if ganhos.ficou > 0 then
		player:sendTextMessage(MESSAGE_STATUS_SMALL, "[Auto Loot] Mochila cheia: " .. ganhos.ficou .. " item(ns) ficaram no corpo. Use !venderloot")
	end
end

function onKill(player, target)
	if not target:isMonster() then
		return true
	end
	addEvent(scanContainer, 100, player:getId(), target:getPosition())
	return true
end
