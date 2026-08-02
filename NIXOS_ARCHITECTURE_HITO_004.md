# NixOS + Hyprland — Mapa de Arquitectura del Sistema
## Jerimy's Laptop | Hito 004 — QuickShell (bar, wallpaper-sync, dashboard, notificaciones)

**Fecha del hito:** 2026-08-01
**Estado:** QuickShell construido y verificado en vivo contra la sesión Hyprland real, pero **no autostarted todavía** — ver §5 antes de asumir que ya reemplazó a waybar/swaync en el sistema desplegado.
**Precede a:** `NIXOS_ARCHITECTURE_HITO_003.md` (2026-08-01), `002` (2026-08-01), `001` (2026-07-07). Este documento asume esos tres baselines.
**Uso:** Adjuntar junto a los Hitos 001-003 al inicio de cualquier sesión futura.

---

## 0. Resumen ejecutivo del hito

Sesión autónoma (sin supervisión humana disponible) que implementó las 4 piezas especificadas para el rediseño del shell de escritorio, en orden:

1. Barra principal: workspaces animados (grow+glow) + cápsulas de sistema agrupadas (red/bluetooth/batería/reloj).
2. Wallpaper dinámico por workspace + sincronización del acento/glow de la barra.
3. Dashboard desplegable: perfil, toggles rápidos, accesos a carpetas, calendario, mezclador de volumen por dispositivo.
4. Centro de notificaciones (reemplaza swaync como servidor `org.freedesktop.Notifications`).

Motor elegido: **QuickShell** (QML/Qt), decisión ya tomada antes de esta sesión (ver Hito 003 §7.1 — evaluado contra HyprPanel/AGS, elegido por el techo de animación de QML). Cada pieza se verificó **en vivo** contra la sesión Hyprland real corriendo en la máquina (no solo `nixos-rebuild build`), lo cual expuso y corrigió varios bugs reales que una simple evaluación de Nix nunca habría detectado — documentados en detalle en los mensajes de commit de cada pieza (`git log`), resumidos en §4 aquí.

**Limitación crítica de esta sesión:** no hubo forma de ejecutar `sudo nixos-rebuild switch` (contraseña de sudo interactiva no disponible en el entorno del agente). Todo se validó con `nixos-rebuild build` (evalúa y construye el closure sin activarlo) más pruebas en vivo de QuickShell vía `nix shell nixpkgs#quickshell -c qs -p modules/quickshell` apuntando directamente a la sesión Wayland real. Esto significa que **el sistema desplegado todavía no tiene los paquetes nuevos activos** (`quickshell`, `kdePackages.qt6ct`, `services.upower`) hasta que alguien con la contraseña corra `nix-rebuild-fast`. Ver §5.

---

## 1. Estructura del nuevo módulo

```
modules/quickshell/
├── shell.qml                          # Entry point (qs -p modules/quickshell)
├── services/                          # Singletons, importados como `qs.services`
│   ├── Theme.qml                      # Paleta única del sistema + curvas de easing
│   ├── Hypr.qml                       # Envoltorio sobre Quickshell.Hyprland
│   ├── Battery.qml                    # Quickshell.Services.UPower
│   ├── Network.qml                    # nmcli por Process (no hay módulo nativo)
│   ├── BluetoothStatus.qml            # Quickshell.Bluetooth
│   ├── Volume.qml                     # Quickshell.Services.Pipewire
│   ├── NotifServer.qml                # NotificationServer — reemplaza swaync
│   ├── WorkspaceSync.qml              # Wallpaper + acento por workspace
│   └── UiState.qml                    # Visibilidad compartida dashboard/notif-center
└── modules/
    ├── bar/            Bar.qml, Workspaces.qml, Capsule.qml, SystemCapsules.qml
    ├── dashboard/       Dashboard.qml, ProfileHeader.qml, QuickToggles.qml,
    │                    Shortcuts.qml, Calendar.qml, VolumeMixer.qml
    └── notifications/   NotificationCard.qml, NotificationPopups.qml,
                         NotificationCenter.qml
```

**Convención de imports (QuickShell-specific, no es un patrón QML estándar):** QuickShell registra automáticamente el directorio de configuración como un módulo implícito `qs`, y cada subcarpeta como submódulo (`qs.services`, `qs.modules.bar`, ...). Los singletons se declaran con `pragma Singleton` + `Singleton { ... }` (tipo base de Quickshell, no `QtObject`) y **no requieren `qmldir`** — se descubren solo por convención de carpeta+nombre de archivo. Esto se confirmó inspeccionando una config de referencia real (`caelestia-dots/shell`) porque la documentación oficial de quickshell.org no cubre esta convención explícitamente.

**Un solo archivo = un widget**, mandatorio (ver directriz del brief): cualquier módulo nuevo futuro es una carpeta/archivo nuevo bajo `modules/`, sin tocar `shell.qml` salvo por la línea de instanciación.

---

## 2. Paleta y animación

`services/Theme.qml` centraliza la paleta ya establecida en el resto del sistema (bordes Hyprland en `themes/cyberdream/theme.lua`, rofi en `modules/rofi/*.rasi`):

- **Acentos núcleo** (bordes activos de Hyprland, base de la barra): lavender `#cba6f7`, blue `#89b4fa`, pink `#f5c2e7`.
- **Acentos neón** (reservados a superficies elevadas — dashboard, notificaciones — nunca la barra base, por directriz explícita del brief): magenta `#ff2a6d`, cyan `#05d9e8`, verde `#00ff9f`.
- **Curvas compartidas:** `durFast/durMed/durSlow` (140/240/420ms) + `Easing.OutCubic/OutBack/InOutQuad`, usadas consistentemente en todos los `Behavior on` del árbol para que la barra, el dashboard y las notificaciones se sientan como un solo sistema, no piezas sueltas.

**Gotcha real encontrado y corregido (ver §4.1):** QML interpreta los colores hex de 8 dígitos como `#AARRGGBB`, no `#RRGGBBAA`. Todo color con alpha en este módulo pasa por `Qt.rgba(r, g, b, a)` o por las constantes ya resueltas de `Theme.qml` — no hay hex de 8 dígitos sueltos en ningún otro archivo del módulo.

---

## 3. Detalle por ítem de scope

### 3.1 Barra (`modules/bar/`)

- `Workspaces.qml`: 9 slots fijos (igual que los binds `SUPER+1..9` de `core/keybinds.lua`). Activo = pastilla ancha + halo de glow con `Theme.activeAccent`; ocupado-inactivo = punto mediano gris; vacío = punto mínimo casi invisible. Todas las transiciones vía `Behavior on width/color` con `Easing.OutBack` — nunca un salto instantáneo.
- `SystemCapsules.qml`: red (nmcli, click abre `nm-applet-ctl toggle`), bluetooth (`Quickshell.Bluetooth`, click togglea el adapter), batería (`Quickshell.Services.UPower`), reloj (`SystemClock`, click abre el dashboard).
- `Capsule.qml`: componente genérico icono+valor reutilizado por las 4 cápsulas de sistema — el punto de extensión para agregar módulos nuevos a la barra.
- Despacho a Hyprland vía `Hyprland.dispatch("hl.dsp.focus({ workspace = \"N\" })")` — sintaxis Lua nativa de Hyprland ≥0.55 (Hito 002 §1.3), no el formato de dispatcher clásico.

### 3.2 Wallpaper + acento por workspace (`services/WorkspaceSync.qml`)

- Escucha `Hypr.activeId` (alimentado por `Hyprland.rawEvent` nativo de QuickShell, sin mecanismo paralelo).
- En cada cambio: dispara `workspace-wallpaper <ruta>` (nuevo script en `scripts.nix`, deliberadamente separado de `set-wallpaper` para saltar pywal/matugen y sentirse instantáneo) y fija `Theme.activeAccent` a un color del ciclo núcleo `(id-1) % 3`.
- Mapeo de wallpapers usa la librería real del usuario en `~/Pictures/Wallpapers/` (9 imágenes), no assets del repo.
- **Bug preexistente encontrado y corregido de paso:** `set-wallpaper` (ya existente desde antes de este hito) todavía usaba `${pkgs.swww}/bin/swww` — nixpkgs renombró el atributo a `pkgs.awww` y el binario resultante también se llama `awww`, no `swww`. El script fallaba en silencio en el paso de wallpaper (pywal/matugen sí corrían, enmascarando el fallo). Corregido a `${pkgs.awww}/bin/awww`.

### 3.3 Dashboard (`modules/dashboard/`)

Panel desplegable desde la cápsula del reloj (`UiState.toggleDashboard()`), glassmorphism (`Theme.surfaceElevated` + borde teñido con `Theme.activeAccent`), animación open/close vía scale+opacity con un `Timer` de gracia (`hideDelay`) para que la ventana siga mapeada durante el fade-out — si no, no hay animación de cierre posible.

Sub-widgets: `ProfileHeader` (usuario@host + `uptime -p`), `QuickToggles` (wifi/bluetooth/DND/mute), `Shortcuts` (chips que abren Thunar), `Calendar` (grid mensual, hoy resaltado con el acento activo — verificado contra la fecha real del sistema), `VolumeMixer` (sliders por nodo de Pipewire, salida y entrada por separado).

### 3.4 Centro de notificaciones (`modules/notifications/`)

`services/NotifServer.qml` instancia `NotificationServer` (Quickshell.Services.Notifications) y mantiene `popups` (activos, auto-descartados a 6s) e `history` (hasta 50). `NotificationCard.qml` es la unidad visual compartida entre el toast (`NotificationPopups`) y el historial (`NotificationCenter`) — borde izquierdo coloreado por urgencia (magenta=crítica, cyan=normal, verde=baja).

Esto convierte a QuickShell en el daemon de notificaciones real del sistema — **compite con swaync por el nombre `org.freedesktop.Notifications`**, y gana si arranca antes o si swaync no está corriendo. swaync se queda instalado y con su `systemd --user` service intacto (no se tocó `home.nix` ni el autostart) — ver §5 sobre por qué el corte definitivo se dejó pendiente.

---

## 4. Bugs reales encontrados por verificación en vivo (no por revisión de código)

Cada uno de estos solo se detectó porque la verificación fue "lanzar QuickShell contra la sesión Hyprland real + `grim` + `awww query` + `notify-send`", no solo "¿compila el flake". Se documentan aquí porque son la evidencia de por qué ese método de verificación es el correcto para este tipo de cambio, y porque el patrón general (síntoma sutil, causa no obvia) es reutilizable.

1. **Hex de 8 dígitos en QML es `#AARRGGBB`, no `#RRGGBBAA`.** Colores pensados como "blanco casi transparente" (`#ffffff08`) se renderizaban como amarillo opaco. Visible solo en un screenshot real, nunca en el código fuente. Fix: `Qt.rgba()` en todas partes.
2. **`SystemClock` expone `date`, no `currentDate`.** Tiraba `Invalid argument passed to formatDateTime()` en cada tick — visible solo en los logs de `qs`, no en la superficie visual (el reloj simplemente no aparecía).
3. **`Component.onCompleted` no es válido directamente sobre `ShellRoot`** ("Non-existent attached object"). QuickShell rechazaba la config entera al arrancar. Fix: envolver la referencia forzadora del singleton en un `QtObject` hijo.
4. **`NotificationPopups` y `NotificationCenter` colisionaban visualmente** — mismo anchor top-right, misma margin. Solo visible al forzar ambos abiertos a la vez durante la prueba. Fix: ocultar los popups mientras el centro está abierto.
5. **`services.upower.enable` no estaba declarado en ningún lado del sistema** — `Quickshell.Services.UPower` necesita que el nombre `org.freedesktop.UPower` sea activatable por D-Bus, y nada en `configuration.nix` lo proveía (el `battery-notify` existente lee `/sys/class/power_supply` directo, así que el hueco era invisible hasta ahora). Agregado a `configuration.nix`.
6. **`swaync` no muere con `kill`/`pkill`** — corre como `systemd --user` service (`swaync.service`) que se re-activa por D-Bus. Para probar el registro exclusivo de `NotifServer` hubo que `systemctl --user stop swaync.service`, no solo matar el PID. (Se restauró con `start` al terminar.)
7. **Gotcha de la propia sesión del agente, no del código:** `pkill -9 -f "bin/quickshell -p"` mata su propio shell invocador, porque `-f` matchea contra la línea de comando completa y esa línea literalmente contiene el string del patrón como argumento de `pkill`. Causó abortos silenciosos de scripts de prueba completos (exit code 1/144 sin explicación) hasta que se cambió a `pkill -9 quickshell` (sin `-f`, matchea solo el nombre del proceso).

---

## 5. Por qué QuickShell NO reemplazó a waybar/swaync en el autostart todavía

Esto es una decisión deliberada, no un ítem olvidado:

- **No se pudo correr `nixos-rebuild switch`** en esta sesión (sudo pide contraseña interactiva; el entorno del agente no tiene una). Todo se validó con `nixos-rebuild build` (construye el closure, no lo activa) más pruebas ad-hoc de QuickShell vía `nix shell nixpkgs#quickshell -c qs -p modules/quickshell` contra la sesión Wayland real ya corriendo — que es como se generaron todos los screenshots y verificaciones de este documento.
- Esto significa que **el sistema activo todavía no tiene `quickshell`, `kdePackages.qt6ct` ni `services.upower` en su PATH/generación real** — solo están en el store porque `build` los compiló, pero la generación de sistema activa (`/run/current-system`) es anterior a este hito.
- Si `modules/hyprland/core/autostart.lua` se hubiera cambiado para lanzar `quickshell` en vez de `waybar`+`swaync` en esta sesión, y Hyprland se reinicia (o la sesión se re-loguea) antes de que alguien corra `nix-rebuild-fast` con la contraseña real, **el autostart fallaría silenciosamente y el usuario se quedaría sin ninguna barra** — exactamente el escenario que el brief pidió evitar explícitamente para `modules/ml4w/`, aplicado aquí al mismo razonamiento.

**Siguiente paso manual, en orden, la próxima vez que Jerimy esté frente al teclado:**

1. `nix-rebuild-fast` (con la contraseña real) para activar `quickshell`, `qt6ct` y `services.upower` en el sistema de verdad.
2. Verificar visualmente que `qs -p ~/.config/quickshell` (ahora resuelto vía el symlink de Home Manager, no la ruta del repo) sigue viéndose igual que en los screenshots de esta sesión.
3. Recién ahí, editar `modules/hyprland/core/autostart.lua`: quitar `hl.exec_cmd("swaync")` y `hl.exec_cmd("waybar")`, agregar `hl.exec_cmd("qs")`. Mantener `~/.config/waybar/launch.sh` (bind `SUPER+SHIFT+B`) intacto como fallback manual durante un período de prueba.
4. Solo después de confirmar estabilidad en uso real (no en una sesión de prueba de 30 minutos), evaluar la eliminación de `modules/ml4w/settings/` (pendiente desde Hito 003) y de `modules/waybar/` completo.

---

## 6. Pendientes abiertos (heredados o nuevos)

### 6.1 Heredados de Hitos anteriores, aún sin resolver
- Refactor topológico del flake (`flake-parts`, `disko`, `sops-nix`/`agenix`, `nh`).
- Migración de rEFInd a gestión declarativa.
- Deprecación de `modules/ml4w/settings/` (5 archivos, pendiente desde Hito 003 — ahora doblemente pendiente de la estabilización de QuickShell, ver §5).
- `services.logind.settings.Login` (lid-switch en dock) — evaluado en Hito 003, no aplicado.
- Bug de matugen (`--prefer` ambiguo con fuente de color múltiple) en `set-wallpaper` — detectado en esta sesión al diagnosticar el bug de `swww`→`awww`, pero es una decisión de UX separada (qué preferencia default usar) y se dejó sin tocar.

### 6.2 Nuevos de esta sesión
- **Cutover de autostart pendiente** — ver §5, es el pendiente más importante de este hito.
- **`services.upower`** recién declarado, nunca activado en el sistema real (pendiente de switch) — confirmar que no rompe nada más una vez activo (no debería; es un servicio D-Bus pasivo).
- **Colisión de posición popups/notification-center** — resuelta con "ocultar popups si el center está abierto", pero es una solución de alcance mínimo; si en el futuro se quiere que convivan (ej. mostrar el toast desplazado en vez de ocultarlo), es un rediseño de layout pendiente.
- **Explícitamente fuera de alcance, sin tocar:** panel de IA/chat (diferido a un módulo futuro por decisión ya tomada), `sidepad-toggle`, mecanismo de Claude Code, quicklinks de rofi (`SUPER+CTRL+U`).

---

## 8. Addendum — Follow-up en la misma rama (mismo día, sesión posterior)

Las secciones 1-6 son el snapshot original, sin editar. Esto documenta una sesión de seguimiento en `hito-04-quickshell` que ejecutó exactamente los 4 pendientes marcados en §5 y parte de §6.2. **Supera puntualmente** la afirmación de §5 de que "QuickShell no reemplazó a waybar/swaync en el autostart" — eso ya no es cierto en el código de la rama (sigue sin probarse en el sistema activado, ver más abajo).

### 8.1 Los 4 cambios, en orden

1. **Autostart real.** `autostart.lua` ahora lanza `qs` en vez de `waybar`+`swaync`. Se encontró y corrigió un gap real de la sesión original: `home.nix` nunca linkeaba `modules/quickshell` a `~/.config/quickshell` (`xdg.configFile`) — sin eso, `qs` en autostart no habría encontrado ninguna config. También se activó `settings.watchFiles: true` en `shell.qml`.
2. **Keybinds.** `SUPER+CTRL+B` ahora mata y relanza `quickshell` (antes: señal específica de waybar). `SUPER+SHIFT+B` ahora togglea el dashboard vía `quickshell ipc call uiState toggleDashboard` (antes: `waybar/launch.sh`) — se agregó un `IpcHandler` a `UiState.qml` para esto. `SUPER+CTRL+T` (themeswitcher de waybar) se eliminó sin reemplazo directo.
3. **Acento matugen-driven.** `WallpaperPalette.qml` (nombrado así y no `Palette.qml` por una colisión real con el tipo built-in `QtQuick.Palette`, encontrada en runtime) lee una paleta cacheada por wallpaper que `workspace-wallpaper` genera corriendo matugen una sola vez por imagen, en background, sin bloquear el cambio de workspace. Se corrigió el bug preexistente de `--prefer` en matugen (`--prefer saturation`). Los colores de matugen se "vividize"-an (clamp de saturación/luminosidad en HSL) porque Material You por defecto elige tonos pastel, incompatible con la regla no-negociable de este sistema.
4. **Limpieza de lo muerto.** `modules/waybar/` completo y los 5 archivos restantes de `modules/ml4w/settings/` eliminados (verificado por grep, no asumido — todas sus referencias vivían exclusivamente dentro de `modules/waybar/`). Paquetes `dunst` y `swaynotificationcenter` retirados de `home.nix`. Bonus: se reemplazaron los `layer_rule` muertos de swaync/waybar en `window-rules.lua` por uno para el namespace real de QuickShell (`"quickshell"`, confirmado con `hyprctl layers -j`) — esto además cierra un hueco real de la sesión original, donde el dashboard y el centro de notificaciones nunca tuvieron blur de compositor de verdad detrás del glassmorphism.

### 8.2 Estado de verificación — sigue sin haber `switch`

Mismo bloqueo que la sesión original: sin contraseña de sudo interactiva disponible, todo se validó con `nixos-rebuild build` (5 veces, una por cambio funcional) más pruebas en vivo de QuickShell contra la sesión Hyprland real (`qs -p modules/quickshell`, y una vez con un symlink manual `~/.config/quickshell` → repo para probar la invocación exacta `qs` sin argumentos que usa el autostart real, removido después de la prueba). El cambio de `window-rules.lua` es la única pieza de este follow-up que **no** se pudo probar en vivo: `~/.config/hypr` ya es un symlink de home-manager de un switch real anterior a esta sesión, así que Hyprland corre una generación vieja del store, ajena a estos archivos de trabajo — apuntar el compositor real a la config en progreso sin un switch de verdad habría arriesgado la sesión real del usuario. Se dejó verificado solo por consistencia de patrón contra la regla `rofi-glass` ya probada, no por ejecución.

### 8.3 Incidente — pantalla bloqueada

Durante la verificación del ítem 3 se mató por error una instancia de `hyprlock` disparada por idle-timeout (confundida con un proceso de prueba propio), lo que dejó al compositor en su fallback nativo de "lockscreen died" (Hyprland rechaza un lock client nuevo tras la muerte de uno viejo salvo que se permita explícitamente). Se recuperó con:
```
hyprctl eval "hl.config({misc={allow_session_lock_restore=true}})"
hyprctl dispatch "hl.dsp.exec_cmd([[hyprlock]])"
```
`hyprctl eval "<lua>"` es un verbo de nivel superior no documentado en `hyprctl --help` de este fork con motor Lua — `hyprctl keyword` falla explícitamente ("can't work with non-legacy parsers. Use eval.") bajo este engine. Vale la pena recordarlo junto a los gotchas de `hl.dsp.*` ya documentados en el Hito 002 §1.3. La pantalla quedó bloqueada de verdad al final (correcto) — la lección real: un lock screen durante trabajo desatendido es una señal a respetar, no un obstáculo para matar.

### 8.4 Pendientes actualizados

- Los 4 puntos de §5 (roadmap de cutover) ya están hechos en la rama. Lo único que falta es que Jerimy corra `nix-rebuild-fast` (contraseña real) y confirme visualmente que todo se ve/comporta igual que en las pruebas de esta sesión antes de mergear.
- `services.logind.settings.Login` (lid-switch en dock, Hito 003) — sigue sin aplicar.
- Refactor topológico del flake, migración de rEFInd — siguen sin tocar.
- Nuevo: el `layer_rule` de `window-rules.lua` para el namespace `quickshell` está sin probar en vivo (ver §8.2) — confirmar visualmente el blur del dashboard/notificaciones apenas se pueda hacer un switch real.

---

## 10. Addendum 2 — dos bugs reales y pase de calidad de animación

Tercera sesión en la misma rama. Alcance: dos bugs reportados por Jerimy sobre el uso real de la barra (batería, bluetooth) y un pase de pulido de movimiento/interacción sobre lo ya construido en §1-8, sin tocar el layout estructural (la barra sigue arriba, sin dock ni auto-hide).

### 10.1 Bug — batería mostraba "1%"

Causa real, confirmada en vivo con una config QML de prueba apuntando al `UPower.displayDevice` real: `UPowerDevice.percentage` en Quickshell 0.3.0 es una fracción `0.0-1.0` (62% real → `percentage = 0.62`), no `0-100` como decía el comentario original en `Battery.qml`. `Math.round(0.62) = 1` — de ahí el "1%" fantasma en cualquier batería por encima del 50%. Fix: escalar `× 100` antes de redondear (`services/Battery.qml`).

De paso, `icon()` ya reflejaba nivel + estado de carga desde la sesión anterior (tramos de carga + ícono distinto en fully-charged/charging) — no hizo falta reescribirlo. Lo que sí se agregó es un **anillo de progreso real** detrás del ícono (ver §10.3).

### 10.2 Bug — el toggle de bluetooth "no hacía nada"

Diagnóstico en vivo antes de tocar código: se instrumentó el `BluetoothStatus.qml` real (no una copia) con un `ShellRoot` de prueba que llama `toggle()` y escucha `onPoweredChanged` — el wiring **ya funcionaba** (`true → false → true` confirmado). El bug real no estaba en QuickShell: el adaptador estaba rfkill soft-blocked, y en ese estado BlueZ rechaza `Powered=true` en silencio. Se confirmó de forma concluyente corriendo `bluetoothctl power on` directamente (sin QuickShell de por medio) — falló idéntico: `org.bluez.Error.Failed`. Un click que no cambia nada visualmente es indistinguible de un handler roto; de ahí el reporte.

Se intentó primero leer un estado `blocked` en `BluetoothAdapter` (existe en el qmltypes de `Quickshell.Bluetooth`, pero pertenece a `BluetoothDevice`, no al adapter — error de lectura del propio autor de este cambio, corregido tras un warning en vivo de "Unable to assign [undefined] to bool"). Como no hay señal QML para detectar rfkill, la solución robusta implementada es: `toggle()` para encender ahora corre `rfkill unblock bluetooth` (vía `Process`, paquete `util-linux` ya en el sistema) y solo entonces pone `adapter.enabled = true` en el `onExited`. Desbloquear un adaptador ya desbloqueado es no-op, así que no hay costo en el caso común. Verificado en vivo el ciclo completo: `rfkill block` → toggle() → `rfkill list` confirma `Soft blocked: no` y `bluetoothctl show` confirma `Powered: yes`.

### 10.3 Pase de animación

Referencia dada: la config pública "soramane" — el pedido explícito fue "se siente genérico, en la referencia se nota la suavidad cuando el mouse pasa cerca", no una lista de features nuevas porque sí.

- **Anillo circular (batería).** Componente nuevo `modules/bar/CircularGauge.qml` (`QtQuick.Shapes` + `PathAngleArc`, extremos redondeados vía `ShapePath.RoundCap`, valor animado con `Behavior + NumberAnimation`, tope en `359.9°` porque a `360°` exactos el arco colapsa visualmente por el solape de los caps redondeados — confirmado con captura de pantalla real vía `grim`, no asumido). `Capsule.qml` gana una prop opcional `gauge: -1..1` (sigue siendo la misma cápsula genérica de red/bluetooth/batería/reloj — solo la batería la usa hoy, ver `SystemCapsules.qml`).
- **Tabs/segmented control.** No se tocó — el dashboard no tiene tabs, no hay nada que animar acá. Documentado en vez de inventar UI nueva fuera de alcance.
- **Hover con scale.** `Workspaces.qml` (pastillas de workspace, antes sin ninguna reacción a hover) y `Shortcuts.qml` (chips de carpetas del dashboard) ahora escalan suavemente (`Easing.OutBack`, `Theme.durFast`) al pasar el mouse — antes solo cambiaban de color.
- **Proximidad ("wakes up as you approach").** Implementado a nivel de `Capsule.qml`: cada cápsula tiene una zona de detección invisible más grande que su propio tamaño visual (`HoverHandler` sobre un `Item` +60px/+40px), y el glow de fondo interpola su opacidad según la distancia real del cursor al centro, no solo un binario dentro/fuera. No se implementó como auto-hide de la barra completa — el brief pidió explícitamente mantener el layout estructural intacto (barra arriba, sin reubicación), así que el efecto se aplicó localmente por widget en vez de re-arquitecturar el `PanelWindow`.
- **Auditoría de consistencia.** `grep -rn "duration:"` y `grep -rn "easing.type:"` sobre todo `modules/quickshell/` — el 100% de usos preexistentes ya referenciaba `Theme.dur*`/`Theme.ease*`, ningún valor ad-hoc que consolidar. Los widgets nuevos de este pase siguen el mismo patrón.

### 10.4 Límites de verificación de este pase

- El ciclo completo de bluetooth (block → toggle → unblock real) y la fracción de batería se verificaron con datos reales del hardware, no simulados.
- El anillo circular se verificó visualmente con capturas `grim` reales, incluyendo con datos de batería en vivo (52%, ícono + anillo rosa correctos).
- La animación de proximidad (interpolación continua por distancia del cursor) **no se pudo verificar con movimiento real de mouse** — no hay `ydotool`/`wlrctl`/`dotool` instalados en este sistema para sintetizar movimiento de puntero, y `hyprctl` no expone un dispatcher para mover el cursor. Se verificó que el QML parsea y corre sin errores (`HoverHandler`, `PointerHandler.point.position` disponibles y funcionando en Quickshell 0.3.0), pero la sensación real de "se despierta según te acercas" queda pendiente de confirmación visual por Jerimy con su propio mouse.
- `nixos-rebuild build` pasó limpio (solo warnings preexistentes de versión Home Manager/Nixpkgs, no relacionados a este cambio).

### 10.5 Nota sobre el commit de este pase

Esta sesión se cortó por un bug del propio sistema de notificaciones de tareas en background (mecanismo ajeno a este repo) mientras `nixos-rebuild build` corría. Un mecanismo de recuperación externo autogeneró un commit `wip: cambios pendientes al momento del corte por bug de notificación` (`0892988`) con todo el estado del working tree en ese momento **y lo empujó a `origin/hito-04-quickshell` antes de que esta sesión pudiera continuar** — no fue un `git commit`/`git push` intencional de esta sesión, y para cuando se detectó ya era historia compartida (reescribirla habría significado force-push sobre una rama remota, algo que no se hace sin confirmación explícita). Ese commit mezcla, sin querer, un cambio de `hosts/laptop/home.nix` ajeno a este pase (`vivid generate modus-operandi` → `lava`, ya pendiente en el working tree antes de que arrancara esta sesión) junto con los fixes de batería/bluetooth y el pase de animación descritos arriba. El contenido en sí (diffs) es correcto y fue verificado en vivo antes del corte; lo único atípico es el mecanismo y el agrupamiento del commit, no el código.

---

## 12. Addendum 3 — menú de energía, picker de wallpaper, DND con duración, más matugen

Cuarta sesión en la misma rama, ya con `spotify`/`discord` instalados y un `nixos-rebuild switch` real corrido por Jerimy antes de empezar (primera vez en todo Hito 004 que hay un sistema activado real detrás, no solo `nixos-rebuild build`). Dato importante descubierto al arrancar: `~/.config/quickshell` ahora apunta a un snapshot inmutable del store (de ese switch), no al working tree — así que las pruebas en vivo de esta sesión (`qs -p <repo>`) corren como una instancia **separada** de la real (compiten brevemente por el nombre DBus de notificaciones, de ahí el warning inofensivo "already registered" en cada prueba), y ninguna edición de esta sesión fue visible en el escritorio real de Jerimy durante el trabajo — solo lo será después del próximo switch.

### 12.1 Los 5 puntos del pedido

1. **Menú de energía nativo** (`modules/quickshell/modules/powermenu/PowerMenu.qml`) reemplaza `wlogout-launch` por completo. Dock flotante en la esquina inferior derecha, independiente del layout de la barra (que sigue arriba sin tocarse). Reusa literalmente el patrón de proximidad de `Capsule.qml` (zona `HoverHandler` más grande que el elemento + distancia normalizada al centro) pero acá el resultado controla cuánto se despliega el abanico de acciones (lock/suspend/logout/reboot/shutdown), no solo un glow. Un click en el trigger fija el estado abierto vía `UiState.powerMenuOpen`/`togglePowerMenu()` (mismo patrón de IPC que dashboard/notif center) — necesario también porque este entorno no tiene `ydotool`/`wlrctl` para sintetizar movimiento real de mouse, así que el pin por click fue la única vía de verificar la interacción en vivo. Una vez confirmado funcionando (ver §12.3), se eliminó `wlogout-launch` de `scripts.nix`, el paquete `wlogout` y su entrada `xdg.configFile` de `home.nix`, y `modules/wlogout/` completo (layout/style.css/icons). `XF86PowerOff` y `SUPER+CTRL+Q` ahora llaman `quickshell ipc call uiState togglePowerMenu`.
2. **Picker de wallpaper** (`modules/quickshell/modules/dashboard/WallpaperPicker.qml`), grid de miniaturas de `~/Pictures/Wallpapers` con el mismo lenguaje visual que `Shortcuts.qml`. Al clickear llama `WorkspaceSync.setWallpaperForCurrent()`, no `workspace-wallpaper` directo — así el pick manual pasa por el mismo pipeline de cacheo/acento que el ciclo automático. Se encontró y corrigió un gap real en el camino: sin un mapa de overrides, un pick manual se habría revertido solo con volver a ese workspace (`wallpaperFor()` era puramente función del array fijo). `SUPER+CTRL+W` (waypaper manual) ahora abre el dashboard; `SUPER+ALT+W` (`waypaper --random`) se conserva a propósito, documentado, porque no hay equivalente de un tecleo para "aleatorio" en el picker nuevo.
3. **DND con duración** (30m/1h/2h/hasta reiniciar): `NotifServer.qml` gana `enableDnd(durationMs)`/`disableDnd()` con un `Timer` real; `durationMs === 0` es "hasta reiniciar" (sin timer). `DndToggle.qml` reemplaza el `ToggleButton` genérico de DND en `QuickToggles.qml`: un click estando apagado despliega un acordeón horizontal de duraciones (mismo idioma `Behavior on implicitWidth` que ya usaba `Capsule.qml`), un click estando encendido apaga directo. `QuickToggles` pasó de `Row` a `Flow` porque el acordeón expandido (~200px) no cabía junto a los otros 3 toggles sin desbordar el ancho fijo del dashboard.
4. **Acento matugen más amplio**: se auditó cada uso de colores núcleo/neón fuera de `Theme.qml` antes de tocar nada (ver diffs, grep referenciado en el commit). Se amplió `Theme.activeAccent` a los tres separadores de sección del dashboard y al borde de los chips de `Shortcuts.qml` en hover. Deliberadamente NO se tocaron los colores identidad-por-cápsula (red=azul, bluetooth=lavanda, batería=rosa/danger) ni el código de urgencia de notificaciones (crítico=magenta, bajo=verde, normal=cian) — son sistemas de significado funcional, no decoración, y atarlos al wallpaper habría sido una regresión de legibilidad, no una mejora.
5. **Disciplina de animación**: todo lo nuevo de esta sesión usa `Theme.dur*`/`Theme.ease*` exclusivamente — mismo patrón auditado limpio en el pase anterior (§10.3), sin valores ad-hoc nuevos.

### 12.2 Bugs/gaps reales encontrados en el camino (no asumidos)

- `WorkspaceSync.wallpaperFor()` no soportaba overrides manuales — encontrado al razonar sobre el flujo del picker antes de escribirlo, no en runtime. Corregido con el mapa `overrides` (§12.1.2).
- El `Row` de `QuickToggles.qml` habría desbordado silenciosamente bajo el `clip:true` del `Flickable` del dashboard apenas el DND se expandiera — detectado por cálculo de anchos antes de probar en vivo (56×4 + spacing vs. ~200px del acordeón expandido no entran en los ~300px de ancho del contenido), no por observar el bug ya ocurrido. Corregido cambiando a `Flow`.
- Dashboard.qml terminó con dos cambios de items distintos (2 y 4) en hunks de diff adyacentes/entrelazados; separarlos en parches de git independientes no era práctico sin arriesgar un parche roto, así que el tinte de los separadores (ítem 4) quedó en el mismo commit que el picker (ítem 2), documentado explícitamente en ambos mensajes de commit.

### 12.3 Verificación en vivo — qué se pudo probar y qué no

- **Probado con evidencia real**: el menú de energía completo (`qs -p` + IPC `togglePowerMenu` + captura `grim` mostrando las 5 acciones desplegadas con los tintes de acento correctos); el picker de wallpaper (dashboard abierto por IPC, captura mostrando el grid con miniaturas reales cargando desde la carpeta real); el timer de DND (arnés QML standalone que importó el `NotifServer.qml` real y confirmó `enableDnd(1200)` → auto-apagado a los 1.2s, y `enableDnd(0)` → sigue encendido 3+ segundos después sin timer); namespace de layer-shell del nuevo `PowerMenu` confirmado como `"quickshell"` vía `hyprctl layers -j` (hereda el blur existente sin regla nueva). `nixos-rebuild build` pasó limpio.
- **No verificable en este entorno**: la sensación real de "se despliega según te acercas" del menú de energía (sin `ydotool`/`wlrctl` no hay forma de sintetizar movimiento de cursor continuo) — se verificó la lógica y el resultado final vía el pin por click, pero no el gesto de aproximación en sí. Tampoco se verificó si `XF86PowerOff` con `{ locked = true }` efectivamente muestra el menú de energía sobre la pantalla de bloqueo real de hyprlock — `ext-session-lock-v1` está diseñado para bloquear otras superficies layer-shell mientras está bloqueado, así que es posible que esto tampoco haya funcionado nunca con `wlogout` (misma clase de superficie); no se intentó una prueba en vivo de esto para no repetir el incidente de pantalla bloqueada de la sesión anterior (§8.3).

### 12.4 Pendientes actualizados

- Confirmar visualmente con el próximo `nix-rebuild-fast` real: el menú de energía (especialmente el gesto de proximidad con mouse real), el picker de wallpaper, el acordeón de DND, y si `XF86PowerOff` realmente hace algo útil estando bloqueado.
- El resto de pendientes de §6 y §8.4 (refactor de flake, rEFInd, lid-switch) sigue igual, sin tocar en esta sesión.

---

## 14. Addendum 4 — correcciones visuales sobre feedback en vivo del escritorio real

Quinta sesión en la misma rama. A diferencia de los follow-ups anteriores, el disparador acá no fue un pedido de features nuevas sino **feedback visual de Jerimy mirando su propio escritorio real** después del primer `nixos-rebuild switch` verdadero de todo Hito 004 (ver inicio de §12). Cuatro correcciones puntuales sobre piezas ya construidas.

### 14.1 Descubrimiento importante de infraestructura de pruebas

`~/.config/quickshell` ahora apunta a un snapshot inmutable del store (por el switch real). Esto significa que cada `qs -p <repo>` de esta sesión corre como una instancia **separada** de la real, y ambas pueden renderizar superficies en la MISMA posición de pantalla simultáneamente (la barra ocupa siempre 0,0-1366x38; el PowerMenu siempre la esquina inferior derecha) — un screenshot en ese caso puede mostrar la superficie de la instancia real (vieja) por encima de la de prueba (nueva), dando la falsa impresión de que un fix no funcionó. Pasó de verdad en el ítem 1 (ver 14.2) y de nuevo casi pasa en el ítem 3. Solución aplicada de acá en adelante: para cualquier verificación visual de una superficie que comparta posición con algo ya renderizado por la instancia real, se corre la prueba con un offset temporal (`margins` cambiados solo en la copia de scratch, nunca en el archivo real) para que ambas queden visualmente distinguibles en la misma captura.

### 14.2 Incidente — se mató la instancia real de producción por accidente

Durante la limpieza de un debug harness para el ítem 1, un `pkill -9 quickshell` (sin `-f`, pensado para matar solo instancias de prueba) mató también la instancia real de producción (autostart de Jerimy), no solo la de prueba — porque el patrón hace match por NOMBRE de proceso, y la real también se llama `quickshell`. Se detectó de inmediato (`pgrep quickshell` quedó vacío) y se relanzó con la invocación exacta de autostart (`qs` sin argumentos, dejando que resuelva `~/.config/quickshell` solo), confirmado con una captura de la barra real ya funcionando de nuevo antes de seguir con cualquier otra cosa. Mismo tipo de error que ya se había documentado en §8.3 de otra forma (matar sin querer algo que sí estaba en uso) — la lección concreta esta vez: con una instancia real persistente corriendo, cualquier `pkill`/`kill -9` por nombre es peligroso; de acá en adelante todo kill de instancia de prueba en esta rama se hace por PID capturado (`$!`), nunca por nombre.

### 14.3 Los 4 puntos del feedback

1. **Trigger del PowerMenu siempre visible.** La lógica de proximidad (`win._amount`) ya era correcta — el bug era que el `Rectangle` del trigger se dibujaba a opacidad/color/borde completos sin importar `_amount`. Ahora `opacity`/`scale` del trigger derivan de `_amount` (mismo mecanismo Behavior-driven que ya animaba el despliegue del abanico), y en reposo queda un punto de 8px en el mismo centro en vez de invisibilidad total (una hotzone 100% transparente sería indescubrible para alguien que no sepa que esa esquina es interactiva). El hitbox de click sigue siendo el mismo tamaño aunque esté en opacidad 0.
2. **Picker de wallpaper sobrecargando el dashboard.** Resuelto con pestañas reales (Dashboard/Wallpapers/Media) — ver §14.4 para el proceso de esa decisión, que necesitó una pregunta directa a Jerimy porque el pedido original asumía tabs que no existían en el repo.
3. **Fondo de la barra sin tinte de acento.** Antes solo la línea de 2px de abajo usaba `Theme.activeAccent`; el resto era `Theme.surface` plano. Se agregó una capa `Rectangle` a opacidad 0.09 con el acento activo, superpuesta sobre la base oscura (no reemplazándola) — sigue siendo vidrio oscuro con tinte, no una barra de color.
4. **Lanzadores reales de Discord/Spotify.** `AppLaunchers.qml`, reusando `Capsule.qml` de verdad (se le agregó una prop `iconSource` opcional que cambia el glifo de texto por un `Quickshell.Widgets.IconImage` real vía `Quickshell.iconPath()`). Un click enfoca la ventana si ya existe o la lanza si no, vía un script nuevo `app-toggle CLASE COMANDO` (scripts.nix) que usa la sintaxis Lua de este fork (`hl.dsp.focus({window = "class:^(...)$"})`) — confirmado en vivo que la sintaxis clásica `hyprctl dispatch focuswindow` falla acá.

### 14.4 Cómo se resolvió la ambigüedad del ítem 2 (tabs)

El pedido original decía "dale su propia pestaña junto a Dashboard/Media/Performance/Workspaces (revisá cómo están armadas esas pestañas y seguí el mismo patrón)" — pero un grep completo del árbol (`TabBar`, `tabIndex`, `currentTab`, `Media`, `Performance`) no encontró nada: el dashboard era una sola columna vertical sin ningún sistema de pestañas. En vez de asumir cuál de las dos lecturas posibles era la correcta (¿construir un sistema de tabs entero, con el riesgo de inventar contenido para "Performance"/"Workspaces" que no existe, o es un malentendido y alcanza con separar el picker a otra superficie?), se preguntó directamente. Jerimy eligió construir el sistema de tabs real.

Con esa dirección, se armaron 3 pestañas con contenido real (Dashboard/Wallpapers/Media) y se documentó explícitamente por qué NO se inventaron "Performance" (no hay ningún widget de CPU/GPU/memoria construido en todo Hito 004 — sería una pestaña vacía) ni "Workspaces" (ya vive en la barra, una pestaña duplicada no aportaría nada) — ver commit `3956db8` y §14.3.2. De paso, esto permitió cerrar un pendiente real de la sesión de animación (dos rondas atrás, §10.3): el indicador deslizante de pestañas, documentado ahí como "no aplica, no hay tabs" — ahora sí aplica, y `TabBar.qml` lo implementa con `Behavior on x`.

### 14.5 Bugs reales encontrados por verificación en vivo (no asumidos)

- **Batería/bluetooth**: ninguno nuevo esta sesión (ya cubiertos en §10).
- **Spotify — clase de ventana real distinta a la declarada.** El `.desktop` de spotify declara `StartupWMClass=spotify`, pero lanzando la app de verdad y leyendo `hyprctl clients -j`, la clase real es `Spotify` (con mayúscula). Si se hubiera confiado en el `.desktop` sin probar, la detección de "¿ya está corriendo?" y el re-foco habrían fallado en silencio siempre. También el ícono correcto es `spotify-client`, no `spotify` (`Quickshell.hasThemeIcon("spotify")` da `false`).
- **Quickshell.Hyprland no expone lista de clientes por QML.** Su archivo de introspección (`.qmltypes`) viene vacío — no hay forma de confirmar qué propiedades expone sin probar en vivo. Se resolvió consultando `hyprctl clients -j` desde `Hypr.qml` (mismo patrón que `sidepad-toggle` ya usaba fuera de QML), no asumiendo una API que no se pudo verificar.
- **Sintaxis de foco por ventana bajo el motor Lua.** `hyprctl dispatch focuswindow "class:^(...)$"` (sintaxis clásica) fallá con "expected a dispatcher"; la forma que sí funciona es `hyprctl dispatch "hl.dsp.focus({ window = [[class:^(...)$]] })"` — confirmado con un window real (firefox) antes de escribir el script `app-toggle`.

### 14.6 Verificación en vivo — qué se pudo y qué no

- **Probado con evidencia real:** las 4 correcciones, cada una con captura de pantalla y/o log de eventos reales. El launcher de apps se probó lanzando y cerrando Discord y Spotify de verdad (no solo el script en aislado): instancia única al lanzar, re-foco (no duplicado) al repetir, y el borde "activo" de la cápsula encendiéndose en vivo al abrirse la app real. `nixos-rebuild build` pasó limpio (con `--option substitute false` por una falla de DNS/nix-daemon no relacionada, ver más abajo).
- **No verificable en este entorno:** igual que en §12.3, la sensación real de "aparece según te acercas" del trigger del PowerMenu no se pudo probar con movimiento de mouse real (sigue sin `ydotool`/`wlrctl`).
- **Incidente ajeno detectado, no causado por esta sesión:** a mitad de sesión, `nixos-rebuild build` falló con `cache.nixos.org` sin resolver DNS y el nix-daemon se cayó (systemd lo reinició solo). `getent hosts cache.nixos.org` seguía sin resolver al momento de escribir esto. No se investigó a fondo por estar fuera de alcance de este hito, pero vale la pena que Jerimy lo revise por separado — con `--option substitute false` el build igual pasó limpio, así que no bloqueó esta sesión.

### 14.7 Pendientes actualizados

- Confirmar visualmente con el próximo `nix-rebuild-fast` real: las 4 correcciones de este addendum, en especial el trigger del PowerMenu (proximidad real) y las 3 pestañas del dashboard.
- Investigar por separado (fuera de alcance de Hito 004) la falla de resolución DNS de `cache.nixos.org` / el crash del nix-daemon — ver §14.6.
- El resto de pendientes de §6, §8.4 y §12.4 sigue igual.

---

## 15. Estado de Ratificación

Snapshot verdadero al cierre del Hito 004 (secciones 1-7) más sus cuatro follow-ups en la misma rama (secciones 8, 10, 12 y 14). Cualquier cambio posterior invalida secciones específicas y debe generar Hito 005. No modificar retroactivamente — versionar hitos.

**FIN DEL DOCUMENTO — Hito 004**
