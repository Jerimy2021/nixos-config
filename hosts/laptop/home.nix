{ config, pkgs, inputs, ... }:

{
  home.username = "jerimy";
  home.homeDirectory = "/home/jerimy";

  # --- PAQUETES (LOS OBREROS) ---
  home.packages = with pkgs; [
    # 1. ENTRONO GRÁFICO (Core ML4W)
    waybar              # Barra de estado
    rofi                # Lanzador de aplicaciones
    swww                # Motor de fondo de pantalla
    waypaper            # Selector gráfico de fondos
    wlogout             # Menú de salida (Apagar/Reiniciar)
    hyprlock            # Bloqueo de pantalla
    hypridle            # Suspensión por inactividad
    hyprpicker          # Selector de color (Pipeta)
    dunst               # Sistema de notificaciones
    networkmanagerapplet # Icono de Wifi en la barra
    blueman             # Gestor de Bluetooth
    nautilus            # Explorador de archivos

    # 2. DEPENDENCIAS DE SCRIPTS (Vitales para que no se vea negro)
    jq                  # Procesador de datos (Sin esto, los scripts fallan)
    imagemagick         # Procesamiento de iconos e imágenes
    libnotify           # Para enviar notificaciones al sistema
    cliphist            # Historial del portapapeles
    wl-clipboard        # Copiar/Pegar en Wayland
    grim                # Herramienta de captura de pantalla
    slurp               # Herramienta de selección de área
    swaynotificationcenter # Centro de notificaciones alternativo
    wlsunset            # Filtro de luz azul (Noche)
    hyprshade           # Motor de shaders para hyprland
    grimblast           

    # 3. MULTIMEDIA Y CONTROL
    pavucontrol         # Control de volumen avanzado (GUI)
    playerctl           # Control de música (Play/Pause teclas)
    brightnessctl       # Control de brillo de pantalla

    # 4. HERRAMIENTAS HACKER / PRO (Terminal Moderna)
    fastfetch           # Información del sistema
    btop                # Monitor de recursos estilo Matrix
    ripgrep             # Buscador rápido (grep con esteroides)
    fd                  # Alternativa rápida a 'find'
    fzf                 # <--- PRO: Buscador borroso (Ctrl+R mejorado)
    eza                 # <--- PRO: Reemplazo de 'ls' con iconos y colores
    bat                 # <--- PRO: Reemplazo de 'cat' para leer código
    zoxide              # <--- PRO: Reemplazo de 'cd' que recuerda rutas
    tldr                # <--- PRO: Manuales simplificados (ej: 'tldr tar')

    # 5. UTILIDADES BASE
    unzip
    gcc
    wget
    direnv
    nix-direnv
    vivid

    # 6. APLICACIONES
    kitty
    firefox
    neovim
    
    # 7. DESARROLLO
    nodejs_22

    # 8. FUENTES E ICONOS
    nerd-fonts.jetbrains-mono # Fuente principal para código
    font-awesome              # Iconos extra para Waybar

    psmisc
    matugen
    glib

    bc 
    findutils
    pywal
    # 9. Mensajería

    #10. Games
    prismlauncher
    #11. Redes y seguridad (hacker mode)
    aircrack-ng
    termshark
    rsync
    
    # 12. Videollamadas
    zoom-us
  ];

  # --- ENLACES DE CONFIGURACIÓN (LOS PLANOS) ---
  xdg.configFile = {
    "nvim".source = inputs.nvim-config;
    "waybar".source = ../../modules/waybar;
    "hypr".source = ../../modules/hyprland;
    "ml4w".source = ../../modules/ml4w;
    "rofi/config.rasi".source = ../../modules/ml4w/settings/rofi-border.rasi;
	"matugen".source = ../../modules/matugen;
  };

  # --- CONFIGURACIÓN DE PROGRAMAS ---

  # Git
  programs.git = {
    enable = true;
    extraConfig = {
      user.name = "jerimy";
      user.email = "jerimy.sandoval@utec.edu.pe";
      init.defaultBranch = "main";
    };
  };

  # Kitty
  programs.kitty = {
    enable = true;
		#extraConfig = ''
		#include ~/.cache/wal/colors-kitty.conf
		#'';
	themeFile = "Dracula";
    settings = {
      font_family = "JetBrainsMono Nerd Font";
      bold_font = "JetBrainsMono Nerd Font Bold";
      italic_font = "JetBrainsMono Nerd Font Italic";
      bold_italic_font = "JetBrainsMono Nerd Font Bold Italic";
      font_size = 12.0;
      copy_to_clipboard = "yes";
      shell = "zsh";
      enable_audio_bell = false; 
      background_opacity = "0.32";
      dynamic_background_opacity = "yes";
    };
  };

  # Zsh + Powerlevel10k
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    # Alias para usar las herramientas modernas
    shellAliases = {
      ls = "eza --icons";        # Usar eza en lugar de ls
      ll = "eza -l --icons";     # Lista detallada
      cat = "bat";               # Usar bat en lugar de cat
      cd = "z";                  # Usar zoxide en lugar de cd
	  claude = "npx @anthropic-ai/claude-code"; # claude-code
      nix-rebuild-fast = "sudo nixos-rebuild switch --flake ~/system/nixos/#laptop"; # Alias para reconstruir el sistema con un comando corto
    };

     initContent = ''
        source ~/.p10k.zsh
        fastfetch 
        # Iniciar zoxide (cd inteligente)
        eval "$(zoxide init zsh)"
        
        # Configurar colores para ls y eza usando un tema armónico con el fondo claro
        export LS_COLORS="$(vivid generate modus-operandi)"
        export EZA_COLORS="$(vivid generate modus-operandi)"
        typeset -A ZSH_HIGHLIGHT_STYLES
        ZSH_HIGHLIGHT_STYLES[command]='fg=cyan,bold'       # Comandos base (ej: ls, cd, nvim)
        ZSH_HIGHLIGHT_STYLES[alias]='fg=magenta,bold'     # Tus alias personalizados
        ZSH_HIGHLIGHT_STYLES[builtin]='fg=cyan,bold'       # Comandos internos de zsh
        ZSH_HIGHLIGHT_STYLES[function]='fg=blue,bold'      # Funciones de shell
    '';
    
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];
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
      # x11.enable = true; # Si usas aplicaciones antiguas
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
  };
  programs.home-manager.enable = true;
}
