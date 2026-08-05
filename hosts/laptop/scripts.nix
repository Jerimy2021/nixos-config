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

    # 1. Transición de cristal con AWWW (fork de swww; nixpkgs renombró el
    # atributo pkgs.swww -> pkgs.awww, pero el binario resultante también
    # pasó a llamarse "awww", no "swww" — bug preexistente detectado y
    # corregido en Hito 004, ver commit).
    ${pkgs.awww}/bin/awww img "$WALLPAPER" \
        --transition-type grow \
        --transition-pos 0.5,0.5 \
        --transition-step 90 \
        --transition-fps 60

    # 2. Inteligencia Artificial Básica (Calcular Luz)
    LUMA=$(${pkgs.imagemagick}/bin/magick "$WALLPAPER" -resize 1x1 -colorspace Gray -format "%[fx:int(mean*255)]" info:)

    # 3. Extraer paleta y aplicar modo Claro/Oscuro
    # --prefer saturation: fix de Hito 004 — sin esto, matugen aborta con
    # "Multiple source colors found, no preference was inputted" en
    # cualquier imagen con más de un color dominante viable (la mayoría).
    # saturation también es la opción más coherente con la estética
    # Hacker Pro/Cyberpunk del sistema (alta saturación, nunca pastel).
    if [ "$LUMA" -gt 140 ]; then
        ${pkgs.pywal}/bin/wal -i "$WALLPAPER" -n -q -a 32 -l
        ${pkgs.matugen}/bin/matugen image "$WALLPAPER" --mode "light" --prefer saturation < /dev/null
    else
        ${pkgs.pywal}/bin/wal -i "$WALLPAPER" -n -q -a 32
        ${pkgs.matugen}/bin/matugen image "$WALLPAPER" --mode "dark" --prefer saturation < /dev/null
    fi

    # 4. Refrescar la interfaz — ya no hace falta (Hito 004): QuickShell lee
    # todo por binding reactivo (FileView.watchChanges, Process, señales de
    # Hyprland), no por una señal de refresco explícita como waybar
    # (pkill -SIGUSR2) o swaync (swaync-client -rs), ambos retirados.
  '';

  # 2b. WALLPAPER POR WORKSPACE (Hito 004 / QuickShell)
  # Deliberadamente separado de set-wallpaper: la transición visual (awww)
  # corre siempre y en primer plano para sentirse instantánea, sin esperar
  # a pywal. matugen sí corre acá, pero solo la PRIMERA vez que se ve un
  # wallpaper dado (cacheado por ruta absoluta en palette.json) y en
  # segundo plano — así los workspaces ya visitados siguen siendo
  # instantáneos, y solo la primera visita paga el costo de extracción de
  # color. services/Palette.qml (QML) lee este archivo y lo vigila con
  # FileView.watchChanges, así que el acento de la barra se actualiza solo
  # en cuanto matugen termina, sin bloquear el cambio de workspace.
  # Hito 004 follow-up 15: segundo argumento opcional, tipo de transición
  # de awww (antes hardcodeado a "wipe" siempre). WorkspaceSync.qml ahora
  # hashea el id de workspace contra una lista fija de tipos
  # (transitionTypeFor()) para que cada workspace tenga una transición
  # visualmente distinta y consistente (mismo criterio que el wallpaper
  # por workspace: identidad reconocible, no aleatorio en cada cambio).
  # Default "wipe" si no se pasa — mantiene compatible cualquier llamador
  # viejo que no mande este argumento.
  workspace-wallpaper = pkgs.writeShellScriptBin "workspace-wallpaper" ''
    AWWW=${pkgs.awww}/bin/awww
    MATUGEN=${pkgs.matugen}/bin/matugen
    JQ=${pkgs.jq}/bin/jq
    FLOCK=${pkgs.util-linux}/bin/flock
    MKTEMP=${pkgs.coreutils}/bin/mktemp
    WALLPAPER="$1"
    TRANSITION_TYPE="''${2:-wipe}"
    CACHE_DIR="$HOME/.cache/quickshell"
    PALETTE_FILE="$CACHE_DIR/palette.json"

    [ -f "$WALLPAPER" ] || exit 0
    mkdir -p "$CACHE_DIR"
    [ -f "$PALETTE_FILE" ] || echo '{}' > "$PALETTE_FILE"

    "$AWWW" img "$WALLPAPER" \
        --transition-type "$TRANSITION_TYPE" \
        --transition-angle 30 \
        --transition-pos 0.5,0.5 \
        --transition-duration 0.65 \
        --transition-fps 60

    if ! "$JQ" -e --arg w "$WALLPAPER" 'has($w)' "$PALETTE_FILE" >/dev/null 2>&1; then
      (
        COLOR=$("$MATUGEN" image "$WALLPAPER" \
            --mode dark \
            --type scheme-vibrant \
            --prefer saturation \
            --json hex \
            --dry-run \
            --quiet 2>/dev/null | "$JQ" -r '.colors.primary.dark.color // empty')

        if [ -n "$COLOR" ]; then
          exec 9>"$CACHE_DIR/palette.lock"
          "$FLOCK" -x 9
          TMP=$("$MKTEMP" "$CACHE_DIR/palette.XXXXXX.json")
          "$JQ" --arg w "$WALLPAPER" --arg c "$COLOR" '.[$w] = $c' "$PALETTE_FILE" > "$TMP" && mv "$TMP" "$PALETTE_FILE"
        fi
      ) &
    fi
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
  CLAUDE=${pkgs.claude-code}/bin/claude

  clients=$("$HYPRCTL" clients -j)
  need_claude=1
  need_term=1
  echo "$clients" | "$JQ" -e '.[] | select(.class=="claude-sidepad" or .initialClass=="claude-sidepad")' >/dev/null 2>&1 && need_claude=0
  echo "$clients" | "$JQ" -e '.[] | select(.class=="term-sidepad" or .initialClass=="term-sidepad")' >/dev/null 2>&1 && need_term=0

  if [ "$need_claude" -eq 1 ] || [ "$need_term" -eq 1 ]; then
    dir=$("$ZOXIDE" query -l | "$ROFI" -dmenu -i -p '󰉋 Proyecto' -theme "$HOME/.config/rofi/projects.rasi")
    if [ -z "$dir" ]; then dir="$HOME"; fi

    if [ "$need_claude" -eq 1 ]; then
      cmd="[workspace special:sidepad silent] $FOOT --app-id claude-sidepad -D '$dir' -e $BASH -lc 'exec 9>/tmp/claude-sidepad.lock; $FLOCK -n 9 || exit 0; $CLAUDE'"
      "$HYPRCTL" dispatch "hl.dsp.exec_cmd([[$cmd]])"
    fi

    if [ "$need_term" -eq 1 ]; then
      cmd="[workspace special:sidepad silent] $FOOT --app-id term-sidepad -D '$dir' -e $ZSH"
      "$HYPRCTL" dispatch "hl.dsp.exec_cmd([[$cmd]])"
    fi
  fi

  "$HYPRCTL" dispatch 'hl.dsp.workspace.toggle_special([[sidepad]])'
  '';

  battery-notify = pkgs.writeShellScriptBin "battery-notify" ''
    NOTIFY=${pkgs.libnotify}/bin/notify-send
    BAT=$(${pkgs.coreutils}/bin/ls -d /sys/class/power_supply/BAT* 2>/dev/null | ${pkgs.coreutils}/bin/head -n 1)
    if [ -z "$BAT" ]; then
      exit 0
    fi

    notified_20=false
    notified_15=false

    while true; do
      capacity=$(${pkgs.coreutils}/bin/cat "$BAT/capacity")
      status=$(${pkgs.coreutils}/bin/cat "$BAT/status")

      if [ "$status" = "Discharging" ]; then
        if [ "$capacity" -le 15 ] && [ "$notified_15" = false ]; then
          "$NOTIFY" -u critical "Batería baja" "Restante: ''${capacity}%"
          notified_15=true
        elif [ "$capacity" -le 20 ] && [ "$capacity" -gt 15 ] && [ "$notified_20" = false ]; then
          "$NOTIFY" -u normal "Batería baja" "Restante: ''${capacity}%"
          notified_20=true
        elif [ "$capacity" -gt 20 ]; then
          notified_20=false
          notified_15=false
        fi
      else
        notified_20=false
        notified_15=false
      fi

      ${pkgs.coreutils}/bin/sleep 60
    done
  '';

  # 4. TOGGLE DE NM-APPLET
  nm-applet-ctl = pkgs.writeShellScriptBin "nm-applet-ctl" ''
    PGREP=${pkgs.procps}/bin/pgrep
    KILLALL=${pkgs.psmisc}/bin/killall
    NMAPPLET=${pkgs.networkmanagerapplet}/bin/nm-applet

    case "$1" in
      stop)
        "$KILLALL" nm-applet
        ;;
      toggle)
        if "$PGREP" -x "nm-applet" >/dev/null; then
          "$KILLALL" nm-applet
        else
          "$NMAPPLET" --indicator &
        fi
        ;;
      *)
        "$NMAPPLET" --indicator &
        ;;
    esac
  '';

  # 6. ESTADÍSTICAS DEL SISTEMA PARA LA PESTAÑA "PERFORMANCE" DEL DASHBOARD
  # (Hito 004 follow-up 8). Toda la lógica frágil (buscar el hwmon correcto,
  # tolerar que la GPU no responda) vive acá, auditable/testeable a mano con
  # `system-stats` desde una terminal — no como strings de shell sueltas
  # dentro del QML.
  system-stats = pkgs.writeShellScriptBin "system-stats" ''
    JQ=${pkgs.jq}/bin/jq
    AWK=${pkgs.gawk}/bin/awk

    # CPU: temperatura de paquete real vía sysfs (hwmon), no lm_sensors.
    # Confirmado en vivo (Hito 004 follow-up 8): el kernel de esta laptop ya
    # carga el driver "coretemp" (i5-1035G1) y expone "Package id 0" — leerlo
    # directo de /sys da el mismo número que `sensors` daría, sin agregar
    # lm_sensors a home.packages solo para esto. El índice hwmonN no es
    # estable entre reinicios (depende de qué más registre hwmon antes), así
    # que se busca por el archivo "name", nunca se asume "hwmon4".
    cpu_temp="null"
    for d in /sys/class/hwmon/hwmon*; do
      [ -f "$d/name" ] || continue
      if [ "$(cat "$d/name")" = "coretemp" ]; then
        pkg_file=""
        for lf in "$d"/temp*_label; do
          [ -f "$lf" ] || continue
          if [ "$(cat "$lf")" = "Package id 0" ]; then
            pkg_file="''${lf%_label}_input"
            break
          fi
        done
        [ -z "$pkg_file" ] && pkg_file="$d/temp1_input"
        if [ -f "$pkg_file" ]; then
          cpu_temp=$("$AWK" -v r="$(cat "$pkg_file")" 'BEGIN{printf "%.1f", r/1000}')
        fi
        break
      fi
    done

    # GPU: NVIDIA discreta en PRIME render-offload puro (no es el renderer
    # por defecto). Confirmado en vivo: `nvidia-smi` puede fallar con
    # "couldn't communicate with the NVIDIA driver" aun con la GPU presente
    # y el binario instalado, cuando nada la despertó todavía vía
    # __NV_PRIME_RENDER_OFFLOAD=1 — no es un error real del sistema, es el
    # estado normal de una GPU en offload puro sin nada renderizando ahí en
    # este momento. Se trata como "no disponible" (null), no se fuerza a la
    # GPU a encenderse solo para leer su temperatura.
    gpu_temp="null"
    if command -v nvidia-smi >/dev/null 2>&1; then
      raw=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | tr -dc '0-9')
      [ -n "$raw" ] && gpu_temp="$raw"
    fi

    mem_total_kb=$("$AWK" '/^MemTotal:/{print $2}' /proc/meminfo)
    mem_avail_kb=$("$AWK" '/^MemAvailable:/{print $2}' /proc/meminfo)
    mem_used_pct=$("$AWK" -v t="$mem_total_kb" -v a="$mem_avail_kb" 'BEGIN{ printf "%.1f", (t>0)?(t-a)/t*100:0 }')
    mem_used_gib=$("$AWK" -v t="$mem_total_kb" -v a="$mem_avail_kb" 'BEGIN{printf "%.1f", (t-a)/1048576}')
    mem_total_gib=$("$AWK" -v t="$mem_total_kb" 'BEGIN{printf "%.1f", t/1048576}')

    "$JQ" -n \
      --argjson cpuTempC "$cpu_temp" \
      --argjson gpuTempC "$gpu_temp" \
      --argjson memUsedPercent "$mem_used_pct" \
      --argjson memUsedGiB "$mem_used_gib" \
      --argjson memTotalGiB "$mem_total_gib" \
      '{cpuTempC:$cpuTempC, gpuTempC:$gpuTempC, memUsedPercent:$memUsedPercent, memUsedGiB:$memUsedGiB, memTotalGiB:$memTotalGiB}'
  '';

  # 5. LANZADOR/FOCUS DE APPS EXTERNAS (Discord, Spotify — Hito 004 follow-up 4)
  # Genérico y parametrizado (clase de ventana + comando de lanzamiento) en
  # vez de un script por app, mismo criterio que nm-applet-ctl. El foco por
  # selector de ventana usa la sintaxis Lua de este fork de Hyprland
  # (hl.dsp.focus({window=...})) — la sintaxis clásica `hyprctl dispatch
  # focuswindow "class:^(...)$"` falla acá ("expected a dispatcher"),
  # confirmado en vivo antes de escribir esto.
  app-toggle = pkgs.writeShellScriptBin "app-toggle" ''
    HYPRCTL=${pkgs.hyprland}/bin/hyprctl
    JQ=${pkgs.jq}/bin/jq
    CLASS="$1"
    LAUNCH_CMD="$2"

    if "$HYPRCTL" clients -j | "$JQ" -e --arg c "$CLASS" 'any(.[]; .class == $c)' >/dev/null 2>&1; then
      "$HYPRCTL" dispatch "hl.dsp.focus({ window = [[class:^($CLASS)$]] })"
    else
      "$HYPRCTL" dispatch "hl.dsp.exec_cmd([[$LAUNCH_CMD]])"
    fi
  '';
}
