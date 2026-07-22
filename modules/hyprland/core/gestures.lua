-- ==============================================================================
-- CORE: ADVANCED GESTURES (Hyprland 0.55+ Lua Engine)
-- ==============================================================================

-- 1. CAMBIO DE WORKSPACE (Clásico)
-- Deslizar 3 dedos horizontalmente para cambiar de escritorio
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- 2. ZOOM EN VIVO ESTILO MAC (Pellizco)
-- Pellizcar con 2 dedos hacia afuera/adentro para hacer zoom fluido donde esté el mouse
hl.gesture({ fingers = 2, direction = "pinch", action = "cursorZoom", zoom_level = 1, mode = "live" })

-- 3. CERRAR VENTANA RÁPIDO
-- Deslizar 3 dedos hacia abajo cierra la ventana activa inmediatamente
hl.gesture({ fingers = 3, direction = "down", action = "close" })

-- 4. MODO PANTALLA COMPLETA
-- Deslizar 3 dedos hacia arriba pone la ventana en Fullscreen (ideal para videos/código)
hl.gesture({ fingers = 3, direction = "up", action = "fullscreen" })

-- 5. CONTROL DE VOLUMEN DINÁMICO (Gestos en vivo)
-- Deslizar 4 dedos arriba/abajo sube o baja el volumen progresivamente
local volume_gesture = function(change) 
    -- wpctl es el controlador nativo de audio en NixOS/Wayland (Wireplumber)
    hl.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ " .. math.abs(change) .. "%" .. (change<0 and "-" or "+")) 
end

hl.gesture({
    fingers = 4,
    direction = "vertical",
    action = {
        start = function(e) volume_gesture(-0.25 * e.delta.y) end,
        update = function(e) volume_gesture(-0.25 * e.delta.y) end
    },
})
