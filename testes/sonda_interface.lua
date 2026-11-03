-- Somente teste: nao incluir no cliente de producao.
local function rect(w)
    if not w then return '0,0,0,0' end
    local r=w:getRect();return string.format('%d,%d,%d,%d',r.x,r.y,r.width,r.height)
end
local state={message='Configuracao de teste local',goldBank=false,items={
    {id=2148,name='gold coin',collect=true},{id=2152,name='platinum coin',collect=true},{id=2160,name='crystal coin',collect=false}}}
local function instalarTransporte()
if JVAutoloot then
    JVAutoloot.transporte=function(action,ref)
        scheduleEvent(function()
            for _,item in ipairs(state.items) do if tostring(item.id)==tostring(ref) then item.collect=action=='take' end end
            JVAutoloot.receber(state)
        end,80)
    end
end
end
connect(g_game,{onGameStart=instalarTransporte})
instalarTransporte()
g_keyboard.bindKeyDown('Ctrl+Shift+F1',function()
    if not JVToque or not JVToque.pronto then return end
    local size=rootWidget:getSize()
    for id,w in pairs(JVToque.janelas) do
        g_logger.info(string.format('JV_WINDOW id=%s visible=%d root=%d,%d rect=%s close=%s min=%s',id,w:isVisible() and 1 or 0,size.width,size.height,rect(w),rect(w:getChildById('jvFechar')),rect(w:getChildById('jvMinimizar'))))
    end
    local menu=rootWidget:recursiveGetChildById('jvLootChoice2148PopupMenu')
    if menu then for _,child in ipairs(menu:getChildren()) do
        if child:getText()=='Ignorar' then g_logger.info('JV_LOOT_IGNORE_RECT '..rect(child)) end
    end end
    if JVAutoloot and JVAutoloot.window then
        g_logger.info('JV_LOOT_STATUS '..JVAutoloot.status:getText())
        for _,item in ipairs(JVAutoloot.estado and JVAutoloot.estado.items or {}) do
            g_logger.info(string.format('JV_LOOT_ITEM id=%d collect=%d rect=%s',item.id,item.collect and 1 or 0,rect(rootWidget:recursiveGetChildById('jvLootChoice'..item.id))))
        end
    end
end,rootWidget)
