-- JV Baiak: todo personagem ja comeca com um Amulet of Loss (AOL) no pescoco.
-- Vale para os novos e, uma unica vez, para os que ja existiam. Se o colar ja
-- estiver ocupado, o AOL vai para a mochila (ou cai no chao, se nao couber).
-- Depois de usado (morreu), o jogador compra outro com !aol.
local MARCA = 79002
local AOL = 2173

local ev = CreatureEvent("JVAolInicial")
function ev.onLogin(player)
	if player:getStorageValue(MARCA) == 1 then
		return true
	end
	player:setStorageValue(MARCA, 1)
	local colar = player:getSlotItem(CONST_SLOT_NECKLACE)
	if colar and colar:getId() == AOL then
		return true
	end
	if not colar then
		player:addItem(AOL, 1, true, 1, CONST_SLOT_NECKLACE)
	else
		local item = Game.createItem(AOL, 1)
		if item then player:addItemEx(item, true) end
	end
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
		"[JV Baiak] Voce ganhou um Amulet of Loss: nao perde itens ao morrer. Depois de usado, compre outro com !aol")
	return true
end
ev:register()
