-- OTClientV8: usa apenas tiles visiveis; o cliente original trata destinos distantes.
local campos = { [105]=true, [2118]=true, [2119]=true, [2120]=true, [2121]=true,
  [2123]=true, [2124]=true, [2125]=true, [2131]=true, [2132]=true, [2133]=true,
  [10069]=true, [10070]=true, [10071]=true }
local movimentos = {
  {0,-1,North}, {1,0,East}, {0,1,South}, {-1,0,West},
  {1,-1,NorthEast}, {1,1,SouthEast}, {-1,1,SouthWest}, {-1,-1,NorthWest}
}
local function chave(x,y) return x .. ':' .. y end
local function estado(tile)
  if not tile or not tile:isWalkable(false) then return false, false end
  local campo = false
  for _, item in ipairs(tile:getItems()) do
    if campos[item:getId()] then campo = true end
  end
  if not tile:isPathable() and not campo then return false, false end
  return true, campo
end

local function procurar(origem, destino, permitirCampo)
  local limite=24
  local origemKey=chave(origem.x,origem.y)
  local lista, visitados={{x=origem.x,y=origem.y}}, {[origemKey]=true}
  local inicio=1
  while inicio<=#lista do
    local atual=lista[inicio];inicio=inicio+1
    if atual.x==destino.x and atual.y==destino.y then
      local path={}
      while atual.anterior do table.insert(path,1,atual.dir);atual=atual.anterior end
      return path
    end
    for _,m in ipairs(movimentos) do
      local x,y=atual.x+m[1],atual.y+m[2]
      local k=chave(x,y)
      if not visitados[k] and math.abs(x-origem.x)<=limite and math.abs(y-origem.y)<=limite then
        visitados[k]=true
        local tile=g_map.getTile({x=x,y=y,z=origem.z})
        local livre,campo=estado(tile)
        if livre and (permitirCampo or not campo) then
          lista[#lista+1]={x=x,y=y,anterior=atual,dir=m[3]}
        end
      end
    end
  end
end

function caminhar(player,destino)
  if not player or not destino then return false end
  local origem=player:getPosition()
  if origem.z~=destino.z or math.max(math.abs(origem.x-destino.x),math.abs(origem.y-destino.y))>24 then return false end
  local ok,path=pcall(function() return procurar(origem,destino,false) or procurar(origem,destino,true) end)
  if not ok or not path or #path==0 or #path>127 then return false end
  g_game.autoWalk(path,{x=0,y=0,z=0})
  return true
end
