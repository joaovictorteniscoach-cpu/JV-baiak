-- ============================================================================
-- JV Baiak - EVOLUCAO DE CLASSE (efeito no combate)
--  Comprada no NPC Mestre das Classes (templo de Thunder City), 4 niveis de 100.000 gold.
--    nivel 1 = 2x | nivel 2 = 4x | nivel 3 = 7x | nivel 4 = 10x
--  * Ataque: o dano que voce (ou sua invocacao) causa em MONSTROS e multiplicado.
--    Contra jogadores o ataque continua normal.
--  * Defesa: todo dano que voce recebe (monstro ou jogador, vida e mana) e dividido.
--  !evolucao mostra o seu nivel.
--  Os monstros tem o dobro de vida (instalador: ferramentas/vida_monstros.py).
--  O evento de ataque e ligado no monstro quando um jogador o ataca
--  (data/events/scripts/creature.lua, Creature:onTargetCombat, colocado pelo instalador).
-- ============================================================================
JV_EVOLUCAO = JV_EVOLUCAO or {}
local E = JV_EVOLUCAO
local STORAGE = 79300
local MULT = {2, 4, 7, 10}
local NOMES = {"Evolucao I", "Evolucao II", "Evolucao III", "Evolucao IV"}

function E.nivel(player)
	return math.max(0, math.min(#MULT, player:getStorageValue(STORAGE)))
end

function E.multiplicador(player)
	local n = E.nivel(player)
	return n > 0 and MULT[n] or 1
end

-- quem bateu: o jogador, ou o dono da invocacao
local function jogadorDe(attacker)
	if not attacker then return nil end
	if attacker:isPlayer() then return attacker end
	local dono = attacker:getMaster()
	if dono and dono:isPlayer() then return dono end
	return nil
end

local function dividir(valor, m)
	if valor == 0 or m <= 1 then return valor end
	local sinal = valor < 0 and -1 or 1
	return sinal * math.max(1, math.floor(math.abs(valor) / m))
end

-- ataque: ligado no monstro
local dano = CreatureEvent("JVEvolucaoDano")
function dano.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if primaryType == COMBAT_HEALING or not creature:isMonster() then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local player = jogadorDe(attacker)
	local m = player and E.multiplicador(player) or 1
	if m > 1 then
		return primaryDamage * m, primaryType, secondaryDamage * m, secondaryType
	end
	return primaryDamage, primaryType, secondaryDamage, secondaryType
end
dano:register()

-- defesa: ligada no jogador
local defesa = CreatureEvent("JVEvolucaoDefesa")
function defesa.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if primaryType == COMBAT_HEALING or not creature:isPlayer() then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local m = E.multiplicador(creature)
	return dividir(primaryDamage, m), primaryType, dividir(secondaryDamage, m), secondaryType
end
defesa:register()

local defesaMana = CreatureEvent("JVEvolucaoMana")
function defesaMana.onManaChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if not creature:isPlayer() then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end
	local m = E.multiplicador(creature)
	return dividir(primaryDamage, m), primaryType, dividir(secondaryDamage, m), secondaryType
end
defesaMana:register()

local entrar = CreatureEvent("JVEvolucaoLogin")
function entrar.onLogin(player)
	player:registerEvent("JVEvolucaoDefesa")
	player:registerEvent("JVEvolucaoMana")
	local n = E.nivel(player)
	if n > 0 then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("[Evolucao] %s: ataque e defesa %dx.", NOMES[n], MULT[n]))
	end
	return true
end
entrar:register()

local comando = TalkAction("!evolucao")
function comando.onSay(player, words, param)
	local n = E.nivel(player)
	local texto
	if n == 0 then
		texto = "[Evolucao] Voce ainda nao tem evolucao de classe. Fale com o Mestre das Classes no templo de Thunder City (100.000 gold por nivel)."
	else
		texto = string.format("[Evolucao] %s: ataque contra monstros e defesa %dx.", NOMES[n], MULT[n])
		if n < #MULT then
			texto = texto .. string.format(" Proxima: %s (%dx) por 100.000 gold no Mestre das Classes.", NOMES[n + 1], MULT[n + 1])
		end
	end
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, texto)
	return false
end
comando:register()
