-- ============================================================================
-- JV Baiak - SAIU DA ABA DO JOGO? O PERSONAGEM NAO MORRE
--  No celular, quando voce sai do jogo (outro app, tela bloqueada, outra aba) o navegador
--  congela o jogo e a conexao cai, mas o personagem continua no mapa. Antes os monstros
--  continuavam batendo e voce morria. Agora, enquanto o jogo esta fora da tela:
--    * monstros, campos e veneno NAO tiram vida nem mana (so jogadores podem);
--    * as magias de ataque automaticas param (a cura continua).
--  Ao voltar, tudo volta ao normal na hora.
--  Como o servidor sabe: o jogo (navegador e apps) manda um sinal a cada 2 s (opcode 80);
--  sem sinal por 6 s, ou sem conexao, o personagem esta "fora".
-- ============================================================================
JV_AUSENTE = JV_AUSENTE or {vivo = {}, desde = {}}
local A = JV_AUSENTE
local OPCODE = 80
local LIMITE = 6000

local function agora()
	return os.mtime and os.mtime() or os.time() * 1000
end

-- true = o jogo desse personagem esta fora da tela (ou sem conexao)
function A.fora(player)
	if player:getIp() == 0 then return true end
	local v = A.vivo[player:getId()]
	return v ~= nil and agora() - v > LIMITE
end

local function deJogador(attacker)
	if not attacker then return false end
	if attacker:isPlayer() then return true end
	local dono = attacker:getMaster()
	return dono ~= nil and dono:isPlayer()
end

local vida = CreatureEvent("JVAusenteVida")
function vida.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if primaryType ~= COMBAT_HEALING and creature:isPlayer() and A.fora(creature) and not deJogador(attacker) then
		return 0, primaryType, 0, secondaryType
	end
	return primaryDamage, primaryType, secondaryDamage, secondaryType
end
vida:register()

local mana = CreatureEvent("JVAusenteMana")
function mana.onManaChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if creature:isPlayer() and A.fora(creature) and not deJogador(attacker) then
		return 0, primaryType, 0, secondaryType
	end
	return primaryDamage, primaryType, secondaryDamage, secondaryType
end
mana:register()

-- sinal do jogo: "estou na tela". Responde para o jogo saber que a conexao esta viva.
local sinal = CreatureEvent("JVAusenteSinal")
function sinal.onExtendedOpcode(player, opcode, buffer)
	if opcode ~= OPCODE then return true end
	local cid = player:getId()
	local estavaFora = A.desde[cid]
	A.vivo[cid] = agora()
	if estavaFora then
		A.desde[cid] = nil
		local s = os.time() - estavaFora
		if s >= 10 then
			player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format(
				"[Protecao] Voce ficou %d s fora do jogo. Enquanto isso os monstros nao te machucaram.", s))
		end
	end
	player:sendExtendedOpcode(OPCODE, "ok")
	return true
end
sinal:register()

-- marca quando ficou fora (para a mensagem ao voltar)
local ronda = GlobalEvent("JVAusenteRonda")
function ronda.onThink(interval)
	for _, p in ipairs(Game.getPlayers()) do
		local cid = p:getId()
		if A.fora(p) then
			A.desde[cid] = A.desde[cid] or os.time()
		end
	end
	return true
end
ronda:interval(1000)
ronda:register()

local entrar = CreatureEvent("JVAusenteLogin")
function entrar.onLogin(player)
	player:registerEvent("JVAusenteVida")
	player:registerEvent("JVAusenteMana")
	player:registerEvent("JVAusenteSinal")
	A.vivo[player:getId()] = nil
	A.desde[player:getId()] = nil
	return true
end
entrar:register()

local sair = CreatureEvent("JVAusenteSair")
function sair.onLogout(player)
	A.vivo[player:getId()] = nil
	A.desde[player:getId()] = nil
	return true
end
sair:register()
