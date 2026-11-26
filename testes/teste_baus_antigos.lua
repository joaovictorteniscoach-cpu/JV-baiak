RETURNVALUE_NOERROR,MESSAGE_EVENT_ADVANCE=0,1
local acoes={}
function Action()
 local a={ids={},aids={}}
 function a:uid(...) self.ids={...} end
 function a:aid(...) self.aids={...} end
 function a:register() acoes[#acoes+1]=self end
 return a
end
local estado={}
Game={createItem=function(id,count)
 if estado.semCriar then return nil end
 local i={id=id,count=count,remove=function() estado.removido=true end};estado.item=i;return i
end}
function ItemType(id)return{getName=function()return tostring(id)end}end
local p={}
function p:getStorageValue(k)return estado.storages[k] or -1 end
function p:setStorageValue(k,v)estado.storages[k]=v end
function p:addItemEx(item,drop)assert(drop==false);return estado.cheio and 1 or 0 end
function p:sendCancelMessage(m)estado.msg=m end
function p:sendTextMessage(_,m)estado.msg=m end
dofile('servidor-imagem/extras/data/scripts/custom/jv_baus_antigos.lua')
local dados={
 {5058,1145,186,7,2494,82901},{5059,1147,186,7,2472,82902},{5060,1149,186,7,2522,82903},
 {9978,1152,188,7,2400,82904},{5957,1154,188,7,8925,82905},{5956,1156,188,7,2421,82906},
 {5955,1160,188,7,8854,82907},{5954,1165,188,7,8922,82908},{5953,1167,188,7,2183,82909},
}
assert(#acoes==2 and #acoes[1].ids==9 and acoes[2].aids[1]==13100)
for _,t in ipairs(dados) do
 local item={getUniqueId=function()return t[1]end};local pos={x=t[2],y=t[3],z=t[4]}
 estado={storages={},cheio=true};assert(acoes[1].onUse(p,item,pos));assert(estado.removido and not estado.storages[t[6]])
 estado={storages={}};assert(acoes[1].onUse(p,item,{x=0,y=0,z=0})==false and not estado.item)
 assert(acoes[1].onUse(p,item,pos));assert(estado.item.id==t[5] and estado.storages[t[6]]==1)
 estado.item=nil;assert(acoes[1].onUse(p,item,pos) and not estado.item)
end
estado={storages={}};assert(acoes[2].onUse(p,{}, {x=1101,y=1375,z=7}));assert(estado.item.id==2160 and estado.item.count==5 and estado.storages[82910]==1)
print('OK: nove baus antigos, cabana, retirada unica, mochila cheia e coordenadas')
