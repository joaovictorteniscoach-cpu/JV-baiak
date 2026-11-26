RETURNVALUE_NOERROR=0
MESSAGE_EVENT_ADVANCE=1
local dados={}
Game={createItem=function(id,count)
    if dados.criacaoFalhou then return nil end
    local item={id=id,count=count}
    function item:remove() dados.removido=true end
    dados.item=item
    return item
end}
ItemType=function(id) return {getName=function() return 'item '..id end} end
local player={}
function player:getStorageValue(k) return dados.storage[k] or -1 end
function player:setStorageValue(k,v) dados.storage[k]=v end
function player:addItemEx(item,drop) assert(drop==false); return dados.semEspaco and 1 or 0 end
function player:sendCancelMessage(t) dados.msg=t end
function player:sendTextMessage(_,t) dados.msg=t end
function player:getPosition() return {sendMagicEffect=function() end} end
local tests={
 {'quests.lua',46571,2497,1,91143}, {'quests.lua',46572,9693,1,91146},
 {'quests.lua',46573,9971,20,91147}, {'medusaAnihiPremio.lua',34589,2407,1,88914},
 {'medusaAnihiPremio.lua',34590,2466,1,88914}, {'medusaAnihiPremio.lua',34591,7456,1,88914},
 {'medusaAnihiPremio.lua',34592,8855,1,88914},
}
for _,t in ipairs(tests) do
 dofile('servidor-imagem/ajustes/quests/'..t[1])
 dados={storage={},semEspaco=true};assert(onUse(player,{actionid=t[2]}));assert(dados.storage[t[5]]==nil and dados.removido)
 dados={storage={}};assert(onUse(player,{actionid=t[2]}));assert(dados.storage[t[5]]==1 and dados.item.id==t[3] and dados.item.count==t[4])
 dados.item=nil;assert(onUse(player,{actionid=t[2]}));assert(not dados.item)
 dados={storage={},criacaoFalhou=true};assert(onUse(player,{actionid=t[2]}));assert(dados.storage[t[5]]==nil)
end
print('OK: recompensas originais, mochila cheia, falha de criacao e retirada unica')
