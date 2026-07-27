-- ==============================================================================
-- hyprland master- LUA VERSION
-- ==============================================================================

-- Definimos la ruta base dinámica usando la variable de entorno de tu usuario
local conf_dir = os.getenv("HOME") .. "/.config/hypr/"

-- 1. core & hardware
dofile(conf_dir .. "core/env.lua")
dofile(conf_dir .. "core/monitors.lua")
dofile(conf_dir .. "core/inputs.lua")
dofile(conf_dir .. "core/gestures.lua")
dofile(conf_dir .. "core/autostart.lua")
dofile(conf_dir .. "core/keybinds.lua")
dofile(conf_dir .. "core/window-rules.lua")
dofile(conf_dir .. "core/behavior.lua")

-- 2. theme engine pivot
-- Nota: Asegúrate de renombrar tu archivo active.conf a active.lua también
dofile(conf_dir .. "themes/active.lua")
