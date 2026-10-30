-- Teste do treino automatico com uma imitacao minima da API do TFS 1.3
SKILL_FIST, SKILL_CLUB, SKILL_SWORD, SKILL_AXE, SKILL_DISTANCE, SKILL_SHIELD = 0, 1, 2, 3, 4, 5
WEAPON_NONE, WEAPON_SWORD, WEAPON_CLUB, WEAPON_AXE, WEAPON_SHIELD, WEAPON_DISTANCE, WEAPON_WAND, WEAPON_AMMO = 0, 1, 2, 3, 4, 5, 6, 7
CONST_SLOT_LEFT, CONST_SLOT_RIGHT = 6, 5
MESSAGE_STATUS_CONSOLE_BLUE = 4

local tipos = {[2400] = WEAPON_SWORD, [2525] = WEAPON_SHIELD, [2190] = WEAPON_WAND, [2389] = WEAPON_DISTANCE}
function ItemType(id) return {getWeaponType = function() return tipos[id] or WEAPON_NONE end} end

local registrados = {}
function GlobalEvent(nome)
  local o = {nome = nome}
  function o:interval(ms) self.ms = ms end
  function o:register() registrados.global = self end
  return o
end
function TalkAction(w)
  local o = {words = w}
  function o:separator(s) self.sep = s end
  function o:register() registrados.talk = self end
  return o
end

local function novoJogador(guid, voc, pos, slots, gm)
  local p = {guid = guid, voc = voc, pos = pos, slots = slots or {}, tries = {}, mana = 0, msgs = {}, idle = 0, gm = gm}
  function p:getGuid() return self.guid end
  function p:getVocation() local v = self.voc; return {getId = function() return v end} end
  function p:getPosition() return self.pos end
  function p:getSlotItem(s) local id = self.slots[s]; if id then return {getId = function() return id end} end end
  function p:addSkillTries(s, n) self.tries[s] = (self.tries[s] or 0) + n end
  function p:addManaSpent(n) self.mana = self.mana + n end
  function p:sendTextMessage(t, m) self.msgs[#self.msgs + 1] = m end
  function p:resetIdleTime() self.idle = self.idle + 1 end
  function p:getGroup() local g = self.gm; return {getAccess = function() return g end} end
  return p
end

local sala = {x = 216, y = 1261, z = 8}
local salaPremium = {x = 31, y = 1208, z = 4}
local cidade = {x = 991, y = 1210, z = 7}
local knight = novoJogador(1, 8, sala, {[CONST_SLOT_LEFT] = 2400, [CONST_SLOT_RIGHT] = 2525})
local mago = novoJogador(2, 5, salaPremium, {[CONST_SLOT_LEFT] = 2190})
local paladino = novoJogador(3, 3, cidade, {[CONST_SLOT_LEFT] = 2389})
local semArma = novoJogador(4, 4, sala, {})
local players = {knight, mago, paladino, semArma}
Game = {getPlayers = function() return players end}

dofile(arg[1])
local ok = 0
local function check(cond, desc) assert(cond, "FALHOU: " .. desc); ok = ok + 1 end

check(registrados.global and registrados.global.ms == 2000, "globalevent registrado com intervalo")
check(registrados.talk and registrados.talk.sep == " ", "talkaction registrada")

for i = 1, 3 do registrados.global.onThink(2000) end
check(knight.tries[SKILL_SWORD] == 3 and knight.tries[SKILL_SHIELD] == 3, "knight treina sword + shielding")
check(knight.mana == 15, "knight ganha magic (5 x 3)")
check(knight.idle == 3, "knight nao cai por AFK")
check(#knight.msgs == 1 and knight.msgs[1]:find("sword %+ shielding %+ magic level"), "aviso de inicio unico")
check(mago.tries[SKILL_FIST] == nil and mago.mana == 120, "mago (MS) com wand: so magic 40 x 3")
check(paladino.mana == 0 and next(paladino.tries) == nil and #paladino.msgs == 0, "fora da sala nao treina")
check(semArma.tries[SKILL_FIST] == 3, "knight sem arma treina fist")

knight.pos = cidade
registrados.global.onThink(2000)
check(knight.msgs[#knight.msgs]:find("Pausado"), "aviso ao sair da sala")
check(TREINO_AUTO.jogadores[1] == nil, "estado limpo ao sair")

-- relog longe da sala apos muito tempo: nao deve avisar
TREINO_AUTO.jogadores[4] = os.time() - 999
semArma.pos = cidade
local antes = #semArma.msgs
registrados.global.onThink(2000)
check(#semArma.msgs == antes, "sem aviso falso depois de relogar")

registrados.talk.onSay(paladino, "!treino", "")
check(paladino.msgs[#paladino.msgs]:find("Entre em uma sala"), "!treino explica fora da sala")
local gm = novoJogador(9, 0, cidade, {}, true)
registrados.talk.onSay(gm, "!treino", "OFF")
check(TREINO_AUTO.cfg.ativo == false, "GM desliga o sistema")
local m = mago.mana
registrados.global.onThink(2000)
check(mago.mana == m, "sistema desligado nao treina")
registrados.talk.onSay(paladino, "!treino", "on")
check(TREINO_AUTO.cfg.ativo == false, "jogador comum nao liga o sistema")
registrados.talk.onSay(gm, "!treino", "on")
check(TREINO_AUTO.cfg.ativo == true, "GM liga de novo")
print(("OK: %d verificacoes passaram"):format(ok))
