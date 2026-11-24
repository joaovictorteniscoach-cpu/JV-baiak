-- As armas sao instancias proprias: a loja padrao so entregaria o item base.
local handler=NpcHandler:new(KeywordHandler:new())
NpcSystem.parseParameters(handler)
local C=dofile('data/lib/jv_arsenal.lua')
local escolha={}
function onCreatureAppear(cid) handler:onCreatureAppear(cid) end
function onCreatureDisappear(cid) escolha[cid]=nil;handler:onCreatureDisappear(cid) end
function onCreatureSay(cid,tipo,msg) handler:onCreatureSay(cid,tipo,msg) end
function onThink() handler:onThink() end
local function obter(chave)
 for _,f in ipairs(C.familias) do if f.chave==chave then return f end end
end
local function falar(cid,tipo,msg)
 if not handler:isFocused(cid) then return false end
 local player=Player(cid);if not player then return false end
 local texto=msg:lower():gsub('^%s+',''):gsub('%s+$','')
 local pedido=escolha[cid]
 if pedido and pedido.ate<os.time() then escolha[cid]=nil;pedido=nil end
 if texto=='loja' or texto=='trade' or texto=='armas' or texto=='familias' then
  escolha[cid]=nil
  handler:say('Escolha {espada}, {machado}, {martelo}, {arco}, {besta}, {cetro} ou {bastao}. Existem 4 patamares; o item exige level e evolucao para equipar.',cid)
 elseif obter(texto) then
  escolha[cid]={familia=texto,ate=os.time()+60}
  handler:say('Escolha {patamar 1}, {patamar 2}, {patamar 3} ou {patamar 4}. Precos: 500 mil, 2 milhoes, 8 milhoes e 30 milhoes de gold.',cid)
 elseif texto:match('^patamar%s+[1-4]$') and pedido then
  local n=tonumber(texto:match('%d'));local f=obter(pedido.familia)
  pedido.n=n;pedido.ate=os.time()+60
  handler:say(f.nomes[n]..' custa '..C.precosLoja[n]..' gold. Para equipar: level '..C.levels[n]..', Evolucao '..n..' e vocacao da arma. Confirmar? {sim} ou {nao}.',cid)
 elseif texto=='sim' and pedido and pedido.n then
  escolha[cid]=nil
  if not JV_ARSENAL or not JV_ARSENAL.comprar then handler:say("A loja esta indisponivel; tente mais tarde.",cid);return true end
  local ok,retorno=JV_ARSENAL.comprar(player,pedido.familia,pedido.n)
  handler:say(retorno..(ok and ' Escolha outras {armas} quando quiser.' or ''),cid)
 elseif texto=='nao' then escolha[cid]=nil;handler:say('Compra cancelada. Veja as {armas} quando quiser.',cid)
 else return false end
 return true
end
handler:setMessage(MESSAGE_GREET,'Ola |PLAYERNAME|! Vendo as novas armas de Ascensao. Diga {armas} para escolher; aceito gold da mochila e do banco.')
handler:setMessage(MESSAGE_FAREWELL,'Ate mais!')
handler:setMessage(MESSAGE_WALKAWAY,'Ate mais!')
handler:setCallback(CALLBACK_ONRELEASEFOCUS,function(cid) escolha[cid]=nil;return true end)
handler:setCallback(CALLBACK_MESSAGE_DEFAULT,falar)
handler:addModule(FocusModule:new())
