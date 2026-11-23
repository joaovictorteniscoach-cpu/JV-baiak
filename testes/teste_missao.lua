-- Exercita morte, limite diario, pagamento e virada do dia sem banco real.
MESSAGE_STATUS_CONSOLE_BLUE=1
local comandos={}
function TalkAction(nome)local t={separator=function()end,register=function(s)comandos[nome]=s end};return t end
local dia=20000;os.time=function()return dia*86400 end
local p={dados={},banco=0}
function p:getStorageValue(k)return self.dados[k] or -1 end
function p:setStorageValue(k,v)self.dados[k]=v end
function p:getBankBalance()return self.banco end
function p:setBankBalance(v)self.banco=v end
function p:sendTextMessage(_,m)self.msg=m end
dofile('servidor-imagem/extras/data/scripts/custom/jv_missoes.lua')
local falar=comandos['!missao'].onSay
for i=1,49 do JV_MISSOES.abate(p) end
falar(p,'!missao','resgatar');assert(p.banco==0,'premio antecipado')
for i=1,5 do JV_MISSOES.abate(p) end
assert(p.dados[79801]==50,'contagem acima da meta')
falar(p,'!missao','resgatar');assert(p.banco==50000,'premio incorreto')
falar(p,'!missao','resgatar');assert(p.banco==50000,'premio repetido')
dia=dia+1;falar(p,'!missao','resgatar');assert(p.banco==50000 and p.dados[79801]==0,'virada nao zerou')
print('OK: missao valida meta, pagamento unico, limite e virada UTC')
