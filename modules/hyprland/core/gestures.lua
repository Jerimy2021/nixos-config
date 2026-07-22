-- ==============================================================================
-- CORE: ADVANCED GESTURES (Hyprland 0.55+ Lua Engine)
-- ==============================================================================

-- 1. CAMBIO DE WORKSPACE (Clásico)
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- 2. ZOOM EN VIVO ESTILO MAC (Pellizco)
hl.gesture({ fingers = 2, direction = "pinch", action = "cursorZoom", zoom_level = 1, mode = "live" })

-- 3. CERRAR VENTANA RÁPIDO
hl.gesture({ fingers = 3, direction = "down", action = "close" })

-- 4. MODO PANTALLA COMPLETA
hl.gesture({ fingers = 3, direction = "up", action = "fullscreen" })

-- 5. CONTROL DE VOLUMEN (Vía Hyprctl Nativo)
-- Esto inyecta el atajo directamente al motor en su idioma original
hl.exec_cmd("hyprctl keyword bind swipe:4:u, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+")
hl.exec_cmd("hyprctl keyword bind swipe:4:d, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
