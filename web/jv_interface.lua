-- JV Baiak: opcao 2. Os widgets originais flutuam sobre o mapa.
if not g_platform.isMobile() then return end
JVToque = {janelas = {}, pronto = false}
local J = JVToque
local function root() return modules.game_interface.getRootPanel() end
local function orientacao() return root():getWidth() < root():getHeight() and 'retrato' or 'paisagem' end
local function settingsKey() return (g_game.getCharacterName() or '') .. ':' .. orientacao() end
local function button(parent, id, text, x, y, width, fn)
    local b = g_ui.createWidget('Button', parent)
    b:setId(id); b:setText(text); b:setSize({width=width or 48,height=30})
    b:addAnchor(AnchorLeft,'parent',AnchorLeft); b:addAnchor(AnchorTop,'parent',AnchorTop)
    b:setMarginLeft(x); b:setMarginTop(y); b.onClick=fn
    return b
end
function J.salvar(win)
    if not g_game.isOnline() or win:isDestroyed() then return end
    local all = g_settings.getNode('JVJanelasFlutuantes') or {}
    local key = settingsKey(); all[key] = all[key] or {}
    local p=win:getPosition(); all[key][win:getId()]={x=p.x,y=p.y}
    g_settings.setNode('JVJanelasFlutuantes',all)
end
local function defaultPosition(win)
    local w,h=root():getWidth(),root():getHeight()
    local id=win:getId(); local x,y=8,32
    if id=='jvEquipamento' then x,y=w-win:getWidth()-6,32
    elseif id=='jvMinimapa' then x,y=6,32
    elseif id=='jvChat' then x,y=math.max(6,(w-win:getWidth())/2),h-win:getHeight()-46
    elseif id:match('^container') then
        x,y=6,h-win:getHeight()-46
    else x,y=(w-win:getWidth())/2,(h-win:getHeight())/2 end
    return {x=math.max(0,x),y=math.max(0,y)}
end
function J.posicionar(win)
    if not win or win:isDestroyed() then return end
    local all=g_settings.getNode('JVJanelasFlutuantes') or {}
    local p=all[settingsKey()] and all[settingsKey()][win:getId()] or defaultPosition(win)
    if type(p.x)~='number' or type(p.y)~='number' then p=defaultPosition(win) end
    win:setPosition(p); win:bindRectToParent()
end
local function fit(win)
    win:setWidth(math.min(win.jvLargura or win:getWidth(),root():getWidth()))
    win:setHeight(math.min(win.jvMinimizado and 32 or (win.jvAltura or win:getHeight()),root():getHeight()-2))
    win:bindRectToParent()
end
function J.criarJanela(id, title, width, height)
    local win=g_ui.createWidget('UIWindow',root())
    win:setId(id);win.jvLargura=width;win.jvAltura=height; win:setSize({width=width,height=height}); win:setDraggable(true)
    win:setImageSource('/images/ui/background_dark'); win:setImageRepeated(true)
    local titleLabel=g_ui.createWidget('Label',win)
    titleLabel:setText(title); titleLabel:setHeight(30); titleLabel:setWidth(width-70)
    titleLabel:addAnchor(AnchorLeft,'parent',AnchorLeft);titleLabel:addAnchor(AnchorTop,'parent',AnchorTop)
    titleLabel:setMarginLeft(6);titleLabel:setPhantom(true)
    local body=g_ui.createWidget('UIWidget',win);body:setId('jvConteudo')
    body:addAnchor(AnchorLeft,'parent',AnchorLeft);body:addAnchor(AnchorRight,'parent',AnchorRight)
    body:addAnchor(AnchorTop,'parent',AnchorTop);body:addAnchor(AnchorBottom,'parent',AnchorBottom)
    body:setMarginTop(32)
    local close=button(win,'jvFechar','X',width-32,0,32,function() win:hide() end)
    local minimize=button(win,'jvMinimizar','-',width-65,0,32,function()
        if win.jvMinimizado then
            body:show();win:setHeight(win.jvAltura);win.jvMinimizado=false
        else win.jvAltura=win:getHeight();body:hide();win:setHeight(32);win.jvMinimizado=true end
        win:bindRectToParent()
    end)
    close:breakAnchors();close:addAnchor(AnchorRight,'parent',AnchorRight);close:addAnchor(AnchorTop,'parent',AnchorTop)
    minimize:breakAnchors();minimize:addAnchor(AnchorRight,'jvFechar',AnchorLeft);minimize:addAnchor(AnchorTop,'parent',AnchorTop)
    win.onDragEnter=function(self,p)
        if p.y-self:getY()>32 then return false end
        return UIWindow.onDragEnter(self,p)
    end
    win.onDragLeave=function(self) J.salvar(self) end
    win.onEscape=function() win:hide() end
    J.posicionar(win);fit(win);J.janelas[id]=win
    return win,body
end
local function wrap(panel,id,title,width,height)
    local win,body=J.criarJanela(id,title,width,height+32)
    panel:setParent(body);panel:breakAnchors()
    panel:addAnchor(AnchorLeft,'parent',AnchorLeft);panel:addAnchor(AnchorTop,'parent',AnchorTop)
    panel:addAnchor(AnchorRight,'parent',AnchorRight);panel:addAnchor(AnchorBottom,'parent',AnchorBottom)
    panel:setDraggable(false);panel:show()
    return win
end
function J.alternar(id)
    if not g_game.isOnline() or not J.pronto then return end
    local win=J.janelas[id]
    if not win then return end
    if win:isVisible() then win:hide() else win:show();win:raise();win:bindRectToParent();if id=='jvChat' and modules.game_console then modules.game_console.getConsole():focus() end end
end
function J.bolsas()
    if not g_game.isOnline() or not J.pronto then return end
    local any=false
    for _,container in pairs(g_game.getContainers()) do
        if container.window then container.window:show();container.window:raise();any=true end
    end
    if not any then
        local bag=g_game.getLocalPlayer():getInventoryItem(InventorySlotBack)
        if bag then g_game.open(bag) end
    end
end
function J.container(container)
    if not J.pronto or not container or not container.window then return end
    local win=container.window
    if not win.jvFlutuante then
        win.jvFlutuante=true;win:setParent(root(),true);win:breakAnchors();win:setDraggable(true)
        win.minimizedHeight=32
        local bar=win:getChildById('miniwindowTopBar');if bar then bar:setHeight(28) end
        for _,id in ipairs({'closeButton','minimizeButton','upButton'}) do
            local b=win:getChildById(id);if b then b:setSize({width=26,height=26});b:setImageSize({width=24,height=24}) end
        end
        local leave=win.onDragLeave
        win.onDragLeave=function(self,drop,p)
            if leave then leave(self,drop,p) end
            J.salvar(self)
        end
        win:setWidth(192);win:setHeight(math.min(140,root():getHeight()-46));J.posicionar(win)
    end
    win:show();win:bindRectToParent()
end
function J.atualizarBarras()
    if not J.vida or not g_game.isOnline() then return end
    local player=g_game.getLocalPlayer()
    local hp,maxhp=player:getHealth(),player:getMaxHealth()
    local mp,maxmp=player:getMana(),player:getMaxMana()
    J.vida:setPercent(maxhp>0 and hp/maxhp*100 or 0)
    J.vida:setText(hp..'/'..maxhp)
    J.mana:setPercent(maxmp>0 and mp/maxmp*100 or 0)
    J.mana:setText(mp..'/'..maxmp)
end
local function criarBarras()
    local holder=g_ui.createWidget('UIWidget',root())
    holder:setId('jvVidaMana');holder:setSize({width=100,height=28});holder:setPhantom(true)
    holder:addAnchor(AnchorHorizontalCenter,'parent',AnchorHorizontalCenter);holder:addAnchor(AnchorTop,'parent',AnchorTop);holder:setMarginTop(3)
    for i,color in ipairs({'#2aab28','#246ac6'}) do
        local bar=g_ui.createWidget('LifeProgressBar',holder)
        bar:addAnchor(AnchorLeft,'parent',AnchorLeft);bar:addAnchor(AnchorRight,'parent',AnchorRight)
        bar:addAnchor(AnchorTop,'parent',AnchorTop);bar:setMarginTop((i-1)*14);bar:setHeight(12)
        bar:setBackgroundColor(color);bar:setPhantom(true)
        if i==1 then J.vida=bar else J.mana=bar end
    end
    J.hud=holder;J.atualizarBarras()
end
connect(LocalPlayer,{onHealthChange=J.atualizarBarras,onManaChange=J.atualizarBarras})
local function preparar()
    if not g_game.isOnline() or J.pronto then return end
    local main=modules.game_interface.getMainRightPanel()
    local inventory=main:getChildById('maininventorypanel')
    local minimap=main:getChildById('mainmappanel')
    if not inventory or not minimap then return end
    J.pronto=true
    criarBarras()
    if not inventory:isOn() then modules.game_inventory.changeInventorySize() end
    wrap(inventory,'jvEquipamento','Equipamento',176,162)
    local mini=wrap(minimap,'jvMinimapa','Minimapa',176,116);mini:hide()
    local chat=wrap(modules.game_interface.getBottomPanel(),'jvChat','Chat',280,65)
    chat:getChildById('jvMinimizar').onClick()
    J.posicionar(chat)
    local combat,body=J.criarJanela('jvCombate','Combate',180,172)
    local inv=modules.game_inventory
    local actions={{'Ataque',function() inv.selectCombat('attack') end},
        {'Equilibrio',function() inv.selectCombat('balanced') end},
        {'Defesa',function() inv.selectCombat('defense') end},
        {'Parado',function() inv.selectPosture('stand') end},
        {'Seguir',function() inv.selectPosture('follow') end},
        {'Parar',function() g_game.cancelAttack();g_game.cancelFollow() end}}
    for i,a in ipairs(actions) do button(body,'jvCombate'..i,a[1],4+((i-1)%2)*86,4+math.floor((i-1)/2)*40,82,a[2]) end
    combat:hide()
    for _,p in ipairs({main,modules.game_interface.getRightPanel()}) do p:setWidth(0);p:hide() end
    local shortcuts=modules.game_shortcuts.getPanel()
    shortcuts:breakAnchors();shortcuts:addAnchor(AnchorRight,'parent',AnchorRight);shortcuts:addAnchor(AnchorBottom,'parent',AnchorBottom)
    for _,container in pairs(g_game.getContainers()) do J.container(container) end
    J.bolsas()
    modules.game_interface.updateStretchShrink()
    g_logger.info('JV_FLOATING_READY')
end
-- As teclas nao disputam atalhos normais: sao enviadas pelos botoes HTML.
local function bind(key,fn) g_keyboard.bindKeyDown('Ctrl+Shift+'..key,fn,rootWidget) end
bind('F8',function() J.alternar('jvEquipamento') end)
bind('F9',function() J.alternar('jvMinimapa') end)
bind('F11',function() J.alternar('jvCombate') end)
bind('F5',function() J.alternar('jvChat') end)
bind('F4',J.bolsas)
bind('F10',function() if g_game.isOnline() then modules.client_options.toggle() end end)
bind('F2',function() if g_game.isOnline() then modules.game_hotkeys.toggle() end end)
bind('F12',function() for _,win in pairs(J.janelas) do win:hide() end end)
connect(Container,{onOpen=function(container) addEvent(function() J.container(container) end) end})
local lastOrientation
connect(rootWidget,{onGeometryChange=function()
    if not J.pronto then return end
    scheduleEvent(function()
        if not J.pronto then return end
        local changed=lastOrientation~=orientacao();lastOrientation=orientacao()
        for _,win in pairs(J.janelas) do
            fit(win)
            if changed then J.posicionar(win) else win:bindRectToParent() end
        end
        for _,c in pairs(g_game.getContainers()) do
            if c.window then if changed then J.posicionar(c.window) else c.window:bindRectToParent() end end
        end
    end,100)
end})
connect(g_game,{onGameStart=function() scheduleEvent(preparar,300) end,
    onGameEnd=function()
        J.pronto=false
        if J.hud then J.hud:hide() end
        -- Os paineis originais sobrevivem ao logout; as janelas nao sao destruidas.
        for _,win in pairs(J.janelas) do win:hide() end
        g_logger.info('JV_WEB_GAME_END')
    end})
-- Reutiliza as mesmas janelas ao reconectar, sem destacar os widgets duas vezes.
local firstPrepare=preparar
preparar=function()
    if next(J.janelas) then
        if not g_game.isOnline() then return end
        J.pronto=true
        if J.hud then J.hud:show();J.atualizarBarras() end
        J.janelas.jvEquipamento:show();J.janelas.jvChat:show()
        for _,win in pairs(J.janelas) do J.posicionar(win) end
        J.bolsas();modules.game_interface.updateStretchShrink();g_logger.info('JV_FLOATING_READY')
    else firstPrepare() end
end
