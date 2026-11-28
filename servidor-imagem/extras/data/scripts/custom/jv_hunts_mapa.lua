-- Hunts sobre regioes livres do mapa original; nao altera o arquivo OTBM.
local M={}
local PORTAL, SAIDA = 48260,48270
local hub=Position(30000,30000,7)
local hunts={
    {nome='Groove Perdido', centro=Position(456,984,7), entrada=Position(29994,30005,7), level=600,evo=2,tier=2,arsenalIndice=2,chance=0.008,respawn=45, quantidade=16, monstros={'Sentinela do Groove','Guardiao do Groove','Guardiao das Brasas','Cacador Abissal'}},
    {nome='Dominio da Fumaca', centro=Position(1400,1336,7), entrada=Position(30006,30005,7), level=1000,evo=4,tier=4,arsenalIndice=5,chance=0.03,respawn=60, quantidade=15, monstros={'Guardiao da Fumaca','Soberano da Fumaca','Arauto Celestial'}},
}
local function deslocar(p,x,y) return Position(p.x+x,p.y+y,p.z) end
local function valido(t)
    return t and t:getGround() and not t:getHouse() and not t:hasFlag(TILESTATE_PROTECTIONZONE)
        and not t:hasFlag(TILESTATE_BLOCKSOLID) and not t:hasFlag(TILESTATE_BLOCKPATH) and not t:getItemById(1387)
end
local function novoPortal(pos,aid)
    local t=Tile(pos)
    if not t or not t:getGround() or t:getItemById(1387) or t:getTopCreature() or #(t:getItems() or {})>0 then return nil end
    local item=Game.createItem(1387,1,pos)
    if item then item:setActionId(aid) end
    return item
end
local inicio=GlobalEvent('JVHuntsMapaInicio')
inicio:type('startup')
function inicio.onStartup()
    if not JV_ASCENSAO or not JV_ASCENSAO.hub then print('[Hunts mapa] Sala de hunts indisponivel.'); return true end
    for i,h in ipairs(hunts) do
        local seguro=true
        for _,nome in ipairs(h.monstros) do if not MonsterType(nome) then seguro=false end end
        for x=-7,7 do for y=-7,7 do if not valido(Tile(deslocar(h.centro,x,y))) then seguro=false end end end
        local saida=deslocar(h.centro,-7,0)
        local portalSaida=seguro and novoPortal(saida,SAIDA+i)
        local portalEntrada=portalSaida and novoPortal(h.entrada,PORTAL+i)
        if portalEntrada then
            M[i]=true
            for _,nome in ipairs(h.monstros) do JV_ASCENSAO.monstros[nome]=h end
            for n=1,h.quantidade do
                local col=(n-1)%4; local linha=math.floor((n-1)/4)
                JV_ASCENSAO.slots[#JV_ASCENSAO.slots+1]={hunt=h,nome=h.monstros[(n-1)%#h.monstros+1],pos=deslocar(h.centro,-4+col*3,-5+linha*4)}
            end
        else
            if portalSaida then portalSaida:remove() end
            print('[Hunts mapa] Area ocupada ou portal indisponivel: '..h.nome)
        end
    end
    return true
end
inicio:register()
local passo=MoveEvent(); passo:type('stepin')
function passo.onStepIn(creature,item,position,fromPosition)
    local p=creature:getPlayer();if not p then return true end
    local aid=item:getActionId();local i=aid>=SAIDA and aid-SAIDA or aid-PORTAL
    local h=hunts[i]
    if not h or not M[i] or p:isPzLocked() then p:teleportTo(fromPosition,true);return true end
    if aid<SAIDA and (p:getLevel()<h.level or JV_EVOLUCAO.nivel(p)<h.evo) then
        p:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,h.nome..': level '..h.level..' e Evolucao '..h.evo..' necessarios.')
        p:teleportTo(fromPosition,true);return true
    end
    local centro=aid>=SAIDA and deslocar(hub,0,3) or deslocar(h.centro,-5,0)
    local destino=JV_ASCENSAO.livre(p,centro,2)
    if not destino or not p:teleportTo(destino) then p:teleportTo(fromPosition,true);return true end
    destino:sendMagicEffect(CONST_ME_TELEPORT)
    return true
end
for i=1,#hunts do passo:aid(PORTAL+i);passo:aid(SAIDA+i) end
passo:register()
local nomes=GlobalEvent('JVHuntsMapaNomes')
function nomes.onThink()
    for i,h in ipairs(hunts) do if M[i] then
        for _,p in ipairs(Game.getSpectators(h.entrada,false,true,7,7,7,7)) do
            p:say(h.nome..' Lv '..h.level,TALKTYPE_MONSTER_SAY,false,p,h.entrada)
        end
    end end
    return true
end
nomes:interval(3500);nomes:register()
