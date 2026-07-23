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
    rofi
    swww
    waypaper
    wlogout
    hyprlock
    hypridle
    hyprpicker
    dunst
    networkmanagerapplet
    blueman
    
    # Thunar y Miniaturas
    thunar
    tumbler
    thunar-archive-plugin
    ffmpegthumbnailer
    webp-pixbuf-loader
    poppler_gi
    papirus-icon-theme

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
    wget
    direnv
    nix-direnv
    vivid

    # 6. APLICACIONES
    foot
    firefox
    neovim
    rofimoji
    wtype
    rofi-calc
    qalculate-gtk
    wl-clip-persist
    
    # 7. DESARROLLO
    nodejs_22

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
  ];

  # --- ENLACES DE CONFIGURACIÓN (LOS PLANOS) ---
  xdg.configFile = {
    "nvim".source = inputs.nvim-config;
    "waybar".source = ../../modules/waybar;
    "hypr".source = ../../modules/hyprland;
    "ml4w".source = ../../modules/ml4w;
    "rofi/config.rasi".source = ../../modules/ml4w/settings/rofi-border.rasi;
    "rofi/glass-window.rasi".source = ../../modules/ml4w/settings/glass-window.rasi;
    "rofi/cheatsheet.rasi".source = ../../modules/ml4w/settings/cheatsheet.rasi;
    "wlogout".source = ../../modules/wlogout;
    "matugen".source = ../../modules/matugen;
    
    "gtk-3.0/gtk.css".source = ../../modules/gtk/gtk.css;
  };

  # --- CONFIGURACIÓN DE TERMINAL PREDETERMINADA PARA XFCE ---
  xdg.configFile."xfce4/helpers.rc".text = ''
     TerminalEmulator=foot
  '';

  # --- GIT ---
  programs.git = {
    enable = true;
    extraConfig = {
      user.name = "jerimy";
      user.email = "jerimy.sandoval@utec.edu.pe";
      init.defaultBranch = "main";
    };
  };

  # --- FOOT TERMINAL (Corregido) ---
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
      claude = "npx @anthropic-ai/claude-code";
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
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
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
