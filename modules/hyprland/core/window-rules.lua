-- ==============================================================================
-- REGLAS DE VENTANAS Y CAPAS (Sintaxis Lua - Estilo Jakoolit / End4)
-- ==============================================================================

-- Panel combinado: Claude Code (derecha) + Terminal (izquierda), mismo workspace especial
hl.window_rule({
  name = "claude-sidepad-style",
  match = { class = "^(claude-sidepad)$" },
  float = true,
  size = {"monitor_w*0.47", "monitor_h*0.94-40"},
  move = {"monitor_w*0.515", "monitor_h*0.03+40"},
  rounding = 16,
  border_size = 2,
  border_color = "rgba(cba6f7ee) rgba(89b4faee) 45deg",
  animation = "slide right",
  opacity = "0.94 override 0.88 override",
  dim_around = true
})

hl.window_rule({
  name = "term-sidepad-style",
  match = { class = "^(term-sidepad)$" },
  float = true,
  size = {"monitor_w*0.47", "monitor_h*0.94-40"},
  move = {"monitor_w*0.015", "monitor_h*0.03+40"},
  rounding = 16,
  border_size = 2,
  border_color = "rgba(89b4faee) rgba(a6e3a1ee) 225deg",
  animation = "slide left",
  opacity = "0.94 override 0.88 override"
})

hl.window_rule({ match = { class = "^(foot)$" }, opacity = "0.80 override 0.70 override 1.0 override" })
hl.window_rule({
  name = "thunar-float",
  match = { class = "^(thunar)$" },
  float = true,
  size = "60% 70%",
  center = true,
  opacity = "0.80 override 0.65 override"
})
hl.window_rule({ match = { class = "^(nemo)$" }, opacity = "0.90 override 0.80 override" })
hl.window_rule({ match = { class = "^(code-oss)$" }, opacity = "0.95 override 0.85 override 1.0 override" })

-- --- 4. MAGIA EN LAS CAPAS (Rofi, QuickShell)
hl.layer_rule({
  name = "rofi-glass",
  match = { namespace = "^(rofi)$" },
  blur = true,
  ignore_alpha = 0,
  animation = "popin 80%",
  xray = true
})
-- QuickShell (Hito 004) usa un solo namespace de layer-shell ("quickshell")
-- para todas sus superficies — barra, dashboard y centro de notificaciones
-- comparten esta regla. Confirmado en vivo con `hyprctl layers -j`, no
-- asumido (era "waybar" antes de la migración).
hl.layer_rule({
  match = { namespace = "^(quickshell)$" },
  blur = true,
  ignore_alpha = 0.1,
  xray = true
})
