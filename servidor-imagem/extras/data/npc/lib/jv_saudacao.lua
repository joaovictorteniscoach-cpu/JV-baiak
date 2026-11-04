-- JV Baiak: conversa com NPC sem digitar. Chegou perto (ate 2 quadrados), o NPC ja
-- cumprimenta e abre a conversa; as opcoes aparecem entre {chaves} e o jogo mostra
-- como botoes para tocar. Depois de dar tchau, so cumprimenta de novo em 30 s.
-- Carregado no fim de data/npc/lib/npc.lua (o instalador acrescenta o dofile).
if NpcHandler and not NpcHandler.jvSaudacao then
	NpcHandler.jvSaudacao = true
	local pensarOriginal = NpcHandler.onThink
	local DISTANCIA, ESPERA = 2, 30
	function NpcHandler:onThink()
		pensarOriginal(self)
		local npc = Npc()
		if not npc then return end
		self.jvUltimo = self.jvUltimo or {}
		local agora = os.time()
		local perto = Game.getSpectators(npc:getPosition(), false, true, DISTANCIA, DISTANCIA, DISTANCIA, DISTANCIA)
		for i = 1, #perto do
			local cid = perto[i]:getId()
			if not self:isFocused(cid) and agora - (self.jvUltimo[cid] or 0) >= ESPERA then
				self.jvUltimo[cid] = agora
				self:onGreet(cid)
			elseif self:isFocused(cid) then
				self.jvUltimo[cid] = agora
			end
		end
	end
end
