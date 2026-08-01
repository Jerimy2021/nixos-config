{ config, pkgs, inputs, lib, ... }:

let
  mis-scripts = import ./scripts.nix { inherit pkgs; };
in
{
  home.username = "jerimy";
  home.homeDirectory = "/home/jerimy";

  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    TERMINAL = "foot";
    TERM = "foot";
  };

  # --- PAQUETES (LOS OBREROS) ---
  home.packages = with pkgs; [
    # 1. ENTORNO GRÁFICO Y TEMAS
    waybar
    awww
    waypaper
    wlogout
    hyprlock
    hypridle
    hyprpicker
    dunst
    networkmanagerapplet
    blueman
    gnome-themes-extra
	
    # Thunar, Miniaturas y Visor de Imágenes
    thunar
    tumbler
    thunar-archive-plugin
    ffmpegthumbnailer
    webp-pixbuf-loader
    poppler_gi
    papirus-icon-theme
    imv

    # 2. DEPENDENCIAS DE SCRIPTS
    jq
    imagemagick
    libnotify
    cliphist
    wl-clipboard
    grim
    slurp
    swaynotificationcenter
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
	mis-scripts.sidepad-toggle
	mis-scripts.battery-notify
  ];

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
    "waybar".source = ../../modules/waybar;
    "hypr".source = ../../modules/hyprland;
    "ml4w".source = ../../modules/ml4w;
    "rofi/rofi-border.rasi".source = ../../modules/rofi/rofi-border.rasi;
    "rofi/glass-window.rasi".source = ../../modules/rofi/glass-window.rasi;
    "rofi/cheatsheet.rasi".source = ../../modules/rofi/cheatsheet.rasi;
    "rofi/projects.rasi".source = ../../modules/rofi/projects.rasi;
    "wlogout".source = ../../modules/wlogout;
    "matugen".source = ../../modules/matugen; 
    "gtk-3.0/gtk.css".source = ../../modules/gtk/gtk.css;
    "gtk-global/base.css".source = ../../modules/gtk-global/base.css;
    "thunar/thunar.css".source = ../../modules/thunar/thunar.css;
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

        export LS_COLORS="$(vivid generate modus-operandi)"
        export EZA_COLORS="$(vivid generate modus-operandi)"
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
