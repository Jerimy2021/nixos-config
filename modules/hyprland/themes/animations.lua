-- ==============================================================================
-- ANIMATION ENGINE (Ultimate Fusion: End-4 + Jakoolit + Dynamic - LUA)
-- ==============================================================================

hl.config({
  animations = {
    enabled = true,

    -- --- 1. CURVAS MAESTRAS ---
    bezier = {
      -- Elegancia Material (End-4)
      "md3_decel, 0.05, 0.7, 0.1, 1",
      "md3_accel, 0.3, 0, 0.8, 0.15",
      "menu_decel, 0.1, 1, 0, 1",
      "menu_accel, 0.38, 0.04, 1, 0.07",
      
      -- Rebotes y Fluidez (Smooth / Jakoolit)
      "easeOutBack, 0.34, 1.56, 0.64, 1",
      "overshot, 0.05, 0.9, 0.1, 1.05",
      
      -- Movimiento Continuo (Dynamic / High)
      "linear, 0, 0, 1, 1",
      "wind, 0.05, 0.9, 0.1, 1.05"
    },

    -- --- 2. REGLAS DE ANIMACIÓN ---
    animation = {
      -- Ventanas
      "windows, 1, 5, wind, slide",
      "windowsIn, 1, 4, easeOutBack, popin 60%",
      "windowsOut, 1, 3, md3_accel, popin 60%",
      "windowsMove, 1, 4, menu_decel, slide",

      -- Bordes (El motor de energía)
      "border, 1, 5, default",
      "borderangle, 1, 30, linear, loop",

      -- Interfaces (Waybar, Rofi, Menús)
      "fade, 1, 3, md3_decel",
      "layersIn, 1, 3, menu_decel, slide",
      "layersOut, 1, 1.6, menu_accel",
      "fadeLayersIn, 1, 2, menu_decel",
      "fadeLayersOut, 1, 4.5, menu_accel",

      -- Espacios de Trabajo
      "workspaces, 1, 5, menu_decel, slide",
      "specialWorkspace, 1, 3, md3_decel, slidevert"
    }
  }
})
