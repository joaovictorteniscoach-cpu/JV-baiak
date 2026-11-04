-- JV Baiak: CONVERSA COM NPC SO QUANDO VOCE QUER (carregado no fim de data/npc/lib/npc.lua).
--  * O NPC NAO cumprimenta mais sozinho quando voce chega perto (com muitos NPCs juntos
--    isso abria varias conversas ao mesmo tempo).
--  * Voce TOCA no NPC e o jogo diz "hi" por voce. Para nao abrir conversa com todos os
--    NPCs em volta, so o NPC MAIS PERTO de voce responde ao "hi".
if NpcHandler and not NpcHandler.jvSoMaisPerto then
	NpcHandler.jvSoMaisPerto = true
	local dizerOriginal = NpcHandler.onCreatureSay
	local SAUDACAO = {hi = true, hello = true, ola = true, oi = true}

	local function distancia(a, b)
		local dx, dy = a.x - b.x, a.y - b.y
		return dx * dx + dy * dy
	end

	function NpcHandler:onCreatureSay(creature, msgtype, msg)
		local cid = creature:getId()
		if msgtype ~= TALKTYPE_PRIVATE_PN and not self:isFocused(cid) then
			local m = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
			if SAUDACAO[m] then
				local npc, player = Npc(), Player(cid)
				if npc and player then
					local pp = player:getPosition()
					local minha = distancia(npc:getPosition(), pp)
					local perto = Game.getSpectators(pp, false, false, 3, 3, 3, 3)
					for i = 1, #perto do
						local outro = perto[i]
						if outro:isNpc() and outro:getId() ~= npc:getId() and distancia(outro:getPosition(), pp) < minha then
							return -- outro NPC esta mais perto: ele e que responde
						end
					end
				end
			end
		end
		return dizerOriginal(self, creature, msgtype, msg)
	end
end
