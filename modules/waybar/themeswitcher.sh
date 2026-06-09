#!/usr/bin/env bash
#  _____ _                               _ _       _   
# |_   _| |__   ___ _ __ ___   ___  _____      _(_) |_ ___| |__   ___  ___ _ __
#   | | | '_ \ / _ \ '_ ` _ \ / _ \/ __\ \ /\ / / | __/ __| '_ \ / _ \/ __| '__|
#   | | | | | |  __/ | | | | |  __/\__ \\ V  V /| | || (__| | | |  __/ (__| |   
#   |_| |_| |_|\___|_| |_| |_|\___||___/ \_/\_/ |_|\__\___|_| |_|\___|\___|_|   
#
# Optimizado y libre de errores para Symlinks en NixOS

launcher=$(cat $HOME/.config/ml4w/settings/launcher 2>/dev/null || echo "rofi")
themes_path="$HOME/.config/waybar/themes"
listNames=""

while IFS= read -r style_file; do
    rel_path=$(echo "$style_file" | sed "s#$themes_path/##" | sed "s#/style.css##")
    if [[ "$rel_path" == *"assets"* ]]; then continue; fi
    listNames+="$rel_path\n"
done < <(find -L "$themes_path" -type f -name "style.css" 2>/dev/null)

listNames=$(echo -e "$listNames" | sed '/^$/d' | sort)

if [ "$launcher" == "walker" ]; then
    choice=$(echo -e "$listNames" | $HOME/.config/walker/launch.sh -d -i -N -H --height 400 -p "Search Theme")
else
    choice=$(echo -e "$listNames" | rofi -dmenu -replace -i -config ~/.config/rofi/config-themes.rasi -no-show-icons -width 30 -p "Themes")
fi

choice=$(echo "$choice" | xargs)

if [ -n "$choice" ]; then
    echo "Loading waybar theme: $choice"
    
    # 🔥 EL CAMBIO CLAVE: Guardamos en .cache que siempre es escribible
    echo "$choice" > ~/.cache/waybar-theme-active
    
    bash ~/.config/waybar/launch.sh
fi
