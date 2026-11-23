-- Catalogo e conquista de armas. Sem sprites novos, venda em dinheiro ou janela nova.
JV_ARSENAL = JV_ARSENAL or {}
local A=JV_ARSENAL
local C=dofile('data/lib/jv_arsenal.lua')
local MSG=MESSAGE_STATUS_CONSOLE_BLUE
local function avisar(p,t) p:sendTextMessage(MSG,'[Arsenal] '..t) end
local function familia(chave)
    for _,f in ipairs(C.familias)do if f.chave==chave then return f end end
end
function A.identificar(item)
    local id=item and item:getCustomAttribute('jvarmaid')
    if type(id)~='string' then return nil end
    local chave,n=id:match('^(%a+):([1-4])$')
    local f=familia(chave);n=tonumber(n)
    if f and f.item==item:getId() then return f,n end
end
function A.podeUsar(player,item)
    if not item or not item:getCustomAttribute('jvarmaid') then return true end
    local f,n=A.identificar(item)
    if not f then return false end
    return player:getVocation():getClientId()==f.classe and player:getLevel()>=C.levels[n]
        and player:getStorageValue(C.evoStorage)>=n
end
function A.equipamentoValido(player)
    for _,s in ipairs({CONST_SLOT_LEFT,CONST_SLOT_RIGHT})do
        if not A.podeUsar(player,player:getSlotItem(s)) then return false end
    end
    return true
end
function A.bonus(player,item,origin)
    local f,n=A.identificar(item)
    if not f or not A.podeUsar(player,item) then return nil end
    if f.classe==2 and (origin==ORIGIN_RANGED or origin==ORIGIN_SPELL) then return C.distancia[n] end
    if f.magico and origin==ORIGIN_SPELL then return C.magia[n] end
    -- Melee ja usa o ataque real; wand/rod usa a faixa real no motor.
    return 1
end
local function detalhes(f,n)
    local s
    if f.magico then
        s=math.floor(f.ataque[n]*7/10)..'-'..f.ataque[n]..' de dano base; magias PvE +'..math.floor((C.magia[n]-1)*100+0.5)..'%'
    elseif f.classe==2 then
        s='Atk '..f.ataque[n]..' (soma a municao); dano PvE +'..math.floor((C.distancia[n]-1)*100+0.5)..'%'
    else s='Atk '..f.ataque[n]..' / Def '..f.defesa[n] end
    return s..'. Lv '..C.levels[n]..', Evolucao '..n..'.'
end
function A.criar(chave,n,container)
    local f=familia(chave)
    if not f or type(n)~='number' or n~=math.floor(n) or n<1 or n>4 then return nil end
    local item
    if container then item=container:addItem(f.item,1) else item=Game.createItem(f.item,1) end
    if not item then return nil end
    item:setAttribute(ITEM_ATTRIBUTE_NAME,f.nomes[n])
    item:setAttribute(ITEM_ATTRIBUTE_ARTICLE,f.artigo)
    item:setAttribute(ITEM_ATTRIBUTE_ATTACK,f.ataque[n])
    if f.defesa then item:setAttribute(ITEM_ATTRIBUTE_DEFENSE,f.defesa[n]) end
    item:setAttribute(ITEM_ATTRIBUTE_DESCRIPTION,detalhes(f,n)..' Origem: '..C.origem[n]..'. Colecao de Ascensao.')
    item:setCustomAttribute('jvarmaid',f.chave..':'..n)
    item:setCustomAttribute('jvarmaclasse',f.classe)
    item:setCustomAttribute('jvarmalevel',C.levels[n])
    item:setCustomAttribute('jvarmaevolucao',n)
    item:setCustomAttribute('jvarmaevostorage',C.evoStorage)
    item:setCustomAttribute('jvascensaotier',n) -- autoloot raro e protecao do !venderloot
    return item
end
function A.sortear(corpse,hunt,indice)
    local chance=C.chances[indice]
    if not corpse or not chance then return nil end
    if math.random(1,1000000)>math.floor(chance*1000000) then return nil end
    local f=C.familias[math.random(#C.familias)]
    return A.criar(f.chave,hunt.tier,corpse)
end
function A.creditar(player,hunt)
    if player:getLevel()<hunt.level or player:getStorageValue(C.evoStorage)<hunt.evo then return end
    local key=C.fragmentosStorage+hunt.tier-1
    local antes=math.max(0,player:getStorageValue(key))
    player:setStorageValue(key,math.min(2147483647,antes+1))
    if antes+1==C.custos[hunt.tier] then
        avisar(player,'Voce ja pode escolher uma arma do patamar '..hunt.tier..'. Veja !arsenal.')
    end
end
function A.resgatar(player,chave,n)
    local f=familia(chave)
    if not f or type(n)~='number' or n~=math.floor(n) or n<1 or n>4 then avisar(player,'Use !arsenal resgatar, familia, patamar (1 a 4).');return false end
    if player:getVocation():getClientId()~=f.classe then avisar(player,'Esta familia pertence a outra classe.');return false end
    if player:getLevel()<C.levels[n] or player:getStorageValue(C.evoStorage)<n then
        avisar(player,'Requer level '..C.levels[n]..' e Evolucao '..n..'.');return false
    end
    local key=C.fragmentosStorage+n-1
    local saldo=math.max(0,player:getStorageValue(key));local custo=C.custos[n]
    if saldo<custo then avisar(player,'Fragmentos '..n..': '..saldo..'/'..custo..'. Conquiste nas hunts desse patamar.');return false end
    local mochila=player:getSlotItem(CONST_SLOT_BACKPACK)
    if not mochila or not mochila:isContainer() then avisar(player,'Equipe uma mochila com espaco.');return false end
    local item=A.criar(chave,n)
    if not item then avisar(player,'Nao foi possivel criar o item; seus fragmentos foram mantidos.');return false end
    if mochila:addItemEx(item)~=RETURNVALUE_NOERROR then
        item:remove();avisar(player,'Sem espaco ou capacidade; seus fragmentos foram mantidos.');return false
    end
    player:setStorageValue(key,saldo-custo)
    avisar(player,'Conquistou '..f.nomes[n]..'! '..detalhes(f,n))
    return true
end
function A.catalogo(player)
    local classe=player:getVocation():getClientId()
    local linhas={'ARSENAL DE ASCENSAO - sua proxima conquista','Drops nao sao multiplicados pelo loot 100x.','Fragmentos sao individuais e ficam salvos no personagem.'}
    for n=1,4 do
        local saldo=math.max(0,player:getStorageValue(C.fragmentosStorage+n-1))
        linhas[#linhas+1]='\nPATAMAR '..n..' - '..C.origem[n]..'\nFragmentos: '..saldo..'/'..C.custos[n]
        for _,f in ipairs(C.familias)do if f.classe==classe then
            linhas[#linhas+1]=f.nomes[n]..' - '..detalhes(f,n)..'\nEscolher: !arsenal resgatar, '..f.chave..', '..n
        end end
    end
    linhas[#linhas+1]='\nUm fragmento por abate qualificado nas hunts do patamar; IV apenas no Soberano. Dupla proxima recebe para ambos. Fragmentos nao ocupam a mochila. Armas podem ser negociadas; os requisitos continuam valendo.'
    player:showTextDialog(1950,table.concat(linhas,'\n'),false)
end
local comando=TalkAction('!arsenal')
function comando.onSay(player,words,param)
    local texto=(param or ''):lower():gsub('^%s+',''):gsub('%s+$','')
    if texto=='' or texto=='lista' then A.catalogo(player);return false end
    local chave,n=texto:match('^resgatar%s*,%s*(%a+)%s*,%s*(%d+)$')
    if chave then A.resgatar(player,chave,tonumber(n)) else avisar(player,'Use !arsenal ou !arsenal resgatar, familia, patamar.') end
    return false
end
comando:separator(' ');comando:register()
