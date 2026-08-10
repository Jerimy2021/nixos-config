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
    # Hito 005 follow-up 3 (ver docs/NIXOS_ARCHITECTURE_HITO_005.md §8):
    # nixfm necesita más que un acento suelto — fondo/texto/superficie
    # realmente claros y cálidos (paleta "cream/terracotta/gold" del
    # mockup aprobado), con pares de contraste garantizado, no algo que un
    # solo hex pueda derivar de forma segura a mano. Cache SEPARADO de
    # palette.json a propósito — nunca se toca ese archivo ni
    # WallpaperPalette.qml (el tema oscuro de la barra), cero riesgo ahí.
    FM_PALETTE_FILE="$CACHE_DIR/filemanager-palette.json"

    [ -f "$WALLPAPER" ] || exit 0
    mkdir -p "$CACHE_DIR"
    [ -f "$PALETTE_FILE" ] || echo '{}' > "$PALETTE_FILE"
    [ -f "$FM_PALETTE_FILE" ] || echo '{}' > "$FM_PALETTE_FILE"

    "$AWWW" img "$WALLPAPER" \
        --transition-type "$TRANSITION_TYPE" \
        --transition-angle 30 \
        --transition-pos 0.5,0.5 \
        --transition-duration 0.65 \
        --transition-fps 60

    NEED_ACCENT=1
    "$JQ" -e --arg w "$WALLPAPER" 'has($w)' "$PALETTE_FILE" >/dev/null 2>&1 && NEED_ACCENT=0
    NEED_ROLES=1
    "$JQ" -e --arg w "$WALLPAPER" 'has($w)' "$FM_PALETTE_FILE" >/dev/null 2>&1 && NEED_ROLES=0

    if [ "$NEED_ACCENT" -eq 1 ] || [ "$NEED_ROLES" -eq 1 ]; then
      (
        # --json hex siempre incluye AMBOS modos (.light y .dark) para
        # cada rol en una sola invocación (confirmado en vivo con
        # --mode dark: .colors.primary.light.color sigue presente) — un
        # solo proceso matugen alimenta las dos caches, no hace falta
        # correrlo dos veces.
        MATUGEN_JSON=$("$MATUGEN" image "$WALLPAPER" \
            --mode dark \
            --type scheme-vibrant \
            --prefer saturation \
            --json hex \
            --dry-run \
            --quiet 2>/dev/null)

        if [ "$NEED_ACCENT" -eq 1 ]; then
          COLOR=$(printf '%s' "$MATUGEN_JSON" | "$JQ" -r '.colors.primary.dark.color // empty')
          if [ -n "$COLOR" ]; then
            exec 9>"$CACHE_DIR/palette.lock"
            "$FLOCK" -x 9
            TMP=$("$MKTEMP" "$CACHE_DIR/palette.XXXXXX.json")
            "$JQ" --arg w "$WALLPAPER" --arg c "$COLOR" '.[$w] = $c' "$PALETTE_FILE" > "$TMP" && mv "$TMP" "$PALETTE_FILE"
          fi
        fi

        if [ "$NEED_ROLES" -eq 1 ]; then
          # background/alternateBackground/text/disabledText: par
          # background+on_background y surface_variant+on_surface_variant
          # de Material — matugen ya garantiza contraste legible acá, no
          # es un cálculo HSL a ojo. activeBackground/activeText:
          # primary_container/on_primary_container — el PAR que Material
          # diseña específicamente para "superficie tintada de acento +
          # texto legible encima", que es exactamente activeBackgroundColor/
          # activeTextColor de Kirigami. link: tertiary (tono oro/oliva,
          # la pata "gold" de la paleta cream/terracotta/gold).
          ROLES=$(printf '%s' "$MATUGEN_JSON" | "$JQ" -c '{
              background: (.colors.background.light.color // empty),
              surfaceVariant: (.colors.surface_variant.light.color // empty),
              text: (.colors.on_background.light.color // empty),
              textMuted: (.colors.on_surface_variant.light.color // empty),
              activeBackground: (.colors.primary_container.light.color // empty),
              activeText: (.colors.on_primary_container.light.color // empty),
              link: (.colors.tertiary.light.color // empty)
          }')

          if [ -n "$ROLES" ] && [ "$ROLES" != "null" ]; then
            exec 8>"$CACHE_DIR/filemanager-palette.lock"
            "$FLOCK" -x 8
            TMP2=$("$MKTEMP" "$CACHE_DIR/filemanager-palette.XXXXXX.json")
            "$JQ" --arg w "$WALLPAPER" --argjson r "$ROLES" '.[$w] = $r' "$FM_PALETTE_FILE" > "$TMP2" && mv "$TMP2" "$FM_PALETTE_FILE"
          fi
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
    # Argumento opcional $1 (feature "Open in sidepad" de nixfm, ver
    # docs/NIXOS_ARCHITECTURE_HITO_005.md §11): el keybind real
    # (keybinds.lua) sigue llamando este script SIN argumentos, así que
    # ese camino no cambia — el picker rofi/zoxide de siempre. Cuando SÍ
    # llega un argumento (nixfm pasando la carpeta que tiene abierta) se
    # salta el picker y usa esa carpeta directo, sin tocar nada del
    # lanzamiento de foot/claude/flock de más abajo.
    if [ -n "''${1:-}" ]; then
      dir="$1"
    else
      dir=$("$ZOXIDE" query -l | "$ROFI" -dmenu -i -p '󰉋 Proyecto' -theme "$HOME/.config/rofi/projects.rasi")
      if [ -z "$dir" ]; then dir="$HOME"; fi
    fi

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

  hdmi-control = pkgs.writeShellScriptBin "hdmi-control" ''
    HYPRCTL=${pkgs.hyprland}/bin/hyprctl
    WPCTL=${pkgs.wireplumber}/bin/wpctl
    PWDUMP=${pkgs.pipewire}/bin/pw-dump
    JQ=${pkgs.jq}/bin/jq
    MODE="''${1:-status}"

    HDMI_NAME=""
    for f in /sys/class/drm/card*-HDMI-A-*/status; do
      [ -f "$f" ] || continue
      if [ "$(cat "$f")" = "connected" ]; then
        HDMI_NAME=$(basename "$(dirname "$f")" | sed 's/^card[0-9]*-//')
        break
      fi
    done

    hl_monitor() {
      # $1=output $2=mode $3=position $4=scale $5=disabled ("true"/"false",
      # opcional, default "false") $6=mirror (nombre de output a espejar,
      # opcional, default "none")
      #
      # Hito 004 follow-up 21 — dos bugs reales encontrados en vivo con el
      # TV conectado, ninguno de los dos era la sintaxis heredada del
      # keyword clásico `monitor=`:
      #
      # 1) mode="disable"/position="" (lo que se asumía en el follow-up 20
      #    sin poder probarlo) NO sirve. Confirmado con `hyprctl eval`
      #    directo: tira "error applying field 'mode'" y "... 'position'",
      #    y el monitor se queda encendido pese al "ok" cosmético de
      #    llamadas previas. La forma real de apagar/prender un output es
      #    el campo booleano `disabled` — confirmado en vivo:
      #    `hl.monitor({output="HDMI-A-1", disabled=true})` sí lo saca de
      #    `hyprctl monitors -j` (solo sigue apareciendo en `monitors all
      #    -j`), y re-encenderlo requiere pasar `disabled=false` explícito
      #    junto con mode/position válidos — pasar solo mode/position sin
      #    el campo disabled NO lo reactiva (probado en vivo).
      #
      # 2) position="mirror,eDP-1" (sintaxis clásica del keyword
      #    `monitor=`) tampoco sirve acá — mismo error, "error applying
      #    field 'position'". El espejo es un campo SEPARADO, `mirror`,
      #    que toma el nombre del output a espejar (o "none" para
      #    desactivar el espejo) — confirmado en vivo: con
      #    `mirror="eDP-1"` `hyprctl monitors all -j` muestra
      #    `"mirrorOf":"0"` (el id interno de eDP-1) en vez de sus propias
      #    coordenadas/tamaño, y `mirror="none"` lo devuelve a extend
      #    normal sin tocar nada más.
      disabled="''${5:-false}"
      mirror="''${6:-none}"
      "$HYPRCTL" eval "hl.monitor({output=\"$1\", mode=\"$2\", position=\"$3\", scale=$4, disabled=$disabled, mirror=\"$mirror\"})"
    }

    set_default_sink_matching() {
      # Busca un sink cuyo nombre/descripción contenga $1 (case-insensitive)
      # dentro de la sección "Sinks:" de `wpctl status` y lo hace default.
      # No falla si no encuentra nada — el audio simplemente se queda en el
      # sink que ya estaba activo.
      #
      # Reintentos: encontrado en vivo con el TV real (reproducido dos
      # veces en la misma sesión) que, encadenando un cambio de modo justo
      # después de otro (p.ej. laptop-only -> extend con menos de ~1s de
      # diferencia), el sink nuevo que switch_audio_profile() debería
      # haber creado a veces todavía no aparece en el PRIMER `wpctl
      # status` posterior al `wpctl set-profile` — aun cuando la consulta
      # de disponibilidad de perfil en pw-dump ya decía "yes". Un segundo
      # intento inmediato (llamado a mano) sí lo encontraba. Mismo patrón
      # de reintento corto que switch_audio_profile(), por la misma razón:
      # más robusto que asumir "no hay match" cuando en realidad es
      # "todavía no asentó".
      id=""
      for _ in 1 2 3 4; do
        id=$("$WPCTL" status 2>/dev/null | awk -v pat="$1" '
          /Sinks:/{f=1; next}
          /Sources:/{f=0}
          f && tolower($0) ~ tolower(pat) {
            for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+\.$/) { print substr($i,1,length($i)-1); exit }
          }
        ')
        [ -n "$id" ] && break
        sleep 0.3
      done
      [ -n "$id" ] && "$WPCTL" set-default "$id"
    }

    find_audio_profile() {
      # $1=nombre de perfil preferido (duplex, con input) $2=fallback (solo output)
      # Busca en TODOS los Audio/Device de pw-dump (no asume que es la
      # tarjeta 47 — otro hardware podría enumerar distinto) el primero
      # cuyo EnumProfile tenga $1 o $2 con available="yes", prefiriendo $1.
      # Devuelve "<device_id> <profile_index>" o nada si no encontró nada.
      "$PWDUMP" 2>/dev/null | "$JQ" -r --arg pref "$1" --arg fallback "$2" '
        [ .[] | select(.info.props["media.class"]? == "Audio/Device")
          | . as $d
          | ($d.info.params.EnumProfile // [])[]
          | select(.available == "yes")
          | select(.name == $pref or .name == $fallback)
          | {device: $d.id, index: .index, name: .name}
        ]
        | sort_by(.name != $pref)
        | .[0]
        | if . then "\(.device) \(.index)" else empty end
      '
    }

    switch_audio_profile() {
      # $1 = "hdmi" | "laptop" — cambia el PERFIL de la tarjeta ALSA antes
      # de que exista ningún sink que buscar (ver comentario largo arriba,
      # follow-up 21). No falla si no encuentra un perfil que matchee — el
      # audio simplemente se queda como estaba, igual que
      # set_default_sink_matching.
      if [ "$1" = "hdmi" ]; then
        pref="output:hdmi-stereo+input:analog-stereo"; fallback="output:hdmi-stereo"
      else
        pref="output:analog-stereo+input:analog-stereo"; fallback="output:analog-stereo"
      fi
      # Reintentos — causa raíz real encontrada en vivo (reproducida 3/3
      # veces, medida con precisión): la disponibilidad del perfil de
      # audio HDMI en PipeWire/ALSA (api.acp) sigue al ESTADO DEL LINK DE
      # VIDEO HDMI, no es independiente. Confirmado midiendo con `date`:
      # tras re-habilitar el output de video HDMI-A-1 con `hl.monitor()`,
      # `pw-dump` siguió reportando "output:hdmi-stereo+..." como
      # available="no" durante ~1.5s consistentes (1.52s/1.49s/1.52s en
      # tres corridas) antes de pasar a "yes" — el audio digital viaja
      # sobre el mismo cable/enlace que el video (ELD vía DRM/KMS), así
      # que el jack-detect de audio tiene que esperar a que el link de
      # video termine de re-negociarse. Esto es DISTINTO de (y más lento
      # que) la sospecha original de "la tarjeta ALSA se reabre al cambiar
      # de perfil" — importa sobre todo en `extend`/`mirror`/`hdmi-only`
      # cuando el output de video HDMI-A-1 venía de estar apagado (p.ej.
      # viniendo de `laptop-only`). Presupuesto de reintento
      # dimensionado con margen real sobre la medición de arriba, no a
      # ojo: 12 intentos x 0.3s = 3.6s tope (solo se paga completo si de
      # verdad no hay perfil disponible — sale del loop apenas encuentra
      # uno, así que el caso común con el link ya estable no se retrasa).
      result=""
      for _ in $(seq 1 12); do
        result=$(find_audio_profile "$pref" "$fallback")
        [ -n "$result" ] && break
        sleep 0.3
      done
      [ -z "$result" ] && return 0
      "$WPCTL" set-profile ''${result% *} ''${result#* }
      # Da tiempo a que WirePlumber cree/promueva el sink nuevo tras el
      # cambio de perfil antes de que set_default_sink_matching intente
      # encontrarlo — confirmado en vivo que sin esta espera corta el
      # primer `wpctl status` inmediatamente después puede no listar
      # todavía el sink nuevo.
      sleep 0.5
    }

    case "$MODE" in
      status)
        if [ -n "$HDMI_NAME" ]; then
          echo "{\"connected\":true,\"name\":\"$HDMI_NAME\"}"
        else
          echo "{\"connected\":false,\"name\":null}"
        fi
        ;;
      extend)
        [ -z "$HDMI_NAME" ] && exit 0
        hl_monitor "eDP-1" "1366x768@60" "0x0" 1
        hl_monitor "$HDMI_NAME" "preferred" "auto" 1
        switch_audio_profile "hdmi"
        set_default_sink_matching "hdmi"
        ;;
      mirror)
        [ -z "$HDMI_NAME" ] && exit 0
        hl_monitor "eDP-1" "1366x768@60" "0x0" 1
        # $6="eDP-1" -> campo `mirror`, no position="mirror,eDP-1" (ver
        # comentario en hl_monitor arriba, esa sintaxis clásica también
        # falla acá).
        hl_monitor "$HDMI_NAME" "preferred" "0x0" 1 false "eDP-1"
        switch_audio_profile "hdmi"
        set_default_sink_matching "hdmi"
        ;;
      hdmi-only)
        [ -z "$HDMI_NAME" ] && exit 0
        hl_monitor "$HDMI_NAME" "preferred" "0x0" 1
        # eDP-1 apagado: hl.monitor NO acepta mode="disable"/position=""
        # (ver comentario en hl_monitor arriba) — hay que pasar un
        # mode/position válidos igual (los últimos conocidos-buenos) junto
        # con disabled=true, que es el campo que realmente apaga el output.
        hl_monitor "eDP-1" "1366x768@60" "0x0" 1 true
        switch_audio_profile "hdmi"
        set_default_sink_matching "hdmi"
        ;;
      laptop-only)
        # ORDEN IMPORTA — bug real encontrado en vivo: si se apaga HDMI
        # ANTES de prender eDP-1, y eDP-1 ya venía apagado (p.ej. viniendo
        # de hdmi-only), hay una ventana donde CERO monitores están
        # habilitados a la vez. Confirmado en vivo que Hyprland entra en
        # un estado del que `hl.monitor({disabled=false})` YA NO puede
        # sacarlo por sí solo después — hyprctl seguía devolviendo "ok"
        # pero el monitor se quedaba "disabled":true para siempre, ambos
        # outputs a la vez, pantalla del laptop literalmente apagada.
        # Recuperado en esa prueba solo con `hyprctl reload` (fuerza
        # releer monitors.lua desde cero). Fix: SIEMPRE prender el output
        # que va a quedar activo ANTES de apagar el que se va — mismo
        # orden que ya usaba hdmi-only (por eso ese caso nunca mostró el
        # bug al probarlo). Nunca debe haber un instante con cero
        # monitores habilitados.
        hl_monitor "eDP-1" "1366x768@60" "0x0" 1
        [ -n "$HDMI_NAME" ] && hl_monitor "$HDMI_NAME" "preferred" "auto" 1 true
        switch_audio_profile "laptop"
        set_default_sink_matching "built-in"
        ;;
      *)
        echo "Uso: hdmi-control [status|extend|mirror|hdmi-only|laptop-only]" >&2
        exit 1
        ;;
    esac
  '';

  nixfm-fileops = pkgs.writeShellScriptBin "nixfm-fileops" ''
    CP=${pkgs.coreutils}/bin/cp
    MV=${pkgs.coreutils}/bin/mv
    RM=${pkgs.coreutils}/bin/rm
    MKDIR=${pkgs.coreutils}/bin/mkdir
    DATE=${pkgs.coreutils}/bin/date
    BASENAME=${pkgs.coreutils}/bin/basename
    STAT=${pkgs.coreutils}/bin/stat
    JQ=${pkgs.jq}/bin/jq
    MODE="$1"; shift || true

    case "$MODE" in
      copy)
        "$CP" -r -- "$1" "$2"
        ;;
      move)
        "$MV" -- "$1" "$2"
        ;;
      mkdir)
        "$MKDIR" -p -- "$1"
        ;;
      delete)
        "$RM" -rf -- "$1"
        ;;
      trash)
        # Implementación directa del freedesktop.org Trash spec — ni
        # kioclient ni ktrash6 sirven para esto (ver plan §1.6: ktrash6
        # solo vacía/restaura, su propio --help remite a kioclient, que no
        # existe acá). Spec real: mover el archivo a
        # $XDG_DATA_HOME/Trash/files/ + escribir un .trashinfo hermano en
        # Trash/info/ con la ruta original (percent-encoded) y la fecha.
        SRC="$1"
        [ -e "$SRC" ] || { echo "no existe: $SRC" >&2; exit 1; }

        DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"
        TRASH_DIR="$DATA_HOME/Trash"
        "$MKDIR" -p "$TRASH_DIR/files" "$TRASH_DIR/info"

        # El spec solo garantiza mover-sin-copiar (rename() atómico) DENTRO
        # del mismo dispositivo — cruzar dispositivos necesita un
        # $topdir/.Trash-$uid aparte en la raíz de ESE punto de montaje,
        # que v1 no implementa (ver plan §5.1/§7). Se corta acá explícito
        # con un código de salida distinto (2) en vez de silenciosamente
        # caer a un delete permanente que el usuario no pidió — la UI
        # decide qué mostrar, no este script.
        SRC_DEV=$("$STAT" -c %d "$SRC")
        TRASH_DEV=$("$STAT" -c %d "$TRASH_DIR")
        if [ "$SRC_DEV" != "$TRASH_DEV" ]; then
          echo "cross-device, no soportado en v1: $SRC" >&2
          exit 2
        fi

        NAME=$("$BASENAME" -- "$SRC")
        DEST="$TRASH_DIR/files/$NAME"
        INFO="$TRASH_DIR/info/$NAME.trashinfo"
        i=1
        while [ -e "$DEST" ] || [ -e "$INFO" ]; do
          DEST="$TRASH_DIR/files/$NAME.$i"
          INFO="$TRASH_DIR/info/$NAME.$i.trashinfo"
          i=$((i + 1))
        done

        # Path= del spec: percent-encoded, ruta absoluta original. @uri de
        # jq hace el percent-encoding real (RFC 3986) sin agregar una
        # dependencia nueva (jq ya es dependencia de scripts en este
        # archivo).
        ENCODED=$(printf '%s' "$SRC" | "$JQ" -sRr @uri)
        DELETION_DATE=$("$DATE" '+%Y-%m-%dT%H:%M:%S')

        printf '[Trash Info]\nPath=%s\nDeletionDate=%s\n' "$ENCODED" "$DELETION_DATE" > "$INFO"
        "$MV" -- "$SRC" "$DEST"
        ;;
      *)
        echo "Uso: nixfm-fileops [copy|move|mkdir|delete|trash] ..." >&2
        exit 1
        ;;
    esac
  '';
}
