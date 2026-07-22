{ pkgs }:

{
  # 1. Modo Juego para Hyprland (El que ya tenías)
  hypr-gamemode = pkgs.writeShellScriptBin "hypr-gamemode" ''
    HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
    
    if [ "$HYPRGAMEMODE" = 1 ] ; then
        hyprctl --batch "\
            keyword animations:enabled 0;\
            keyword decoration:drop_shadow 0;\
            keyword decoration:blur:enabled 0;\
            keyword general:gaps_in 0;\
            keyword general:gaps_out 0;\
            keyword general:border_size 1;\
            keyword decoration:rounding 0"
        notify-send "🎮 Modo Juego: ACTIVADO" "Rendimiento máximo."
        exit
    fi
    
    hyprctl reload
    notify-send "💻 Modo Juego: DESACTIVADO" "Entorno restaurado."
  '';

  # 2. MOTOR DE THEMING DINÁMICO (Estilo End-4 / Jakoolit)
  set-wallpaper = pkgs.writeShellScriptBin "set-wallpaper" ''
    WALLPAPER="$1"
    
    if [ -z "$WALLPAPER" ]; then
        echo "Uso: set-wallpaper /ruta/a/tu/imagen.jpg"
        exit 1
    fi

    # 1. Transición de cristal con SWWW
    ${pkgs.swww}/bin/swww img "$WALLPAPER" \
        --transition-type grow \
        --transition-pos 0.5,0.5 \
        --transition-step 90 \
        --transition-fps 60

    # 2. Inteligencia Artificial Básica (Calcular Luz)
    LUMA=$(${pkgs.imagemagick}/bin/magick "$WALLPAPER" -resize 1x1 -colorspace Gray -format "%[fx:int(mean*255)]" info:)

    # 3. Extraer paleta y aplicar modo Claro/Oscuro
    if [ "$LUMA" -gt 140 ]; then
        ${pkgs.pywal}/bin/wal -i "$WALLPAPER" -n -q -a 32 -l
        ${pkgs.matugen}/bin/matugen image "$WALLPAPER" --mode "light" < /dev/null
    else
        ${pkgs.pywal}/bin/wal -i "$WALLPAPER" -n -q -a 32
        ${pkgs.matugen}/bin/matugen image "$WALLPAPER" --mode "dark" < /dev/null
    fi

    # 4. Refrescar la Interfaz sin parpadeos
    pkill -SIGUSR2 waybar
    ${pkgs.swaynotificationcenter}/bin/swaync-client -rs
  '';
}
