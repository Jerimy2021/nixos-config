-- ==============================================================================
-- COMPORTAMIENTO DEL ENTORNO (Layouts & Misc - Lua v0.55+)
-- ==============================================================================

hl.config({
  -- --- 1. MOTOR DE VENTANAS (Dwindle Avanzado) ---
  dwindle = {
    preserve_split = true,       -- Mantiene el orden espacial al cerrar/abrir ventanas
    smart_split = false,          -- MEJORA PRO: Divide la ventana según la posición exacta de tu cursor (triángulos conceptuales)
    smart_resizing = true,       -- Redimensionamiento basado en la posición del mouse hacia las esquinas
    precise_mouse_move = true,   -- MEJORA PRO: Soltar ventanas al arrastrarlas es mucho más exacto
    default_split_ratio = 1.0,   -- Asegura que las ventanas se dividan en un 50/50 perfecto al inicio
    special_scale_factor = 0.95, -- Hace que el workspace especial (scratchpad) se vea un poco más pequeño para dar efecto de superposición
  },

  -- --- 2. CONFIGURACIÓN MISCELÁNEA (Limpieza visual y Rendimiento) ---
  misc = {
    disable_hyprland_logo = true,      -- Adiós al logo de anime al arrancar
    disable_splash_rendering = true,   -- Adiós a los textos de advertencia rojos
    initial_workspace_tracking = 1,
    
    vrr = 1,                           -- Variable Refresh Rate: Activa Freesync/G-Sync
    
    -- Animaciones extra (Estilo End-4)
    animate_manual_resizes = true,     -- Animación fluida al cambiar el tamaño con el mouse
    animate_mouse_windowdragging = true
  },

  -- --- 3. COMPORTAMIENTO DE ESCRITORIOS ---
  binds = {
    workspace_back_and_forth = true,   -- UX Brutal: Volver al escritorio anterior con la misma tecla
    allow_workspace_cycles = true,
    pass_mouse_when_bound = false
  }
})
