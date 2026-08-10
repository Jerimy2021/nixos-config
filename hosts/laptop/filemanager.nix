{ pkgs }:
pkgs.stdenv.mkDerivation {
  pname = "nixfm";
  version = "0.1.0";
  src = ../../modules/filemanager;

  nativeBuildInputs = with pkgs; [
    cmake
    ninja
    kdePackages.extra-cmake-modules
    kdePackages.wrapQtAppsHook
  ];

  buildInputs = with pkgs; [
    kdePackages.qtbase
    kdePackages.qtdeclarative
    kdePackages.kirigami
    kdePackages.qqc2-desktop-style
    kdePackages.kio
  ];

  meta = {
    description = "File manager Kirigami+KIO (Hito 005) — scaffold, sin funcionalidad de archivos todavía";
    mainProgram = "nixfm";
    platforms = pkgs.lib.platforms.linux;
  };
}
