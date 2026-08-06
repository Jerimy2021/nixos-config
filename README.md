# ❄️ NixOS + Hyprland + QuickShell

Configuración personal de escritorio, 100% declarativa, gestionada con **Nix Flakes** y **Home Manager**. Hyprland como compositor (config nativa en Lua), **QuickShell** (QML/Qt) como shell completo — barra, dashboard, notificaciones, menú de sesión, selector de wallpaper — con acento de color derivado del wallpaper vía **matugen**.

## Filosofía (no negociable)

1. **Declaratividad absoluta.** Todo cambio pasa por el Flake. Prohibido `npm install -g`, `curl | bash`, o cualquier gestor de paquetes ajeno a Nix. Único permitido: `nix shell`/`nix run` para herramientas efímeras de un solo uso.
2. **Arquitectura modular.** Cada componente (bar, dashboard, notificaciones, servicio de red/bluetooth/HDMI) vive en su propio archivo QML o Lua — agregar algo nuevo no debería requerir tocar el resto.
3. **Estética Hacker Pro / Cyberpunk.** Alta saturación, glow, superficies de vidrio esmerilado. Sin pastel, sin bajo contraste.
4. **Reproducibilidad.** El repo debe poder clonarse en otra máquina y compilar a la primera, con el ajuste esperado de hardware (ver más abajo).

## Stack

| Capa | Tecnología |
|---|---|
| Sistema | NixOS 24.11, Nix Flakes |
| Compositor | Hyprland (config nativa en Lua, API `hl.*`) |
| Shell de escritorio | [QuickShell](https://quickshell.org/) (QML/Qt6) — reemplaza Waybar + swaync por completo |
| Theming dinámico | `matugen` (paleta derivada del wallpaper activo, por workspace) |
| Wallpapers | `swww`/`awww` con transiciones distintas por workspace |
| Terminal | `foot` |
| Shell interactivo | Zsh + Powerlevel10k |
| Editor | Neovim (flake input externo, `nvim-config`) |
| Explorador de archivos | Dolphin (Qt/KDE) + Kvantum, tema propio |
| Launcher / menús | `rofi` |
| IA en terminal | Claude Code (`pkgs.claude-code`, nixpkgs) |

## Estructura del repositorio

```
~/system/nixos/
├── flake.nix                          # Inputs, outputs, hosts
├── hosts/laptop/
│   ├── configuration.nix              # Sistema (root)
│   ├── home.nix                       # Usuario (Home Manager)
│   ├── scripts.nix                    # Scripts declarativos (writeShellScriptBin)
│   └── hardware-configuration.nix     # Auto-generado — NO portar entre máquinas
└── modules/
    ├── hyprland/
    │   ├── core/                      # env, monitors, inputs, keybinds, window-rules, behavior
    │   ├── themes/                    # Presets de tema (activo: cyberdream)
    │   └── assets/                    # atajos.txt, quicklinks.txt (texto plano, editable a mano)
    ├── quickshell/
    │   ├── shell.qml                  # Entry point
    │   ├── modules/                   # bar, dashboard, notifications, powermenu, hdmi, network
    │   └── services/                  # Theme, Hypr, Network, BluetoothStatus, Battery, Hdmi, WorkspaceSync...
    ├── rofi/                          # Temas .rasi (rofi-border, glass-window, cheatsheet, projects)
    ├── matugen/                       # Templates de generación de paleta
    └── kvantum/                       # Tema Qt/Dolphin + kdeglobals + applications.menu
```

## ⚠️ Antes de reproducir esto en otra máquina

Este repo es fiel a **mi** hardware y cuentas. Para que otra persona lo use como base (no como clon 1:1), hay tres cosas que ajustar:

1. **`hosts/laptop/hardware-configuration.nix`** — auto-generado por NixOS, específico de cada máquina. Regenéralo con `nixos-generate-config` en la tuya.
2. **Gráfica híbrida** (`configuration.nix`, sección NVIDIA/PRIME) — asume Intel iGPU + NVIDIA dGPU en modo *offload*. Si tu hardware es distinto (una sola GPU, o AMD), esa sección no aplica tal cual.
3. **`inputs.nvim-config`** en `flake.nix` apunta a mi propio repo privado de configuración de Neovim (`github:Jerimy2021/nvim-config`). No es público — reemplazalo por tu propia config de Neovim o por otro flake de Neovim si querés compilar esto.

El resto (QuickShell, Hyprland, rofi, matugen, Dolphin+Kvantum) es genérico y debería funcionar en cualquier máquina con Hyprland.

## Cómo aplicar

```bash
sudo nixos-rebuild switch --flake .#laptop
```

Alias declarado en el propio sistema: `nix-rebuild-fast`.

## Créditos

Parte del sistema de QuickShell (menú de sesión, notificaciones, carrusel de tabs del dashboard) está adaptado de [`caelestia-dots/shell`](https://github.com/caelestia-dots/shell) (GPLv3) — atribución específica en los archivos correspondientes.

## Historial de arquitectura

Cada hito mayor de este repo está documentado en `NIXOS_ARCHITECTURE_HITO_*.md` (001 a 004) — decisiones tomadas, bugs reales encontrados y su causa raíz, y el estado exacto del sistema en ese momento. Léelos en orden si querés entender *por qué* algo está hecho como está, no solo qué hace.
