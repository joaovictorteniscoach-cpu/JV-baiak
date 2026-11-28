-- Spawns sao distribuidos apenas em pisos livres e preservam os monstros anteriores.
local tiles,registrados={},{}
function Position(x,y,z)return{x=x,y=y,z=z}end
local function key(p)return p.x..':'..p.y..':'..p.z end
function Tile(p)return tiles[key(p)]end
local function preparar(cx,cy)
 for x=-7,7 do for y=-7,7 do
  local pos=Position(cx+x,cy+y,7);local t={items={}}
  function t:getGround()return true end
  function t:getHouse()return nil end
  function t:hasFlag()return false end
  function t:getTopCreature()return nil end
  function t:getItems()return self.items end
  function t:getItemById(id)for _,item in ipairs(self.items)do if item.id==id then return item end end end
  tiles[key(pos)]=t
 end end
end
preparar(456,984);preparar(1400,1336)
local function ponto(p)local t={items={}};function t:getGround()return true end;function t:getTopCreature()end;function t:getItems()return self.items end;function t:getItemById(id)for _,i in ipairs(self.items)do if i.id==id then return i end end end;tiles[key(p)]=t end
ponto(Position(29994,30005,7));ponto(Position(30006,30005,7))
TILESTATE_PROTECTIONZONE,TILESTATE_BLOCKSOLID,TILESTATE_BLOCKPATH=1,2,3
Game={createItem=function(id,_,p)local i={id=id};function i:setActionId(a)self.aid=a end;tiles[key(p)].items[#tiles[key(p)].items+1]=i;return i end}
function MonsterType(n)registrados[n]=true;return{}end
local globais={};function GlobalEvent(n)local e={type=function()end,register=function()end,interval=function()end};globais[n]=e;return e end
function MoveEvent()return{type=function()end,aid=function()end,register=function()end}end
JV_ASCENSAO={hub=true,slots={},monstros={}}
dofile('servidor-imagem/extras/data/scripts/custom/jv_hunts_mapa.lua')
globais.JVHuntsMapaInicio.onStartup()
assert(#JV_ASCENSAO.slots==31)
local total={}
for _,s in ipairs(JV_ASCENSAO.slots)do total[s.nome]=(total[s.nome] or 0)+1 end
for _,nome in ipairs({'Sentinela do Groove','Guardiao do Groove','Guardiao das Brasas','Cacador Abissal','Guardiao da Fumaca','Soberano da Fumaca','Arauto Celestial'})do
 assert(registrados[nome] and total[nome] and JV_ASCENSAO.monstros[nome],nome..' ausente')
end
assert(total['Guardiao das Brasas']==4 and total['Cacador Abissal']==4 and total['Arauto Celestial']==5)
print('OK: 31 monstros, sete tipos e tres criaturas novas nas duas hunts')
