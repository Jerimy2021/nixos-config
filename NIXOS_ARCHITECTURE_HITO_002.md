# NixOS + Hyprland — Mapa de Arquitectura del Sistema
## Jerimy's Laptop | Hito 002 — Pivote a Lua + Sidepad Declarativo

**Fecha del hito:** 2026-08-01
**Estado:** Baseline post-migración a Hyprland Lua config, sidepad-toggle declarativo funcional, theming de rofi unificado.
**Precede a:** `NIXOS_ARCHITECTURE_HITO_001.md` (2026-07-07) — este documento asume ese baseline y documenta únicamente lo que cambió o se añadió desde entonces.
**Uso:** Adjuntar junto al Hito 001 al inicio de cualquier sesión futura para restaurar contexto completo.

---

## 0. Resumen ejecutivo del hito

Desde el Hito 001, el sistema avanzó en tres frentes:

1. **Hyprland migró de sintaxis `.conf` clásica a la API nativa Lua** (`hl.*`, Hyprland 0.55.4+), con arquitectura modular `core/` (funcional) + `themes/` (decoración, con presets) — validando la propuesta arquitectónica que estaba pendiente de revisión en el Hito 001.
2. **`console.keyMap = "la-latin1"`** ya está declarado en `configuration.nix` — el pendiente inmediato §14.1 del Hito 001 quedó resuelto.
3. **Se construyó `sidepad-toggle`**, un panel dual (Claude Code + terminal) declarativo, con selector de proyecto vía `rofi` + `zoxide`, resolviendo un bug de compatibilidad de sintaxis introducido por la migración a Lua.

---

## 1. Confirmación del pivote a Lua en Hyprland

Repositorio verificado: `github.com/Jerimy2021/nixos-config` (rama `master`).

### 1.1 Estructura real (reemplaza la propuesta "pendiente de revisión" del Hito 001)

```
modules/hyprland/
├── hyprland.lua                  # Entry point — dofile() de todos los módulos
├── core/                         # Config funcional (cambia poco)
│   ├── env.lua                   # Variables de entorno (Optimus, Wayland toolkits)
│   ├── monitors.lua              # eDP-1 1366x768@60 + fallback universal
│   ├── inputs.lua                # kb_layout=latam, kb_options=caps:escape, touchpad
│   ├── gestures.lua
│   ├── autostart.lua
│   ├── keybinds.lua               # Incluye el bind de sidepad-toggle (ver §2)
│   ├── window-rules.lua           # Reglas de sidepad, thunar, code-oss, etc.
│   └── behavior.lua               # dwindle, misc, binds
├── hypridle.conf                  # (aún .conf nativo, no requiere Lua)
├── hyprlock.conf
└── themes/                        # Decoración (cambia seguido, por preset)
    ├── active.lua                  # Selector de preset activo
    ├── animations.lua              # Motor de animaciones base
    └── cyberdream/
        ├── theme.lua                # Bordes, blur, sombras — ACTIVO
        ├── colors.conf              # ⚠ residual, ver §4 pendientes
        ├── decorations.conf         # ⚠ residual
        └── animations.conf          # ⚠ residual
```

### 1.2 Confirmación técnica

- API usada: `hl.config()`, `hl.monitor()`, `hl.window_rule()`, `hl.layer_rule()`, `hl.env()`, `hl.bind()`, `hl.dispatch()`, `hl.get_windows()` — nativa de Hyprland ≥0.55, no un wrapper de terceros.
- `hyprland.lua` carga todo vía `dofile(conf_dir .. "...")` con `conf_dir = os.getenv("HOME") .. "/.config/hypr/"`.
- `themes/active.lua` es el pivote de preset: carga `themes/animations.lua` (base) + el preset elegido (`themes/cyberdream/theme.lua`). Patrón "presets" aprobado en el Hito 001, aunque `cyberdream/` vive directo bajo `themes/` en vez de `themes/presets/cyberdream/`.

### 1.3 Gotcha crítico descubierto esta sesión — sintaxis de `hyprctl dispatch`

**Hyprland 0.55.4 ya no acepta el formato clásico `hyprctl dispatch <dispatcher> <args>` en texto plano.** Todo lo que sigue a `dispatch` se interpreta como **código Lua**. Cualquier script externo (fuera de los archivos `.lua` cargados por `dofile`) que invoque `hyprctl dispatch exec '[workspace ...] comando'` fallará con:

```
error: [string "return hl.dispatch(exec [workspace..."]:1: ']' expected near 'special'
→ Note: dispatch in lua is a shorthand for hl.dispatch(...), your syntax might need to be updated.
```

**Fix:** desde scripts externos (Nix `writeShellScriptBin`, etc.), invocar `hyprctl dispatch` pasando una expresión Lua completa, usando long-brackets `[[ ]]` para evitar el infierno de escapado de comillas:

```bash
hyprctl dispatch "hl.dsp.exec_cmd([[$cmd]])"
hyprctl dispatch 'hl.dsp.workspace.toggle_special([[sidepad]])'
```

**Implicancia futura:** cualquier automatización externa a los `.lua` del flake (scripts Nix, alias de shell, integraciones de terceros) que dispare acciones de Hyprland vía `hyprctl dispatch` debe usar esta sintaxis `hl.dsp.*` a partir de ahora, no el formato dispatcher clásico.

---

## 2. `sidepad-toggle` — Panel dual Claude Code + Terminal

### 2.1 Propósito

Un solo atajo (`SUPER + CTRL + →` / `SUPER + CTRL + ←`) que:
1. Pregunta en qué proyecto trabajar (lista de `zoxide` vía `rofi`, o path manual).
2. Abre dos paneles flotantes en un workspace especial (`sidepad`): uno con Claude Code, otro con una shell — ambos con `cwd` en el proyecto elegido.
3. Si los paneles ya existen, solo hace toggle de visibilidad (sin repreguntar el proyecto).

### 2.2 Historial de iteración (por qué se descartaron las versiones previas)

| Versión | Problema |
|---|---|
| `io.popen(...)` directo dentro de `keybinds.lua` | **Deadlock total del compositor.** `io.popen` bloquea síncronamente el hilo de Hyprland esperando a `rofi`, pero `rofi` necesita que Hyprland esté respondiendo para renderizarse → congelamiento, requiere matar `Hyprland` desde una TTY. |
| Script `.sh` suelto en `modules/hyprland/scripts/sidepad.sh` | No declarativo: no versionado por Nix, depende de binarios resueltos por `$PATH` en runtime (no reproducible entre máquinas). |
| `writeShellScriptBin` con `set -euo pipefail` + `[ cond ] && cmd` | `set -e` combinado con `[ ] && comando` aborta el script completo si la condición es falsa — silenciosamente no ejecutaba el resto. |
| `hyprctl dispatch exec '[workspace...] comando'` en texto plano | Sintaxis incompatible con Hyprland 0.55.4 (ver §1.3) — error de parseo Lua. |

### 2.3 Versión final (activa)

Ubicación: `hosts/laptop/scripts.nix`, expuesto como paquete `mis-scripts.sidepad-toggle`, agregado a `home.packages`.

```nix
sidepad-toggle = pkgs.writeShellScriptBin "sidepad-toggle" ''
  HYPRCTL=${pkgs.hyprland}/bin/hyprctl
  JQ=${pkgs.jq}/bin/jq
  ZOXIDE=${pkgs.zoxide}/bin/zoxide
  ROFI=${pkgs.rofi}/bin/rofi
  FOOT=${pkgs.foot}/bin/foot
  BASH=${pkgs.bash}/bin/bash
  ZSH=${pkgs.zsh}/bin/zsh
  FLOCK=${pkgs.util-linux}/bin/flock

  clients=$("$HYPRCTL" clients -j)
  need_claude=1
  need_term=1
  echo "$clients" | "$JQ" -e '.[] | select(.class=="claude-sidepad" or .initialClass=="claude-sidepad")' >/dev/null 2>&1 && need_claude=0
  echo "$clients" | "$JQ" -e '.[] | select(.class=="term-sidepad" or .initialClass=="term-sidepad")' >/dev/null 2>&1 && need_term=0

  if [ "$need_claude" -eq 1 ] || [ "$need_term" -eq 1 ]; then
    dir=$("$ZOXIDE" query -l | "$ROFI" -dmenu -i -p '󰉋 Proyecto' -theme "$HOME/.config/rofi/projects.rasi")
    if [ -z "$dir" ]; then dir="$HOME"; fi

    if [ "$need_claude" -eq 1 ]; then
      cmd="[workspace special:sidepad silent] $FOOT --app-id claude-sidepad -D '$dir' -e $BASH -lc 'exec 9>/tmp/claude-sidepad.lock; $FLOCK -n 9 || exit 0; npx @anthropic-ai/claude-code'"
      "$HYPRCTL" dispatch "hl.dsp.exec_cmd([[$cmd]])"
    fi

    if [ "$need_term" -eq 1 ]; then
      cmd="[workspace special:sidepad silent] $FOOT --app-id term-sidepad -D '$dir' -e $ZSH"
      "$HYPRCTL" dispatch "hl.dsp.exec_cmd([[$cmd]])"
    fi
  fi

  "$HYPRCTL" dispatch 'hl.dsp.workspace.toggle_special([[sidepad]])'
'';
```

`core/keybinds.lua` (bind final, reemplaza la función `open_sidepad` original con lógica inline):

```lua
hl.bind(mainMod .. " + CTRL + right", function()
  hl.dispatch(hl.dsp.exec_cmd("sidepad-toggle"))
end)
hl.bind(mainMod .. " + CTRL + left", function()
  hl.dispatch(hl.dsp.exec_cmd("sidepad-toggle"))
end)
```

### 2.4 Decisiones de diseño

- Todas las rutas a binarios son absolutas al store (`${pkgs.X}/bin/Y`) — reproducible en cualquier máquina que reconstruya el flake, sin depender de `$PATH` imperativo.
- `hyprctl clients -j` se consulta **una sola vez** (no dos) y se reutiliza para ambas comprobaciones de `pad_exists`.
- Sin `set -e`: cada condición usa `if/then` explícito para evitar abortos silenciosos por condiciones falsas.
- El comando dentro de `foot` sigue usando `npx @anthropic-ai/claude-code` (no un binario fijo del store) — consistente con el patrón ya documentado en el Hito 001 §5.6/§10.1 (`nix-ld` habilita la ejecución de binarios Node genéricos sin wrappear).

---

## 3. Theming de rofi — Selector de proyecto

Nuevo archivo: `modules/rofi/projects.rasi`, registrado en `home.nix`:
```nix
"rofi/projects.rasi".source = ../../modules/rofi/projects.rasi;
```

Reutiliza el lenguaje visual ya establecido en `window-switcher.rasi` (glassmorphism, borde lavanda `rgba(203,166,247,*)`, radios 18px/12px/10px) para que los tres `.rasi` del sistema (window-switcher, cheatsheet, project-picker) se perciban como un solo sistema de diseño, no piezas sueltas con estilos distintos.

**Nota de icono:** el prompt usa `` (glyph Nerd Font), no emoji — consistente con `` del window-switcher.

---

## 4. Pendientes abiertos (heredados o nuevos)

### 4.1 Heredados del Hito 001 aún sin resolver
- Deprecación progresiva de `modules/ml4w/`.
- Refactor topológico del flake (`flake-parts`, `disko`, `sops-nix`/`agenix`, `nh`).
- Migración de rEFInd a gestión declarativa.

### 4.2 Nuevos, detectados en esta sesión
- **Archivos `.conf` residuales en `themes/cyberdream/`** (`colors.conf`, `decorations.conf`, `animations.conf`) conviven con `theme.lua`. Confirmar si siguen siendo referenciados por algo o son huérfanos del pre-pivote a Lua — riesgo de doble fuente de verdad.
- **Evaluación de AGS/Astal (Aylur's GTK Shell)** para llevar el theming más allá de lo que `.rasi` permite (rofi no soporta JS/scripting embebido). Es una escalada arquitectónica real (nuevo flake input, nuevo lenguaje, posible reemplazo parcial de rofi/waybar) — tratar como ítem de roadmap propio, no como parte incremental de una tarea existente.
- **Posible migración de `npx @anthropic-ai/claude-code` a `pkgs.claude-code`** (nixpkgs, paquete unfree confirmado en `pkgs/by-name/cl/claude-code/`). Ventaja: arranque sin resolución de red en cada invocación. Requiere: (a) agregar `"claude-code"` al `allowUnfreePredicate` en `configuration.nix`, (b) reemplazar el alias de zsh y la línea `npx` dentro de `sidepad-toggle` a la vez, para no tener dos formas de lanzar Claude Code conviviendo. **No aplicado aún** — evaluado pero no decidido.

---

## 5. Estado de Ratificación

Snapshot verdadero al cierre del Hito 002. Cualquier cambio posterior invalida secciones específicas y debe generar Hito 003. No modificar retroactivamente — versionar hitos.

**FIN DEL DOCUMENTO — Hito 002**
