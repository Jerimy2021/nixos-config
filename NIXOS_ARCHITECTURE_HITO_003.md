# NixOS + Hyprland — Mapa de Arquitectura del Sistema
## Jerimy's Laptop | Hito 003 — Deprecación total de ML4W + Rescates declarativos

**Fecha del hito:** 2026-08-01
**Estado:** `modules/ml4w/` reducido de 11 subcarpetas/archivos a 5 archivos sueltos (todos justificados, en espera del rediseño del waybar). Claude Code migrado a paquete declarativo de nixpkgs. Sistema de quicklinks nativo implementado.
**Precede a:** `NIXOS_ARCHITECTURE_HITO_002.md` (2026-08-01, mismo día — sesión larga) y `NIXOS_ARCHITECTURE_HITO_001.md` (2026-07-07). Este documento asume ambos baselines.
**Próximo hito (004):** Rediseño completo del waybar + estrategia de workspaces. Pendiente de especificación por Jerimy — se documentará por separado cuando esté definido y aplicado.
**Uso:** Adjuntar junto a los Hitos 001 y 002 al inicio de cualquier sesión futura.

---

## 0. Resumen ejecutivo del hito

Sesión larga con tres frentes de trabajo, en este orden:

1. **Claude Code migrado de `npx @anthropic-ai/claude-code` a `pkgs.claude-code`** (nixpkgs, unfree) — arranque sin resolución de red en cada invocación, misma forma de lanzarlo en terminal normal y en el sidepad.
2. **Sistema de quicklinks nativo** vía `rofi` + `.txt` plano, sin scripts nuevos en `scripts.nix` — reutiliza la infraestructura del cheatsheet ya existente.
3. **Deprecación sistemática y verificada de `modules/ml4w/`**, carpeta por carpeta, con rescate declarativo de todo lo que seguía activo (batería, wlogout, nm-applet), y desactivación de lo que estaba activo pero roto por incompatibilidad estructural con NixOS (el checker de actualizaciones basado en pacman/AUR/dnf).

---

## 1. Migración de Claude Code a nixpkgs

### 1.1 Cambios aplicados

**`configuration.nix`** — predicado unfree extendido:
```nix
allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  "steam" "steam-original" "steam-unwrapped" "steam-run"
  "claude-code"
];
```

**`home.nix`** — paquete agregado (sección 7, Desarrollo), alias de zsh **eliminado** (`claude = "npx @anthropic-ai/claude-code"` ya no existe, el binario `claude` viene directo del paquete):
```nix
    nodejs_22
    claude-code
```

**`scripts.nix`** — `sidepad-toggle` actualizado: variable `CLAUDE=${pkgs.claude-code}/bin/claude` reemplaza el `npx @anthropic-ai/claude-code` hardcodeado dentro del comando de `foot`.

### 1.2 Rationale

Antes: cada lanzamiento de Claude Code vía `npx` resolvía la versión contra el registro de npm por red — demora perceptible en cada apertura del sidepad. Después: binario resuelto una sola vez en el store al hacer `nix-rebuild-fast`, arranque instantáneo. Única forma de lanzarlo en todo el sistema (terminal normal y sidepad comparten el mismo binario del store) — se evitó a propósito tener dos rutas de invocación distintas conviviendo.

**Nota de mantenimiento:** el primer rebuild con este cambio compila/descarga `claude-code` desde npm.js.org vía nixpkgs — build de tamaño considerable la primera vez, luego cacheada.

---

## 2. Sistema de quicklinks nativo

Decisión de diseño explícita: sin `writeShellScriptBin` nuevo. Se reutilizó el mismo patrón que ya usa el cheatsheet de atajos (`SUPER+CTRL+K`), solo agregando un paso de `eval` al comando seleccionado.

**Archivo de datos** — `modules/hyprland/assets/quicklinks.txt` (formato `Nombre | Comando`, editable a mano, sin tocar Nix/Lua):
```
 USIL Portal | firefox --new-window https://portal.usil.edu.pe
 Correo UTEC | firefox --new-window https://mail.utec.edu.pe
 Proyecto Sidepad | sidepad-toggle
```

**Bind en `core/keybinds.lua`** (`SUPER+CTRL+U`), reutiliza `themes/cheatsheet.rasi`:
```lua
hl.bind(mainMod .. " + CTRL + U", hl.dsp.exec_cmd([==[bash -c 'sel=$(cat ~/.config/hypr/assets/quicklinks.txt | rofi -dmenu -i -theme ~/.config/rofi/cheatsheet.rasi -p "  Quicklinks"); [ -z "$sel" ] && exit 0; cmd=$(echo "$sel" | cut -d"|" -f2- | xargs); eval "$cmd"']==]))
```

### 2.1 Gotcha crítico — comandos multilínea en `hl.dsp.exec_cmd`

**Cualquier salto de línea real dentro del string pasado a `exec_cmd` rompe el bind silenciosamente** (no tira error de Lua, simplemente el keybind no hace nada). El motor de dispatch de Hyprland corta el comando en el primer newline, sin importar que el string Lua esté bien formado. Regla adoptada: todo comando multi-instrucción dentro de `hl.dsp.exec_cmd(...)` debe quedar en **una sola línea física**, separando pasos con `;` o `&&`, nunca con Enter real — incluso si se usa `[==[ ]==]` (long-bracket que sí permite newlines en Lua puro, pero Hyprland igual los interpreta mal).

### 2.2 Gotcha secundario — colisión de long-brackets con `[[:class:]]` de POSIX

Se detectó que `[[ ]]` (long-bracket nivel 0 de Lua) se cierra en la **primera** aparición de `]]`, incluida la de clases POSIX como `[[:space:]]` (usadas por ejemplo en `sed`). Adoptado como práctica default: usar `[==[ ]==]` (nivel 1) para cualquier comando embebido que pueda contener `sed`, `grep -E`, o regex con corchetes dobles.

---

## 3. Rescates declarativos (`scripts.nix`)

Inventario completo de paquetes agregados a `mis-scripts` en esta sesión, todos con rutas absolutas al store (`${pkgs.X}/bin/Y`), sin excepción:

| Paquete | Reemplaza | Activación |
|---|---|---|
| `sidepad-toggle` | Función Lua `open_sidepad()` con `io.popen` (causaba deadlock del compositor) | `hl.bind` en `keybinds.lua`, `SUPER+CTRL+←/→` |
| `battery-notify` | `modules/ml4w/listeners/low-bat-notification.sh` | **Servicio `systemd.user.services`**, no `exec_cmd` — se reinicia solo si falla, logs en `journalctl --user -u battery-notify` |
| `wlogout-launch` | `modules/ml4w/scripts/wlogout.sh` | `on-click` del módulo `custom/exit` en `modules/waybar/modules.json` |
| `nm-applet-ctl` | `modules/ml4w/scripts/nm-applet.sh` | `on-click-right` del módulo `network` en `modules/waybar/modules.json` |

### 3.1 Historial de iteración de `sidepad-toggle` (resumen — detalle completo en Hito 002)

1. `io.popen` directo en Lua → **deadlock total del compositor** (bloquea el hilo de Hyprland esperando `rofi`, que necesita a Hyprland respondiendo para renderizarse).
2. Script `.sh` suelto fuera de Nix → no declarativo, no reproducible.
3. `set -euo pipefail` + `[ cond ] && cmd` → aborta el script completo si la condición es falsa, silenciosamente.
4. `hyprctl dispatch exec '[workspace...] comando'` en texto plano → **incompatible con Hyprland 0.55.4**, que interpreta todo lo posterior a `dispatch` como código Lua (ver `hl.dsp.exec_cmd([[...]])` como forma correcta, documentado en Hito 002 §1.3).
5. Versión final: sin `set -e`, `hyprctl clients -j` consultado una sola vez, sintaxis `hl.dsp.*` correcta.

### 3.2 `battery-notify` — por qué systemd y no `exec_cmd`

Es un bucle infinito (`while true; sleep 60`) de larga duración. Si se lanza con `hl.exec_cmd` en `autostart.lua` y crashea, nadie lo revive. Un servicio `systemd.user` sí. No requiere `WAYLAND_DISPLAY` (verificado: `notify-send` habla por D-Bus de sesión, no por Wayland directo, así que no hay carrera con el `systemctl --user import-environment` que ya corre `autostart.lua` al iniciar Hyprland).

---

## 4. Rofi — consolidación bajo `modules/rofi/`

Movidos fuera de `ml4w/settings/` a su propia carpeta neutral (sin dependencia de ml4w):
```bash
git mv modules/ml4w/settings/rofi-border.rasi   modules/rofi/rofi-border.rasi
git mv modules/ml4w/settings/glass-window.rasi  modules/rofi/glass-window.rasi
git mv modules/ml4w/settings/cheatsheet.rasi    modules/rofi/cheatsheet.rasi
```
Confirmado antes del move: cero `@import`/rutas relativas entre ellos, y `keybinds.lua` ya invocaba desde `~/.config/rofi/*.rasi` (no desde `~/.config/ml4w/settings/`), así que el move fue de solo relocación de origen en `home.nix`, sin tocar Lua.

`home.nix` — bloque `rofi/*` completo, ya sin ninguna ruta a `ml4w`:
```nix
    "rofi/rofi-border.rasi".source = ../../modules/rofi/rofi-border.rasi;
    "rofi/glass-window.rasi".source = ../../modules/rofi/glass-window.rasi;
    "rofi/cheatsheet.rasi".source = ../../modules/rofi/cheatsheet.rasi;
    "rofi/projects.rasi".source = ../../modules/rofi/projects.rasi;
```

`modules/rofi/projects.rasi` (nuevo, Hito 002) reutiliza el lenguaje visual del `glass-window.rasi` (glassmorphism, borde lavanda `#cba6f7`) para el selector de proyecto del sidepad.

---

## 5. Deprecación completa de `modules/ml4w/` — inventario carpeta por carpeta

Metodología aplicada en cada archivo/carpeta: `grep` de referencias en todo el repo, distinguiendo activo (wireado en `keybinds.lua`, `autostart.lua`, `modules.json`/`config` de waybar activo) de muerto (solo auto-referenciado dentro de `ml4w/` o sin referencias en absoluto).

### 5.1 Eliminados sin reemplazo — cero referencias en todo el repo
- `library.sh` (raíz) — huérfano total. **Ojo:** existía un segundo `library.sh` en `version/`, con funciones distintas, referenciado por `version/update.sh` — no confundir, ambos se fueron igual pero por razones separadas (el de `version/` cayó junto con toda esa carpeta, ver 5.2).
- `listeners.sh` + `listeners/gtk-theme-switcher.sh` (pelea contra `gtk.theme` declarativo en `home.nix`) — `low-bat-notification.sh` fue el único rescatado (ver §3).
- `login/issue` — banner ASCII de `/etc/issue` nunca conectado (ni `environment.etc`, ni `console.*`). Anotado como idea suelta para el futuro si se quiere un banner de TTY real.
- `tpl/.zshrc` — template que un instalador imperativo (`scripts/shell.sh`, también muerto) usaría para *sobrescribir* el `.zshrc` que Home Manager ya genera declarativamente. Doblemente descartable.
- `version/` completo (`library.sh`, `name`, `update.sh`) — sistema de auto-update contra **AUR de Arch Linux** (`aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=ml4w-hyprland`), con `ping google.com` en cada corrida. Cero aplicabilidad a NixOS.
- `bin/` completo — 5 scripts, todos redundantes con herramientas nativas ya en uso:
  - `ml4w-apps.sh` → redundante con `rofi -show drun` (`SUPER+D`)
  - `ml4w-screenshot.sh` → redundante con `grimblast` + `PRINT`+`slurp`
  - `ml4w-wallpaper.sh` → redundante con `waypaper` + `set-wallpaper` (propio, con pywal/matugen)
  - `ml4w-finder.sh` → redundante con Snacks.nvim (picker dentro del editor) + `zoxide`
  - `ml4w-quicklinks.sh` → **rescatado como concepto**, reimplementado nativo (ver §2), no como script
- `scripts/` completo:
  - `figlet.sh`, `ml4w-autostart.sh` (lanza el Flatpak "ML4W Welcome App", producto ajeno), `sidepad.sh` (sistema de sidepad *original* de ML4W — no confundir con el propio, ver §3.1), `toggle-theme.sh` (pelea contra `gtk.theme` declarativo) — muertos sin referencias.
  - `updates.sh` + `installupdates.sh` (dos variantes, una en `scripts/` otra en `settings/`) — **activos pero estructuralmente rotos**: lógica 100% pacman/yay/dnf, en NixOS caen al `else` y reportan "0 actualizaciones" siempre, dato falso silencioso. Módulo `custom/updates` **desactivado** en `modules/waybar/themes/ml4w-modern/config` (comentado, no borrado, para dejar constancia de que fue decisión consciente).
  - `wlogout.sh`, `nm-applet.sh` — activos, **rescatados** (ver §3).
  - `now-playing.sh` — **inactivo hoy** (`custom/nowplaying` comentado en `modules-left` de `ml4w-modern/config`). Contenido preservado en el historial de conversación; se re-evaluará en el Hito 004 (posible reemplazo por el módulo nativo `mpris` de waybar en vez de resucitar el script de polling).
  - `arch/` completo (`cleanup.sh`, `installprinters.sh`, `installtimeshift.sh`, `pacman.sh`, `snapshot.sh`, `unlock-pacman.sh`) — 100% Arch/AUR/GRUB, sin excepción.
    - **Excepción parcial:** `lid-improvements.sh` tenía una idea válida (ignorar lid-switch cuando el laptop está en dock) pero mal implementada (edita `/etc/systemd/logind.conf` a mano, que Nix regenera en cada rebuild). Equivalente declarativo correcto, **no aplicado aún**, solo anotado:
      ```nix
      services.logind.settings.Login = {
        HandleLidSwitchDocked = "ignore";
        HoldoffTimeoutSec = "5s";
      };
      ```
- `themes/` completo (`themes.sh` dispatcher + `glass`, `modern`, `transparent`, `glass-walker`, `modern-walker`) — sistema de cambio de tema de dotfiles completo, cero referencias en todo el repo. Resolvió de paso 3 pendientes de `settings/` que solo este árbol usaba: `dock-theme`, `walker-theme`, `waybar-theme.sh`.
- `wallpapers/` completo (10 imágenes: `mountain.jpg`, `red-waves.jpg`, `bullet-space.jpg`, `Nocturne-of-Steel-and-Glass.jpg`, `golden-horizon.jpg`, `default.jpg`, `orange-mountain.jpg`, `fall-echo-tries.png`, `minimal-waves.jpg`, `stars-as-minimal.jpg`) — sin referencias en el repo. Verificado además que `waypaper` (estado runtime en `~/.config/waypaper/config.ini`, fuera del flake) no las tenía registradas como carpeta-fuente antes de borrar.
- `settings/` — grueso del archivo eliminado en un solo lote: `ai.sh`, `blur.sh`, `calendar.sh`, `dock-border.css`, `dotfiles-folder.sh`, `editor.sh`, `email.sh`, `filemanager`, `hyprpaper.tpl`, `hyprpicker.sh`, `hyprshade.sh`, `rofi_bordersize.sh`, `screenshot-editor`, `systemmonitor`, `wallpaper-automation.sh`, `wallpaper-effect.sh`, `wallpaper-engine.sh`, `waybar_appmenu.sh`, `waybar_backlight.sh`, `waybar_chatgpt.sh`, `waybar_custom_timedateformat.sh`, `waybar_dateformat.sh`, `waybar_quicklinks.sh`, `waybar_screenlock.sh`, `waybar_settings.sh`, `waybar_systray.sh`, `waybar_taskbar.sh`, `waybar_timeformat.sh`, `waybar_timezone.sh`, `waybar_toggle.sh`, `waybar_window.sh`, `waybar_workspaces.sh`, `wlogout-parameters.sh`, `waybar_network.sh` — todos internos de la app GTK "ML4W Settings" (ya sin autostart), y `printer-drivers.sh`, `screenshot-filename`, `screenshot-folder`, `sidepad-active`, `wallpaper-folder`, `aur.sh` — muertos en cascada (solo los referenciaban archivos ya eliminados).

### 5.2 Estado final de `modules/ml4w/`

De 11 subcarpetas/archivos en la raíz a **5 archivos sueltos**, todos activos y justificados, en espera del Hito 004:
```
modules/ml4w/
└── settings/
    ├── bluetooth.sh          # módulo "bluetooth" en modules.json
    ├── launcher               # leído por themeswitcher.sh (SUPER+CTRL+T)
    ├── networkmanager.sh      # on-click del módulo "network"
    ├── system-monitor.sh      # ligado a group/hardware en modules.json
    └── waybar-quicklinks.json # "include" obligatorio en TODOS los config de tema
```

**Por qué no se tocaron:** los 5 siguen wireados en `modules/waybar/modules.json` / `modules/waybar/themes/ml4w-modern/config` (el tema realmente activo — confirmado en runtime, no asumido, ver §6). Rescatarlos uno por uno ahora sería trabajo duplicado, dado que el Hito 004 va a rediseñar el waybar completo y probablemente los reemplace o absorba en una sola pasada.

---

## 6. Hallazgo de arquitectura — cómo arranca realmente el waybar

Descubrimiento importante para el Hito 004, documentado aquí para no repetir la investigación:

- `core/autostart.lua` lanza `waybar` **sin flags** (`hl.exec_cmd("waybar")`) — usa descubrimiento de config por defecto, que en la práctica no encuentra nada útil en la raíz de `modules/waybar/` (no hay `config`/`style.css` ahí, solo `modules.json`, `colors.css`, `launch.sh`, `themeswitcher.sh`).
- El waybar que el usuario **ve de verdad** se lanza vía `~/.config/waybar/launch.sh` (bind `SUPER+SHIFT+B`), que lee el tema activo desde `~/.cache/waybar-theme-active` (estado runtime, no versionado) y arma el comando con `-c`/`-s` explícitos apuntando a `themes/<tema>/config` + `style.css`.
- Confirmado en runtime (2026-08-01): `~/.cache/waybar-theme-active` = `ml4w-modern/black` → proceso real corriendo con `-c .../themes/ml4w-modern/config -s .../themes/ml4w-modern/black/style.css`.
- Ese `config` de tema **incluye** (`"include"`) el `modules.json` raíz — las *definiciones* de módulo viven ahí, pero cuál se *muestra* lo decide el array `modules-left/center/right` de cada `config` de tema. Es decir, hay dos capas: definición (modules.json) + selección de layout (config del tema activo).

**Implicancia para el Hito 004:** el rediseño debe decidir explícitamente si se mantiene este sistema de dos capas + selector de temas en runtime (`themeswitcher.sh` + caché), o si se simplifica a una única fuente de verdad declarativa (por ejemplo, un solo `config` fijo gestionado 100% por Nix, sin `~/.cache/waybar-theme-active` como estado mutable fuera del flake).

---

## 7. Pendientes abiertos (heredados o nuevos)

### 7.1 Heredados de Hitos anteriores, aún sin resolver
- Refactor topológico del flake (`flake-parts`, `disko`, `sops-nix`/`agenix`, `nh`).
- Migración de rEFInd a gestión declarativa.
- Evaluación de AGS/Astal (Aylur's GTK Shell) para theming con animaciones reales más allá del techo de `.rasi` — roadmap propio, no incremental.

### 7.2 Nuevos, de esta sesión
- **Hito 004 (el siguiente, prioritario):** rediseño completo del waybar + estrategia de workspaces. Especificación pendiente de Jerimy.
- `services.logind.settings.Login` (lid-switch en dock) — evaluado, no aplicado.
- `now-playing.sh` — decisión diferida al Hito 004 (script rescatado tal cual vs. módulo nativo `mpris`).
- Los 5 archivos de `settings/` — su destino final depende 100% del Hito 004.

---

## 8. Estado de Ratificación

Snapshot verdadero al cierre del Hito 003. Cualquier cambio posterior invalida secciones específicas y debe generar Hito 004. No modificar retroactivamente — versionar hitos.

**FIN DEL DOCUMENTO — Hito 003**
