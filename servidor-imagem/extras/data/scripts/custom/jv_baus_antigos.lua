-- Os nove baus da sala antiga tinham UID, mas nao tinham script nem premio no mapa.
-- Estas recompensas sao novas: nao representam premios recuperados da quest original.
local premios={
    [5058]={x=1145,y=186,z=7,id=2494,storage=82901},
    [5059]={x=1147,y=186,z=7,id=2472,storage=82902},
    [5060]={x=1149,y=186,z=7,id=2522,storage=82903},
    [9978]={x=1152,y=188,z=7,id=2400,storage=82904},
    [5957]={x=1154,y=188,z=7,id=8925,storage=82905},
    [5956]={x=1156,y=188,z=7,id=2421,storage=82906},
    [5955]={x=1160,y=188,z=7,id=8854,storage=82907},
    [5954]={x=1165,y=188,z=7,id=8922,storage=82908},
    [5953]={x=1167,y=188,z=7,id=2183,storage=82909},
}
-- Bau com action ID sem registro na cabana em ruinas: premio novo e unico.
local cabana={x=1101,y=1375,z=7,id=2160,count=5,storage=82910}
local function entregar(player,q,pos)
    -- Nao associar um UID reutilizado em um mapa personalizado a esta recompensa.
    if not q or not pos or pos.x~=q.x or pos.y~=q.y or pos.z~=q.z then return false end
    if player:getStorageValue(q.storage)>=0 then
        player:sendCancelMessage('Voce ja recebeu a recompensa deste bau.')
        return true
    end
    local premio=Game.createItem(q.id,q.count or 1)
    if not premio then player:sendCancelMessage('Nao foi possivel criar a recompensa.'); return true end
    if player:addItemEx(premio,false)~=RETURNVALUE_NOERROR then
        premio:remove()
        player:sendCancelMessage('Libere espaco e capacidade na mochila para receber a recompensa.')
        return true
    end
    player:setStorageValue(q.storage,1)
    player:sendTextMessage(MESSAGE_EVENT_ADVANCE,'Voce encontrou '..(q.count or 1)..'x '..ItemType(q.id):getName()..'.')
    return true
end
local antigos=Action()
function antigos.onUse(player,item,fromPosition)
    return entregar(player,premios[item:getUniqueId()],fromPosition)
end
antigos:uid(5058,5059,5060,9978,5957,5956,5955,5954,5953)
antigos:register()
local abrigo=Action()
function abrigo.onUse(player,item,fromPosition)
    return entregar(player,cabana,fromPosition)
end
abrigo:aid(13100)
abrigo:register()
