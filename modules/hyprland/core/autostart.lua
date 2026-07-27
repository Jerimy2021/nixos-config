-- ==============================================================================
-- CORE: AUTOSTART (Demonios y servicios de arranque en Lua)
-- ==============================================================================

hl.on("hyprland.start", function()
  -- 1. ENTORNO WAYLAND (Crítico para OBS, compartir pantalla y DBus)
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

  -- 2. POLKIT (Ventana para pedir contraseña de administrador)
  hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

  -- 3. CURSOR DEL SISTEMA
  hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")

  -- 4. MOTOR DE FONDOS DE PANTALLA (Nativo)
  hl.exec_cmd("awww-daemon --format xrgb")

  -- 5. DEMONIOS DEL SISTEMA (Notificaciones, Energía y Portapapeles)
  hl.exec_cmd("swaync")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")

  -- 6. APPLETS DEL SISTEMA (Red, Bluetooth y Luz Nocturna)
  hl.exec_cmd("nm-applet --indicator")
  hl.exec_cmd("blueman-applet")
  hl.exec_cmd("wlsunset -S 9:00 -s 19:00")
  
  -- 7. BARRAS Y WALLPAPERS
  hl.exec_cmd("waybar")
  hl.exec_cmd("waypaper --random")
end)
