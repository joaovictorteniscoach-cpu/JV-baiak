-- Uma escolha por personagem, igual a quest original.
local premios={[34589]=2407,[34590]=2466,[34591]=7456,[34592]=8855}
function onUse(player,item)
    local id=premios[item.actionid]
    if not id then return false end
    if player:getStorageValue(88914) >= 0 then
        player:sendCancelMessage('Voce ja pegou seu premio.')
        return true
    end
    local premio=Game.createItem(id,1)
    if not premio then player:sendCancelMessage('Nao foi possivel criar o premio.'); return true end
    if player:addItemEx(premio,false) ~= RETURNVALUE_NOERROR then
        premio:remove()
        player:sendCancelMessage('Libere espaco e capacidade na mochila para receber o premio.')
        return true
    end
    player:setStorageValue(88914,1)
    player:getPosition():sendMagicEffect(30)
    player:sendTextMessage(MESSAGE_EVENT_ADVANCE,'Voce ganhou 1x '..ItemType(id):getName()..'.')
    return true
end
