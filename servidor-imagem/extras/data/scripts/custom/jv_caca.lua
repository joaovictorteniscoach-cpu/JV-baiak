-- JV Baiak: estilo "Tibia idle" - as moedas (gold, platinum, crystal) entram sozinhas
-- na lista de autoloot de cada personagem na primeira vez que ele entra depois desta
-- atualizacao. O jogador pode mudar depois com !autoloot add/remove/list.
local MARCA = 79001
local MOEDAS = {2148, 2152, 2160}

local ev = CreatureEvent("JVAutolootMoedas")
function ev.onLogin(player)
	if player:getStorageValue(MARCA) == 1 or not AUTOLOOT_STORAGE_START then
		return true
	end
	local tem = {}
	for i = AUTOLOOT_STORAGE_START, AUTOLOOT_STORAGE_END do
		local v = player:getStorageValue(i)
		if v > 0 then tem[v] = true end
	end
	for _, id in ipairs(MOEDAS) do
		if not tem[id] then
			for i = AUTOLOOT_STORAGE_START, AUTOLOOT_STORAGE_END do
				if player:getStorageValue(i) <= 0 then
					player:setStorageValue(i, id)
					break
				end
			end
		end
	end
	player:setStorageValue(MARCA, 1)
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
		"[Caca automatica] As moedas agora vao direto para a sua mochila (autoloot). Veja com !autoloot list")
	return true
end
ev:register()
