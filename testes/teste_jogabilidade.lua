-- Lua 5.1: lua5.1 testes/teste_jogabilidade.lua (na raiz do kit).
-- Executa os modulos reais com dependencias do jogo controladas.
local function check(v, msg) assert(v, msg) end
local function carregar(path) dofile(path) end

-- Parar tem prioridade sobre a automacao; retomar pela espada continua possivel.
modules = {}; g_platform = {isMobile = function() return false end}
g_settings = {get = function() return false end, set = function() end}
PlayerStates = {Pz = 1}; g_clock = {millis = function() return 10000 end}
g_logger = {info = function() end}; ProtocolGame = {registerExtendedOpcode = function() end}
function connect() end
local tick
function cycleEvent(fn, intervalo) if intervalo == 400 then tick = fn end return intervalo end
function scheduleEvent() end
local pl = {getPosition = function() return {x=10,y=10,z=7} end, hasState = function() return false end}
local alvo = {isMonster = function() return true end, getHealthPercent = function() return 100 end,
    getPosition = function() return {x=11,y=10,z=7} end, getId = function() return 123 end}
g_map = {getSpectators = function() return {alvo} end}
local atacando, ataques, seguiu, falas = false, 0, true, {}
g_game = {isOnline = function() return true end, getLocalPlayer = function() return pl end,
    isAttacking = function() return atacando end, setChaseMode = function() end,
    attack = function() ataques = ataques + 1; atacando = true end,
    talk = function(t) falas[#falas+1] = t end,
    cancelAttack = function() atacando = false end, cancelFollow = function() seguiu = false end}
carregar('web/jv_autoataque.lua')
JVAutoAtaque.iniciar(); JVAutoAtaque.definir(true); tick(); tick()
JVAutoAtaque.pararCombate()
for i=1,10 do tick() end
check(ataques == 1 and not atacando and not seguiu and not JVAutoAtaque.ligado, 'Parar foi desfeito')
check(falas[#falas] == '!automagia off', 'Magias de ataque ficaram ligadas')
for _, t in ipairs(falas) do check(not t:find('autocura') and not t:find('autopocao'), 'Parar alterou a cura') end
JVAutoAtaque.definir(true); tick()
check(ataques == 2 and atacando, 'Nao retomou pela espada')
print('OK: Parar, retomada e cura independente')

-- Cura usa apenas confirmacao valida e descarta o estado da sessao anterior.
local eventos, resposta, timers = nil, nil, {}
rootWidget = {}; g_keyboard = {bindKeyDown = function() end}
function connect(obj, ev) eventos = ev end
function scheduleEvent(fn, ms) timers[#timers+1] = {fn=fn,ms=ms} end
ProtocolGame.registerExtendedOpcode = function(op, fn) resposta = fn end
local function botao()
    return {isDestroyed=function() return false end, setOpacity=function(self,v) self.opacity=v end,
        setBorderWidth=function() end, setBorderColor=function() end}
end
carregar('web/jv_rapido.lua'); JVRapido.botoes = {cura=botao()}
JVRapido.iniciar(); JVRapido.pintar()
check(JVRapido.botoes.cura.opacity == 0.65, 'Cura parece confirmada antes da resposta')
resposta(nil,79,'1,0,1'); check(JVRapido.botoes.cura.opacity==1, 'Cura ligada nao confirmada')
resposta(nil,79,'9,0,1'); check(JVRapido.cura==true, 'Aceitou estado invalido')
resposta(nil,79,'0,0,0'); check(JVRapido.botoes.cura.opacity==0.45, 'Cura desligada nao confirmada')
eventos.onGameEnd(); eventos.onGameStart()
check(JVRapido.cura==nil and JVRapido.pocao==nil and JVRapido.botoes.cura.opacity==0.65, 'Vazou estado entre sessoes')

-- Monta os botoes reais, sem desenhar; verifica clique pendente e resposta.
local gameEvents = eventos
g_platform.isMobile = function() return true end
JVRapido.ligado = false; JVRapido.iniciar(); gameEvents = eventos
local widgets = {}
g_ui = {createWidget = function()
    local b = botao()
    setmetatable(b, {__index=function() return function() end end})
    widgets[#widgets+1] = b; return b
end}
modules.game_interface = {getMapPanel=function() return {} end}
AnchorTop, AnchorLeft = 1,2
gameEvents.onGameStart()
for _, t in ipairs(timers) do if t.ms==1500 then t.fn() end end
local enviados = {}
g_game.getProtocolGame = function() return {sendExtendedOpcode=function(self,o,t) enviados[#enviados+1]=t end} end
JVRapido.botoes.cura.onClick()
check(enviados[#enviados]=='', 'Estado desconhecido alternou a cura')
resposta(nil,79,'1,0,1'); JVRapido.botoes.cura.onClick()
check(JVRapido.pendente and JVRapido.cura and enviados[#enviados]=='tudo', 'Clique alterou estado antes de confirmar')
JVRapido.botoes.cura.onClick()
check(enviados[#enviados]=='', 'Clique duplicado alternou outra vez')
resposta(nil,79,'0,0,0')
check(not JVRapido.pendente and not JVRapido.cura and JVRapido.botoes.cura.opacity==0.45, 'Resposta nao atualizou o botao')
JVRapido.botoes.cura.onClick()
local espera = timers[#timers]
check(espera.ms==2500, 'Nao agendou recuperacao da resposta')
espera.fn()
check(JVRapido.cura==nil and not JVRapido.pendente and enviados[#enviados]=='', 'Nao recuperou confirmacao perdida')
resposta(nil,79,'1,0,1'); JVRapido.botoes.cura.onClick()
local antiga = timers[#timers]
gameEvents.onGameEnd(); gameEvents.onGameStart(); resposta(nil,79,'1,0,1')
antiga.fn()
check(JVRapido.cura==true and JVRapido.pocao==true, 'Timeout da sessao antiga alterou a nova')
print('OK: estado desconhecido, resposta, troca de sessao e clique duplicado')

-- Autoloot: ignorar prevalece sobre raros, caros, lista, moedas e depot.
local criaturas, comando, agendados = {}, nil, {}
function CreatureEvent(nome)
    local e={register=function() end}; criaturas[nome]=e; return e
end
function TalkAction() comando={separator=function() end,register=function() end}; return comando end
function addEvent(fn, ms, ...) agendados[#agendados+1]={fn=fn,args={...}} end
MESSAGE_STATUS_CONSOLE_BLUE=1; MESSAGE_STATUS_SMALL=2; ITEM_ATTRIBUTE_CORPSEOWNER=3
AUTOLOOT_STORAGE_START, AUTOLOOT_STORAGE_END = 2000,2001
local nomes={['royal helmet']=2498,['gold coin']=2148}
function ItemType(v)
    local id = type(v)=='number' and v or nomes[v] or 0
    return {getId=function() return id end, getName=function() return id==2498 and 'royal helmet' or 'gold coin' end}
end
function MonsterType() return {getLoot=function() return {{itemId=2498,chance=10}} end} end
JV_PRECOS={[2498]=5000}
local dados, mensagens, movimentos, removidos = {[2000]=2498}, {}, 0,0
local player = {getStorageValue=function(self,s) return dados[s] or -1 end,
    setStorageValue=function(self,s,v) dados[s]=v end,
    sendTextMessage=function(self,t,m) mensagens[#mensagens+1]=m end,
    isUsingOtClient=function() return true end, sendExtendedOpcode=function() end,
    getId=function() return 1 end, getBankBalance=function() return 0 end,
    setBankBalance=function(self,v) self.banco=v end, showTextDialog=function(self,id,t) self.dialogo=t end,
    getTown=function() return {getId=function()return 1 end} end,
    getDepotChest=function() return {} end}
function Player() return player end
local item={getId=function()return 2498 end,isContainer=function()return false end,
    getWorth=function()return 0 end,getCount=function()return 1 end,
    moveTo=function()movimentos=movimentos+1;return true end}
local corpo={getSize=function()return 1 end,getItem=function()return item end,
    getType=function()return{isCorpse=function()return true end}end,getAttribute=function()return 1 end}
function Tile() return {getTopDownItem=function()return corpo end} end
carregar('servidor-imagem/extras/data/scripts/custom/jv_loot.lua')
local function matar()
    criaturas.JVLootKill.onKill(player,{isMonster=function()return true end,getPosition=function()return{}end,getName=function()return'Dragon'end})
    local t=table.remove(agendados,1);t.fn(unpack(t.args))
end
comando.onSay(player,'!loot','ignorar, royal helmet'); matar()
check(movimentos==0 and dados[79300]==2498, 'Item ignorado foi recolhido')
dados[79205], dados[79206] = 1,1
matar(); check(movimentos==0, 'Item ignorado foi enviado ao depot')
-- A mesma storage permanece apos uma nova leitura/carregamento do modulo.
carregar('servidor-imagem/extras/data/scripts/custom/jv_loot.lua'); matar()
check(movimentos==0, 'Perdeu exclusao persistente')
comando.onSay(player,'!loot','permitir, 2498'); matar()
check(movimentos==1 and dados[79300]==0, 'Permitir nao restaurou a coleta')
comando.onSay(player,'!loot','ignorar, gold coin')
item.getId=function()return 2148 end;item.getWorth=function()return 10 end
item.remove=function()removidos=removidos+1 end
matar(); check(removidos==0, 'Moeda ignorada foi recolhida')
comando.onSay(player,'!loot','ignorar, item inexistente')
check(mensagens[#mensagens]:find('desconhecido'), 'Aceitou item invalido')
comando.onSay(player,'!loot','ignorados'); check(player.dialogo:find('2148'), 'Lista nao mostra ignorados')
for s=79300,79399 do dados[s]=3000+s-79300 end
comando.onSay(player,'!loot','ignorar, royal helmet')
check(mensagens[#mensagens]:find('cheia') and dados[79400]==nil, 'Lista ultrapassou as storages reservadas')
print('OK: ignorar persistente, permitir, moedas e item invalido')
print('Jogabilidade: todos os cenarios passaram')
