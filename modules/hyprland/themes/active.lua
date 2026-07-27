-- ==============================================================================
-- TEMA ACTIVO (THEME ENGINE PIVOT - LUA)
-- ==============================================================================

local conf_dir = os.getenv("HOME") .. "/.config/hypr/"

-- 1. BASE DEFAULT: Tu Súper Motor de Animaciones
dofile(conf_dir .. "themes/animations.lua")

-- 2. TEMA ELEGIDO: Colores, bordes, etc.
dofile(conf_dir .. "themes/cyberdream/theme.lua")
