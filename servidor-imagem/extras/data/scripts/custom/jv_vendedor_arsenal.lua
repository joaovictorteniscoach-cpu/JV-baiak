-- Localiza um piso seguro junto ao Mestre das Classes, sem alterar o mapa.
local inicio=GlobalEvent('JVLojaArsenalInicio')
inicio:type('startup')
function inicio.onStartup()
 local centro=Position(988,1213,7)
 for _,c in ipairs(Game.getSpectators(centro,false,false,8,8,8,8)) do
  if c:isNpc() and c:getName()=='Arsenal Ascensao' then return true end
 end
 for raio=1,5 do for dx=-raio,raio do for dy=-raio,raio do
  if math.max(math.abs(dx),math.abs(dy))==raio then
   local p=Position(centro.x+dx,centro.y+dy,centro.z);local t=Tile(p)
   if t and t:getGround() and t:hasFlag(TILESTATE_PROTECTIONZONE) and not t:getHouse()
    and not t:hasFlag(TILESTATE_BLOCKSOLID) and not t:hasFlag(TILESTATE_BLOCKPATH)
    and not t:getTopCreature() and not t:getItemById(1387) and #(t:getItems() or {})==0 then
    if Game.createNpc('Arsenal Ascensao',p,false,false) then
     print('[Arsenal] Vendedor no templo: '..p.x..':'..p.y..':'..p.z);return true
    end
   end
  end
 end end end
 print('[Arsenal] Nao foi encontrado piso seguro para o vendedor no templo.')
 return true
end
inicio:register()
