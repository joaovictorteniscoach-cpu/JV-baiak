-- Oito rolagens independentes do loot anterior; bolsas marcadas acomodam excedente.
JV_LOOT_MULTIPLO = JV_LOOT_MULTIPLO or {}
local L=JV_LOOT_MULTIPLO
L.rolagens=8
local MARCA='jvLootExcedente'
local DIRETORIO='jvLootDiretorio'

local function folha(c)
    return c:getCapacity()-c:getSize()>1
end
local function bolsa(c,diretorio)
    if c:getCapacity()-c:getSize()<1 then return nil end
    local b=c:addItem(1988,1,INDEX_WHEREEVER,FLAG_NOLIMIT)
    if b then
        b:setCustomAttribute(MARCA,1)
        if diretorio then b:setCustomAttribute(DIRETORIO,1) end
    end
    return b
end
local function diretorioDe(c)
    for i=0,c:getSize()-1 do
        local item=c:getItem(i)
        if item and item:isContainer() and item:getCustomAttribute(DIRETORIO)==1 then return item end
    end
    return bolsa(c,true)
end

function L.destino(corpo)
    if not corpo or not corpo:isContainer() then return nil end
    if folha(corpo) then return corpo end
    local dir=diretorioDe(corpo)
    for _=1,64 do
        if not dir then return nil end
        for i=0,dir:getSize()-1 do
            local item=dir:getItem(i)
            if item and item:isContainer() and item:getCustomAttribute(MARCA)==1
                and item:getCustomAttribute(DIRETORIO)~=1 and folha(item) then return item end
        end
        if dir:getCapacity()-dir:getSize()>1 then return bolsa(dir,false) end
        dir=diretorioDe(dir)
    end
end

function L.limpar(corpo)
    if not corpo or not corpo:isContainer() then return end
    for i=corpo:getSize()-1,0,-1 do
        local item=corpo:getItem(i)
        if item and item:isContainer() and item:getCustomAttribute(MARCA)==1 then
            L.limpar(item)
            if item:getSize()==0 then item:remove() end
        end
    end
end

function L.adicionar(corpo,id,quantidade)
    local destino=L.destino(corpo)
    return destino and destino:addItem(id,quantidade)
end

-- O container temporario usa a rotina original, preservando atributos, pilhas,
-- conteudos aninhados e a rolagem de chance/boost ja aplicados pelo servidor.
function L.gerar(corpo,bloco)
    local temporario=Game.createItem(1988,1)
    if not temporario then return false end
    for _=1,L.rolagens do
        local ok=temporario:createLootItem(bloco)
        while temporario:getSize()>0 do
            local item=temporario:getItem(0)
            local destino=L.destino(corpo)
            if not destino or not item:moveTo(destino,0) then
                -- Nunca descartar o conteudo se nao foi possivel transferi-lo.
                temporario:setCustomAttribute(MARCA,1)
                if temporario:moveTo(corpo,FLAG_NOLIMIT) then return false end
                print('[Loot 8x] Falha ao acomodar loot no corpo.')
                temporario:remove();return false
            end
        end
        if not ok then temporario:remove();L.limpar(corpo);return false end
    end
    temporario:remove()
    return true
end

-- Recompensas individuais de boss seguem as regras de contribuicao originais.
if MonsterType and MonsterType.getBossReward and not L.recompensaOriginal then
    L.recompensaOriginal=MonsterType.getBossReward
    function MonsterType.getBossReward(self,lootFactor,topScore)
        local resultado={}
        for _=1,L.rolagens do
            for _,item in ipairs(L.recompensaOriginal(self,lootFactor,topScore) or {}) do
                resultado[#resultado+1]=item
            end
        end
        return resultado
    end
end
