-- ==============================================================================
-- MOTOR ESTÉTICO (Bordes, Gaps, Blur y Efecto Neón - LUA)
-- ==============================================================================

hl.config({
  general = {
    border_size = 3,
    gaps_in = 6,
    gaps_out = 12,
	col = {
     active_border = {
       colors = { "rgba(89b4faff)", "rgba(cba6f7ff)", "rgba(f5c2e7ff)" },
       angle = 45
     },
     inactive_border = "rgba(333333aa)"
    },
	layout = "dwindle",
    resize_on_border = true
  },

  decoration = {
    rounding = 12,
    
    -- OPACIDAD BASE
    active_opacity = 1.0,
    inactive_opacity = 0.90,
    
    -- DIMMING: Oscurece ligeramente las ventanas sin foco
    dim_inactive = false,
    dim_strength = 0.35,

    -- EL MEJOR BLUR DEL ECOSISTEMA
    blur = {
      enabled = true,
      size = 8,
      passes = 3,                    -- Balance perfecto entre belleza y rendimiento
      ignore_opacity = true,         -- Blur nítido en ventanas transparentes
      new_optimizations = true,
      xray = false,
      vibrancy = 0.2,                -- Saturation boost
      popups = true                  -- Aplica blur a menús y tooltips
    },

    -- EFECTO NEÓN (SOMBRAS CON LUZ)
    shadow = {
      enabled = true,
      range = 30,                    -- Brillo (Glow) amplio
      render_power = 3,
      color = "rgba(cba6f788)",      -- Brillo dorado intenso (Foco)
      color_inactive = "rgba(00000000)" -- Se apaga al perder foco
    }
  }
})
