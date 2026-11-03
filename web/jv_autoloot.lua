-- Janela nativa: estado confirmado pelo servidor, separado por personagem.
if not g_platform.isMobile() then return end
JVAutoloot = {estado=nil,pendente=false,confirmado=false}
local A=JVAutoloot
local function label(parent,text)
    local w=g_ui.createWidget('Label',parent);w:setText(text);return w
end
local function unlock()
    A.pendente=false
    if A.timer then removeEvent(A.timer);A.timer=nil end
end
function A.enviar(action,ref)
    if not g_game.isOnline() or A.pendente then return false end
    if not A.confirmado and not A.transporte then
        A.status:setText('Ative o script de autoloot no servidor e entre novamente.');return false
    end
    ref=ref and tostring(ref):match('^%s*(.-)%s*$') or ''
    if (action=='find' or action=='take' or action=='ignore') and (ref=='' or #ref>70) then
        A.status:setText('Digite o nome ou ID do item.');return false
    end
    A.pendente=true;A.status:setText('Consultando servidor...')
    A.timer=scheduleEvent(function()
        A.timer=nil;A.pendente=false
        A.status:setText('Servidor sem resposta. Instale o suporte de autoloot v7.')
        if A.estado then A.renderizar(A.estado,true) end
    end,4000)
    if A.transporte then A.transporte(action,ref)
    else g_game.talk('!jvloot '..action..(ref~='' and ' '..ref or '')) end
    return true
end
function A.renderizar(data,keepStatus)
    A.lista:destroyChildren()
    for i,item in ipairs(data.items) do
        local row=g_ui.createWidget('UIWidget',A.lista)
        row:setHeight(34);row:addAnchor(AnchorLeft,'parent',AnchorLeft);row:addAnchor(AnchorRight,'parent',AnchorRight)
        row:addAnchor(AnchorTop,'parent',AnchorTop);row:setMarginTop((i-1)*34)
        local name=label(row,item.name)
        name:addAnchor(AnchorLeft,'parent',AnchorLeft);name:addAnchor(AnchorTop,'parent',AnchorTop)
        name:addAnchor(AnchorRight,'parent',AnchorRight);name:setMarginRight(110);name:setHeight(32)
        local choice=g_ui.createWidget('ComboBox',row);choice:setId('jvLootChoice'..item.id);choice:setWidth(104);choice:setHeight(30)
        choice:addAnchor(AnchorRight,'parent',AnchorRight);choice:addAnchor(AnchorTop,'parent',AnchorTop)
        choice:addOption('Recolher','take');choice:addOption('Ignorar','ignore')
        choice:setCurrentOption(item.collect and 'Recolher' or 'Ignorar')
        choice.onOptionChange=function(_,_,action)
            if A.restaurando then return end
            if A.pendente then
                A.restaurando=true;choice:setCurrentOption(item.collect and 'Recolher' or 'Ignorar');A.restaurando=false;return
            end
            if (action=='take')~=item.collect then A.enviar(action,item.id) end
        end
    end
    if not keepStatus then A.status:setText(data.message~='' and data.message or 'Somente itens marcados como Recolher entram no autoloot.') end
    A.gold:setVisible(data.goldBank==true)
end
function A.receber(data)
    if type(data)~='table' or type(data.items)~='table' or #data.items>512 then return false end
    local seen={}
    for _,item in ipairs(data.items) do
        if type(item)~='table' or type(item.id)~='number' or item.id<1 or item.id%1~=0 or seen[item.id] or
            type(item.name)~='string' or #item.name>150 or type(item.collect)~='boolean' then return false end
        seen[item.id]=true
    end
    if type(data.message or '')~='string' or (data.goldBank~=nil and type(data.goldBank)~='boolean') then return false end
    data.message=data.message or ''
    unlock();A.confirmado=true;A.estado=data
    if A.window then A.renderizar(data) end
    return true
end
function A.abrir()
    if not g_game.isOnline() or not JVToque.pronto then return end
    if not A.window then
        local root=modules.game_interface.getRootPanel()
        local win,body=JVToque.criarJanela('jvAutoloot','Autoloot',math.min(340,root:getWidth()),math.min(290,root:getHeight()))
        A.window=win
        local search=g_ui.createWidget('TextEdit',body);A.search=search
        search:addAnchor(AnchorLeft,'parent',AnchorLeft);search:addAnchor(AnchorTop,'parent',AnchorTop)
        search:addAnchor(AnchorRight,'parent',AnchorRight);search:setMarginRight(82);search:setHeight(32)
        local find=g_ui.createWidget('Button',body);find:setText('Buscar');find:setSize({width=78,height=32})
        find:addAnchor(AnchorRight,'parent',AnchorRight);find:addAnchor(AnchorTop,'parent',AnchorTop)
        find.onClick=function() A.enviar('find',search:getText()) end
        A.status=label(body,'Busque um item pelo nome ou ID.');A.status:setTextWrap(true)
        A.status:addAnchor(AnchorLeft,'parent',AnchorLeft);A.status:addAnchor(AnchorRight,'parent',AnchorRight)
        A.status:addAnchor(AnchorBottom,'parent',AnchorBottom);A.status:setHeight(36)
        A.gold=g_ui.createWidget('Button',body);A.gold:setText('Desligar deposito de moedas no banco')
        A.gold:addAnchor(AnchorLeft,'parent',AnchorLeft);A.gold:addAnchor(AnchorRight,'parent',AnchorRight)
        A.gold:addAnchor(AnchorBottom,'parent',AnchorBottom);A.gold:setMarginBottom(38);A.gold:setHeight(28)
        A.gold.onClick=function() A.enviar('goldoff') end;A.gold:hide()
        local scrollbar=g_ui.createWidget('VerticalScrollBar',body)
        scrollbar:addAnchor(AnchorRight,'parent',AnchorRight);scrollbar:addAnchor(AnchorTop,'parent',AnchorTop)
        scrollbar:addAnchor(AnchorBottom,'parent',AnchorBottom);scrollbar:setMarginTop(36);scrollbar:setMarginBottom(68)
        A.lista=g_ui.createWidget('ScrollablePanel',body)
        A.lista:addAnchor(AnchorLeft,'parent',AnchorLeft);A.lista:addAnchor(AnchorRight,'parent',AnchorRight)
        A.lista:addAnchor(AnchorTop,'parent',AnchorTop);A.lista:addAnchor(AnchorBottom,'parent',AnchorBottom)
        A.lista:setMarginTop(36);A.lista:setMarginRight(14);A.lista:setMarginBottom(68)
        A.lista:setVerticalScrollBar(scrollbar)
    elseif A.window:isVisible() then A.window:hide();return end
    A.window:show();A.window:raise();A.window:bindRectToParent()
    A.enviar('list')
end
ProtocolGame.registerExtendedOpcode(204,function(_,_,buffer)
    local ok,data=pcall(json.decode,buffer)
    if ok then A.receber(data) end
end)
g_keyboard.bindKeyDown('Ctrl+Shift+F3',A.abrir,rootWidget)
connect(g_game,{onGameEnd=function()
    unlock();A.confirmado=false;A.estado=nil
    if A.window then A.window:hide();A.lista:destroyChildren();A.status:setText('') end
end})
