{ config, pkgs, inputs, lib, ... }:

let
  mis-scripts = import ./scripts.nix { inherit pkgs; };

  # Hito 005 — File manager Kirigami+KIO (ver NIXOS_FILEMANAGER_HITO05_PLAN.md
  # §6, migración final). Reemplaza a Dolphin — ver keybinds.lua
  # (fileManager), xdg.desktopEntries.nixfm y xdg.mimeApps más abajo.
  nixfm = import ./filemanager.nix { inherit pkgs; };

  # Hito 004 follow-up 19 — causa raíz real del bug "Dolphin no abre
  # archivos al hacer click": ningún paquete de este sistema (no corremos
  # Plasma/GNOME/XFCE) instala /etc/xdg/menus/applications.menu, el
  # archivo base de la XDG Desktop Menu Specification que kbuildsycoca6
  # necesita para indexar CUALQUIER aplicación (confirmado en vivo vía
  # journalctl — ver modules/kde-integration/applications.menu para el
  # detalle completo de la investigación). Se empaqueta acá como una
  # derivación mínima en vez de buscar un paquete nixpkgs que lo traiga —
  # el archivo real (gnome-menus, plasma-workspace) viene siempre atado a
  # una DE completa, exactamente lo que este sistema evita a propósito.
  # Re-confirmado real (no solo un resto de Dolphin) en la migración
  # final a nixfm (Hito 005 §6/§12): KIO::OpenUrlJob, que
  # FileOperations::openFile() de nixfm usa para abrir archivos,
  # depende del mismo índice kbuildsycoca6/KService que este archivo
  # arregla — sigue haciendo falta con Dolphin fuera del todo.
  applicationsMenu = pkgs.runCommand "applications-menu" { } ''
    mkdir -p $out/etc/xdg/menus
    cp ${../../modules/kde-integration/applications.menu} $out/etc/xdg/menus/applications.menu
  '';
in
{
  home.username = "jerimy";
  home.homeDirectory = "/home/jerimy";

  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    TERMINAL = "foot";
    TERM = "foot";
    # QuickShell corre sobre Qt6 en un escritorio GTK — qt6ct evita que sus
    # ventanas (si las hubiera) se vean ajenas a la paleta del sistema.
    # CONFIRMADO además (no solo hipotético) como dependencia real de
    # nixfm (Hito 005 §12): su tema de íconos activo (icon_theme=
    # Papirus-Dark, ver modules/kde-integration/qt6ct.conf) es lo que
    # resuelve los íconos del toolbar de nixfm — investigado en vivo esa
    # ronda comparando contra qt6ct.conf, no es una suposición.
    QT_QPA_PLATFORMTHEME = "qt6ct";
    # QT_STYLE_OVERRIDE=kvantum (Hito 004 follow-up 18) se quitó en la
    # migración final a nixfm (Hito 005 §6/§12): Kvantum es un QStyle
    # plugin, solo afecta apps QWidget — Dolphin era la única en este
    # sistema. nixfm es QML puro y fuerza su propio style
    # (QQuickStyle::setStyle("org.kde.desktop") en main.cpp, ver ese
    # archivo), un mecanismo completamente distinto que Kvantum nunca
    # tocó. Auditado el resto de home.packages: ninguna otra app QWidget/
    # Qt queda en el sistema (spotify/discord/firefox son Electron/GTK,
    # pavucontrol/blueman/qalculate-gtk son GTK) — sin ningún consumidor,
    # tanto la variable como el paquete/tema de Kvantum se retiran del
    # todo (ver más abajo).
  };

  # --- PAQUETES (LOS OBREROS) ---
  home.packages = with pkgs; [
    # 1. ENTORNO GRÁFICO Y TEMAS
    awww
    waypaper
    hyprlock
    hypridle
    hyprpicker
    networkmanagerapplet
    blueman
    gnome-themes-extra

    # QuickShell (Hito 004): motor de shell QML/Qt — reemplazó waybar
    # (paquete + modules/waybar/ eliminados) y swaync/dunst (NotifServer.qml
    # es el único servidor de notificaciones ahora).
    quickshell
    kdePackages.qt6ct
	
    # Dolphin SE RETIRÓ (Hito 005 §6 paso 4 — migración final a nixfm,
    # ver docs/NIXOS_ARCHITECTURE_HITO_005.md §12). Lo que queda acá es
    # KIO y lo que nixfm mismo necesita, confirmado por auditoría real
    # (§12), no supuesto: kio-extras trae el protocolo "network:/" que
    # alimenta el grupo "Red" del sidebar de nixfm (los .desktop de
    # remoteview — sin esto esa sección del sidebar queda vacía/rota);
    # kimageformats nunca dependió de Dolphin (lo usa imv, ver plan §6);
    # kservice es dependencia transitiva de kio (cualquier app que
    # linkee KIO se lo trae, nixfm incluido); applicationsMenu arregla
    # kbuildsycoca6 para CUALQUIER .desktop del sistema, incluido el
    # propio KIO::OpenUrlJob que usa FileOperations::openFile() de
    # nixfm. ark se queda como app standalone (extraer/comprimir
    # manual) — nixfm no integra esa función en v1, decisión de v2
    # explícitamente diferida en el plan (§6, punto 1). ffmpegthumbs/
    # kdegraphics-thumbnailers (miniaturas de video/PDF) SÍ eran
    # específicos de Dolphin — nixfm no genera miniaturas en v1 (fuera
    # de scope, ver plan §5.2, todos los íconos de este hito son íconos
    # de sistema por mimetype, nunca una miniatura real del contenido,
    # confirmado en cada screenshot de este hito) — retirados.
    kdePackages.kio-extras
    kdePackages.ark
    kdePackages.kimageformats
    kdePackages.kservice
    applicationsMenu
    papirus-icon-theme
    imv

    # Hito 005 (ver NIXOS_FILEMANAGER_HITO05_PLAN.md) — file manager
    # Kirigami+KIO. Migración final completa (§6): es el file manager
    # default del sistema (xdg.mimeApps/fileManager de keybinds.lua
    # apuntan acá) — Dolphin ya no está instalado, sin fallback.
    nixfm
    # Paso 4: operaciones de archivo (copy/move/mkdir/delete/trash) que
    # FileOperations.cpp invoca por nombre vía QProcess — tiene que estar
    # en el PATH real del usuario, igual que hdmi-control/workspace-wallpaper.
    mis-scripts.nixfm-fileops

    # 2. DEPENDENCIAS DE SCRIPTS
    jq
    imagemagick
    libnotify
    cliphist
    wl-clipboard
    grim
    slurp
    wlsunset
    hyprshade
    grimblast         

    # 3. MULTIMEDIA Y CONTROL
    pavucontrol
    playerctl
    brightnessctl

    # 4. HERRAMIENTAS HACKER / PRO (Terminal Moderna)
    fastfetch
    btop
    ripgrep
    fd
    fzf
    eza
    bat
    zoxide
    tldr

    # 5. UTILIDADES BASE
    unzip
    gcc
	gnumake
    wget
    direnv
    nix-direnv
    vivid
	tree-sitter
	gnutar
	curl

    # 6. APLICACIONES
    foot
	papirus-folders
    firefox
    neovim
    rofimoji
    wtype
    qalculate-gtk
    # wl-clip-persist eliminado en el "dead package audit": es un demonio
    # (mantiene vivo el portapapeles después de que la app origen cierra),
    # cero referencias en el repo y — a diferencia de cliphist/wl-paste,
    # que sí están en autostart.lua §5 — nunca se lanza en ningún lado, ni
    # en autostart.lua ni en ningún script. Instalado, nunca corrido.
    spotify
    discord
    
    # 7. DESARROLLO
    nodejs_22
    claude-code

    # 8. FUENTES E ICONOS
    nerd-fonts.jetbrains-mono
    font-awesome

    psmisc
    matugen
    glib
    bc 
    findutils
    pywal

    # 9. JUEGOS Y VIDEOLLAMADAS
    prismlauncher
    zoom-us

    # 10. REDES Y SEGURIDAD
    aircrack-ng
    termshark
    rsync
    
    # 11. SCRIPTS NATIVOS DE NIX
    mis-scripts.hypr-gamemode
    mis-scripts.set-wallpaper
    mis-scripts.workspace-wallpaper
	mis-scripts.sidepad-toggle
	mis-scripts.battery-notify
    mis-scripts.nm-applet-ctl
    mis-scripts.app-toggle
    mis-scripts.system-stats
    mis-scripts.hdmi-control
    wlr-randr
  ];

  # Hito 004 follow-up 19 (pedido explícito: "figure out how to trigger
  # [kbuildsycoca6] declaratively on activation"). La causa raíz real del
  # bug de Dolphin resultó ser applications.menu faltante (ver
  # `applicationsMenu` arriba), no la cache en sí — pero de todos modos es
  # la práctica correcta en cualquier distro KDE: cada vez que cambia el
  # set de paquetes/.desktop instalados (cualquier `nixos-rebuild switch`
  # que toque home.packages), la cache de ksycoca debería refrescarse
  # proactivamente en vez de depender del rebuild perezoso que Dolphin
  # dispara por su cuenta al notar que está desactualizada. `entryAfter
  # ["writeBoundary"]` asegura que corra DESPUÉS de que mimeapps.list/
  # kdeglobals/applications.menu ya estén escritos en su ubicación final.
  home.activation.rebuildKSycoca = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental
  '';

  systemd.user.services.battery-notify = {
    Unit = {
      Description = "Notificación de batería baja";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${mis-scripts.battery-notify}/bin/battery-notify";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  xdg.configFile = {
    "nvim".source = inputs.nvim-config;
    "quickshell".source = ../../modules/quickshell;
    "hypr".source = ../../modules/hyprland;
    "rofi/rofi-border.rasi".source = ../../modules/rofi/rofi-border.rasi;
    "rofi/glass-window.rasi".source = ../../modules/rofi/glass-window.rasi;
    "rofi/cheatsheet.rasi".source = ../../modules/rofi/cheatsheet.rasi;
    "rofi/projects.rasi".source = ../../modules/rofi/projects.rasi;
    "matugen".source = ../../modules/matugen;
    "gtk-3.0/gtk.css".source = ../../modules/gtk/gtk.css;
    "gtk-global/base.css".source = ../../modules/gtk-global/base.css;
    # Hito 005 §6/§12 (migración final) — modules/kvantum/ se renombró a
    # modules/kde-integration/ y perdió Kvantum/NixCyber/ por completo
    # (el tema de Kvantum en sí, el "Kvantum/kvantum.kvconfig" selector
    # de tema, y las líneas de este bloque que los instalaban) — auditado
    # en vivo (ver home.sessionVariables arriba y docs §12): ninguna app
    # QWidget queda en el sistema una vez que Dolphin se retire (paso 4),
    # nixfm nunca usó Kvantum (QML puro, style propio). kdeglobals y
    # qt6ct.conf SÍ siguen — confirmados como dependencias reales de
    # nixfm mismo, no solo restos de Dolphin, ver el comentario de cada
    # archivo para el detalle real de qué necesita cada uno.
    "kdeglobals".source = ../../modules/kde-integration/kdeglobals;
    "qt6ct/qt6ct.conf".source = ../../modules/kde-integration/qt6ct.conf;
  };
  
  dconf.settings = {
     "org/gnome/desktop/wm/preferences" = {
     button-layout = "close,minimize,maximize:";
    };
  };

  # --- CONFIGURACIÓN DE TERMINAL PREDETERMINADA PARA XFCE ---
  xdg.configFile."xfce4/helpers.rc".text = ''
     TerminalEmulator=foot
  '';

  # --- APLICACIONES POR DEFECTO (LA SOLUCIÓN A THUNAR) ---
  xdg = {
    enable = true;
    
    # 1. Creamos un acceso directo "falso" que obliga a usar Foot
    desktopEntries.nvim-foot = {
      name = "Neovim (Foot)";
      genericName = "Text Editor";
      exec = "foot -e nvim %F"; # Aquí está la magia: Abre foot y dentro ejecuta nvim
      terminal = false; # Se pone false porque nosotros ya estamos llamando a la terminal manualmente arriba
      categories = [ "Development" "Utility" "TextEditor" ];
      mimeType = [
        "text/plain"
        "text/markdown"
        "text/x-c"
        "text/x-c++"
        "text/x-c++src"
        "text/x-c++hdr"
        "text/x-csrc"
        "text/x-chdr"
        "text/x-python"
        "text/x-java"
        "text/x-go"
        "text/x-rust"
        "text/x-javascript"
        "text/x-typescript"
        "text/x-html"
        "text/x-css"
        "application/json"
        "application/xml"
        "application/x-shellscript"
        "application/x-yaml"
        "text/x-cmake"
        "text/x-nix"
      ];
	};

    # 1b. Hito 005 §6 (migración final) — nixfm no traía ningún .desktop
    # propio (el CMakeLists.txt de modules/filemanager solo instala el
    # binario, ver install(TARGETS...) ahí — confirmado, no hay ningún
    # install(FILES *.desktop) en todo el archivo). Sin esto no hay forma
    # de que xdg.mimeApps lo referencie por id, ni de que aparezca como
    # una app normal (rofi drun, "Abrir con", etc.), solo un binario
    # crudo. Mismo mecanismo declarativo que nvim-foot arriba, no un
    # .desktop escrito a mano en /etc.
    desktopEntries.nixfm = {
      name = "nixfm";
      genericName = "File Manager";
      comment = "Explorador de archivos Kirigami + KIO";
      exec = "nixfm %u";
      # system-file-manager: ícono genérico freedesktop, confirmado
      # presente en Papirus-Dark (el icon theme activo, ver qt6ct.conf)
      # — nixfm no tiene todavía un ícono propio diseñado.
      icon = "system-file-manager";
      terminal = false;
      categories = [ "Qt" "System" "FileTools" "FileManager" ];
      mimeType = [ "inode/directory" ];
    };

    # 2. Le decimos al sistema qué usar para cada archivo
    mimeApps = {
      enable = true;
      defaultApplications = {
        # Todo tipo de código o texto a Neovim en Foot
        "text/plain" = "nvim-foot.desktop";
        "text/markdown" = "nvim-foot.desktop";
        "text/x-c" = "nvim-foot.desktop";
        "text/x-c++" = "nvim-foot.desktop";
        "text/x-c++src" = "nvim-foot.desktop";
        "text/x-c++hdr" = "nvim-foot.desktop";
        "text/x-csrc" = "nvim-foot.desktop";
        "text/x-chdr" = "nvim-foot.desktop";
        "text/x-python" = "nvim-foot.desktop";
        "text/x-java" = "nvim-foot.desktop";
        "text/x-go" = "nvim-foot.desktop";
        "text/x-rust" = "nvim-foot.desktop";
        "text/x-javascript" = "nvim-foot.desktop";
        "text/x-typescript" = "nvim-foot.desktop";
        "text/x-html" = "nvim-foot.desktop";
        "text/x-css" = "nvim-foot.desktop";
        "application/json" = "nvim-foot.desktop";
        "application/xml" = "nvim-foot.desktop";
        "application/x-shellscript" = "nvim-foot.desktop";
        "application/x-yaml" = "nvim-foot.desktop";
        "text/x-cmake" = "nvim-foot.desktop";
        "text/x-nix" = "nvim-foot.desktop";

        # Imágenes estrictamente a IMV
        "image/png" = "imv.desktop";
        "image/jpeg" = "imv.desktop";
        "image/jpg" = "imv.desktop";
        "image/gif" = "imv.desktop";
        "image/webp" = "imv.desktop";
        "image/svg+xml" = "imv.desktop";

        # Hito 005 §6 (migración final: Dolphin -> nixfm). inode/directory
        # es el mimetype que xdg-open y otras apps consultan para "abrir
        # esta carpeta con el explorador de archivos" — apunta al
        # xdg.desktopEntries.nixfm declarado arriba (mismo mecanismo que
        # ya usa nvim-foot.desktop/imv.desktop en este mismo bloque, no
        # un .desktop escrito a mano).
        "inode/directory" = "nixfm.desktop";
      };
    };
  };

  # --- GIT ---
  programs.git = {
    enable = true;
    extraConfig = {
      user.name = "jerimy";
      user.email = "jerimy.sandoval@utec.edu.pe";
      init.defaultBranch = "main";
    };
  };

  # --- FOOT TERMINAL ---
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=11";
        font-bold = "JetBrainsMono Nerd Font:style=Bold:size=11";
        font-italic = "JetBrainsMono Nerd Font:style=Italic:size=11";
        font-bold-italic = "JetBrainsMono Nerd Font:style=Bold Italic:size=11";
        pad = "12x12";
        selection-target = "clipboard";
      };
      cursor = {
        style = "beam";
        blink = "yes";
      };
      "colors-dark" = {
        alpha = "0.85";
        foreground = "cdd6f4";
        background = "1e1e2e";
        regular0 = "45475a"; # black
        regular1 = "f38ba8"; # red
        regular2 = "a6e3a1"; # green
        regular3 = "f9e2af"; # yellow
        regular4 = "89b4fa"; # blue
        regular5 = "f5c2e7"; # magenta
        regular6 = "94e2d5"; # cyan
        regular7 = "bac2de"; # white
      };
    };
  };
  
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    plugins = with pkgs; [ rofi-calc ];
  };

  # --- ZSH + POWERLEVEL10K ---
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    shellAliases = {
      ls = "eza --icons";
      ll = "eza -l --icons";
      cat = "bat";
      cd = "z";
      nix-rebuild-fast = "sudo nixos-rebuild switch --flake ~/system/nixos/#laptop";
    };

    initContent = lib.mkMerge [
      (lib.mkOrder 100 ''
        if [[ "$(tty)" == /dev/tty[0-9]* ]]; then 
          exec bash
          fastfetch
        fi 
      '')
      (lib.mkOrder 1000 ''
        source ~/.p10k.zsh 
        eval "$(zoxide init zsh)"

        export LS_COLORS="$(vivid generate lava)"
        export EZA_COLORS="$(vivid generate lava)"
        typeset -A ZSH_HIGHLIGHT_STYLES 
        ZSH_HIGHLIGHT_STYLES[command]='fg=cyan,bold' 
        ZSH_HIGHLIGHT_STYLES[alias]='fg=magenta,bold' 
        ZSH_HIGHLIGHT_STYLES[builtin]='fg=cyan,bold' 
        ZSH_HIGHLIGHT_STYLES[function]='fg=blue,bold'
      '')
    ];
    
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];
  };

  # --- MEJORAS GTK ---
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
	iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  home.stateVersion = "24.11";
  
  # --- CONFIGURACIÓN DEL CURSOR (MOUSE) ---
  home.pointerCursor = {
    gtk.enable = true;
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
  };

  programs.home-manager.enable = true;
}
