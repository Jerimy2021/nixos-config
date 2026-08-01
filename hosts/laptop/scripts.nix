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

  sidepad-toggle = pkgs.writeShellScriptBin "sidepad-toggle" ''
    HYPRCTL=${pkgs.hyprland}/bin/hyprctl
    JQ=${pkgs.jq}/bin/jq
    ZOXIDE=${pkgs.zoxide}/bin/zoxide
    ROFI=${pkgs.rofi}/bin/rofi
    FOOT=${pkgs.foot}/bin/foot
    BASH=${pkgs.bash}/bin/bash
    ZSH=${pkgs.zsh}/bin/zsh
    FLOCK=${pkgs.util-linux}/bin/flock

    clients=$("$HYPRCTL" clients -j)
    need_claude=1
    need_term=1
    echo "$clients" | "$JQ" -e '.[] | select(.class=="claude-sidepad" or .initialClass=="claude-sidepad")' >/dev/null 2>&1 && need_claude=0
    echo "$clients" | "$JQ" -e '.[] | select(.class=="term-sidepad" or .initialClass=="term-sidepad")' >/dev/null 2>&1 && need_term=0

    if [ "$need_claude" -eq 1 ] || [ "$need_term" -eq 1 ]; then
      dir=$("$ZOXIDE" query -l | "$ROFI" -dmenu -i -p '󰉋 Proyecto' -theme "$HOME/.config/rofi/projects.rasi")
      if [ -z "$dir" ]; then dir="$HOME"; fi

      if [ "$need_claude" -eq 1 ]; then
        cmd="[workspace special:sidepad silent] $FOOT --app-id claude-sidepad -D '$dir' -e $BASH -lc 'exec 9>/tmp/claude-sidepad.lock; $FLOCK -n 9 || exit 0; npx @anthropic-ai/claude-code'"
        "$HYPRCTL" dispatch "hl.dsp.exec_cmd([[$cmd]])"
      fi

      if [ "$need_term" -eq 1 ]; then
        cmd="[workspace special:sidepad silent] $FOOT --app-id term-sidepad -D '$dir' -e $ZSH"
        "$HYPRCTL" dispatch "hl.dsp.exec_cmd([[$cmd]])"
      fi
    fi

    "$HYPRCTL" dispatch 'hl.dsp.workspace.toggle_special([[sidepad]])'
  '';
}
