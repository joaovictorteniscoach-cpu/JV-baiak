-- Configuracao do autoloot existente. Nao cria loot nem altera taxas/cadaveres.
JVAutolootUI = {}
local A=JVAutolootUI
local PRESETS={2148,2152,2160}
local COINS={[2148]=true,[2152]=true,[2160]=true}
local function quote(s)
    return '"'..tostring(s):gsub('[%z\1-\31\\"]',function(c)
        if c=='\\' then return '\\\\' end
        if c=='"' then return '\\"' end
        return string.format('\\u%04x',c:byte())
    end)..'"'
end
local function slots(player)
    local selected,free,count={},nil,0
    for i=AUTOLOOT_STORAGE_START,AUTOLOOT_STORAGE_END do
        local id=player:getStorageValue(i)
        if id>0 then selected[id]=true;count=count+1 elseif not free then free=i end
    end
    return selected,free,count
end
function A.responder(player,message,found)
    local selected=slots(player);local ids={};for id in pairs(selected) do ids[id]=true end
    for _,id in ipairs(PRESETS) do ids[id]=true end
    if found then ids[found]=true end
    local ordered={};for id in pairs(ids) do ordered[#ordered+1]=id end;table.sort(ordered)
    local rows={}
    local bank=player:getStorageValue(AUTOLOOT_STORAGE_GOLD)==1
    for _,id in ipairs(ordered) do
        local item=ItemType(id)
        if item and item:getId()>0 then
            rows[#rows+1]='{"id":'..id..',"name":'..quote(item:getName())..',"collect":'..tostring(selected[id]==true or (bank and COINS[id]==true))..'}'
        end
    end
    local json='{"message":'..quote(message or '')..',"goldBank":'..tostring(player:getStorageValue(AUTOLOOT_STORAGE_GOLD)==1)..',"items":['..table.concat(rows,',')..']}'
    player:sendExtendedOpcode(204,json)
end
function A.configurar(player,param)
    if not AUTOLOOT_STORAGE_START or not AUTOLOOT_STORAGE_END then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,'Autoloot indisponivel neste servidor.');return false
    end
    if type(param)~='string' or #param>100 then A.responder(player,'Pedido invalido.');return false end
    local action,ref=param:match('^(%S+)%s*(.-)%s*$')
    if action=='list' then A.responder(player);return false end
    if action=='goldoff' then player:setStorageValue(AUTOLOOT_STORAGE_GOLD,-1);A.responder(player,'Deposito automatico de moedas desligado.');return false end
    if action~='find' and action~='take' and action~='ignore' then A.responder(player,'Acao invalida.');return false end
    if not ref or ref=='' then A.responder(player,'Digite o nome ou ID do item.');return false end
    local numeric=tonumber(ref)
    if numeric and (numeric%1~=0 or numeric<1 or numeric>65535) then A.responder(player,'Item nao encontrado.');return false end
    local item=ItemType(numeric or ref)
    if not item or item:getId()==0 then A.responder(player,'Item nao encontrado.');return false end
    local id=item:getId();local selected,free,count=slots(player)
    if action=='find' then A.responder(player,'',id);return false end
    if action=='take' then
        if selected[id] then A.responder(player,'O item ja sera recolhido.',id);return false end
        if not free or count>=(AUTO_LOOT_MAX_ITEMS or AUTOLOOT_STORAGE_END-AUTOLOOT_STORAGE_START+1) then
            A.responder(player,'Lista cheia. Ignore um item antes de adicionar outro.',id);return false
        end
        player:setStorageValue(free,id)
        A.responder(player,'Item marcado para recolher.',id)
    else
        for i=AUTOLOOT_STORAGE_START,AUTOLOOT_STORAGE_END do
            if player:getStorageValue(i)==id then player:setStorageValue(i,0) end
        end
        -- Ignorar moeda prevalece sobre o modo antigo que deposita todas no banco.
        if COINS[id] then player:setStorageValue(AUTOLOOT_STORAGE_GOLD,-1) end
        A.responder(player,'Item sera ignorado e ficara no corpo.',id)
    end
    return false
end
local talk=TalkAction('!jvloot')
function talk.onSay(player,words,param) return A.configurar(player,param) end
talk:separator(' ');talk:register()
