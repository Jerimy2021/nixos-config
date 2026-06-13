{ config, pkgs, inputs, ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix
    ];

  nixpkgs.config.allowUnfree = true;
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "laptop"; 
  networking.networkmanager.enable = true;

  # Timezone & Locale
  time.timeZone = "America/Lima"; # Asumo tu zona por tu contexto, ajusta si es necesario
  i18n.defaultLocale = "en_US.UTF-8";

  # --- HYPRLAND SYSTEM CONFIG ---
  programs.hyprland.enable = true; 
  # XDG Portal es necesario para que las apps sepan que están en Wayland
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Gráficos (Intel)
  services.xserver.videoDrivers = [ "intel" ];
  hardware.graphics.enable = true; 

  # Sonido (Pipewire es mejor para Hyprland)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Fuentes (Crucial para ML4W y tu Kitty)
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    font-awesome
  ];
  
  virtualisation.docker.enable = true;
  programs.wireshark.enable = true;

  # Usuario
  users.users.jerimy = {
    isNormalUser = true;
    description = "Jerimy";
    extraGroups = [ "networkmanager" "wheel" "video" "audio" "docker" "wireshark" ];
    shell = pkgs.zsh; # Declaramos Zsh como shell del sistema
  };

  # Habilitar Zsh a nivel sistema para que funcione el path
  programs.zsh.enable = true;

  # Habilitar Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Optimización de almacenamiento y limpieza automática
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  system.stateVersion = "24.11"; 
}
