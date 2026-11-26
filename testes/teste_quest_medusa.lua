-- Fluxo real da alavanca: solo, grupo e destino bloqueado.
CONST_ME_POFF,CONST_ME_TELEPORT,RETURNVALUE_NOERROR,RETURNVALUE_NOTPOSSIBLE=1,2,0,1
function Position(x,y,z)
 if type(x)=='table' then return x end
 return {x=x,y=y,z=z,sendMagicEffect=function()end}
end
local pads={};local bloqueado=false;local gerados=0;local tempo=0;local callback
local function jogador(i)
 local p={indice=i,localidade=Position(946-i,1410,8),viagens=0}
 function p:isPlayer()return true end
 function p:teleportTo(destino)self.localidade=destino;self.viagens=self.viagens+1;return true end
 function p:getPosition()return self.localidade end
 function p:sendCancelMessage(m)self.msg=m end
 return p
end
function Tile(pos)
 return {getTopCreature=function()return pos.y==1410 and pads[pos.x] or nil end,
  queryAdd=function()return bloqueado and 1 or 0 end}
end
Game={getStorageValue=function()return tempo end,setStorageValue=function(_,v)tempo=v end,
 createMonster=function(nome)assert(nome=='Serpent Spawn');gerados=gerados+1;return{}end,
 getSpectators=function()return{}end}
function addEvent(f,ms)callback=f;assert(ms==4*60*60*1000)end
string.diff=function()return '4 horas'end
local alavanca={itemid=1945,transform=function(s,id)s.itemid=id end}
dofile('servidor-imagem/ajustes/quests/medusaAnihi.lua')
local p=jogador(2)
onUse(p,alavanca);assert(p.viagens==0 and gerados==0 and alavanca.itemid==1945)
pads[944]=p;bloqueado=true;onUse(p,alavanca);assert(p.viagens==0 and gerados==0 and tempo==0)
bloqueado=false;onUse(p,alavanca)
assert(p.viagens==1 and p.localidade.x==942 and p.localidade.y==1429 and gerados==8 and alavanca.itemid==1946)
assert(tempo>os.time() and callback);onUse(p,alavanca);assert(p.viagens==1 and gerados==8)
callback();assert(alavanca.itemid==1945)
tempo=0;pads={};local grupo={}
for i=1,5 do grupo[i]=jogador(i);pads[946-i]=grupo[i] end
onUse(grupo[1],alavanca)
for i=1,5 do assert(grupo[i].viagens==1 and grupo[i].localidade.x==944-i and grupo[i].localidade.y==1429)end
assert(gerados==16 and alavanca.itemid==1946)
print('OK: Medusa solo, equipe de cinco, cooldown e destino bloqueado')
