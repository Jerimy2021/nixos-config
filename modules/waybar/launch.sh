#!/usr/bin/env bash
#  _                       _       _     
# | |    __ _ _   _ _ __   ___| |__  _ __  
# | |   / _` | | | | '_ \ / __| '_ \| '_ \ 
# | |__| (_| | |_| | | | | (__| | | | | | |
# |_____\__,_|\__,_|_| |_|\___|_| |_|_| |_|
# Patched for NixOS Immutability

# Evitar ejecuciones duplicadas en paralelo
exec 200>/tmp/waybar-launch.lock
flock -n 200 || exit 0

# Matar instancias previas de Waybar
killall waybar || true
pkill waybar || true
sleep 0.3

# Tema por defecto si no se encuentra ninguno
default_theme="/default;/default"

# Obtener el tema seleccionado desde el archivo mutable de configuración
if [ -f ~/.config/ml4w/settings/waybar-theme.sh ]; then
    themestyle=$(cat ~/.config/ml4w/settings/waybar-theme.sh)
else
    mkdir -p ~/.config/ml4w/settings
    echo "$default_theme" > ~/.config/ml4w/settings/waybar-theme.sh
    themestyle=$default_theme
fi

IFS=';' read -ra arrThemes <<<"$themestyle"
echo ":: Cargando Tema Waybar: ${arrThemes[0]}"

# Validar que el archivo de estilo exista en el entorno Nix, si no, usar default
if [ ! -f ~/.config/waybar/themes${arrThemes[1]}/style.css ]; then
    themestyle=$default_theme
    IFS=';' read -ra arrThemes <<<"$themestyle"
fi

config_file="config"
style_file="style.css"

# Permitir sobreescritura si existen archivos personalizados (-custom)
if [ -f ~/.config/waybar/themes${arrThemes[0]}/config-custom ]; then
    config_file="config-custom"
fi
if [ -f ~/.config/waybar/themes${arrThemes[1]}/style-custom.css ]; then
    style_file="style-custom.css"
fi

# Lanzar Waybar apuntando directamente a las rutas del Nix Store en ~/.config/waybar
if [ ! -f $HOME/.config/ml4w/settings/waybar-disabled ]; then
    HYPRLAND_SIGNATURE=$(hyprctl instances -j | jq -r '.[0].instance')
    HYPRLAND_INSTANCE_SIGNATURE="$HYPRLAND_SIGNATURE" waybar -c ~/.config/waybar/themes${arrThemes[0]}/$config_file -s ~/.config/waybar/themes${arrThemes[1]}/$style_file &
else
    echo ":: Waybar deshabilitado en los settings"
fi

flock -u 200
exec 200>&-
