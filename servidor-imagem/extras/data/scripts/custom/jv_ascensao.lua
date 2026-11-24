-- Hunts novas com sprites 8.60. Areas isoladas: nunca editar o mapa existente.
JV_ASCENSAO = JV_ASCENSAO or {}
local H = JV_ASCENSAO
local P = dofile('data/lib/jv_progressao.lua')
local MSG = MESSAGE_STATUS_CONSOLE_BLUE
local AID_HUB, AID_VOLTA, AID_HUNT, AID_ANDAR = 47800, 47820, 47801, 47830
local AID_BOSS = 47900
local bosses = {
    {nome="Orshabaal", modelo="Portal Orshabaal", x=36000},
    {nome="Ferumbras", modelo="Portal Ferumbras", x=36100},
    {nome="Morgaroth", modelo="Portal Morgaroth", x=36200},
    {nome="Ghazbaran", modelo="Portal Ghazbaran", x=36300},
}
local HUB_RAIO=17
local QUANTIDADE_ANDAR={6,8,10,12,14}
local placas={'Portal Infernal','Portal Abissal','Portal Ancestral','Portal Titas','Portal Soberano'}
H.areas, H.slots, H.monstros = H.areas or {}, H.slots or {}, H.monstros or {}
local function pos(t, dx, dy) return Position(t.x+(dx or 0), t.y+(dy or 0), t.z) end
local function posPortal(i) return pos(P.hub,-12+(i-1)*6,0) end
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
                if JV_MISSOES then JV_MISSOES.abate(p) end
                if JV_ARSENAL then JV_ARSENAL.creditar(p,hunt) end
            end
        end
    end
    -- Uma rolagem por morte, sem RATE_LOOT nem boost de loot. Vai ao corpo para
    -- continuar respeitando propriedade, capacidade e exclusoes do autoloot.
    if corpse and math.random(1,1000000) <= math.floor(hunt.chance*1000000) then
        local item = corpse:addItem(P.itens[math.random(#P.itens)],1)
        if item then H.reforcar(item,hunt.tier) end
    end
    if JV_ARSENAL then JV_ARSENAL.sortear(corpse,hunt,hunt.arsenalIndice,player) end
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

function H.salaLivre(sala, raio)
    -- Verificar a sala inteira antes de criar o primeiro tile: falha fechada em
    -- mapas customizados que ja usam estas coordenadas.
    for dx=-raio,raio do for dy=-raio,raio do
        if Tile(pos(sala,dx,dy)) then return false end
    end end
    return true
end

function H.criarSala(sala, raio)
    if not H.salaLivre(sala,raio) then return false end
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
    mensagem(player,h.nome .. ' - andar 1/5. Direita: proximo andar. Esquerda: voltar ao templo.')
    return true
end

local passo=MoveEvent()
passo:type('stepin')
function passo.onStepIn(creature,item,position,fromPosition)
    local player=creature:getPlayer()
    if not player then return true end
    local aid=item:getActionId()
    if player:isPzLocked() then
        mensagem(player,'Aguarde o fim do bloqueio de combate para usar o portal.')
        player:teleportTo(fromPosition,true); return true
    end
    if aid==AID_VOLTA then
        local town=player:getTown()
        if not town or not player:teleportTo(town:getTemplePosition()) then
            mensagem(player,'Nao foi possivel voltar ao templo. Tente novamente.')
            player:teleportTo(fromPosition,true)
        end
    elseif aid==AID_HUB then
        if not H.hub then mensagem(player,'Sala de Ascensao indisponivel.'); player:teleportTo(fromPosition,true); return true end
        local livre=H.livre(player,pos(P.hub,0,3),2)
        if not livre or livre.x==0 or not player:teleportTo(livre) then
            mensagem(player,'Entrada ocupada ou indisponivel; tente novamente.')
            player:teleportTo(fromPosition,true)
        end
    elseif aid>AID_BOSS and aid<=AID_BOSS+#bosses then
        local indice=aid-AID_BOSS
        local sala=H.salasBoss and H.salasBoss[indice]
        if not sala or player:getLevel()<300 then
            mensagem(player, sala and "Bosses: necessario level 300." or "Sala de boss indisponivel.")
            player:teleportTo(fromPosition,true); return true
        end
        local livre=H.livre(player,pos(sala,-7,0),2)
        if not livre or not player:teleportTo(livre) then
            mensagem(player,"Entrada ocupada; tente novamente."); player:teleportTo(fromPosition,true)
        else
            livre:sendMagicEffect(CONST_ME_TELEPORT)
            mensagem(player,bosses[indice].nome..": portal de retorno a esquerda.")
        end
    elseif aid==AID_ANDAR then
        local transicao=H.transicoes[chave(position)]
        local h=transicao and P.hunts[transicao.hunt]
        local sala=transicao and H.andares[transicao.hunt] and H.andares[transicao.hunt][transicao.andar]
        local ok,erro=transicao and H.podeEntrar(player,transicao.hunt)
        if not transicao or not h or not sala or not ok then
            mensagem(player,erro or 'Andar indisponivel; tente novamente.')
            player:teleportTo(fromPosition,true);return true
        end
        local x=transicao.lado=='direita' and h.raio-3 or -h.raio+3
        local livre=H.livre(player,pos(sala,x,0),2)
        if not livre or not player:teleportTo(livre) then
            mensagem(player,'Entrada ocupada; tente novamente.');player:teleportTo(fromPosition,true)
        else
            livre:sendMagicEffect(CONST_ME_TELEPORT)
            local orientacao=transicao.andar==5 and 'Esquerda: andar anterior. Portal acima da entrada: templo.'
                or 'Direita: proximo andar. Esquerda: andar anterior. Portal acima da entrada: templo.'
            mensagem(player,h.nome..' - andar '..transicao.andar..'/5. '..orientacao)
        end
    elseif not H.entrar(player,aid-AID_HUNT+1) then
        player:teleportTo(fromPosition,true)
    end
    return true
end
passo:aid(AID_HUB,AID_VOLTA,AID_ANDAR,47801,47802,47803,47804,47805,47901,47902,47903,47904); passo:register()

local comando=TalkAction('!ascensao')
function comando.onSay(player,words,param)
    local i=tonumber(param)
    if i then
        -- O atalho nao e uma fuga gratuita da hunt: usar perto do templo ou no hub.
        local p=player:getPosition()
        local town=player:getTown(); local templo=town and town:getTemplePosition()
        local perto=templo and p.z==templo.z and math.max(math.abs(p.x-templo.x),math.abs(p.y-templo.y))<=12
        local noHub=p.z==P.hub.z and math.max(math.abs(p.x-P.hub.x),math.abs(p.y-P.hub.y))<HUB_RAIO
        if perto or noHub then H.entrar(player,i) else mensagem(player,'Use o portal do templo ou volte ao templo para viajar.') end
    else
        local linhas={'HUNTS NOVAS: procure o portal azul HUNTS NOVAS junto ao templo.',
            'Cada hunt tem cinco andares; a dificuldade aumenta ao avancar.',
            'Direita: proximo andar. Esquerda: andar anterior; no primeiro, volta ao templo.',
            'A partir do segundo andar, o portal acima da entrada tambem volta ao templo.',
            'Armas raras podem cair no corpo. Use !arsenal para ver a garantia e os requisitos.',
            'Primeira hunt: level 300 e Evolucao I. !ascensao numero funciona no templo ou sala.'}
        if H.entrada then linhas[#linhas+1]='Portal no templo: x '..H.entrada.x..', y '..H.entrada.y..', andar '..H.entrada.z..'.' end
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
                local m=Game.createMonster(s.nome or s.hunt.monstro,s.pos,false,false)
                if m then
                    s.id=m:getId();s.aviso=nil
                elseif not s.aviso or agora-s.aviso>=60 then
                    print('[Ascensao] Falha ao criar '..(s.nome or s.hunt.monstro)..' em '..chave(s.pos)..'; nova tentativa em 5s.')
                    s.aviso=agora
                end
                s.proximo=agora+5 -- tenta depois, nunca forca spawn sobre jogadores
            end
        end
    end
end

-- A busca usa somente pisos existentes e livres, incluindo a saida da PZ;
-- nao considera outro portal como passagem para uma sala diferente.
local function alcancaveis(centro, raio)
    local lista={centro};local vistos={[chave(centro)]=true};local i=1
    while i<=#lista do
        local atual=lista[i];i=i+1
        for dx=-1,1 do for dy=-1,1 do if dx~=0 or dy~=0 then
            local p=Position(atual.x+dx,atual.y+dy,centro.z);local k=chave(p)
            if not vistos[k] and math.max(math.abs(p.x-centro.x),math.abs(p.y-centro.y))<=raio then
                vistos[k]=true
                local t=Tile(p)
                if t and t:getGround() and not t:getHouse() and not t:hasFlag(TILESTATE_BLOCKSOLID)
                    and not t:hasFlag(TILESTATE_BLOCKPATH) and not t:getItemById(1387) then
                    lista[#lista+1]=p
                end
            end
        end end end
    end
    local acessiveis={}
    for _,p in ipairs(lista)do acessiveis[chave(p)]=true end
    return acessiveis
end

-- Reforcos apenas em entradas de hunt identificadas no mapa original. Nao
-- alteramos OTBM/spawn.xml e conferimos o destino, PZ, casas e bloqueios.
function H.reforcarEntradas()
    H.entradasAtivas=H.entradasAtivas or {}
    local reservados={}
    for _,e in ipairs(P.entradasReforcadas or {}) do
        local o,d=e.origem,e.destino
        local entrada=o[1]..':'..o[2]..':'..o[3]
        local portalTile=Tile(Position(o[1],o[2],o[3]))
        local item=portalTile and portalTile:getItemById(1387)
        local destino=item and item:getDestination()
        if H.entradasAtivas[entrada] then
            -- Ja criada nesta inicializacao: nao duplicar slots.
        elseif destino and destino.x==d[1] and destino.y==d[2] and destino.z==d[3] then
            local feitos=0
            local acessiveis=alcancaveis(destino,7)
            for raio=3,7 do for dx=-raio,raio do for dy=-raio,raio do
                if feitos<2 and math.max(math.abs(dx),math.abs(dy))==raio then
                    local p=Position(d[1]+dx,d[2]+dy,d[3]);local t=Tile(p);local k=chave(p)
                    if t and acessiveis[k] and t:getGround() and not reservados[k] and not t:getHouse()
                        and not t:hasFlag(TILESTATE_PROTECTIONZONE) and not t:hasFlag(TILESTATE_BLOCKSOLID)
                        and not t:hasFlag(TILESTATE_BLOCKPATH) and not t:getItemById(1387) then
                        reservados[k]=true;feitos=feitos+1
                        H.slots[#H.slots+1]={hunt={monstro=e.monstro,respawn=60},pos=p}
                    end
                end
            end end end
            if feitos>0 then H.entradasAtivas[entrada]=true end
            if feitos<2 then print('[Ascensao] Entrada '..chave(destino)..': apenas '..feitos..' posicoes seguras para reforco.') end
        else
            print('[Ascensao] Entrada antiga alterada ou indisponivel: '..o[1]..':'..o[2]..':'..o[3]..'; sem reforco.')
        end
    end
end

local inicio=GlobalEvent('JVAscensaoInicio')
inicio:type('startup')
function inicio.onStartup()
    H.areas,H.slots,H.monstros,H.andares,H.transicoes={},{},{},{},{}
    H.entradasAtivas={}
    H.hub=H.criarSala(P.hub,HUB_RAIO)
    for i,h in ipairs(P.hunts) do
        h.arsenalIndice=i
        H.andares[i]={}
        local livres=H.hub
        for andar=1,5 do
            -- Espaco entre andares evita que o teto de um obscureca o outro.
            local sala={x=h.x+(andar-1)*1000,y=h.y,z=h.z+andar-1}
            H.andares[i][andar]=sala
            if not H.salaLivre(sala,h.raio) then livres=false end
        end
        if livres then
            local criadas=true
            for andar=1,5 do if not H.criarSala(H.andares[i][andar],h.raio) then criadas=false;break end end
            if criadas and portal(posPortal(i),AID_HUNT+i-1) then
                H.areas[i]=true
                local primeiroSlot=#H.slots
                local portaisOk=true
                local modelo=pos(P.hub,-12+(i-1)*6,-2)
                if not Game.createNpc(placas[i],modelo,false,false) then
                    print('[Ascensao] Nao foi possivel criar identificacao: '..placas[i])
                end
                for andar=1,5 do
                    local sala=H.andares[i][andar]
                    local esquerda=pos(sala,-h.raio+2,0)
                    if andar==1 then portaisOk=portal(esquerda,AID_VOLTA) and portaisOk
                    else
                        portaisOk=portal(esquerda,AID_ANDAR) and portaisOk
                        H.transicoes[chave(esquerda)]={hunt=i,andar=andar-1,lado='direita'}
                        portaisOk=portal(pos(sala,-h.raio+2,-3),AID_VOLTA) and portaisOk
                    end
                    if andar<5 then
                        local direita=pos(sala,h.raio-2,0);portaisOk=portal(direita,AID_ANDAR) and portaisOk
                        H.transicoes[chave(direita)]={hunt=i,andar=andar+1,lado='esquerda'}
                    end
                    local nivel={}
                    for chave,valor in pairs(h) do nivel[chave]=valor end
                    nivel.andar=andar
                    nivel.garantiaIndice=(h.boss and andar<5) and 6 or i
                    nivel.chance=h.chance*(0.6+0.1*(andar-1))
                    if h.boss and andar<5 then
                        nivel.tier=3;nivel.boss=false;nivel.respawn=50;nivel.chance=0.012*(0.6+0.1*(andar-1));nivel.arsenalIndice=4
                    end
                    local nomes={h.monstro,h.variante,h.convidado}
                    for _,nome in ipairs(nomes) do
                        local variante=andar==5 and nome or nome..' A'..andar
                        H.monstros[variante]=nivel
                    end
                    local quantidade=(h.boss and andar==5) and 1 or QUANTIDADE_ANDAR[andar]
                    for n=1,quantidade do
                        local col=(n-1)%5;local linha=math.floor((n-1)/5)
                        local dx=(h.boss and andar==5) and (-h.raio+8) or (-h.raio+7+col*4)
                        local dy=(h.boss and andar==5) and 0 or (-8+linha*3)
                        local nome=(h.convidado and n%3==1) and h.convidado or ((h.variante and n%3==0) and h.variante or h.monstro)
                        if andar<5 then nome=nome..' A'..andar end
                        H.slots[#H.slots+1]={hunt=nivel,nome=nome,andar=andar,pos=pos(sala,dx,dy)}
                    end
                end
                if not portaisOk then
                    H.areas[i]=nil
                    for n=#H.slots,primeiroSlot+1,-1 do H.slots[n]=nil end
                    local t=Tile(posPortal(i));local entrada=t and t:getItemById(1387)
                    if entrada then entrada:remove() end
                    print('[Ascensao] Portais incompletos; hunt desativada: '..h.nome)
                end
            end
        end
        if not H.areas[i] then print('[Ascensao] Area indisponivel: ' .. h.nome) end
    end
    if H.hub then
        H.salasBoss={}
        for i,b in ipairs(bosses) do
            local sala={x=b.x,y=30000,z=7}
            local entrada=pos(P.hub,-9+(i-1)*6,10)
            if MonsterType(b.nome) and H.criarSala(sala,10) and portal(pos(sala,-8,0),AID_VOLTA)
                and portal(entrada,AID_BOSS+i) then
                H.salasBoss[i]=sala
                H.slots[#H.slots+1]={hunt={monstro=b.nome,respawn=300},pos=pos(sala,0,0)}
                if not Game.createNpc(b.modelo,pos(entrada,0,-2),false,false) then
                    print('[Bosses] Nao foi possivel criar a identificacao de '..b.nome)
                end
            else
                print('[Bosses] Sala indisponivel: '..b.nome)
            end
        end
        -- No mapa original, Bosses foi ligado por engano a sala da Capita Cristina.
        -- So corrigimos esse destino conhecido ou o portal originalmente vazio.
        local antigo=Tile(Position(478,1379,6))
        local tp=antigo and antigo:getItemById(1387)
        local destino=tp and tp:getDestination()
        if tp and tp:getActionId()==0 and (not destino or (destino.x==0 and destino.y==0)
            or (destino.x==583 and destino.y==1242 and destino.z==7)) then
            tp:setDestination(pos(P.hub,0,3))
            print('[Bosses] Portal antigo ligado ao salao de bosses e hunts.')
        end
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
    H.reforcarEntradas()
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
    if H.entrada then
        lista[#lista+1]={p=H.entrada,n='HUNTS NOVAS'}
        H.entrada:sendMagicEffect(CONST_ME_MAGIC_BLUE)
    end
    if H.hub then
        for i,h in ipairs(P.hunts) do
            if H.areas[i] then lista[#lista+1]={p=posPortal(i),n='Lv '..h.level..' Evo '..h.evo} end
        end
        for i,b in ipairs(bosses) do
            if H.salasBoss and H.salasBoss[i] then lista[#lista+1]={p=pos(P.hub,-9+(i-1)*6,10),n='Boss '..b.nome} end
        end
    end
    for _,v in ipairs(lista) do
        for _,p in ipairs(Game.getSpectators(v.p,false,true,7,7,7,7)) do p:say(v.n,TALKTYPE_MONSTER_SAY,false,p,v.p) end
    end
    return true
end
nomes:interval(3500); nomes:register()
