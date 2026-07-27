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

-- 5. CONTROL DE VOLUMEN (Swipe de 4 dedos)
hl.config({
  bind = {
    -- Swipe 4 dedos hacia arriba (subir volumen)
    ", swipe:4:u, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+",
    
    -- Swipe 4 dedos hacia abajo (bajar volumen)
    ", swipe:4:d, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
  }
})
