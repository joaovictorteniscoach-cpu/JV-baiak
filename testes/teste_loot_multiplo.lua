-- Testa a rotina real com corpos pequenos, muitas pilhas e bolsas de excesso.
INDEX_WHEREEVER=-1;FLAG_NOLIMIT=1
local function removerDoPai(item)
 if not item.parent then return end
 for i,v in ipairs(item.parent.items) do if v==item then table.remove(item.parent.items,i);break end end
 item.parent=nil
end
local function item(id,cap)
 local o={id=id,cap=cap or 0,items={},attrs={},removido=false}
 function o:isContainer()return self.cap>0 end
 function o:getId()return self.id end
 function o:getCapacity()return self.cap end
 function o:getSize()return #self.items end
 function o:getItem(i)return self.items[i+1]end
 function o:getCustomAttribute(k)return self.attrs[k]end
 function o:setCustomAttribute(k,v)self.attrs[k]=v end
 function o:addItem(iid,q,index,flags)
  if #self.items>=self.cap or (flags~=FLAG_NOLIMIT and #self.items>=self.cap-1) then return nil end
  local child=item(iid,iid==1988 and 20 or 0);child.parent=self;self.items[#self.items+1]=child;return child
 end
 function o:remove()removerDoPai(self);self.removido=true;return true end
 function o:moveTo(dest,flags)
  if #dest.items>=dest.cap or (flags~=FLAG_NOLIMIT and #dest.items>=dest.cap-1) then return false end
  removerDoPai(self);self.parent=dest;dest.items[#dest.items+1]=self;return true
 end
 function o:createLootItem(bloco)
  if not bloco.derrubar then return true end
  return self:addItem(bloco.id,1)~=nil
 end
 return o
end
Game={createItem=function(id) return item(id,20) end}
local chamadas=0
MonsterType={getBossReward=function(_,factor,top)chamadas=chamadas+1;if top then return {{2160,1}} end;return {} end}
dofile('servidor-imagem/extras/data/scripts/custom/jv_loot_multiplo.lua')
local L=JV_LOOT_MULTIPLO;local corpo=item(5995,4)
for _=1,50 do assert(L.gerar(corpo,{id=2160,derrubar=true})) end
local function contar(c,depth)
 local total,profundidade=0,depth
 assert(c:getSize()<=c:getCapacity(),'container ultrapassou a capacidade')
 for i=0,c:getSize()-1 do local v=c:getItem(i)
  if v:isContainer() then local n,d=contar(v,depth+1);total=total+n;profundidade=math.max(profundidade,d)
  else assert(v.id==2160);total=total+1 end
 end
 return total,profundidade
end
local count,depth=contar(corpo,0)
assert(count==400,'nao houve oito rolagens completas: '..count)
assert(depth<=4,'bolsas ficaram profundas demais: '..depth)
local antes=corpo:getSize();assert(L.gerar(corpo,{id=2160,derrubar=false}));assert(corpo:getSize()==antes)
local reward=MonsterType.getBossReward({},1,true)
assert(#reward==8 and chamadas==8,'boss nao recebeu oito rolagens')
assert(#MonsterType.getBossReward({},1,false)==0,'restricao de boss ignorada')
local vazio=item(5995,2);local dest=L.destino(vazio);assert(dest);L.limpar(vazio);assert(vazio:getSize()==0,'bolsa vazia nao removida')
print('OK: 8 rolagens, 400 itens preservados em bolsas acessiveis e recompensa de boss')
