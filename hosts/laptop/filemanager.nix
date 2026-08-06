# Hito 005 — File manager Kirigami+KIO (reemplazo eventual de Dolphin, ver
# NIXOS_FILEMANAGER_HITO05_PLAN.md). Derivation CMake convencional, NO
# mkKdeDerivation — el plan (§1.3) encontró que mkKdeDerivation está atado
# a una base de datos generada de fuentes/dependencias por `pname`, poblada
# solo con proyectos oficiales de KDE Gear/Frameworks/Plasma que nixpkgs ya
# conoce; una app propia de este flake (sin repo en invent.kde.org) no
# tiene de dónde sacar `src` ni dependencias por ese camino.
#
# Todos los paquetes Qt6/KF6 se toman del scope `kdePackages` (no mezclado
# con `pkgs.qt6.*`) — `pkgs/kde/default.nix` de nixpkgs arma ese scope como
# `qt6Packages // frameworks // gear // plasma // {...}`, así que
# `kdePackages.qtbase`/`kdePackages.wrapQtAppsHook` son el mismo Qt6 que
# usa `kdePackages.kirigami`/`kdePackages.dolphin` — evita el riesgo de que
# splicing entregue dos instancias de Qt6 distintas si se mezclaran scopes.
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
    # Paso 2: KCoreDirLister (listado de carpetas) + KFilePlacesModel
    # (sidebar) — ambos vienen de este único paquete nixpkgs.
    kdePackages.kio
  ];

  meta = {
    description = "File manager Kirigami+KIO (Hito 005) — scaffold, sin funcionalidad de archivos todavía";
    mainProgram = "nixfm";
    platforms = pkgs.lib.platforms.linux;
  };
}
