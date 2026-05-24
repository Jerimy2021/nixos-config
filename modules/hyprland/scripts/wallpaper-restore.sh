#!/usr/bin/env bash
# -----------------------------------------------------
# Random Wallpaper on Boot - ROBUST VERSION
# -----------------------------------------------------

# 1. VERIFICACIÓN DE SEGURIDAD
# Si el motor swww no está corriendo, lo iniciamos a la fuerza.
if ! pgrep -x "swww-daemon" > /dev/null; then
    echo ":: swww-daemon not running, starting it..."
    swww-daemon --format xrgb &
    sleep 1
fi

# 2. Definir tu carpeta de imágenes
wallpaper_folder="$HOME/Pictures/Wallpapers"

# 3. Verificar que la carpeta existe
if [ -d "$wallpaper_folder" ]; then
    # Elegir un archivo al azar
    random_wallpaper=$(find "$wallpaper_folder" -type f | shuf -n 1)

    echo ":: Selected Random Wallpaper: $random_wallpaper"

    # 4. EJECUTAR EL SCRIPT MAESTRO
    # Esperamos un microsegundo para asegurar estabilidad
    sleep 0.5
    $HOME/.config/hypr/scripts/wallpaper.sh "$random_wallpaper"

else
    echo ":: Error: Folder $wallpaper_folder not found."
fi
