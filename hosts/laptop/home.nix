{ config, pkgs, inputs, lib, ... }:

let
  mis-scripts = import ./scripts.nix { inherit pkgs; };

  # Hito 005 — File manager Kirigami+KIO (ver NIXOS_FILEMANAGER_HITO05_PLAN.md).
  # Fase 2, paso 1: scaffold desnudo, sin funcionalidad de archivos todavía
  # (Dolphin sigue siendo el file manager activo — ver keybinds.lua).
  nixfm = import ./filemanager.nix { inherit pkgs; };

  # Hito 004 follow-up 19 — causa raíz real del bug "Dolphin no abre
  # archivos al hacer click": ningún paquete de este sistema (no corremos
  # Plasma/GNOME/XFCE) instala /etc/xdg/menus/applications.menu, el
  # archivo base de la XDG Desktop Menu Specification que kbuildsycoca6
  # necesita para indexar CUALQUIER aplicación (confirmado en vivo vía
  # journalctl — ver modules/kvantum/applications.menu para el detalle
  # completo de la investigación). Se empaqueta acá como una derivación
  # mínima en vez de buscar un paquete nixpkgs que lo traiga — el archivo
  # real (gnome-menus, plasma-workspace) viene siempre atado a una DE
  # completa, exactamente lo que este sistema evita a propósito.
  applicationsMenu = pkgs.runCommand "applications-menu" { } ''
    mkdir -p $out/etc/xdg/menus
    cp ${../../modules/kvantum/applications.menu} $out/etc/xdg/menus/applications.menu
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
    QT_QPA_PLATFORMTHEME = "qt6ct";
    # Hito 004 follow-up 18 (migración Thunar -> Dolphin+Kvantum): Kvantum
    # es el motor de estilo real (paleta a medida de Theme.qml, ver
    # modules/kvantum/NixCyber/), pero Qt solo lo aplica si algo fuerza el
    # style plugin — sin esto, Dolphin renderiza con el estilo Qt genérico
    # (Fusion) e ignora Kvantum por completo aunque esté instalado y
    # configurado.
    QT_STYLE_OVERRIDE = "kvantum";
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
	
    # Dolphin + Kvantum (Hito 004 follow-up 18 — antes Thunar, ver
    # NIXOS_ARCHITECTURE_HITO_004.md). kio-extras/ffmpegthumbs/
    # kdegraphics-thumbnailers son el equivalente KIO de lo que tumbler+
    # ffmpegthumbnailer+webp-pixbuf-loader+poppler_gi hacían para Thunar
    # (miniaturas de video/imagen/pdf) — Dolphin no usa el stack de
    # miniaturas de GTK (tumbler), tiene el suyo propio vía KIO. ark
    # reemplaza thunar-archive-plugin (extraer/comprimir desde el
    # explorador). kimageformats amplía los formatos de imagen que Qt
    # entiende nativamente (necesario para que el visor integrado de
    # Dolphin abra más que jpg/png).
    kdePackages.dolphin
    kdePackages.kio-extras
    kdePackages.ark
    kdePackages.ffmpegthumbs
    kdePackages.kdegraphics-thumbnailers
    kdePackages.kimageformats
    kdePackages.qtstyleplugin-kvantum
    kdePackages.kservice
    applicationsMenu
    webp-pixbuf-loader
    poppler_gi
    papirus-icon-theme
    imv

    # Hito 005 (ver NIXOS_FILEMANAGER_HITO05_PLAN.md) — file manager
    # Kirigami+KIO en construcción, instalado en paralelo a Dolphin para
    # poder probarlo en vivo sin tocar el explorador activo todavía.
    # NO reemplaza a Dolphin (xdg.mimeApps/fileManager de keybinds.lua
    # siguen apuntando a Dolphin) hasta que el plan lo apruebe (§6).
    nixfm

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
    wl-clip-persist
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
    # Hito 004 follow-up 18: Thunar -> Dolphin+Kvantum. El tema vive en
    # ~/.config/Kvantum/<nombre>/ (una carpeta por tema, convención de
    # Kvantum) — acá solo se instala el nuestro (NixCyber), no se toca
    # ningún tema de fábrica de qtstyleplugin-kvantum. kvantum.kvconfig es
    # el selector global: le dice a Kvantum qué carpeta usar.
    "Kvantum/NixCyber/NixCyber.kvconfig".source = ../../modules/kvantum/NixCyber/NixCyber.kvconfig;
    "Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=NixCyber
    '';
    # Encontrado en vivo probando esto: Kvantum solo (el style plugin de
    # Qt) no alcanza para que Dolphin calce con Theme.qml — las apps KDE
    # pintan su chrome nativo (sidebar, selección, header de columnas) vía
    # KColorScheme (kdeglobals), una capa PARALELA al QPalette que expone
    # el estilo Qt. Sin este archivo, el resultado medido fue gris oscuro
    # genérico, no nuestra paleta — ver el archivo para el detalle de qué
    # se probó y qué quedó pendiente (la vista de detalles/lista no calca
    # el fondo oscuro en todos los casos, gap real no resuelto esta ronda).
    "kdeglobals".source = ../../modules/kvantum/kdeglobals;
    # Hito 004 follow-up 20: no existía NINGÚN qt6ct.conf pese a que
    # QT_QPA_PLATFORMTHEME=qt6ct está seteado (confirmado en vivo con
    # `ls ~/.config/qt6ct/` -> "No such file or directory") — sin config,
    # qt6ct no tiene nada declarado y Qt cae a sus defaults compilados en
    # vez de a lo que decimos acá. Ver el archivo para más detalle.
    "qt6ct/qt6ct.conf".source = ../../modules/kvantum/qt6ct.conf;
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

        # Hito 004 follow-up 18: Thunar -> Dolphin. inode/directory es el
        # mimetype que xdg-open y otras apps consultan para "abrir esta
        # carpeta con el explorador de archivos" — sin esto, quedaría sin
        # default explícito tras sacar Thunar.
        "inode/directory" = "org.kde.dolphin.desktop";
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
