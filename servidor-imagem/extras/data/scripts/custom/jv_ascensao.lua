-- Hunts novas com sprites 8.60. Areas isoladas: nunca editar o mapa existente.
JV_ASCENSAO = JV_ASCENSAO or {}
local H = JV_ASCENSAO
local P = dofile('data/lib/jv_progressao.lua')
local MSG = MESSAGE_STATUS_CONSOLE_BLUE
local AID_HUB, AID_VOLTA, AID_HUNT = 47800, 47820, 47801
H.areas, H.slots, H.monstros = H.areas or {}, H.slots or {}, H.monstros or {}
local function pos(t, dx, dy) return Position(t.x+(dx or 0), t.y+(dy or 0), t.z) end
local function chave(p) return p.x .. ':' .. p.y .. ':' .. p.z end
local function mensagem(p, s) p:sendTextMessage(MSG, '[Ascensao] ' .. s) end

function H.reforcar(item, tier)
    local fator = P.reforco[tier]
    if not fator then return false end
    local tipo = ItemType(item:getId())
    -- Valores absolutos a partir do item base, nunca multiplicar um reforco anterior.
    for _, campo in ipairs({{ITEM_ATTRIBUTE_ATTACK,'getAttack'}, {ITEM_ATTRIBUTE_DEFENSE,'getDefense'}, {ITEM_ATTRIBUTE_ARMOR,'getArmor'}}) do
        local base = tipo[campo[2]](tipo)
        if base > 0 then item:setAttribute(campo[1], math.ceil(base*fator)) end
    end
    if tipo:getWeaponType() == WEAPON_WAND or tipo:getWeaponType() == WEAPON_DISTANCE then
        item:setCustomAttribute('jvAscensaoPoder', fator)
    end
    item:setCustomAttribute('jvAscensaoTier', tier)
    item:setAttribute(ITEM_ATTRIBUTE_DESCRIPTION, 'Reforco de Ascensao ' .. tier .. ' (+' .. math.floor((fator-1)*100+0.5) .. '%).')
    return true
end

local function jogador(c)
    if not c then return nil end
    if c:isPlayer() then return c end
    local m = c:getMaster()
    return m and m:isPlayer() and m or nil
end

local morte = CreatureEvent('JVAscensaoMorte')
function morte.onDeath(creature, corpse, killer, mostDamageKiller)
    local hunt = H.monstros[creature:getName()]
    if not hunt or creature:getMaster() then return true end
    local player = jogador(mostDamageKiller) or jogador(killer)
    if not player then return true end
    local participantes = {player}
    local party = player:getParty()
    if party then
        participantes = party:getMembers()
        participantes[#participantes+1] = party:getLeader()
    end
    local vistos, onde = {}, creature:getPosition()
    for _, p in ipairs(participantes) do
        if p and not vistos[p:getGuid()] then
            vistos[p:getGuid()] = true
            local l = p:getPosition()
            if p:getHealth() > 0 and l.z == onde.z and math.max(math.abs(l.x-onde.x),math.abs(l.y-onde.y)) <= 20 then
                JV_EVOLUCAO.abate(p)
            end
        end
    end
    -- Uma rolagem por morte, sem RATE_LOOT nem boost de loot. Vai ao corpo para
    -- continuar respeitando propriedade, capacidade e exclusoes do autoloot.
    if corpse and math.random(1,1000000) <= math.floor(hunt.chance*1000000) then
        local item = corpse:addItem(P.itens[math.random(#P.itens)],1)
        if item then H.reforcar(item,hunt.tier) end
    end
    return true
end
morte:register()

local function portal(p, aid)
    local tile = Tile(p)
    if not tile or not tile:getGround() or tile:getItemById(1387) then return false end
    local t = Game.createItem(1387,1,p)
    if not t then return false end
    t:setActionId(aid)
    return true
end

function H.criarSala(sala, raio)
    -- Verificar a sala inteira antes de criar o primeiro tile: falha fechada em
    -- mapas customizados que ja usam estas coordenadas.
    for dx=-raio,raio do for dy=-raio,raio do
        if Tile(pos(sala,dx,dy)) then return false end
    end end
    for dx=-raio,raio do for dy=-raio,raio do
        local p=pos(sala,dx,dy)
        if not Game.createTile(p,true) or not Game.createItem(407,1,p) then return false end
        if math.abs(dx)==raio or math.abs(dy)==raio then
            if not Game.createItem(1050,1,p) then return false end
        end
    end end
    return true
end

function H.podeEntrar(player, indice)
    local h=P.hunts[indice]
    if not h or not H.areas[indice] then return false, 'Area indisponivel; avise a administracao.' end
    if player:isPzLocked() then return false, 'Espere acabar a batalha com jogadores.' end
    if player:getLevel()<h.level or JV_EVOLUCAO.nivel(player)<h.evo then
        return false, h.nome .. ': level ' .. h.level .. '+ e Evolucao ' .. h.evo .. '+.'
    end
    return true
end

function H.livre(player, centro, raio)
    for r=0,raio do for dx=-r,r do for dy=-r,r do
        if math.max(math.abs(dx),math.abs(dy))==r then
            local p=pos(centro,dx,dy); local t=Tile(p)
            if t and t:getGround() and not t:getItemById(1387) and not t:getTopCreature() and t:queryAdd(player)==RETURNVALUE_NOERROR then return p end
        end
    end end end
end

function H.entrar(player, indice)
    local ok, erro=H.podeEntrar(player,indice)
    if not ok then mensagem(player,erro); return false end
    local h=P.hunts[indice]
    local chegada=pos(h,-h.raio+3,0)
    local destino=H.livre(player,chegada,2)
    if not destino or destino.x==0 or not Tile(destino) then mensagem(player,'Entrada ocupada; tente novamente.'); return false end
    if not player:teleportTo(destino) then mensagem(player,'Nao foi possivel viajar.'); return false end
    destino:sendMagicEffect(CONST_ME_TELEPORT)
    mensagem(player,h.nome .. (h.dupla and ': recomendada para 2; solo na evolucao maxima.' or ': hunt solo.') .. ' Volte pelo portal azul na entrada.')
    return true
end

local passo=MoveEvent()
passo:type('stepin')
function passo.onStepIn(creature,item,position,fromPosition)
    local player=creature:getPlayer()
    if not player then return true end
    local aid=item:getActionId()
    if player:isPzLocked() then player:teleportTo(fromPosition,true); return true end
    if aid==AID_VOLTA then
        local town=player:getTown()
        if not town or not player:teleportTo(town:getTemplePosition()) then player:teleportTo(fromPosition,true) end
    elseif aid==AID_HUB then
        if not H.hub then player:teleportTo(fromPosition,true); return true end
        local livre=H.livre(player,pos(P.hub,0,3),2)
        if not livre or livre.x==0 or not player:teleportTo(livre) then player:teleportTo(fromPosition,true) end
    elseif not H.entrar(player,aid-AID_HUNT+1) then
        player:teleportTo(fromPosition,true)
    end
    return true
end
passo:aid(AID_HUB,AID_VOLTA,47801,47802,47803,47804,47805); passo:register()

local comando=TalkAction('!ascensao')
function comando.onSay(player,words,param)
    local i=tonumber(param)
    if i then
        -- O atalho nao e uma fuga gratuita da hunt: usar perto do templo ou no hub.
        local p=player:getPosition()
        local town=player:getTown(); local templo=town and town:getTemplePosition()
        local perto=templo and p.z==templo.z and math.max(math.abs(p.x-templo.x),math.abs(p.y-templo.y))<=12
        local noHub=p.z==P.hub.z and math.max(math.abs(p.x-P.hub.x),math.abs(p.y-P.hub.y))<8
        if perto or noHub then H.entrar(player,i) else mensagem(player,'Use o portal do templo ou volte ao templo para viajar.') end
    else
        local linhas={'Hunts de Ascensao (!ascensao numero, no templo):'}
        for n,h in ipairs(P.hunts) do
            linhas[#linhas+1]=n .. '. ' .. h.nome .. ' - lv ' .. h.level .. ', Evo ' .. h.evo .. (h.dupla and ' (dupla recomendada)' or '')
        end
        player:showTextDialog(1950,table.concat(linhas,'\n'),false)
    end
    return false
end
comando:separator(' '); comando:register()

function H.repor()
    local agora=os.time()
    for _,s in ipairs(H.slots) do
        local vivo=s.id and Monster(s.id)
        if not vivo then
            if s.id then s.id=nil; s.proximo=agora+s.hunt.respawn end
            if agora>=(s.proximo or 0) then
                local m=Game.createMonster(s.hunt.monstro,s.pos,false,false)
                if m then s.id=m:getId() end
                s.proximo=agora+5 -- tenta depois, nunca forca spawn sobre jogadores
            end
        end
    end
end

local inicio=GlobalEvent('JVAscensaoInicio')
inicio:type('startup')
function inicio.onStartup()
    H.areas,H.slots,H.monstros={},{},{}
    H.hub=H.criarSala(P.hub,8)
    for i,h in ipairs(P.hunts) do
        H.monstros[h.monstro]=h
        if H.hub and H.criarSala(h,h.raio) and portal(pos(h,-h.raio+2,0),AID_VOLTA) then
            H.areas[i]=true
            if not portal(pos(P.hub,-6+(i-1)*3,0),AID_HUNT+i-1) then H.areas[i]=nil end
            if H.areas[i] then
                for n=1,h.quantidade do
                    local dx=h.boss and 4 or 1+((n-1)%3)*3
                    local dy=h.boss and 0 or -6+math.floor((n-1)/3)*4
                    H.slots[#H.slots+1]={hunt=h,pos=pos(h,dx,dy)}
                end
            end
        end
        if not H.areas[i] then print('[Ascensao] Area indisponivel: ' .. h.nome) end
    end
    if H.hub then
        portal(pos(P.hub,0,6),AID_VOLTA)
        -- Entrada fisica perto do templo de Thunder City. Somente tile livre, sem
        -- item, casa ou criatura; nunca substituir um portal existente.
        local colocou=false
        for dy=-4,4 do for dx=-4,4 do
            if not colocou and math.max(math.abs(dx),math.abs(dy))>=3 then
                local p=Position(991+dx,1210+dy,7); local t=Tile(p)
                if t and t:getGround() and not t:hasFlag(TILESTATE_BLOCKSOLID) and not t:hasFlag(TILESTATE_BLOCKPATH) and not t:getHouse() and not t:getTopCreature() and #(t:getItems() or {})==0 then
                    colocou=portal(p,AID_HUB)
                    if colocou then H.entrada=p end
                end
            end
        end end
        if not colocou then print('[Ascensao] Sem tile livre para portal do templo; usar !ascensao no templo.') end
    end
    H.repor()
    return true
end
inicio:register()
local repor=GlobalEvent('JVAscensaoRespawn')
function repor.onThink() H.repor(); return true end
repor:interval(5000); repor:register()

local nomes=GlobalEvent('JVAscensaoNomes')
function nomes.onThink()
    local lista={}
    if H.entrada then lista[#lista+1]={p=H.entrada,n='Ascensao'} end
    if H.hub then
        for i,h in ipairs(P.hunts) do
            if H.areas[i] then lista[#lista+1]={p=pos(P.hub,-6+(i-1)*3,0),n=h.nome} end
        end
    end
    for _,v in ipairs(lista) do
        for _,p in ipairs(Game.getSpectators(v.p,false,true,7,7,7,7)) do p:say(v.n,TALKTYPE_MONSTER_SAY,false,p,v.p) end
    end
    return true
end
nomes:interval(3500); nomes:register()
