-- JV Baiak: o autoloot agora fica em data/scripts/custom/jv_loot.lua (com liga/desliga,
-- dinheiro, itens caros, itens raros, sua lista e depot). Este arquivo continua existindo
-- porque o creaturescripts.xml do Baiak aponta para ele; nao faz mais nada.
function onKill(player, target)
	return true
end
