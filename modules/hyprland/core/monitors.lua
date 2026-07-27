-- ==============================================================================
-- CORE: MONITORES Y PANTALLAS (Sintaxis Lua - v0.55+)
-- ==============================================================================

-- 1. Pantalla principal (Tu Laptop) - Forzando su máxima resolución y Hz naturales
hl.monitor({
  output = "eDP-1",
  mode = "1366x768@60",
  position = "0x0",
  scale = 1
})

-- 2. Regla universal de fallback (Por si conectas un HDMI a un proyector o TV)
-- Dejando el 'output' vacío ("") creamos la regla por defecto para cualquier pantalla extra.
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1
})
