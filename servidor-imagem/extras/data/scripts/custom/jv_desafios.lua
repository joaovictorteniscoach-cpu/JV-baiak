-- Tres missoes de abate individuais; os premios sao entregues uma unica vez.
JV_DESAFIOS = JV_DESAFIOS or {}
local D=JV_DESAFIOS
local MSG=MESSAGE_STATUS_CONSOLE_BLUE
D.quests={
 {nome='Prova das Brasas',hunt='Groove Perdido',monstro='Guardiao das Brasas',meta=20,level=600,evo=2,progresso=84010,resgatado=84110,
  armadura={id=2494,nome='Armadura das Brasas',valor=26},escudo={id=2520,nome='Escudo das Brasas',valor=48}},
 {nome='Cacada Abissal',hunt='Groove Perdido',monstro='Cacador Abissal',meta=25,level=600,evo=2,progresso=84011,resgatado=84111,
  armadura={id=2466,nome='Armadura Abissal',valor=32},escudo={id=2514,nome='Escudo Abissal',valor=56}},
 {nome='Julgamento Celestial',hunt='Dominio da Fumaca',monstro='Arauto Celestial',meta=30,level=1000,evo=4,progresso=84012,resgatado=84112,
  armadura={id=2472,nome='Armadura Celestial',valor=40},escudo={id=2522,nome='Escudo Celestial',valor=65}},
}
local function avisar(p,m) p:sendTextMessage(MSG,'[Desafios] '..m) end
function D.abate(p,nome)
 for i,q in ipairs(D.quests) do
  if q.monstro==nome and p:getLevel()>=q.level and JV_EVOLUCAO.nivel(p)>=q.evo then
   local antes=math.max(0,p:getStorageValue(q.progresso))
   if antes<q.meta then
    p:setStorageValue(q.progresso,antes+1)
    if antes+1==q.meta then avisar(p,q.nome..' concluida! Use !desafios resgatar, '..i..'.') end
   end
  end
 end
end
local function criar(container,definicao,campo)
 local item=container:addItem(definicao.id,1)
 if not item then return nil end
 item:setAttribute(ITEM_ATTRIBUTE_NAME,definicao.nome)
 item:setAttribute(campo,definicao.valor)
 item:setAttribute(ITEM_ATTRIBUTE_DESCRIPTION,'Recompensa de desafio. '..(campo==ITEM_ATTRIBUTE_ARMOR and 'Armadura ' or 'Defesa ')..definicao.valor..'.')
 item:setCustomAttribute('jvLootRaro',1)
 item:setCustomAttribute('jvAscensaoTier',4)
 return item
end
function D.resgatar(p,indice)
 local q=D.quests[indice]
 if not q then avisar(p,'Use !desafios resgatar, 1, 2 ou 3.');return false end
 if p:getStorageValue(q.resgatado)==1 then avisar(p,'Voce ja recebeu este conjunto.');return false end
 if p:getLevel()<q.level or JV_EVOLUCAO.nivel(p)<q.evo or math.max(0,p:getStorageValue(q.progresso))<q.meta then
  avisar(p,'Complete '..q.nome..' e alcance level '..q.level..' e Evolucao '..q.evo..'.');return false
 end
 -- Prepara o conjunto inteiro em bolsa virtual; nunca marca a quest se falhar.
 local bolsa=Game.createItem(1988,1)
 if not bolsa then avisar(p,'Nao foi possivel preparar a recompensa.');return false end
 if not criar(bolsa,q.armadura,ITEM_ATTRIBUTE_ARMOR) or not criar(bolsa,q.escudo,ITEM_ATTRIBUTE_DEFENSE) then
  bolsa:remove();avisar(p,'Nao foi possivel preparar o conjunto.');return false
 end
 if p:addItemEx(bolsa,false)~=RETURNVALUE_NOERROR then
  bolsa:remove();avisar(p,'Libere espaco e capacidade para receber o conjunto.');return false
 end
 p:setStorageValue(q.resgatado,1)
 avisar(p,'Conjunto de '..q.nome..' entregue na mochila.')
 return true
end
local comando=TalkAction('!desafios')
function comando.onSay(p,words,param)
 local texto=(param or ''):lower()
 local indice=texto:match('^%s*resgatar%s*,%s*(%d+)%s*$')
 if indice then D.resgatar(p,tonumber(indice));return false end
 local linhas={'DESAFIOS DE ASCENSAO','Derrote os monstros indicados e resgate o conjunto no bau do salao de hunts ou pelo comando.'}
 for i,q in ipairs(D.quests) do
  local atual=math.min(q.meta,math.max(0,p:getStorageValue(q.progresso)))
  linhas[#linhas+1]=string.format('%d. %s (%s): %s %d/%d. Lv %d, Evo %d. Premio: %s e %s. %s',i,q.nome,q.hunt,q.monstro,atual,q.meta,q.level,q.evo,q.armadura.nome,q.escudo.nome,p:getStorageValue(q.resgatado)==1 and 'Ja resgatado.' or ('Use !desafios resgatar, '..i..'.'))
 end
 p:showTextDialog(1950,table.concat(linhas,'\n'),false)
 return false
end
comando:separator(' ');comando:register()

-- Baus fixos no salao das hunts (item imovel 5675); comando segue disponivel.
local HUB=dofile('data/lib/jv_progressao.lua').hub
local AID=48300
local function localBau(i) return Position(HUB.x+(i-2)*6,HUB.y+14,HUB.z) end
local acao=Action()
function acao.onUse(p,item,fromPosition)
 local i=item:getActionId()-AID
 if i<1 or i>#D.quests then return false end
 local pos=localBau(i)
 if not fromPosition or fromPosition.x~=pos.x or fromPosition.y~=pos.y or fromPosition.z~=pos.z then return false end
 D.resgatar(p,i)
 return true
end
acao:aid(48301,48302,48303);acao:register()
local inicio=GlobalEvent('JVDesafiosBaus')
inicio:type('startup')
function inicio.onStartup()
 if not JV_ASCENSAO or not JV_ASCENSAO.hub then return true end
 for i=1,#D.quests do
  local pos=localBau(i);local tile=Tile(pos)
  if tile and tile:getGround() and not tile:getTopCreature() and #(tile:getItems() or {})==0 then
   local bau=Game.createItem(5675,1,pos)
   if bau then bau:setActionId(AID+i) else print('[Desafios] Falha ao criar bau '..i..'.') end
  else print('[Desafios] Local ocupado para bau '..i..'; comando !desafios continua disponivel.') end
 end
 return true
end
inicio:register()
local rotulos=GlobalEvent('JVDesafiosNomes')
function rotulos.onThink()
 if not JV_ASCENSAO or not JV_ASCENSAO.hub then return true end
 for i,q in ipairs(D.quests) do
  local pos=localBau(i);local tile=Tile(pos);local bau=tile and tile:getItemById(5675)
  if bau and bau:getActionId()==AID+i then
   for _,player in ipairs(Game.getSpectators(pos,false,true,7,7,7,7)) do
    player:say(q.nome,TALKTYPE_MONSTER_SAY,false,player,pos)
   end
  end
 end
 return true
end
rotulos:interval(5000);rotulos:register()
