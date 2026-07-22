local config_dir = os.getenv("HOME") .. "/.config/hypr/"

local function load_conf(file)
	hl.exec_cmd("hyprctl keyword source " .. config_dir .. file)
end

load_conf("core/env.conf")
load_conf("core/autostart.conf")
load_conf("core/monitors.conf")
load_conf("core/inputs.conf")
load_conf("core/behavior.conf")
load_conf("core/keybinds.conf")
load_conf("core/window-rules.conf")
load_conf("themes/active.conf")


dotfile(config_dir .. "core/gestures.lua")
