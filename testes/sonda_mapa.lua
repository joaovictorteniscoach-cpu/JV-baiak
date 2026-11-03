-- Somente o workflow de teste acrescenta esta sonda ao cliente.
-- As coordenadas vem dos retangulos usados pelo renderizador nativo.
connect(g_game, {onGameStart = function()
    scheduleEvent(function()
        local map = modules.game_interface.getMapPanel()
        local original = map.onMouseRelease
        map.onMouseRelease = function(self, point, button)
            local p = self:getPosition(point)
            if p then
                g_logger.info(string.format('JV_MAP_RELEASE point=%d,%d tile=%d,%d,%d button=%d', point.x, point.y, p.x, p.y, p.z, button))
            end
            return original(self, point, button)
        end
        g_keyboard.bindKeyDown('Ctrl+Shift+F7', function()
            local p = g_game.getLocalPlayer():getPosition()
            local size = rootWidget:getSize()
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local target = {x=p.x+dx,y=p.y+dy,z=p.z}
                    local r = map:getTileRect(target)
                    if r and r.width > 0 and r.height > 0 then
                        g_logger.info(string.format('JV_MAP_PROBE root=%d,%d rect=%d,%d,%d,%d tile=%d,%d,%d', size.width,size.height,r.x,r.y,r.width,r.height,target.x,target.y,target.z))
                    end
                end
            end
        end, rootWidget)
    end, 1000)
end})
