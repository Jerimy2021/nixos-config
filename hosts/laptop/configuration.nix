{ config, pkgs, inputs, lib, ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix
    ];

  # ==========================================
  # PERMISOS Y FLAKES
  # ==========================================
  nixpkgs.config = {
    allowUnfree = true;
    # Permitir dependencias de Steam
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      "steam" "steam-original" "steam-unwrapped" "steam-run"
    ];
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # ==========================================
  # ARRANQUE Y RED
  # ==========================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "laptop"; 
  networking.networkmanager.enable = true;

  time.timeZone = "America/Lima"; 
  i18n.defaultLocale = "en_US.UTF-8";

  # ==========================================
  # GRÁFICOS, HYPRLAND Y NVIDIA PRO
  # ==========================================
  programs.hyprland.enable = true; 
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  hardware.graphics = {
    enable = true; 
    enable32Bit = true; # VITAL para Steam
  };

  services.xserver.videoDrivers = [ "nvidia" ]; # Cambiado de intel a nvidia para que la detecte
  
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = true;
    open = false;
    nvidiaSettings = true;
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # ==========================================
  # AUDIO Y BLUETOOTH
  # ==========================================
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Enable = "Source,Sink,Media,Socket";
  };
  services.blueman.enable = true;

  # ==========================================
  # JUEGOS (STEAM)
  # ==========================================
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # ==========================================
  # FUENTES, DOCKER Y WIRESHARK
  # ==========================================
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    font-awesome
  ];
  
  virtualisation.docker.enable = true;
  programs.wireshark.enable = true;

  # ==========================================
  # USUARIO JERIMY
  # ==========================================
  users.users.jerimy = {
    isNormalUser = true;
    description = "Jerimy";
    extraGroups = [ "networkmanager" "wheel" "video" "audio" "docker" "wireshark" ];
    shell = pkgs.zsh; 
  };

  programs.zsh.enable = true;

  system.stateVersion = "24.11"; 
}
