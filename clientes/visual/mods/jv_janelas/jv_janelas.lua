-- JV Baiak: JANELAS SEMPRE DENTRO DA TELA (celular; navegador e app Android)
-- Janelas grandes (loja do NPC, roupas, mochila solta, opcoes...) podiam passar da
-- tela e esconder a barra de cima (de arrastar) e o botao de fechar. A cada meio
-- segundo, toda janela solta volta para dentro da tela e, se for mais alta que a
-- tela, fica do tamanho da tela (a barra e o X sempre aparecem; listas rolam dentro).
-- Mesmo arquivo em web/ e em clientes/visual/mods/jv_janelas/ (o teste confere).
JVJanelas = JVJanelas or {}
local J = JVJanelas
local MARGEM = 4

local function celular()
    if g_platform and g_platform.isMobile then return g_platform.isMobile() end
    if g_app and g_app.isMobile then return g_app.isMobile() end
    return false
end

local function conter(janela, L, A)
    local ok, r = pcall(function() return janela:getRect() end)
    if not ok or not r then return end
    local w, h = r.width, r.height
    if h > A - 2 * MARGEM then
        h = A - 2 * MARGEM
        pcall(function() janela:setHeight(h) end)
    end
    if w > L - 2 * MARGEM then
        w = L - 2 * MARGEM
        pcall(function() janela:setWidth(w) end)
    end
    local x = math.max(MARGEM, math.min(r.x, L - w - MARGEM))
    local y = math.max(MARGEM, math.min(r.y, A - h - MARGEM))
    if x ~= r.x or y ~= r.y then
        pcall(function() janela:setPosition({x = x, y = y}) end)
    end
end

local function ciclo()
    local raiz = rootWidget
    if not raiz then return end
    local L, A = raiz:getWidth(), raiz:getHeight()
    for _, filho in ipairs(raiz:getChildren()) do
        local ok, solta = pcall(function()
            return filho:isVisible() and filho:getClassName() == 'UIWindow' and filho:isDraggable()
        end)
        if ok and solta then conter(filho, L, A) end
    end
end

function J.iniciar()
    if J.evento or not celular() then return end
    J.evento = cycleEvent(ciclo, 500)
end

function J.parar()
    if J.evento then removeEvent(J.evento) end
    J.evento = nil
end
