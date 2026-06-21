#!/usr/bin/env bash

WALLPAPER="$1"
[ -z "$WALLPAPER" ] && exit 1

# 1. Aplicar el fondo
swww img "$WALLPAPER" --transition-type wipe --transition-angle 30 --transition-step 90

# 2. Calcular la matemática de la luz (LUMA)
LUMA=$(magick "$WALLPAPER" -resize 1x1 -colorspace Gray -format "%[fx:int(mean*255)]" info:)

# 3. Aplicar el contraste perfecto según la luz
if [ "$LUMA" -gt 140 ]; then
    # LA IMAGEN ES CLARA: 
    # Le pasamos '-l' a Pywal para forzar un tema claro (TEXTO OSCURO)
    wal -i "$WALLPAPER" -n -q -a 32 -l
    matugen image "$WALLPAPER" --mode "light" < /dev/null
else
    # LA IMAGEN ES OSCURA:
    # Pywal normal genera temas oscuros (TEXTO CLARO)
    wal -i "$WALLPAPER" -n -q -a 32
    matugen image "$WALLPAPER" --mode "dark" < /dev/null
fi

# 4. Reiniciar Waybar
pkill -SIGUSR2 waybar
