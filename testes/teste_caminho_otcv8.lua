North,East,South,West,NorthEast,SouthEast,SouthWest,NorthWest=0,1,2,3,4,5,6,7
local tiles, enviado, chamadas = {}, nil, 0
local function key(x,y) return x..':'..y end
local function tile(x,y,id,pathable,walkable)
 local item={getId=function()return id end}
 tiles[key(x,y)]={isWalkable=function()return walkable~=false end,
  isPathable=function()return pathable~=false end,getItems=function()return id and {item} or {} end}
end
g_map={getTile=function(p)return tiles[key(p.x,p.y)]end}
g_game={autoWalk=function(path, start)enviado=path;chamadas=chamadas+1;assert(start.x==0 and start.y==0)end}
local player={getPosition=function()return{x=0,y=0,z=7}end}
dofile('clientes/visual/mods/jv_caminho/jv_caminho.lua')
local destino={x=3,y=0,z=7}
tile(1,0,2118,false);tile(2,0,2121,false);tile(3,0)
assert(caminhar(player,destino) and #enviado==3,'nao atravessou fogo e veneno')
for x=0,3 do tile(x,1)end
assert(caminhar(player,destino),'nao encontrou caminho seguro')
local passos={[North]={0,-1},[East]={1,0},[South]={0,1},[West]={-1,0},
 [NorthEast]={1,-1},[SouthEast]={1,1},[SouthWest]={-1,1},[NorthWest]={-1,-1}}
local x,y=0,0
for _,d in ipairs(enviado)do x=x+passos[d][1];y=y+passos[d][2];assert(not (y==0 and (x==1 or x==2)),'passou por campo apesar da rota segura')end
tiles={};tile(1,0,9999,false);tile(2,0);tile(3,0)
local antes=chamadas
assert(not caminhar(player,destino) and chamadas==antes,'atravessou obstaculo')
tiles={};tile(1,0,2118,false,false);tile(2,0);tile(3,0)
assert(not caminhar(player,destino),'atravessou bloqueio solido sobre campo')
tiles={};tile(1,0,2118,false);tile(2,0);tile(3,0)
assert(caminhar(player,destino),'nao saiu de campo')
assert(not caminhar(player,{x=50,y=0,z=7}),'destino distante deve usar cliente original')
assert(not caminhar(player,{x=3,y=0,z=8}),'atravessou andar')
print('OK: OTCv8 evita campos, atravessa quando preciso, respeita obstaculos e preserva fallback')
