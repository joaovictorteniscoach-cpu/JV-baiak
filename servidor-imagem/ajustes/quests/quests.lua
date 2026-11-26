-- Preserva os IDs, recompensas e storages originais de cada bau.
local quests = {
    [46571] = {id=2497, count=1, storage=91143},
    [46572] = {id=9693, count=1, storage=91146},
    [46573] = {id=9971, count=20, storage=91147},
}
function onUse(player, item)
    local q=quests[item.actionid]
    if not q then return false end
    if player:getStorageValue(q.storage) >= 0 then
        player:sendCancelMessage('Voce ja pegou esta recompensa.')
        return true
    end
    local premio=Game.createItem(q.id,q.count)
    if not premio then player:sendCancelMessage('Nao foi possivel criar a recompensa.'); return true end
    if player:addItemEx(premio,false) ~= RETURNVALUE_NOERROR then
        premio:remove()
        player:sendCancelMessage('Libere espaco e capacidade na mochila para receber a recompensa.')
        return true
    end
    player:setStorageValue(q.storage,1)
    player:sendTextMessage(MESSAGE_EVENT_ADVANCE,'Voce recebeu sua recompensa: '..ItemType(q.id):getName()..'.')
    return true
end
