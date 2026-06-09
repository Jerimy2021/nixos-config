#!/usr/bin/env bash
#  _                               _       _     
# | |    __ _ _   _ _ __   ___| |__  _ __  | |__  
# | |   / _` | | | | '_ \ / __| '_ \| '_ \ | '_ \ 
# | |__| (_| | |_| | | | | (__| | | | | | || | | |
# |_____\__,_|\__,_|_| |_|\___|_| |_|_| |_||_| |_|
# Lanzador Determinista y Resiliente de Waybar para NixOS
#
exec 200>/tmp/waybar-launch.lock
flock -n 200 || exit 0

killall waybar || true
pkill waybar || true
sleep 0.3

# 🔥 EL CAMBIO CLAVE: Leemos desde .cache
if [ -f ~/.cache/waybar-theme-active ]; then
    theme_string=$(cat ~/.cache/waybar-theme-active | xargs)
else
    theme_string="ml4w-transparent/default"
fi

if [ -z "$theme_string" ]; then
    theme_string="ml4w-transparent/default"
fi

parent_theme=$(echo "$theme_string" | cut -d'/' -f1)

if [ -f "$HOME/.config/waybar/themes/$theme_string/config" ]; then
    config_path="$HOME/.config/waybar/themes/$theme_string/config"
elif [ -f "$HOME/.config/waybar/themes/$parent_theme/config" ]; then
    config_path="$HOME/.config/waybar/themes/$parent_theme/config"
else
    config_path="$HOME/.config/waybar/themes/default/config"
fi

if [ -f "$HOME/.config/waybar/themes/$theme_string/style.css" ]; then
    style_path="$HOME/.config/waybar/themes/$theme_string/style.css"
else
    style_path="$HOME/.config/waybar/themes/default/style.css"
fi

echo ":: Cargando Tema Waybar: $theme_string"

if [ ! -f $HOME/.config/ml4w/settings/waybar-disabled ]; then
    HYPRLAND_SIGNATURE=$(hyprctl instances -j | jq -r '.[0].instance')
    HYPRLAND_INSTANCE_SIGNATURE="$HYPRLAND_SIGNATURE" waybar -c "$config_path" -s "$style_path" &
fi

flock -u 200
exec 200>&-
