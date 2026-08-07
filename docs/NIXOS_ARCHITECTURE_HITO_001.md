# NixOS + Hyprland — Mapa de Arquitectura del Sistema
## Jerimy's Laptop | Hito 001 — Baseline Consolidada

**Fecha del hito:** 2026-07-07
**Estado:** Baseline post-refactor de bootloader, íconos rEFInd, y fallback shell TTY.
**Alcance:** Documento vivo. Cada hito posterior debe versionarse (Hito 002, 003, ...) preservando este como referencia histórica.
**Uso:** Contexto de arranque para cualquier sesión futura con un asistente IA o revisión propia. Adjuntar este archivo al inicio de la conversación para restaurar el estado mental del sistema sin repreguntar.

---

## 0. Filosofía y Directrices Operativas Vinculantes

Estas directrices son inviolables y anteceden a cualquier decisión técnica:

1. **Declaratividad absoluta.** Todo cambio pasa por el Flake en `~/system/nixos/`. Prohibido `npm install -g`, `curl | bash`, `pip install` global, o cualquier gestor de paquetes ajeno al ecosistema Nix. Excepciones únicas: `nix-ld` para binarios dinámicos genéricos, o shells efímeros (`nix shell`, `nix run`, dev shells) para herramientas de un solo uso.
2. **Estética Hacker Pro / Cyberpunk.** Alta saturación, alto contraste. Prohibidos temas pastel o de baja saturación por defecto (ej: pywal auto en la terminal principal).
3. **Precisión de hardware.** Toda solución que involucre renderizado, shaders o cómputo debe respetar los Bus IDs y el aislamiento de drivers de la arquitectura híbrida Intel + NVIDIA PRIME.
4. **Automatización sobre protocolos abiertos.** Bots y automatización de mensajería usan APIs oficiales (Telethon, Pyrogram, Matrix bridges). Prohibido re-desplegar soluciones frágiles basadas en ingeniería inversa (nchat y similares).
5. **Reproducibilidad.** El repo debe poder clonarse en otra máquina y hacer `nixos-rebuild switch --flake .#laptop` funcional a la primera (con el ajuste esperado de `hardware-configuration.nix`).

---

## 1. Identidad del Nodo y Hardware Base

| Parámetro | Valor |
|---|---|
| Usuario del sistema | `jerimy` |
| Home directory | `/home/jerimy` |
| Hostname | `laptop` |
| Correo institucional | `jerimy.sandoval@utec.edu.pe` |
| Arquitectura | `x86_64-linux` |
| Zona horaria | `America/Lima` |
| Locale por defecto | `en_US.UTF-8` |
| Layout de teclado | **latam** (pendiente de declarar en `console.keyMap`; ver Hoja de Ruta §14) |
| Versión NixOS pineada | `24.11` |
| Home Manager stateVersion | `24.11` |

### 1.1 Perfil gráfico híbrido

Arquitectura híbrida inteligente con **NVIDIA PRIME en modo Offload**. El iGPU Intel maneja la sesión gráfica base; la dGPU NVIDIA se activa bajo demanda para cargas específicas (Hyprland con shaders pesados, CUDA, juegos vía Steam).

| Componente | Bus ID | Rol |
|---|---|---|
| Intel iGPU | `PCI:0:2:0` | Renderizado por defecto, ahorro energético |
| NVIDIA dGPU | `PCI:1:0:0` | Offload bajo demanda (`nvidia-offload <cmd>`) |

Driver NVIDIA propietario (`open = false`) por estabilidad garantizada en CUDA y renderizado pesado. `modesetting`, `powerManagement.finegrained`, `nvidiaSettings` activos.

### 1.2 Red

| Parámetro | Valor |
|---|---|
| IP LAN (reservada/estática) | `192.168.18.133` |
| Gestor de red | NetworkManager |
| SSH público | Puerto `22`, `PasswordAuthentication = true`, `PermitRootLogin = no` |
| Firewall | Puerto 22/TCP abierto explícitamente |

Rationale del SSH con password: acceso desde macOS + Warp terminal para desarrollo remoto dentro de la LAN de confianza. Fuera de LAN, siempre por VPN.

---

## 2. Filesystem y Layout de Almacenamiento

Origen: `hosts/laptop/hardware-configuration.nix` (auto-generado, no editar manualmente).

| Punto de montaje | Dispositivo (UUID) | Filesystem | Notas |
|---|---|---|---|
| `/` | `9f9337d8-a609-45b6-b8e9-4096af0ea277` | ext4 | Root del sistema |
| `/boot` | `4C20-D56C` | vfat (FAT32) | EFI System Partition (ESP) |
| swap | `b6d06815-6f5f-4d7b-9127-894b46cbdc8d` | swap | Partición dedicada |

### 2.1 Módulos de kernel iniciales

- `initrd.availableKernelModules`: `xhci_pci`, `ahci`, `usb_storage`, `sd_mod`, `sdhci_pci`
- `kernelModules`: `kvm-intel` (virtualización acelerada por Intel VT-x)
- Intel microcode habilitado condicional a `enableRedistributableFirmware`

### 2.2 DHCP

`networking.useDHCP = lib.mkDefault true` sobre todas las interfaces detectadas. NetworkManager es el orquestador activo.

---

## 3. Cadena de Arranque (Boot Chain)

Flujo real de encendido, capa por capa:

```
UEFI Firmware
    ↓
rEFInd (gestor visual, IMPERATIVO — no en el flake)
    ↓
systemd-boot (declarativo, NixOS)
    ↓
Generación seleccionada (kernel + initrd + system profile)
    ↓
getty en TTY1 (consola virtual)
    ↓
[Login manual del usuario en TTY, o auto-login vía DM si se configura]
    ↓
Zsh (con guard TTY → exec bash)
    ↓
Hyprland (compositor Wayland) al iniciar sesión gráfica
```

### 3.1 rEFInd — Estado

- **Instalación:** IMPERATIVA. No aparece en ninguna referencia del flake (`grep -rn "refind" ~/system/nixos/` devuelve vacío).
- **Config activa:** `/boot/EFI/refind/refind.conf`
- **Theme activo:** `refind-ambience-deer-and-fireflies` (`/boot/EFI/refind/themes/`)
- **Convención de tamaño:** `big_icon_size 132` sobre canvas 256×256 (ratio esperado ~51% de ocupación por ícono).
- **Fix aplicado en Hito 001:** El ícono `os_nixos.png` original ocupaba 99.6% × 86.7% del canvas (agregado post-instalación, sin padding). Fue recompuesto para ocupar 51.2% × 44.5%, alineado con la convención del resto del pack. El archivo vive en:
  `/boot/EFI/refind/themes/refind-ambience-deer-and-fireflies/icons/os_nixos.png`

**Implicancia futura:** Cualquier cambio a rEFInd debe hacerse manualmente en `/boot/EFI/refind/`. Los cambios persisten entre `nixos-rebuild` porque NixOS no toca esa ruta. Considerar migración a gestión declarativa (`boot.loader.refind.enable`) como refactor futuro.

### 3.2 systemd-boot — Estado

Declarado en `configuration.nix`:

```nix
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = true;
boot.loader.systemd-boot.configurationLimit = 5;  # Aplicado en Hito 001
```

- **Antes del Hito 001:** 29 generaciones acumuladas (140–168) sin límite.
- **Después:** Máximo 5 entradas visibles en el menú, rotación FIFO automática. Generaciones huérfanas eliminadas manualmente con `nix-env --delete-generations old` + `nix-collect-garbage -d`.

**Distinción crítica a recordar:**
- `configurationLimit` = cuántas entradas se muestran en el menú de systemd-boot (archivos `.conf` en `/boot/loader/entries/`).
- `nix.gc` = limpieza semanal de store paths sin referencias.
- **Estos NO son el mismo mecanismo.** Las generaciones del perfil (`/nix/var/nix/profiles/system-*-link`) son GC roots — se liberan solo cuando salen del límite Y luego `nix.gc` las procesa.

### 3.3 Post-boot: Login en TTY

Al arrancar el sistema y elegir generación, cae en `getty` sobre TTY1. Se pide usuario y contraseña. Al loguearse, se lanza Zsh como shell definida (`users.users.jerimy.shell = pkgs.zsh`).

**Fix aplicado en Hito 001:** Guard al inicio del `initContent` de Zsh que detecta si el TTY es real (patrón `/dev/tty[0-9]*`) y ejecuta `exec bash` inmediatamente. Kitty (que usa `/dev/pts/*`) no dispara la condición y sigue con Zsh + P10k normal. Ver §9 para el bloque completo.

---

## 4. Stack Gráfico

### 4.1 Compositor

- **Wayland nativo:** `programs.hyprland.enable = true`
- **Portales:** `xdg-desktop-portal-gtk` para diálogos GTK compatibles con Wayland
- **Aceleración:** `hardware.graphics.enable = true` + `enable32Bit = true` (Steam requiere 32-bit)

### 4.2 NVIDIA declarativo

```nix
hardware.nvidia = {
  modesetting.enable = true;
  powerManagement.enable = true;
  powerManagement.finegrained = true;
  open = false;                    # Driver propietario, no el open-source
  nvidiaSettings = true;
  prime = {
    offload = {
      enable = true;
      enableOffloadCmd = true;     # Comando `nvidia-offload` disponible en $PATH
    };
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };
};
services.xserver.videoDrivers = [ "nvidia" ];
```

**Nota:** `services.xserver.videoDrivers` sigue siendo `nvidia` pese a que la sesión es Wayland pura, porque NixOS lo usa como hint para wiring de drivers, no solo para X11.

### 4.3 Suite gráfica Hyprland

Suite ML4W Core desplegada vía paquetes en `home.packages`:
- Barra de estado: `waybar` (dotfiles en `modules/waybar/`)
- Launcher: `rofi` (con `config.rasi` custom en `modules/ml4w/settings/`)
- Wallpapers: `swww` (motor) + `waypaper` (selector GUI)
- Salida: `wlogout`
- Bloqueo: `hyprlock`, `hypridle`
- Selector color: `hyprpicker`
- Notificaciones: `dunst` + `swaynotificationcenter` (alternativo)
- Bandeja: `networkmanagerapplet`, `blueman`
- Explorador: `nautilus`
- Capturas: `grim`, `slurp`, `grimblast`
- Filtros/shaders: `wlsunset`, `hyprshade`

### 4.4 Cursor

- Tema: `Bibata-Modern-Ice`
- Paquete: `bibata-cursors`
- Tamaño: `24`
- Integración GTK habilitada

---

## 5. Audio, Bluetooth, Servicios Base

### 5.1 Audio (PipeWire)

```nix
security.rtkit.enable = true;
services.pipewire = {
  enable = true;
  alsa.enable = true;
  alsa.support32Bit = true;
  pulse.enable = true;                # Compat con apps que aún usan PulseAudio
};
```

Control fino: `pavucontrol` (GUI), `playerctl` (teclas multimedia), `brightnessctl` (brillo).

### 5.2 Bluetooth

```nix
hardware.bluetooth = {
  enable = true;
  powerOnBoot = true;
  settings.General.Enable = "Source,Sink,Media,Socket";
};
services.blueman.enable = true;
```

### 5.3 Docker y Wireshark

- `virtualisation.docker.enable = true`
- `programs.wireshark.enable = true` (grupo `wireshark` con privilegios de captura)

### 5.4 SSH

- Puerto 22, PasswordAuth ON (LAN de confianza), RootLogin OFF
- Firewall: `networking.firewall.allowedTCPPorts = [ 22 ]`

### 5.5 Steam (permisos unfree explícitos)

```nix
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  "steam" "steam-original" "steam-unwrapped" "steam-run"
];
programs.steam = {
  enable = true;
  remotePlay.openFirewall = true;
  dedicatedServer.openFirewall = true;
  localNetworkGameTransfers.openFirewall = true;
};
```

### 5.6 nix-ld — Compatibilidad de binarios dinámicos

Habilita la ejecución de binarios genéricos de Linux (compilados dinámicamente contra glibc estándar) sin fricciones, resolviendo el clásico problema de librerías faltantes en NixOS.

```nix
programs.nix-ld.enable = true;
programs.nix-ld.libraries = with pkgs; [
  stdenv.cc.cc.lib
  zlib
  openssl
  curl
  glibc
];
```

**Uso concreto:** Habilita que Claude Code (que ejecuta binarios de Node ajenos al store) corra sin necesidad de wrappearlo.

### 5.7 Nix housekeeping

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
nix.settings.auto-optimise-store = true;
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 7d";
};
```

---

## 6. Topología del Repositorio

```
~/system/nixos/
├── flake.nix                          # Inputs, outputs, hosts
├── flake.lock                         # Lockfile de dependencias
├── hosts/
│   └── laptop/
│       ├── configuration.nix          # Config a nivel sistema (root)
│       ├── home.nix                   # Config a nivel usuario (Home Manager)
│       └── hardware-configuration.nix # Auto-gen; NO editar
└── modules/
    ├── waybar/                        # Dotfiles Waybar
    ├── hyprland/                      # Dotfiles Hyprland (hyprland.conf, etc.)
    ├── matugen/                       # Config de generación de paletas
    └── ml4w/                          # Suite ML4W (a deprecar; ver §14)
        ├── scripts/
        ├── settings/
        ├── tpl/
        └── wallpapers/
```

**Alias crítico de rebuild:**
```zsh
nix-rebuild-fast = "sudo nixos-rebuild switch --flake ~/system/nixos/#laptop"
```

### 6.1 Neovim como flake input

Neovim NO se configura dentro de este repo. Se consume como flake input:

```nix
xdg.configFile."nvim".source = inputs.nvim-config;
```

Esto significa que `~/.config/nvim` es un enlace al store point del input `nvim-config`, no un directorio editable. Los cambios a la config de Neovim requieren:
1. Editar el repo `nvim-config` upstream.
2. Actualizar el lock del flake principal (`nix flake update nvim-config`).
3. `nix-rebuild-fast`.

Ver §11 para el detalle de la arquitectura de plugins.

---

## 7. Detalle del Sistema (`configuration.nix`)

### 7.1 Argumentos de función
`{ config, pkgs, inputs, lib, ... }:` — `lib` es requerido para `allowUnfreePredicate` (usa `lib.getName`).

### 7.2 Imports
- `./hardware-configuration.nix` (único import; toda la config vive inline en este archivo)

### 7.3 Grupos del usuario `jerimy`

`networkmanager`, `wheel`, `video`, `audio`, `docker`, `wireshark`.

### 7.4 Fuentes a nivel sistema

```nix
fonts.packages = with pkgs; [
  nerd-fonts.jetbrains-mono
  font-awesome
];
```

Rationale: JetBrainsMono NF resuelve todos los glyphs de Powerlevel10k, iconos de Waybar y símbolos de eza/bat. Font Awesome complementa la barra Waybar con iconografía extra.

---

## 8. Detalle del Usuario (`home.nix`)

### 8.1 Argumentos de función
`{ config, pkgs, inputs, lib, ... }:` — `lib` es requerido para `lib.mkMerge` y `lib.mkOrder` en `initContent` de Zsh.

### 8.2 Paquetes (inventario por rol)

**GUI core Hyprland:** waybar, rofi, swww, waypaper, wlogout, hyprlock, hypridle, hyprpicker, dunst, networkmanagerapplet, blueman, nautilus.

**Dependencias de scripts (necesarias para que ML4W y widgets funcionen):** jq, imagemagick, libnotify, cliphist, wl-clipboard, grim, slurp, swaynotificationcenter, wlsunset, hyprshade, grimblast.

**Multimedia:** pavucontrol, playerctl, brightnessctl.

**Terminal moderna (CLI stack):** fastfetch, btop, ripgrep, fd, fzf, eza, bat, zoxide, tldr.

**Utilidades base:** unzip, gcc, wget, direnv, nix-direnv, vivid.

**Aplicaciones:** kitty, firefox, neovim.

**Desarrollo:** nodejs_22.

**Fuentes:** nerd-fonts.jetbrains-mono, font-awesome.

**Extras temáticos:** psmisc, matugen, glib, bc, findutils, pywal.

**Juegos:** prismlauncher (además de Steam a nivel sistema).

**Redes y seguridad:** aircrack-ng, termshark, rsync.

**Videollamadas:** zoom-us.

### 8.3 Enlaces de configuración vía `xdg.configFile`

| Ruta destino | Origen |
|---|---|
| `nvim/` | `inputs.nvim-config` (flake input) |
| `waybar/` | `../../modules/waybar` |
| `hypr/` | `../../modules/hyprland` |
| `ml4w/` | `../../modules/ml4w` |
| `rofi/config.rasi` | `../../modules/ml4w/settings/rofi-border.rasi` |
| `matugen/` | `../../modules/matugen` |

### 8.4 Git

```nix
programs.git.extraConfig = {
  user.name = "jerimy";
  user.email = "jerimy.sandoval@utec.edu.pe";
  init.defaultBranch = "main";
};
```

### 8.5 direnv

`enable = true`, `enableZshIntegration = true`, `nix-direnv.enable = true`. Habilita dev shells automáticos al entrar a directorios con `.envrc`.

---

## 9. Entorno de Shell

### 9.1 Kitty (emulador principal)

```nix
programs.kitty = {
  enable = true;
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
    background_opacity = "0.32";           # ⚠ Ver nota
    dynamic_background_opacity = "yes";
  };
};
```

**⚠ Nota de calibración:** `background_opacity = 0.32` es muy agresiva contra el wallpaper claro/gris medio actual. Impacta directamente la paleta de Neovim (obliga a usar colores oscuros saturados en lugar de neones brillantes). Solución raíz posible: subir a `0.75–0.85` — pendiente decisión estética. Ver §14.

### 9.2 Zsh + Powerlevel10k + Guard TTY

**Aliases activos:**
| Alias | Expansión | Rol |
|---|---|---|
| `ls` | `eza --icons` | Reemplazo con glyphs |
| `ll` | `eza -l --icons` | Lista detallada |
| `cat` | `bat` | Con highlighting |
| `cd` | `z` | zoxide (memoria de rutas) |
| `claude` | `npx @anthropic-ai/claude-code` | CLI de Claude Code |
| `nix-rebuild-fast` | `sudo nixos-rebuild switch --flake ~/system/nixos/#laptop` | Rebuild global |

**`initContent` (post-Hito 001):**

```nix
initContent = lib.mkMerge [
  (lib.mkOrder 100 ''
    if [[ "$(tty)" == /dev/tty[0-9]* ]]; then
      exec bash
    fi
  '')
  (lib.mkOrder 1000 ''
    source ~/.p10k.zsh
    fastfetch
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
```

**Rationale de la técnica `mkMerge` + `mkOrder`:**
- `mkOrder 100` fuerza que el guard corra ANTES de cualquier plugin (que Home Manager inyecta con prioridad ~500).
- `mkOrder 1000` garantiza que P10k y demás corran DESPUÉS de todo lo demás.
- Kitty usa `/dev/pts/*` → el regex no matchea → sigue en Zsh con P10k completo.
- TTY real usa `/dev/tty[0–9]*` → matchea → `exec bash` reemplaza el proceso del shell antes de cargar cualquier glyph.

**Convención de colores en la shell (dictada por Perfil V2, no negociable):**
- Comandos base: cyan bold
- Alias: magenta bold
- Builtins: cyan bold
- Funciones: blue bold

### 9.3 Plugins de Zsh

```nix
plugins = [
  {
    name = "powerlevel10k";
    src = pkgs.zsh-powerlevel10k;
    file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
  }
];
```

`enableCompletion = true`, `autosuggestion.enable = true`, `syntaxHighlighting.enable = true`.

---

## 10. Desarrollo

### 10.1 Node.js y Claude Code

`nodejs_22` en `home.packages`. Alias `claude = "npx @anthropic-ai/claude-code"`. Ejecución habilitada gracias a `nix-ld` (§5.6).

### 10.2 Dev shells efímeros

Patrón preferido para herramientas one-shot: `nix run nixpkgs#<tool>` o `nix shell nixpkgs#<tool>`. Ejemplo utilizado en Hito 001: `nix run nixpkgs#file -- <archivo>` para diagnosticar PNGs sin instalar `file` en el sistema.

---

## 11. Arquitectura de Neovim

Neovim se consume como **flake input externo** (`inputs.nvim-config`), no vive en este repo. El detalle a continuación describe el estado del flake externo tal como lo hemos venido iterando.

### 11.1 Gestor de plugins

`lazy.nvim`, estructura modular:

```
nvim/
├── init.lua                          # Entry point + carga de módulos
├── lua/
│   ├── pluginlist.lua                # Manifiesto de plugins (lazy.setup)
│   └── plugins/
│       ├── treesitter.lua
│       ├── mason.lua
│       ├── nvim-cmp.lua
│       ├── lspconfig.lua
│       ├── telescope.lua
│       ├── lsp_signature.lua
│       ├── cyberdream.lua           # ← Iterado activamente
│       ├── lualine.lua
│       ├── nvim-tree.lua
│       ├── luasnip.lua
│       ├── competitest.lua
│       ├── nvim-dap-ui.lua
│       ├── cmp-dap.lua
│       ├── dap.lua
│       ├── hydra.lua
│       ├── mason-nvim-dap.lua
│       ├── nvim-dap-virtual-text.lua
│       ├── telescope-dap.lua
│       ├── harpoon.lua
│       ├── leetcode.lua
│       ├── copilot.lua
│       ├── copilotchat.lua
│       ├── which-key.lua
│       └── gitsigns.lua
```

### 11.2 LSPs y lenguajes principales

- **C#:** Roslyn (`seblyng/roslyn.nvim`), lazy-loaded en filetype `cs`.
- **Java:** `mfussenegger/nvim-jdtls`.
- **Otros:** vía `mason.nvim` + `mason-lspconfig.nvim`.

### 11.3 Tema activo

**CyberDream** con `transparent = true`. Palette recalibrada en Hito 001 para wallpaper claro + Kitty opacity 0.32.

**Estrategia de doble registro visual:**
- **Editor principal (fondo transparente sobre wallpaper claro):** colores OSCUROS y muy saturados. Magenta profundo `#c2185b` (keywords), teal oscuro `#00695c` (variables), índigo `#1a237e` (funciones), púrpura tinta `#4a148c` (tipos), verde bosque `#1b5e20` (strings), carmesí `#b71c1c` (números), negro absoluto `#000000` (operadores y puntuación), pizarra `#455a64` (comentarios).
- **Ventanas flotantes** (which-key, telescope, nvim-tree, cmp, dap-ui, harpoon): fondo oscuro sólido `#0a0a14` forzado + colores neón clásicos brillantes por dentro (rosa `#ff2a6d`, cyan `#05d9e8`, verde `#00ff9f`, púrpura `#bd93f9`).

**Overrides LSP semantic tokens para C#/Roslyn:** `@lsp.type.class`, `@lsp.type.method`, `@lsp.type.property`, `@lsp.type.variable`, `@lsp.type.parameter`, `@lsp.type.namespace` linkeados a los grupos Treesitter equivalentes.

**Anti-pisado por lazy-loading:** `autocmd ColorScheme *` reaplica el diccionario de highlights después de que cualquier plugin cargue tarde.

### 11.4 Copilot

`zbirenbaum/copilot.lua` + `CopilotC-Nvim/CopilotChat.nvim` (con `plenary.nvim`, build `make tiktoken`).

---

## 12. Gobernanza Estética

**Reglas visuales activas del sistema:**
- Kitty: tema Dracula, opacity 0.32, JetBrainsMono NF, sin bell audible.
- Zsh syntax highlighting: cyan/magenta/blue bold según categoría.
- Neovim: dark saturated + neon en flotantes (§11.3).
- Cursor: Bibata-Modern-Ice size 24.
- Iconos: font-awesome + nerd-fonts.jetbrains-mono a nivel sistema.

**Nombre del wallpaper de referencia por defecto en ML4W:** `modules/ml4w/wallpapers/default.jpg`. Se irá reemplazando según diseño personal.

---

## 13. Bitácora del Hito 001 (Fixes Aplicados)

Orden cronológico de esta sesión:

1. **Neovim CyberDream — paleta refactorizada.**
   Palette recalibrada para wallpaper claro + Kitty opacity 0.32. Colores oscuros saturados en el editor + neones dentro de flotantes. `autocmd ColorScheme` para persistencia contra lazy-loading.

2. **systemd-boot — límite de generaciones.**
   Añadido `boot.loader.systemd-boot.configurationLimit = 5;`.
   Purga manual única: `sudo nix-env -p /nix/var/nix/profiles/system --delete-generations old && sudo nix-collect-garbage -d`.
   Verificado: `/boot/loader/entries/` con 1 entrada tras purga, se irá poblando hasta el techo de 5 con futuros rebuilds.

3. **rEFInd — ícono de NixOS recompuesto.**
   Diagnóstico: canvas 256×256 correcto, pero contenido del logo ocupaba 99.6%×86.7% (sin padding) contra el 51.2%×41.0% de los íconos del pack.
   Procedimiento: crop al bounding box, resize a 132px lado mayor (matching `big_icon_size` del theme), recentrado en canvas transparente 256×256.
   Archivo reemplazado en `/boot/EFI/refind/themes/refind-ambience-deer-and-fireflies/icons/os_nixos.png`.
   Persistencia garantizada por instalación imperativa de rEFInd.

4. **Zsh → bash guard en TTY.**
   Insertado bloque `mkOrder 100` en `initContent` de Zsh que detecta `/dev/tty[N]` y ejecuta `exec bash`. Se agregó `lib` a la firma de función de `home.nix` (era el bug del primer intento de rebuild).

---

## 14. Hoja de Ruta (Pendientes Priorizados)

### 14.1 Inmediato (próximas sesiones)

1. **Layout de teclado latam.** No hay `console.keyMap` declarado. Los símbolos españoles no funcionan bien en TTY.
   Ubicación esperada del fix: `configuration.nix`, sección de arranque/locale.
   ```nix
   console.keyMap = "la-latin1";  # candidato para latam
   services.xserver.xkb.layout = "latam";  # para Hyprland/X11
   ```
   Requiere validar el keymap exacto para el layout físico del laptop.

2. **Waybar declarativa avanzada.** Módulos de red LAN, uso GPU dedicada NVIDIA, estado audio PipeWire, integración cromática con Dracula.

### 14.2 Medio plazo

3. **Deprecación de ML4W.** El usuario explicitó intención de removerlo progresivamente. Auditar qué scripts/dotfiles siguen siendo referenciados y migrar los útiles a módulos propios (`modules/waybar`, `modules/hyprland`) antes de eliminar `modules/ml4w`.

4. **Refactor topológico del flake.** Evaluar migración a `flake-parts`, `disko` (particiones declarativas), `sops-nix` o `agenix` (secretos), `nh` (wrapper de rebuild con UX mejorada). Decisión arquitectónica pendiente con tradeoffs.

5. **Migración de rEFInd a gestión declarativa.** Considerar `boot.loader.refind.enable` si existe en NixOS, o construir un módulo propio con `boot.loader.efi.efiSysMountPoint` + copiado declarativo del theme desde `modules/refind/`.

### 14.3 Largo plazo (visión V2)

6. **Backend de LLM local para Telegram.**
   Scripts Python en entornos Nix limpios (dev shells) usando Telethon o Pyrogram. Extracción de históricos de chat → datasets JSON/CSV → refinamiento de respuestas. Demonios en segundo plano que actúen como agentes replicando la identidad de desarrollo controlada.

7. **Bridges Matrix** para consolidar mensajería multi-plataforma bajo protocolo abierto.

### 14.4 Consideraciones abiertas

- **Kitty opacity vs. legibilidad de Neovim.** La opacity 0.32 impacta directamente la paleta de Neovim. Si en algún momento se sube a 0.75+, la paleta de Neovim debería refactorizarse de vuelta a neones brillantes clásicos (versión pre-Hito 001 pero mejorada).

---

## 15. Estado de Ratificación

Este documento es el snapshot verdadero del sistema al cierre del Hito 001. Cualquier cambio ejecutado después de esta fecha invalida secciones específicas de este mapa y debe generar un Hito 002 con las secciones actualizadas explícitamente marcadas. No modificar este archivo retroactivamente — versionar hitos.

**FIN DEL DOCUMENTO — Hito 001**
