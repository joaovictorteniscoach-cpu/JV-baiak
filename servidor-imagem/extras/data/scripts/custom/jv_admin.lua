-- ============================================================================
-- JV Baiak - comandos extras de administrador
--
--   /clonar [quantidade]   copia o item da mao direita (ou da esquerda), com
--                          tudo dentro (se for mochila) e os mesmos atributos
--   /comandos              lista os comandos de administrador
--
-- So para contas de administrador (tipo GOD). Sem acentos de proposito
-- (o cliente 8.60 usa Latin-1).
-- ============================================================================

local function ehAdmin(player)
	return player:getGroup():getAccess() and player:getAccountType() >= ACCOUNT_TYPE_GOD
end

local clonar = TalkAction("/clonar")

function clonar.onSay(player, words, param)
	if not ehAdmin(player) then
		return true
	end
	local item = player:getSlotItem(CONST_SLOT_RIGHT) or player:getSlotItem(CONST_SLOT_LEFT)
	if not item then
		player:sendCancelMessage("Segure na mao (direita ou esquerda) o item que quer clonar.")
		return false
	end
	local vezes = math.min(100, math.max(1, tonumber(param) or 1))
	local feitos = 0
	for _ = 1, vezes do
		local copia = item:clone()
		if not copia then
			break
		end
		-- true = se nao couber na mochila, cai no chao ao lado
		if player:addItemEx(copia, true) ~= RETURNVALUE_NOERROR then
			break
		end
		feitos = feitos + 1
	end
	if feitos > 0 then
		player:getPosition():sendMagicEffect(CONST_ME_MAGIC_GREEN)
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
			string.format("Clonado: %dx %s.", feitos, item:getName()))
	else
		player:sendCancelMessage("Nao deu para clonar esse item.")
	end
	return false
end

clonar:separator(" ")
clonar:register()

local AJUDA = [[
Comandos de administrador do JV Baiak:

ITENS
/i nome ou id, quantidade   cria item (ex.: /i magic plate armor  ou  /i 2160, 100)
/clonar quantidade          clona o item que esta na sua mao (ex.: /clonar 5)
/r                          remove o item/criatura na sua frente
/attr                       muda atributos do item na frente

TELETRANSPORTE
/goto Nome                  vai ate um jogador ou criatura
/c Nome                     puxa um jogador ate voce
/pos x, y, z                vai para uma posicao (so /pos mostra onde voce esta)
/t                          volta para o templo
/town Nome                  vai para uma cidade
/a 5                        anda 5 quadrados para frente (atravessa parede)
/up  /down                  sobe ou desce um andar

CRIATURAS
/m Nome                     cria um monstro
/s Nome                     cria um NPC
/summon Nome                cria um monstro seu
/raid Nome                  comeca uma raid

JOGADORES
/kick Nome  /ban  /ipban  /unban
/addskill Nome, sword, 10   aumenta skill (sword, axe, club, dist, shield, magic, level)
/info Nome                  informacoes do jogador
/addtutor  /removetutor

SERVIDOR
/b mensagem                 aviso para todos
/ghost  /hide               fica invisivel
/looktype n  /chameleon     muda a aparencia
/reload tipo                recarrega (monsters, npcs, items, scripts...)
/clean                      limpa itens do chao
/openserver  /closeserver
]]

local comandos = TalkAction("/comandos")

function comandos.onSay(player, words, param)
	if not ehAdmin(player) then
		return true
	end
	player:showTextDialog(2160, AJUDA)
	return false
end

comandos:register()
