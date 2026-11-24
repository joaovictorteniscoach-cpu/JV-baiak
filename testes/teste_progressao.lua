-- Modulos reais, com API do TFS controlada. Executar na raiz do repositorio.
local originalDofile=dofile
function dofile(p) return originalDofile('servidor-imagem/extras/'..p) end
local P=dofile('data/lib/jv_progressao.lua')
local eventos,globais,comandos={},{},{}
function CreatureEvent(n) local e={register=function()end};eventos[n]=e;return e end
function GlobalEvent(n) local e={register=function()end,interval=function()end,type=function()end};globais[n]=e;return e end
function TalkAction(n) local e={register=function()end,separator=function()end};comandos[n]=e;return e end
local move
function MoveEvent() move={type=function()end,aid=function()end,register=function()end};return move end
CONST_SLOT_LEFT,CONST_SLOT_RIGHT=5,6
CONDITION_HASTE,CONDITIONID_DEFAULT=1,2
CONDITION_PARAM_SUBID,CONDITION_PARAM_TICKS,CONDITION_PARAM_SPEED=3,4,5
ITEM_ATTRIBUTE_ATTACK,ITEM_ATTRIBUTE_DEFENSE,ITEM_ATTRIBUTE_ARMOR,ITEM_ATTRIBUTE_DESCRIPTION=6,7,8,9
COMBAT_HEALING=128;MESSAGE_STATUS_CONSOLE_BLUE=1;MESSAGE_EVENT_ADVANCE=2
WEAPON_WAND,WEAPON_DISTANCE=7,4
CONST_ME_MAGIC_RED,CONST_ME_FIREWORK_YELLOW,CONST_ME_TELEPORT,CONST_ME_POFF=1,2,3,4
TILESTATE_BLOCKSOLID,TILESTATE_BLOCKPATH=1,2
RETURNVALUE_NOERROR=0
TALKTYPE_MONSTER_SAY=1
function Condition()return{params={},setParameter=function(s,k,v)s.params[k]=v end}end
function Position(x,y,z)return{x=x,y=y,z=z,sendMagicEffect=function()end}end
local itensBase={
 [2400]={atk=48,def=35,arm=0,weapon=1},[2472]={atk=0,def=0,arm=17,weapon=0},
 [8922]={atk=0,def=0,arm=0,weapon=7},[8851]={atk=5,def=0,arm=0,weapon=4},
}
local function item(id)
 local b=itensBase[id] or {atk=0,def=0,arm=0,weapon=0}
 local tipo={getAttack=function()return b.atk end,getDefense=function()return b.def end,getArmor=function()return b.arm end,getWeaponType=function()return b.weapon end}
 return{id=id,attrs={},custom={},getType=function()return tipo end,getId=function()return id end,
  setAttribute=function(s,k,v)s.attrs[k]=v end,setCustomAttribute=function(s,k,v)s.custom[k:lower()]=v end,
  getCustomAttribute=function(s,k)return s.custom[k:lower()]end,setActionId=function(s,k)s.aid=k end,
  getActionId=function(s)return s.aid end,isContainer=function()return false end,
  getCount=function()return 1 end,remove=function(s)s.removido=true;return true end}
end
function ItemType(id)return item(id):getType()end
local function player(classe,sexo)
 local p={dados={},classe=classe or 1,sexo=sexo or 0,nivel=1000,localidade=Position(991,1210,7),guid=1,hp=10000,
  inventario={},condicoes={},aparencia={},aplicacoes=0,movimentos=0,money=0,banco=0}
 function p:getStorageValue(k)return self.dados[k] or -1 end
 function p:setStorageValue(k,v)self.dados[k]=v end
 function p:getVocation()return{getId=function()return self.classe+8 end,getClientId=function()return self.classe end,getAttackSpeed=function()return 350 end}end
 function p:getSex()return self.sexo end
 function p:getId()return self.guid end
 function p:getGuid()return self.guid end
 function p:setAttackSpeed(v)self.ataqueMs=v end
 function p:removeCondition(t,id,sub)self.condicoes[sub]=nil end
 function p:addCondition(c)self.condicoes[c.params[CONDITION_PARAM_SUBID]]=c;self.aplicacoes=self.aplicacoes+1 end
 function p:getOutfit()return self.aparencia end
 function p:setOutfit(o)self.aparencia=o end
 function p:addOutfitAddon(tipo,addon)self.addonLiberado=addon end
 function p:getSlotItem(slot)return self.inventario[slot]end
 function p:getLevel()return self.nivel end
 function p:registerEvent()end
 function p:sendTextMessage(t,m)self.msg=m end
 function p:getPosition()return self.localidade end
 function p:getHealth()return self.hp end
 function p:getExperience()return 0 end
 function p:isPlayer()return true end
 function p:isMonster()return false end
 function p:getPlayer()return self end
 function p:getParty()return self.party end
 function p:isPzLocked()return self.locked end
 function p:getTown()return{getTemplePosition=function()return Position(991,1210,7)end}end
 function p:getClosestFreePosition(t)return t end
 function p:teleportTo(t)if self.teleportFalha then return false end;self.localidade=t;self.movimentos=self.movimentos+1;return true end
 function p:showTextDialog(id,t)self.dialogo=t end
 function p:getMoney()return self.money end
 function p:getBankBalance()return self.banco end
 function p:removeMoney(v)if self.money<v then return false end self.money=self.money-v;return true end
 function p:setBankBalance(v)self.banco=v end
 return p
end
local players={}
Game={getPlayers=function()return players end}
dofile('data/scripts/custom/jv_evolucao.lua')
local E=JV_EVOLUCAO
for classe=1,4 do for sexo=0,1 do
 local p=player(classe,sexo)
 for n=1,4 do
  p.dados[P.storage]=n;E.aplicar(p)
  assert(p.ataqueMs==P.intervalo[n]);assert(p.aparencia.lookType==P.classes[classe].outfits[sexo+1]);assert(p.aparencia.lookAddons==P.addons[n])
  assert(p.condicoes[P.storage].params[CONDITION_PARAM_SPEED]==P.movimento[n])
  E.aplicar(p);assert(p.aplicacoes==n,'bonus acumulou sem trocar de evolucao')
 end
 eventos.JVEvolucaoSair.onLogout(p);E.aplicar(p);assert(p.aplicacoes==5,'nao reaplicou ao reconectar')
end end
local p=player(3);p.dados[P.storage]=4;p.dados[P.storageAbates]=99999
assert(E.maestria(p)==10 and E.ataque(p)==12)
local monstro={isMonster=function()return true end}
assert(eventos.JVEvolucaoDano.onHealthChange(monstro,p,1000,1,0,2,0)==12000)
assert(eventos.JVEvolucaoDano.onHealthChange(monstro,p,1000,COMBAT_HEALING,0,2,0)==1000)
assert(eventos.JVEvolucaoDano.onHealthChange(player(),p,1000,1,0,2,0)==1000,'bonus PvE vazou ao PvP')
assert(eventos.JVEvolucaoDefesa.onHealthChange(p,nil,1000,1,0,2,0)==100)
print('OK: 4 classes, ambos sexos, bonus sem acumular, reconexao, maestria e PvP')

-- Mapa em memoria: criar somente em coordenadas livres, nunca substituir o mapa.
local tiles,monstros={},{}
local function key(v)return v.x..':'..v.y..':'..v.z end
function Tile(v)return tiles[key(v)]end
local function tile(v)
 local t={p=v,itens={},getHouse=function()end,getTopCreature=function()end}
 function t:getGround()return self.chao end
 function t:getItems()return self.itens end
 function t:hasFlag()return self.bloqueado end
 function t:queryAdd()return self.bloqueado and 1 or 0 end
 function t:getItemById(id)for _,i in ipairs(self.itens)do if i.id==id then return i end end end
 tiles[key(v)]=t;return t
end
local velho=tile(Position(994,1206,7));velho.chao=true
Game.createTile=function(v)return Tile(v) or tile(v)end
Game.createItem=function(id,q,v)
 local i=item(id)
 if v then local t=assert(Tile(v));if id==407 then t.chao=i else t.itens[#t.itens+1]=i end end
 return i
end
local spawnCount=0
Game.createMonster=function(nome,v,extended,force)
 assert(not force,'spawn forcado');assert(Tile(v) and Tile(v):getGround())
 spawnCount=spawnCount+1;local id=spawnCount
 local m={getId=function()return id end};monstros[id]=m;return m
end
Game.createNpc=function()return {} end
Game.getSpectators=function()return{}end
function Monster(id)return monstros[id]end
dofile('data/scripts/custom/jv_ascensao.lua')
local H=JV_ASCENSAO
globais.JVAscensaoInicio.onStartup()
assert(H.hub and H.entrada and Tile(H.entrada)==velho)
local total=0
for i,h in ipairs(P.hunts)do
 assert(H.areas[i]);total=total+(h.boss and 37 or 50)
 assert(Tile(Position(h.x-h.raio+2,h.y,h.z)):getItemById(1387).aid==47820)
 assert(Tile(Position(P.hub.x-12+(i-1)*6,P.hub.y,7)):getItemById(1387).aid==47800+i)
 for andar=1,5 do
  local sala=H.andares[i][andar];assert(sala.z==h.z+andar-1)
  local volta=Tile(Position(sala.x-h.raio+2,sala.y,sala.z)):getItemById(1387)
  assert(volta and volta.aid==(andar==1 and 47820 or 47830),'portal de volta ausente')
  if andar<5 then
   local avancar=Position(sala.x+h.raio-2,sala.y,sala.z)
   assert(Tile(avancar):getItemById(1387).aid==47830 and H.transicoes[key(avancar)].andar==andar+1,'portal seguinte ausente')
  end
 end
end
for i,h in ipairs(P.hunts)do
 local chegada=Position(h.x-h.raio+3,h.y,7);local visiveis=0
 local convidados=0
 for _,slot in ipairs(H.slots)do if slot.hunt.monstro==h.monstro then
  if h.convidado and slot.nome==h.convidado then convidados=convidados+1 end
  local p=slot.pos;local sala=H.andares[i][slot.andar]
  assert(sala and math.abs(p.x-sala.x)<h.raio and math.abs(p.y-sala.y)<h.raio and p.z==sala.z,'spawn fora da sala')
  assert(not (p.x==chegada.x and p.y==chegada.y),'spawn na chegada')
  if slot.andar==1 and math.abs(p.x-chegada.x)<=7 and math.abs(p.y-chegada.y)<=5 then visiveis=visiveis+1 end
 end end
 assert(visiveis>=1,'nenhum monstro visivel na chegada da hunt '..i)
 if h.convidado then assert(convidados>0 and H.monstros[h.convidado] and H.monstros[h.convidado].nome==h.nome,'monstro convidado ausente da hunt '..i) end
end
assert(spawnCount==total);H.repor();assert(spawnCount==total,'duplicou monstros vivos')
assert(not H.criarSala(P.hub,8),'sobrescreveu tiles ocupados')
local chegada=Position(P.hunts[1].x-P.hunts[1].raio+3,P.hunts[1].y,7)
Tile(chegada).getTopCreature=function()return{}end
local alternativa=H.livre(player(),chegada,2)
assert(alternativa and not Tile(alternativa):getItemById(1387),'segunda pessoa desembarca no portal de volta')
local h0=H.slots[1];monstros[h0.id]=nil;H.repor();assert(spawnCount==total,'respawn sem espera')
local tempo=os.time;os.time=function()return tempo()+1000 end;H.repor();assert(spawnCount==total+1);os.time=tempo
-- Reforco de portal antigo: exige destino identico e nunca cria em PZ/bloqueio.
local conf=P.entradasReforcadas[1];local o,d=conf.origem,conf.destino
local old=tile(Position(o[1],o[2],o[3]));old.chao=true
old.itens={{id=1387,getDestination=function()return Position(d[1],d[2],d[3])end}}
for dx=-7,7 do for dy=-7,7 do local t=tile(Position(d[1]+dx,d[2]+dy,d[3]));t.chao=true end end
local bloqueio=Tile(Position(d[1]-3,d[2]-3,d[3]));bloqueio.bloqueado=true
local antes=#H.slots;H.reforcarEntradas();assert(#H.slots==antes+2,'faltou reforco na entrada auditada')
for i=antes+1,#H.slots do assert(not Tile(H.slots[i].pos).bloqueado and H.slots[i].hunt.monstro==conf.monstro)end
H.reforcarEntradas();assert(#H.slots==antes+2,'duplicou reforco de portal')
local p=player();p.dados[P.storage]=0;assert(not H.podeEntrar(p,1))
p.dados[P.storage]=1;p.nivel=299;assert(not H.podeEntrar(p,1))
p.nivel=300;assert(H.podeEntrar(p,1),'primeira hunt deve aceitar level 300 e Evolucao I')
p.dados[P.storage]=4;p.nivel=1000
for i=1,#P.hunts do assert(H.entrar(p,i),'conteudo maximo exige dupla') end
for i,h in ipairs(P.hunts) do
 for andar=1,4 do
  local origem=H.andares[i][andar];local alvo=H.andares[i][andar+1]
  local saida=Position(origem.x+h.raio-2,origem.y,origem.z)
  move.onStepIn(p,{getActionId=function()return 47830 end},saida,p.localidade)
  assert(p.localidade.x==alvo.x-h.raio+3 and p.localidade.z==alvo.z,'portal de avanco falhou na hunt '..i..' andar '..andar)
  local retorno=Position(alvo.x-h.raio+2,alvo.y,alvo.z)
  move.onStepIn(p,{getActionId=function()return 47830 end},retorno,p.localidade)
  assert(p.localidade.x==origem.x+h.raio-3 and p.localidade.z==origem.z,'portal de retorno falhou na hunt '..i..' andar '..andar)
 end
end
local sala=H.andares[1][1];local avancar=Position(sala.x+P.hunts[1].raio-2,sala.y,sala.z)
move.onStepIn(p,{getActionId=function()return 47830 end},avancar,p.localidade)
assert(p.localidade.z==8 and p.localidade.x==H.andares[1][2].x-P.hunts[1].raio+3,'portal nao avancou ao segundo andar')
local sala2=H.andares[1][2];local voltar=Position(sala2.x-P.hunts[1].raio+2,sala2.y,sala2.z)
move.onStepIn(p,{getActionId=function()return 47830 end},voltar,p.localidade)
assert(p.localidade.z==7 and p.localidade.x==sala.x+P.hunts[1].raio-3,'portal nao voltou ao primeiro andar')
p.locked=true;assert(not H.entrar(p,1));p.locked=false
p.locked=true;move.onStepIn(p,{getActionId=function()return 47820 end},p.localidade,p.localidade)
assert(p.msg:find('bloqueio de combate'));p.locked=false
p.teleportFalha=true;move.onStepIn(p,{getActionId=function()return 47820 end},p.localidade,p.localidade)
assert(p.msg:find('Nao foi possivel voltar'));p.teleportFalha=false
p.teleportFalha=true;assert(not H.entrar(p,1));p.teleportFalha=false
move.onStepIn(p,{getActionId=function()return 47820 end},p.localidade,p.localidade)
assert(p.localidade.x==991 and p.localidade.y==1210,'volta nao leva ao templo')
print('OK: 5 hunts, portals de ida/volta, area ocupada, respawn limitado e todo conteudo solo no topo')

local espada=item(2400);H.reforcar(espada,4);assert(espada.attrs[ITEM_ATTRIBUTE_ATTACK]==72 and espada.attrs[ITEM_ATTRIBUTE_DEFENSE]==53)
H.reforcar(espada,4);assert(espada.attrs[ITEM_ATTRIBUTE_ATTACK]==72,'reforco acumulou')
local armadura=item(2472);H.reforcar(armadura,4);assert(armadura.attrs[ITEM_ATTRIBUTE_ARMOR]==26)
local wand=item(8922);H.reforcar(wand,4);p.classe=3;p.inventario[5]=wand;p.dados[P.storageAbates]=0
assert(E.ataque(p)==15,'wand nao recebe poder proporcional')
p.classe=1;assert(E.ataque(p)==10,'bonus da arma contado duas vezes no knight')
local parceiro=player();parceiro.guid=2;parceiro.dados[P.storage]=4;parceiro.localidade=p.localidade
p.party={getLeader=function()return p end,getMembers=function()return{p,parceiro}end}
local derrotado={getName=function()return P.hunts[1].monstro end,getMaster=function()end,getPosition=function()return p.localidade end}
local drops=0;local corpse={addItem=function(self,id,q)drops=drops+1;return item(id)end}
local random=math.random;math.random=function(a,b)return 1 end
eventos.JVAscensaoMorte.onDeath(derrotado,corpse,p,p)
assert(drops==1 and p.dados[P.storageAbates]==1 and parceiro.dados[P.storageAbates]==1,'party duplicou credito ou nao creditou dupla')
math.random=function(a,b)return b or a end
eventos.JVAscensaoMorte.onDeath(derrotado,corpse,p,p);assert(drops==1,'chance rara saturada')
math.random=random
print('OK: atributos reais, sem reforco duplicado, wands, dupla e rareza independente do loot global')

CONST_SLOT_BACKPACK=10
JV_PRECOS={[2183]=3000}
local raro,normal=item(2183),item(2183);H.reforcar(raro,4)
local mochila={isContainer=function()return true end,getSize=function()return 2 end,
 getItem=function(self,i)return i==0 and raro or normal end}
p.inventario[10]=mochila;p.banco=0;p.dados[79100]=2183
dofile('data/scripts/custom/jv_hunt.lua')
comandos['!venderloot'].onSay(p,'!venderloot','')
assert(not raro.removido and normal.removido and p.banco==3000,'venda em lote destruiu equipamento reforcado')
print('OK: venda em lote preserva raros reforcados e vende loot normal')

-- Compra: verificar level e dinheiro antes de cobrar; preservar evolucoes antigas.
local callback
KeywordHandler={new=function()return{}end};FocusModule={new=function()return{}end}
NpcHandler={new=function()return{
 isFocused=function()return true end,say=function(self,t,cid)p.fala=t end,
 setMessage=function()end,setCallback=function(self,k,fn)callback=fn end,addModule=function()end,
}end}
NpcSystem={parseParameters=function()end};CALLBACK_MESSAGE_DEFAULT=1
MESSAGE_GREET,MESSAGE_FAREWELL,MESSAGE_WALKAWAY=1,2,3
function Player()return p end
dofile('data/npc/scripts/jv_evolucao.lua')
p=player();p.nivel=199;p.money=100000;p.dados[P.storage]=0
callback(1,1,'evoluir');callback(1,1,'sim');assert(p.money==100000 and p.dados[P.storage]==0)
p.nivel=200;p.money=1;p.banco=99999
callback(1,1,'evoluir');callback(1,1,'sim');assert(p.money==0 and p.banco==0 and p.dados[P.storage]==1)
p.nivel=399;p.banco=300000
callback(1,1,'evoluir');callback(1,1,'sim');assert(p.banco==300000 and p.dados[P.storage]==1)
p.dados[P.storage]=4;p.nivel=8;E.aplicar(p);assert(E.nivel(p)==4,'perdeu evolucao comprada antes')
print('OK: compra, level, pagamento misto, limite e evolucoes antigas preservadas')
JV_TEST_PROGRESSAO={P=P,player=player,item=item,eventos=eventos,globais=globais,comandos=comandos}
