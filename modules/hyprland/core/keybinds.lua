-- ==============================================================================
-- CORE: ATAJOS DE TECLADO (Optimizados y Nativos - LUA v0.55+)
-- ==============================================================================

local mainMod = "SUPER"

-- --- VARIABLES DE APLICACIONES ---
local terminal = "foot"
local browser = "firefox"
local fileManager = "thunar"
local menu = "rofi -show drun -theme ~/.config/rofi/rofi-border.rasi"

-- ==============================================================================
-- 1. APLICACIONES PRINCIPALES Y MENÚS
-- ==============================================================================
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))             -- Terminal
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))                   -- Navegador Web
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))               -- Explorador de Archivos
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))                      -- Menú de Apps (Drun)
hl.bind("CTRL + Tab", hl.dsp.exec_cmd("rofi -show window -theme ~/.config/rofi/glass-window.rasi")) -- Cambiar Ventanas
hl.bind(mainMod .. " + CTRL + E", hl.dsp.exec_cmd("rofimoji"))         -- Menú de Emojis
hl.bind(mainMod .. " + CTRL + C", hl.dsp.exec_cmd("rofi -show calc -modi calc -no-show-match -no-sort")) -- Calculadora

-- Comandos complejos envueltos en [[ ... ]] para evitar problemas con comillas
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd([[cliphist list | rofi -dmenu -theme ~/.config/rofi/glass-window.rasi -p "󰅌  Portapapeles" | cliphist decode | wl-copy]]))
hl.bind(mainMod .. " + CTRL + K", hl.dsp.exec_cmd([[bash -c 'cat ~/.config/hypr/assets/atajos.txt | rofi -dmenu -i -markup-rows -theme ~/.config/rofi/cheatsheet.rasi -p "󰌌  Atajos"']]))

-- ==============================================================================
-- 2. GESTIÓN DE VENTANAS Y ESTADOS
-- ==============================================================================
hl.bind(mainMod .. " + Q", hl.dsp.window.close())                      -- Cerrar ventana actual
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd([[hyprctl activewindow | grep pid | tr -d 'pid:' | xargs kill]])) -- Forzar cierre
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())                 -- Pantalla completa real
hl.bind(mainMod .. " + M", hl.dsp.window.fullscreen(1))                -- Maximizar (Mantiene barra visible)
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" })) -- Alternar ventana flotante
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("hyprctl dispatch workspaceopt allfloat")) -- Alternar todas flotantes
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))               -- Cambiar orientación de división (Dwindle)
hl.bind(mainMod .. " + K", hl.dsp.layout("swapsplit"))                 -- Intercambiar división
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("hyprctl dispatch togglegroup")) -- Agrupar ventanas (Tabbed)

-- Función Lambda (Múltiples acciones en un solo atajo) para ALT+Tab
hl.bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())                            -- Navegar entre ventanas
    hl.dispatch(hl.dsp.window.bring_to_top())                          -- Traer ventana al frente
end)

-- ==============================================================================
-- 3. FOCO, MOVIMIENTO Y REDIMENSIÓN
-- ==============================================================================
-- Foco
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Mover ventanas de lugar
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.swap({ direction = "down" }))

-- Redimensionar ventanas con teclado usando el despachador nativo
hl.bind(mainMod .. " + SHIFT + ALT + right", hl.dsp.window.resize({ x = 30, y = 0, relative = true }))
hl.bind(mainMod .. " + SHIFT + ALT + left",  hl.dsp.window.resize({ x = -30, y = 0, relative = true }))
hl.bind(mainMod .. " + SHIFT + ALT + up",    hl.dsp.window.resize({ x = 0, y = -30, relative = true }))
hl.bind(mainMod .. " + SHIFT + ALT + down",  hl.dsp.window.resize({ x = 0, y = 30, relative = true }))

-- Mouse: Mover y Redimensionar usando la bandera { mouse = true }
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })   -- Click Izq
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true }) -- Click Der

-- ==============================================================================
-- 4. NAVEGACIÓN DE ESPACIOS DE TRABAJO (Workspaces)
-- ==============================================================================
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. tostring(i), hl.dsp.focus({ workspace = tostring(i) }))
    hl.bind(mainMod .. " + SHIFT + " .. tostring(i), hl.dsp.window.move({ workspace = tostring(i) }))
end

-- El 0 se maneja aparte por ser el workspace 10
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = "10" }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "10" }))

-- Navegación rápida
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))   -- Rueda abajo
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))    -- Rueda arriba
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "m+1" }))         -- Siguiente workspace
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" })) -- Workspace anterior
hl.bind(mainMod .. " + CTRL + down", hl.dsp.focus({ workspace = "empty" }))
hl.bind(mainMod .. " + CTRL + U", hl.dsp.exec_cmd([==[bash -c 'sel=$(cat ~/.config/hypr/assets/quicklinks.txt | rofi -dmenu -i -theme ~/.config/rofi/cheatsheet.rasi -p "  Quicklinks"); [ -z "$sel" ] && exit 0; cmd=$(echo "$sel" | cut -d"|" -f2- | xargs); eval "$cmd"']==]))

-- ==============================================================================
-- 5. SISTEMA, MEDIOS Y HARDWARE
-- ==============================================================================
-- Banderas clave: { locked = true } permite usar el botón en la pantalla de bloqueo.
-- { repeating = true } permite dejar el botón pulsado.

hl.bind("XF86ScreenSaver", hl.dsp.exec_cmd("hyprlock"), { locked = true })
-- wlogout-launch se retiró por completo (Hito 004 follow-up 3): PowerMenu.qml
-- de QuickShell lo reemplaza (lock/suspend/logout/reboot/shutdown en un
-- flyout que además se despliega solo al acercar el mouse, ver
-- modules/quickshell/modules/powermenu/PowerMenu.qml). Mismo target que el
-- toggle del dashboard: IPC hacia UiState.
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("quickshell ipc call uiState togglePowerMenu"), { locked = true })
hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + CTRL + Q", hl.dsp.exec_cmd("quickshell ipc call uiState togglePowerMenu"))

-- Volumen
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true, locked = true }) --
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true, locked = true }) --
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true }) --
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

-- Medios
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true }) --
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })       --
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })   --

-- Brillo
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { repeating = true, locked = true })

-- ==============================================================================
-- 6. HERRAMIENTAS, ESTÉTICA Y SCRIPTS
-- ==============================================================================
-- QuickShell recarga en caliente al guardar un .qml (settings.watchFiles,
-- ver shell.qml), así que esto es solo para cambios estructurales que el
-- watcher no capta bien (ids de Variants, imports nuevos, etc).
hl.bind(mainMod .. " + CTRL + B", hl.dsp.exec_cmd([[bash -c 'pkill quickshell; sleep 0.3; qs']]))
-- Antes abría el panel de waybar; ahora es la superficie interactiva
-- natural del sistema, así que togglea el dashboard de QuickShell en su
-- lugar (mismo target que la cápsula del reloj en la barra).
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("quickshell ipc call uiState toggleDashboard"))
-- CTRL+T (themeswitcher.sh de waybar) se elimina sin reemplazo: ese script
-- rotaba entre carpetas de temas .css estáticos, algo que no tiene
-- equivalente directo en QuickShell (el theming vivo por Theme.qml/Palette
-- ya cubre la variación de color; un selector de "preset" completo sería
-- una feature nueva, no una migración 1:1 — si se quiere, es un módulo
-- futuro, no una tecla huérfana apuntando a nada).
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

-- Fondos y Shaders
-- CTRL+W abría la GUI de waypaper para elegir wallpaper a mano — ahora
-- redundante con el picker de miniaturas (Hito 004 follow-up 3, ver
-- WallpaperPicker.qml), así que se repunta a abrirlo.
-- Hito 004 follow-up 13: el picker dejó de ser una pestaña anidada del
-- dashboard — pasó a ser su propio popup standalone
-- (WallpaperPickerPopup.qml), así que esto ahora apunta a
-- toggleWallpaperPicker en vez de toggleDashboard.
-- ALT+W (`waypaper --random`) SÍ se conserva: es una acción de un solo tecleo
-- para "sorpréndeme", y el picker nuevo solo soporta selección deliberada
-- por click — no hay equivalente de un tecleo para eso hoy. No es un
-- descuido, es la razón documentada que pide el brief.
hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd("waypaper --random"))
hl.bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd("quickshell ipc call uiState toggleWallpaperPicker"))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.exec_cmd("hyprshade toggle blue-light-filter"))

-- Modo Juego
hl.bind(mainMod .. " + ALT + G", hl.dsp.exec_cmd("hypr-gamemode"))

-- Capturas de Pantalla (Grimblast y estándar)
hl.bind("PRINT", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]]))
hl.bind(mainMod .. " + ALT + F", hl.dsp.exec_cmd("grimblast --notify copysave screen"))
hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd("grimblast --notify copysave area"))

-- Pantalla (Zoom) usando strings de bloque literal
hl.bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.exec_cmd([[hyprctl keyword cursor:zoom_factor $(awk "BEGIN {print $(hyprctl getoption cursor:zoom_factor | grep 'float:' | awk '{print $2}') + 0.5}")]]))
hl.bind(mainMod .. " + SHIFT + mouse_up", hl.dsp.exec_cmd([[hyprctl keyword cursor:zoom_factor $(awk "BEGIN {print $(hyprctl getoption cursor:zoom_factor | grep 'float:' | awk '{print $2}') - 0.5}")]]))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd("hyprctl keyword cursor:zoom_factor 1"))

-- ==============================================================================
-- 7. ZONAS MÁGICAS (Special Workspaces)
-- ==============================================================================
-- Sidepad genérico (sin cambios)
hl.bind(mainMod .. " + S", function() hl.dispatch(hl.dsp.workspace.toggle_special("magic")) end)
hl.bind(mainMod .. " + SHIFT + S", function() hl.dispatch(hl.dsp.window.move({ workspace = "special:magic" })) end)

hl.bind(mainMod .. " + CTRL + right", function()
  hl.dispatch(hl.dsp.exec_cmd("sidepad-toggle"))
end)
hl.bind(mainMod .. " + CTRL + left", function()
  hl.dispatch(hl.dsp.exec_cmd("sidepad-toggle"))
end)
