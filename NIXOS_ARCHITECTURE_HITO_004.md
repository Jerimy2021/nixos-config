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

## 16. Addendum 5 — video de referencia real, reubicación del power menu, glass real, carrusel de tabs, notificaciones con gestos

Sexta sesión en la misma rama. Disparador distinto a los anteriores: Jerimy proveyó un video showcase de QuickShell ("soramane", el proyecto real detrás es `caelestia-dots/shell`, GPLv3) como referencia de calidad de movimiento/interacción a alcanzar, y **más tarde** acceso de solo lectura al código fuente real (`~/reference/caelestia-shell`) que reemplazó la inferencia visual del video por lectura de QML real. Disciplina de dos fases explícita: Fase 1 (análisis, cero QML tocado, documento `NIXOS_SHELL_VIDEO_ANALYSIS.md` con extracción de frames vía ffmpeg + lectura de código real) aprobada por Jerimy antes de empezar Fase 2 (implementación). Cuatro piezas implementadas, cada una decidida explícitamente como "portar adaptado" o "restylear en el lugar" — nunca reemplazo total de `modules/quickshell/` (las piezas propias del proyecto — lanzadores de Discord/Spotify, sidepad, matugen por workspace, quicklinks — no estaban en negociación en ningún momento).

### 16.1 Metodología de análisis (resumen — el detalle completo vive en `NIXOS_SHELL_VIDEO_ANALYSIS.md`)

1. Contact sheet (`ffmpeg fps=1/2,scale=480:-1,tile=4x7`) para overview + 9 ráfagas de frames a resolución completa alrededor de momentos de transición, todo vía `nix shell nixpkgs#ffmpeg` (no instalado en el sistema). Produjo estimados de layout/motion/tokens explícitamente marcados como no medidos.
2. Con acceso real al repo fuente, cada estimado se contrastó contra el código y se corrigieron explícitamente los que estaban mal (no se sobreescribió el análisis original sin decir qué cambió y por qué) — la corrección más importante: lo que el video sugería como "vidrio con blur" resultó ser, leyendo `services/Colours.qml` y `components/effects/Elevation.qml` del proyecto real, una superficie **opaca con tinte** más una **sombra de elevación real** (`RectangularShadow`/`MultiEffect`, tipos estándar de `QtQuick.Effects`, no del plugin nativo) — nunca blur de fondo generalizado. Esto cambió el enfoque del ítem de la barra (ver 16.3).
3. Chequeo explícito de dependencia del plugin C++ nativo de Caelestia (`plugin/src/Caelestia/`, CMake+Qalculate+Pipewire+Aubio+Cava) para cada pieza portada — tabla completa en el documento de análisis §7.7. Conclusión: **ningún componente de esta ronda necesitó empaquetar el plugin nativo como derivación Nix** — cada símbolo nativo encontrado (`SessionManager.exec`, `ButtonRow`, `CUtils.clamp`, `ImageAnalyser`) tenía sustituto trivial en QML/JS puro o ya teníamos equivalente propio.

### 16.2 Power menu — relocación completa, no restyle

Decisión final (revisada una vez, ver el propio `NIXOS_SHELL_VIDEO_ANALYSIS.md` §7.1/§8): el trigger se movió de una `PanelWindow` flotante en la esquina inferior derecha (con expansión por proximidad, construida y ajustada en las dos rondas anteriores) a una `Capsule` más dentro de `Bar.qml`, igual que Discord/Spotify. Toda la lógica de proximidad (`proximityZone`, `HoverHandler`, distancia normalizada) se **eliminó por completo** — no coexiste con la versión nueva, no quedó código muerto. El panel de acciones ahora es un dropdown top-right, mismo patrón que Dashboard/NotificationCenter (`UiState` extendido con exclusión mutua entre los tres: abrir uno cierra los otros dos).

Se agregó un paso de **confirmación por hold** (mantener presionado ~600ms, arco de progreso radial vía `Shape`/`PathAngleArc`) en cada botón de acción — requisito de Jerimy sin precedente en ningún lado consultado: ni el video (no aparece ningún power menu en los 49.4s grabados) ni el código real (`modules/session/Content.qml` de Caelestia ejecuta al instante en click/Enter, sin confirmación). Diseño propio, no adaptado.

**Verificado en vivo:** capsule renderizando en la posición correcta de la barra (confirmado con captura tras cambiar temporalmente a un workspace vacío para no interrumpir el trabajo real de Jerimy — foot en fullscreen ocultaba la barra en el workspace activo), panel dropdown abriendo/cerrando vía IPC con el estilo correcto (5 botones circulares, colores por acción). **No verificable:** el gesto de hold-and-release en sí (sin `ydotool`/entrada sintética, mismo límite de siempre) — se armó y se revisó el código, no se ejecutó con un dedo real.

### 16.3 Barra — tinte real + sombra de elevación, no blur

El fix de la ronda anterior (§14.3.3, overlay plano a 9% de opacidad) se reemplazó por dos técnicas combinadas, elegidas tras la investigación de 16.1:

1. `Theme.tintSurface(base, accent, strength)` — mezcla el hue/saturación del acento activo hacia la superficie base en espacio HSL, preservando luminosidad y alpha del original. Reemplaza el color base directamente, no es una capa encima.
2. Sombra de elevación real vía `layer.effect: MultiEffect { shadowEnabled: true, ... }` sobre el rectángulo de superficie de la barra. La `PanelWindow` se hizo más alta que la barra visual (44px vs 38px) a propósito, para darle a la sombra margen de "sangrado" sin que la recorte el buffer de la superficie Wayland — el `exclusiveZone` real para el tiling de ventanas se mantuvo en 38.

**Verificado en vivo con capturas en 2 workspaces con acentos distintos** (naranja/amarillo cálido) para confirmar que el tinte sigue a `Theme.activeAccent` y no es una coincidencia de un solo hue — se ve claramente el cambio de tono en ambos casos, y una captura de mayor altura confirmó la sombra visible debajo del borde inferior de la barra (banda oscura difusa antes del contenido de la ventana de abajo).

### 16.4 Dashboard — carrusel de pestañas portado

Se reemplazó el salto instantáneo (`visible: dashboardTab === N`) por el mecanismo real de `caelestia-dots/shell` (`modules/dashboard/Content.qml`): un `Flickable` con las 3 pestañas puestas en fila dentro de una `Row`, `contentX` animado hacia la posición de la pestaña activa. No se portó su sistema de `Loader` con activación diferida por `visibleArea` (nuestras 3 pestañas son livianas) ni el swipe manual (fuera de alcance esta ronda, `interactive: false` — solo el click en la tab bar dispara la animación). Comentario de atribución (URL + GPLv3) directamente sobre el bloque adaptado, según acuerdo explícito de esta ronda.

**Verificado en vivo:** las 3 pestañas (Dashboard/Wallpapers/Media) renderizan correctamente tras el slide, sin sangrado de contenido entre paneles, probado vía IPC (`setDashboardTab`) en una copia aislada con offset de posición.

### 16.5 Notificaciones — gestos portados, modelo de reemplazo confirmado (no stacking)

Se portaron 3 gestos individuales de `Notification.qml` de Caelestia, adaptados: arrastre vertical para expandir/colapsar el cuerpo completo (antes truncado a 3 líneas sin forma de ver el resto), swipe horizontal para descartar, y pausa del timer de auto-dismiss mientras el mouse está encima. Se **descartó explícitamente** su modelo de `ListView` apilado — Jerimy pidió una sola tarjeta visible, reemplazo por crossfade cuando llega una nueva (ni cola ni conteo de pendientes). Implementado con dos slots `Loader` que se turnan como "frente" cada vez que cambia la última notificación de `NotifServer.popups`.

`NotifServer.qml` se extendió con un registro `{notif, timer}` (antes el `Timer` de auto-dismiss se creaba sin guardar referencia, así que no había forma de pausarlo desde afuera) — expone `pauseDismiss`/`resumeDismiss` por notificación puntual.

### 16.6 Bugs y hallazgos reales de esta sesión

- **El "vidrio" del video no es blur** (ver 16.1) — hallazgo de investigación, no de verificación en vivo, pero cambió una decisión de implementación real (16.3).
- **El power menu real de Caelestia SÍ vive en la bar** (`modules/bar/components/Power.qml`) — confirmado leyendo el código, contradice el estimado de la Fase 1 de "sin evidencia ni a favor ni en contra" (el video simplemente no lo mostró en los 49.4s grabados, pero el código sí lo tiene).
- **Los iconos por-app en los indicadores de workspace también existen de verdad** en el proyecto real (`Workspace.qml`, gateado por un flag de config) — corrección a la Fase 1, que decía "no tengo referencia real para esa opción". Sigue **diferido, no implementado esta ronda** (decisión explícita de Jerimy: alcance ya suficiente).
- **Bug de identidad en `property list<var>` con objetos JS planos.** Al armar un harness de prueba para inyectar notificaciones falsas (objetos JS literales, no `Notification` reales de `Quickshell.Services.Notifications`), se descubrió que comparaciones por referencia (`===`) contra esos objetos fallan después de pasar por un roundtrip de `property list<var>` — hasta la función `dismissPopup` ya existente (sin tocar en esta sesión) falla con el mismo objeto falso. Diagnosticado como artefacto del harness de prueba, no un bug real: los objetos `Notification` reales son punteros a QObject de C++, que sí preservan identidad a través de `list<var>`. Confirma que `pauseDismiss`/`resumeDismiss` nuevos deberían funcionar correctamente contra notificaciones reales (mismo patrón de comparación que `dismissPopup`, ya probado en producción), pero **no se pudo confirmar con una notificación D-Bus real** sin arriesgar registrar la instancia de prueba como servidor de notificaciones del sistema real (`org.freedesktop.Notifications` es un nombre único en el bus — una instancia de prueba registrándose ahí competiría con la producción). Limitación honesta, no una verificación forzada.
- **nix-daemon con locks huérfanos.** A mitad de sesión, tres builds de `nixos-rebuild build` lanzados en paralelo por error (uno quedó corriendo en background mientras se lanzaba el siguiente sin confirmar que el anterior había terminado) dejaron **workers de `nix-daemon` huérfanos** (propiedad de `root`, en estado de espera) que bloquearon toda build posterior indefinidamente (0% CPU, sin avance, minutos de espera). No se pudo limpiar (`systemctl restart nix-daemon` requiere `sudo`, sin contraseña interactiva disponible en este entorno, mismo límite que en Hito 004 original §5). **Se resolvió sin bloquear el resto de la sesión**: dado que `nixos-rebuild build` nunca valida sintaxis/semántica QML (solo evalúa el lado Nix — rutas, opciones de home-manager), el resto de esta sesión se verificó exclusivamente con el método ya establecido (`qs -p <copia-aislada>` + revisión de logs + capturas), sin depender de que el build de Nix termine. **Corrección posterior:** los procesos huérfanos se limpiaron solos (confirmado por notificaciones del sistema reportando que las builds atascadas terminaron con exit code 0, y `ps aux` sin procesos `nixos-rebuild`/`nix-daemon` numerados remanentes) — no hizo falta que Jerimy corriera `sudo systemctl restart nix-daemon`.

### 16.7 Verificación en vivo — qué se pudo y qué no

- **Probado con evidencia real:** las 4 piezas, cada una con captura de pantalla y/o log de IPC, en copias aisladas con offset de posición para no confundir instancia real vs de prueba (mismo método de §14.1). El tinte de la barra se probó específicamente en 2 acentos distintos para descartar coincidencia de un solo hue.
- **No verificable en este entorno (límite ya conocido, no nuevo):** el gesto de hold-to-confirm del power menu, el drag-to-expand y el swipe-to-dismiss de notificaciones — todos requieren entrada de mouse real sostenida/con movimiento, sin `ydotool`/`wlrctl` disponible.
- **No verificable por una restricción específica de esta sesión:** la interacción real de hover-pausa-timer contra una notificación D-Bus genuina, por el riesgo de contaminar el registro `org.freedesktop.Notifications` de producción con una instancia de prueba — verificado por revisión de código contra un patrón ya probado (`dismissPopup`) en su lugar.
- **Wallpaper drift recurrente** (mismo problema de siempre, ver §14.1 y rondas anteriores): cada instancia de prueba nueva revierte el wallpaper del workspace activo al mapeo por defecto (los overrides manuales del picker viven solo en memoria del proceso real). Restaurado manualmente a `kaneki.png` después de cada tanda de pruebas.

### 16.8 Pendientes actualizados

- Confirmar visualmente con el próximo `nix-rebuild-fast` real: las 4 piezas de este addendum, especialmente el gesto de hold-to-confirm del power menu y los gestos de notificaciones (drag/swipe) con dedo/mouse real.
- Indicadores de workspace por-app: diferido, con referencia real ya documentada en `NIXOS_SHELL_VIDEO_ANALYSIS.md` §7.4 para cuando se retome.
- El resto de pendientes de §6, §8.4, §12.4 y §14.7 sigue igual.

---

## 18. Addendum 6 — apertura del dashboard por proximidad + continuidad visual barra→panel

Séptima sesión en la misma rama. Disparador: Jerimy reaccionó a cómo se veía el dashboard en la práctica — se abría con click (no con la proximidad del mouse pedida en una ronda anterior y nunca implementada) y aparecía como una ventana flotante aparte, con un hueco visible y un "pop" de escala, en vez de leerse como si la barra misma creciera hacia abajo. Dos fixes, uno estructural (trigger) y uno visual (continuidad barra↔panel).

### 18.1 Trigger — proximidad real en el reloj

`Capsule.qml` ganó `readonly property alias hovered: mouseArea.containsMouse`, exponiendo el hover de su `MouseArea` interno sin duplicar lógica. La cápsula del reloj (`SystemCapsules.qml`) reacciona a `onHoveredChanged: if (hovered) UiState.openDashboard()` — nueva función en `UiState.qml` que abre el dashboard (con la misma exclusión mutua que `toggleDashboard()`) pero **nunca lo cierra**. Se decidió deliberadamente no implementar cierre-por-salida-de-hover: un dashboard abierto por teclado (`SUPER+SHIFT+B`/`SUPER+CTRL+W`, sin relación con el mouse) se habría cerrado solo si el cursor pasaba por casualidad sobre el reloj y luego se alejaba — regresión real, no hipotética, detectada al diseñar el mecanismo antes de escribirlo. `onClicked: UiState.toggleDashboard()` se mantiene intacto para cerrar/reabrir explícito por click.

Se revisó `NIXOS_SHELL_VIDEO_ANALYSIS.md` y el historial de commits buscando alguna razón documentada para NO haber implementado proximidad en el reloj en la ronda donde se pidió originalmente — no se encontró ninguna (la única proximidad que sí se documentó y luego se eliminó fue la del power menu, por un motivo no relacionado: se movió de dock flotante a cápsula de barra). Se implementó directo, sin flag a Jerimy, tal como pedía la instrucción de esta ronda ante ausencia de objeción documentada.

### 18.2 Continuidad visual — el fix real estaba en cómo Hyprland mide `margins.top`

`Dashboard.qml` y `NotificationCenter.qml` compartían el mismo patrón: `PanelWindow` con `margins.top: 44`, tarjeta interna con su propio inset de 4px, altura fija instantánea, y reveal por `scale`+`opacity` (pop). Esto se leía como "una ventana aparte apareciendo", no como "la barra se extiende" — exactamente el diagnóstico de Jerimy.

Fix aplicado a ambos paneles:
- **Altura animada** en vez de pop de escala: la tarjeta pasa de `height: 0` a `height: <alto de contenido fijo>` con `Behavior`+`Theme.durMed`/`Theme.easeOutCubic`, con `clip: true` — efecto acordeón, la barra "crece hacia abajo" en vez de una ventana apareciendo de golpe.
- **Esquinas superiores cuadradas** (`topLeftRadius: 0; topRightRadius: 0` — propiedades de `Rectangle` disponibles desde Qt 6.7, confirmado Qt 6.11.1 en uso) para que la silueta continúe la de la barra en vez de leerse como tarjeta redondeada flotando aparte.
- **Mismo color que `Bar.qml`** (`Theme.tintSurface(Theme.surface, Theme.activeAccent, 0.6)` en vez de `Theme.surfaceElevated`/borde de identidad) para que coincida exacto en la costura. La identidad magenta de notificaciones se conserva donde importa funcionalmente (borde de urgencia en `NotificationCard`, acento de la cápsula) — no se perdió, solo se sacó del panel completo.
- **Sin borde propio** (antes 1.4px en las 4 caras — habría dibujado una línea justo en la costura con la barra). Elevación solo por sombra (mismo `MultiEffect` que `Bar.qml`), que por tener `shadowVerticalOffset` positivo se nota en los bordes izquierdo/derecho/inferior y es prácticamente invisible en el superior — justo la costura que debía leerse continua.

**Bug real encontrado al verificar en vivo, no al escribir el código:** el primer intento usó `margins.top: 38` (la altura visual real de `Bar.qml`), asumiendo que ese margin se mide desde el borde de pantalla. Comparando la geometría real vía `hyprctl layers -j` en una copia de prueba aislada, se confirmó que Hyprland **ya** arranca el área utilizable de un panel no-exclusivo justo después de las reservas `exclusiveZone` de otras superficies — el `margins.top` declarado se suma ENCIMA de eso, no se mide desde cero. Con `top: 38` el panel quedaba con un hueco residual (38px de más), no pegado. Corregido a `margins.top: 0`, verificado numéricamente (geometría del panel exactamente igual a la del borde inferior real de una barra de prueba con su propia `exclusiveZone`) y visualmente (captura mostrando la costura sin línea ni hueco, ver 18.3).

`PowerMenu.qml` **no se tocó** — comparte el mismo patrón (`PanelWindow` separada, altura fija, pop de escala) pero Jerimy solo pidió explícitamente Dashboard y, "si aplica", NotificationCenter. Queda como candidato documentado para el mismo tratamiento si se pide en una ronda futura — no se decidió por cuenta propia.

### 18.3 Verificación en vivo

- **Geometría confirmada** vía `hyprctl layers -j` en copia aislada (offset temporal solo en los paneles, nunca en `Bar.qml`): con `margins.top: 0`, el panel de Dashboard y el de NotificationCenter quedan exactamente pegados al borde inferior real de una barra de prueba (mismo `exclusiveZone` que la real), sin hueco.
- **Capturas de pantalla** confirmando la costura: tinte de fondo idéntico al de la barra, esquinas superiores cuadradas, sin línea de borde ni salto visible entre barra y panel — se lee como una sola forma continua.
- **Log de `qs` sin errores ni warnings** tras cargar los 5 archivos modificados (`Capsule.qml`, `SystemCapsules.qml`, `UiState.qml`, `Dashboard.qml`, `NotificationCenter.qml`).
- **Apertura por cierre y reapertura probada vía IPC** (`toggleDashboard`/`toggleNotifCenter`/`closeAll`): la tarjeta colapsa a `height: 0` y la `PanelWindow` se des-mapea limpio tras el `hideDelay`, sin residuos ni crashes.
- **No verificable en este entorno (límite ya conocido, no nuevo):** el gesto de proximidad real del mouse sobre el reloj (`onHoveredChanged`) — sin `ydotool`/`wlrctl` no hay forma de simular movimiento de cursor. Se verificó por revisión de código + el hecho de que dispara la misma función (`UiState.openDashboard()`→`dashboardOpen`) ya probada por el camino IPC, y por ausencia de errores/warnings en el log de `qs` al cargar el nuevo alias/handler.
- Wallpaper restaurado a `kaneki.png` tras las pruebas (mismo drift recurrente de siempre).

---

## 20. Addendum 7 — pestañas Performance y Workspaces, `SystemStats.qml`

Octava sesión en la misma rama. Extiende el carrusel de 3 a 5 pestañas. Implementado y commiteado en dos piezas separadas, cada una verificada en vivo antes de la siguiente.

### 20.1 Performance — `SystemStats.qml` + `PerformanceGauges.qml`

Nuevo servicio `SystemStats.qml` (mismo patrón de `Network.qml`: `Timer` de 6s + `Process` + `StdioCollector`, parseando JSON) contra un script nuevo `system-stats` (`hosts/laptop/scripts.nix`), no contra lógica inline en QML — toda la parte frágil (encontrar el hwmon correcto, tolerar que la GPU no responda) queda en un solo lugar auditable y probable a mano (`system-stats` desde una terminal).

**Decisiones reales, no supuestas:**
- **CPU vía sysfs (`/sys/class/hwmon`), no `lm_sensors`.** Se verificó en vivo que `sensors` ni siquiera está instalado, pero el kernel de esta laptop (i5-1035G1) ya carga el driver `coretemp` y expone "Package id 0" directo en `/sys/class/hwmon/hwmonN/temp1_input` — leerlo da el mismo número que `sensors` daría, sin agregar una dependencia nueva a `home.packages`. El índice `hwmonN` no es estable entre reinicios (depende de qué más registre hwmon antes), así que el script busca por el archivo `name`, nunca asume `hwmon4`.
- **GPU real, hallazgo real:** `nvidia-smi` existe y la GPU NVIDIA discreta está presente, pero **falla en vivo** ("couldn't communicate with the NVIDIA driver") porque está en PRIME render-offload puro — nada la ha "despertado" todavía. Esto no es un error a esconder: se trata como `null`/"N/A" explícitamente, sin forzar que la GPU se encienda solo para leer su temperatura.
- **Memoria:** `/proc/meminfo` (`MemTotal`/`MemAvailable`), verificado contra `free -h` a mano (mismos ~47-49% en varias corridas).

`PerformanceGauges.qml` reusa `CircularGauge.qml` (antes solo detrás del icono de batería) para 3 gauges (CPU/GPU/RAM) con umbrales de color (`Theme.ok`/`warn`/`danger` según ratio) — bloques explícitos, no `Repeater` sobre un modelo (mismo criterio que `SystemCapsules.qml`).

### 20.2 Workspaces — `Hypr.qml` extendido, `WorkspacesOverview.qml`

`Hypr.qml` pasó de guardar solo `runningClasses` (lista plana de clases) a guardar los clientes crudos (`property var clients`) y derivar `runningClasses` de ahí (`readonly property`, sin duplicar estado) más una función nueva `classesByWorkspace(wsId)` que agrupa por `workspace.id` — exactamente el mecanismo que `NIXOS_SHELL_VIDEO_ANALYSIS.md` §7.4 ya había scopeado contra `caelestia-dots/shell` en una ronda anterior, usado ahora. Se agregó `movewindow` al set de eventos que disparan `refreshClients()` — antes solo importaba `openwindow`/`closewindow` porque la lista global de clases no cambia si una ventana cambia de workspace, pero `classesByWorkspace()` sí necesita saberlo.

`WorkspacesOverview.qml`: lista de 10 filas (workspaces 1-10, rango **confirmado en vivo** contra `modules/hyprland/core/keybinds.lua` — el bucle liga `SUPER+1..9` y `SUPER+0` está mapeado aparte a workspace 10 — no se asumió "1-9" a ciegas). Cada fila muestra los iconos de las apps corriendo ahí (`Quickshell.iconPath(class)`, con `Quickshell.hasThemeIcon()` como guardia y una inicial como fallback si no hay icono de tema). Click opcional enfoca el workspace (`Hypr.focusWorkspace`). El scratchpad especial `magic` (`SUPER+S`) queda fuera a propósito — es un concepto distinto (scratchpad, no navegación numerada).

### 20.3 Bug real encontrado durante la verificación en vivo (no del código, del método de prueba)

Al probar la pestaña Workspaces con altura dinámica (ver §18.2 sección "chrome"/`activeContentHeight`, extendida esta ronda para 5 casos), una copia de prueba con offset vertical grande (`margins.top: 400`, para separarla visualmente de la instancia real) hizo que el panel — ahora más alto por el contenido de 10 filas — se recortara contra el borde inferior de la pantalla (768px de alto real, panel posicionado a partir de y=476 con 560px de alto pedido: 476+560=1036 > 768). Un `Rectangle` magenta de control puesto en `anchors.bottom: parent.bottom` no aparecía en ninguna captura, confirmando que el recorte era del compositor por límite de pantalla, no un bug de la altura calculada (`card.height` sí llegaba a 560, confirmado con texto de depuración). Se repitió la prueba con el offset normal (`margins.top: 0`, la posición real de producción) y las 10 filas + el marcador de control aparecieron completas. **Lección para pruebas futuras:** un offset de aislamiento visual grande puede exceder el alto real de pantalla y producir un falso positivo de "el contenido no crece" — verificar primero con `hyprctl monitors -j` cuánto espacio vertical real queda antes de elegir un offset.

### 20.4 Verificación en vivo

- Ambas piezas probadas en copias aisladas (`qs -p <copia>` con `system-stats` inyectado en `PATH` para simular el script sin necesitar `nixos-rebuild switch`), capturas confirmando números reales (`sensors`-equivalente, `free -h`, `nvidia-smi` — los tres contrastados a mano).
- Geometría de la pestaña Workspaces confirmada con las 10 filas completas tras corregir el falso positivo de §20.3.
- Sin errores/warnings en el log de `qs` en ninguna de las dos rondas de prueba.
- **Nota sobre el flujo de commits de esta sesión:** el primer commit (Performance) fue creado por Jerimy mismo desde una sesión en paralelo, tomando el estado de trabajo ya preparado y verificado — no por este asistente. El segundo commit (Workspaces) sí se creó acá, sobre ese mismo estado base.

---

## 21. Addendum 8 — dashboard centrado y con ancho dinámico por pestaña

Novena sesión en la misma rama. Disparador: comparación directa contra capturas del proyecto de referencia (`~/reference/caelestia-shell`) — el dashboard real está centrado bajo la barra y su ancho se adapta al contenido de la pestaña activa (`modules/dashboard/Content.qml`, `nonAnimWidth`), mientras el nuestro seguía ranclado a la derecha con 336px fijos para las 5 pestañas por igual, dejando Dashboard/Performance visiblemente apretadas.

### 21.1 Centrado — adaptado, no portado el mecanismo real

El mecanismo real de centrado de Caelestia (`modules/drawers/ContentWindow.qml`) es una única `StyledWindow` de pantalla completa con máscaras de click-through por `Region` y un sistema de deformación de "blobs" (`BlobGroup`/`BlobInvertedRect`) — pensado para su arquitectura de UNA ventana con TODOS los paneles como hijos transformados, radicalmente distinta a la nuestra (una `PanelWindow` por feature, patrón usado en las 8 rondas anteriores de este hito). Portar eso literalmente habría significado reescribir toda la arquitectura del shell — fuera de alcance y en contra de la regla ya establecida ("no reemplazar `modules/quickshell/` por el de ellos").

Lo que sí se adaptó: su idea de fondo (`Wrapper.qml`: `content.anchors.horizontalCenter: parent.horizontalCenter`, donde `parent` es un área de ancho completo). En nuestra arquitectura eso se logra reanclando la `PanelWindow` de `Dashboard.qml` a ancho completo (`anchors.left/right/top: true`, igual que `Bar.qml`) y centrando la tarjeta interna (`card.anchors.horizontalCenter: parent.horizontalCenter`) en vez de anclarla a la derecha. Mismo resultado visual (dropdown centrado bajo la barra) con el patrón de ventana que ya usamos, sin inventar un tercer sistema.

### 21.2 Ancho dinámico por pestaña — mismo mecanismo que la altura, extendido a ancho

Se agregó `card.activeContentWidth` (switch sobre `UiState.dashboardTab`, exactamente como `activeContentHeight` ya hacía desde el follow-up 6) y `card.targetWidth = clamp(320, 760, activeContentWidth + 36)`, con `Behavior on width` nueva. Solo las pestañas Dashboard (caso 0) y Performance (caso 3) reportan un ancho realmente *bottom-up* esta ronda — Wallpapers/Media/Workspaces se quedan con 336px fijos (no estaban en el alcance pedido, y darles ancho bottom-up real habría requerido reescribir `WallpaperPicker`/`VolumeMixer`/`WorkspacesOverview`, que hoy dependen de que se les imponga un ancho desde afuera, igual que el `Calendar.qml` de la pestaña Dashboard — ver más abajo).

**El carrusel necesitó un cambio real, no cosmético.** `contentX: UiState.dashboardTab * width` asumía que las 5 pestañas medían lo mismo — dejó de ser cierto en cuanto Dashboard/Performance pasaron a tener un ancho propio. Adaptado de la misma idea de `Content.qml` (su `Flickable` ata `contentX` a `currentItem.x`, la posición real que el `Row` interno ya le asignó a la pestaña activa según la suma acumulada de anchos/spacing de las anteriores): cada `Flickable` de pestaña ahora reporta su propio ancho natural (`width: xxxContent.implicitWidth`, ya no `carousel.width` forzado) y `carousel.contentX` es un switch que devuelve el `.x` (asignado automáticamente por el `Row` contenedor) de la pestaña activa.

### 21.3 Restructuración de contenido — de columna apretada a tarjetas lado a lado

**Pestaña Dashboard:** la columna vertical única (`QuickToggles` + divisor + `Shortcuts` + divisor + `Calendar`, todo en 336px) se reemplazó por un `Row` de 2 tarjetas de ancho fijo (280px "Accesos rápidos" con `QuickToggles`+`Shortcuts`, 300px "Calendario"), idea tomada de `modules/dashboard/Dash.qml` de la referencia (su `GridLayout` de 6 celdas con `Layout.preferredWidth` por celda) — **no copiada literal**: nosotros no tenemos weather ni user-con-foto-de-perfil, así que son 2 tarjetas, no 6. Ambas tarjetas comparten la misma altura (`Math.max(quickAccessCol.implicitHeight, calendarCol.implicitHeight) + 40`, sin `QtQuick.Layouts` — no se agregó esa dependencia solo por esta alineación, un cálculo manual alcanza).

**Por qué solo 2 tarjetas y por qué tienen ancho fijo, no bottom-up real:** `Calendar.qml`, `QuickToggles.qml` y `Shortcuts.qml` son fundamentalmente *top-down* — su `Grid`/`Flow` interno necesita que se le imponga un ancho desde afuera para decidir dónde envolver filas/columnas (`(root.width-24)/7` en `Calendar.qml`, por ejemplo). No tienen forma de reportar un `implicitWidth` propio sin que alguien les diga primero cuánto espacio tienen. Se les da entonces un ancho FIJO deliberado (280/300, elegido para verse generoso, no calculado), y es el `Row` de 2 tarjetas — cuyos hijos SÍ tienen ancho fijo — el que reporta un `implicitWidth` bottom-up real (280+300+20 de spacing = 600) hacia `card.activeContentWidth`. Esto coincide con cómo la referencia misma resuelve el mismo problema: `Dash.qml` mezcla `Layout.preferredWidth: Tokens.sizes.dashboard.userWidth` (constante fija) con `Layout.fillWidth: true` (llenar lo que quede) — no todo es medido bottom-up ahí tampoco.

**Pestaña Performance:** `PerformanceGauges.qml` tenía spacing 0 entre los 3 gauges y cada columna a `parent.width/3` — division exacta sin ningún respiro, la causa real de la sensación "apretada". Se cambió a columnas de ancho fijo (104px, gauge de 92px adentro, subido de 76) con `spacing: 36` entre ellas — números de proporción inspirados en los tokens reales de Caelestia (`plugin/src/Caelestia/Config/tokens.hpp`: `perfUsageShapeSize: 100`, `spacing.extraLarge: 28`), sin importar esos tokens como dependencia — solo como referencia de qué se siente "airoso" a esa escala.

### 21.4 Verificación en vivo

- **Centrado confirmado** vía `hyprctl layers -j` (ventana a ancho completo, x=0) + captura de pantalla (la tarjeta se ve centrada horizontalmente bajo la barra en las 3 pestañas probadas).
- **Ancho dinámico por pestaña confirmado**: Dashboard ≈636px, Performance ≈420px, Workspaces ≈372px en capturas consecutivas del mismo proceso de prueba — el panel visiblemente se angosta/ensancha al cambiar de pestaña, sin quedar pegado a un solo ancho.
- **Costura con la barra reverificada tras el cambio** (§18.2 seguía siendo válida, pero había que confirmar que centrar+ensanchar no la rompiera): captura de la costura superior con la pestaña Dashboard activa (la más ancha) — mismo tinte, esquinas superiores cuadradas, sin línea ni hueco, igual que antes de esta ronda.
- **Carrusel probado en las 3 pestañas afectadas por el cambio de mecanismo** (Dashboard/Performance/Workspaces) vía IPC (`setDashboardTab`) — cada una aterriza en la posición correcta, sin quedar a mitad de camino ni mostrar contenido de la pestaña vecina.
- Sin errores/warnings en el log de `qs`.
- **Hallazgo del método, no del código** (ver también §20.3, mismo tipo de problema en la ronda anterior): un `hyprctl layers` devolvió por un momento la geometría del dashboard de PRODUCCIÓN (proceso real de Jerimy, pid distinto) en vez de la copia de prueba, porque **el dashboard real de Jerimy estaba abierto en simultáneo** durante la verificación — su propio `MouseArea` de clic-afuera-para-cerrar de la copia de prueba cubre una región grande de pantalla real y no se puede descartar que un clic suyo de paso haya cerrado la copia de prueba en algún momento (se reabrió sin problema). No se detectó ningún efecto sobre el dashboard REAL de Jerimy — su propia sesión no fue tocada por los archivos de esta copia aislada.
- Wallpaper restaurado a `kaneki.png` tras las pruebas.

### 21.5 Pendientes

- `PowerMenu.qml`, `NotificationCenter.qml`: no tocados esta ronda (el pedido fue específicamente sobre `Dashboard.qml`). Si en el futuro se pide centrar/anchar dinámicamente esos paneles también, este mismo mecanismo (`activeContentWidth`/`targetWidth`/`Behavior on width`) es directamente reutilizable.
- Wallpapers/Media/Workspaces siguen en 336px fijo — candidatas a su propio tratamiento de "tarjetas" si se pide en una ronda futura, mismo motivo que Dashboard/Performance (hoy están igual de apretadas, simplemente no eran parte del pedido de esta ronda).

---

## 23. Addendum 9 — feedback en vivo sobre capturas reales: hover, tabs, glow, wallpaper popup, títulos

Décima sesión en la misma rama. Disparador: siete pedidos puntuales del usuario contra capturas reales del estado tras el Addendum 8 (no contra el video/proyecto de referencia esta vez — feedback directo de uso). Siete commits separados, uno por ítem.

### 23.1 Trigger de hover reubicado a toda la barra (no solo un centro)

Antes vivía en la cápsula del reloj (`SystemCapsules.qml`, `onHoveredChanged: if (hovered) UiState.openDashboard()`) — un blanco chico, solo a la derecha. El pedido daba la opción de "centro de la barra o barra completa, la que se sienta mejor en vivo". Se probó mentalmente la opción centro primero y se descartó sin necesidad de probarla en vivo: la barra no tiene ningún elemento visual en el medio (workspaces a la izquierda, cápsulas a la derecha) que sugiera "hovereá acá" — una franja central sería una zona ciega sin pista de que existe. Se implementó `HoverHandler` sobre `surface` (el `Rectangle` completo de la barra) en `Bar.qml`, mismo mecanismo (`HoverHandler`) que ya usaba `Capsule.qml` para su glow de proximidad — no se inventó un tercer sistema de hover.

`UiState` gana `barHovered`/`dashboardCardHovered` (asignación directa desde afuera, mismo patrón que `Theme.activeAccent` en `WorkspaceSync.qml`) — el primero lo puebla `Bar.qml`, el segundo lo puebla `Dashboard.qml` (ver 23.2), y ambos alimentan la lógica de auto-cierre.

### 23.2 Auto-cierre por salida de hover, click-afuera se mantiene como fallback

`Dashboard.qml` (`win`) gana `hoveringDashboard: UiState.barHovered || UiState.dashboardCardHovered` y un `Timer` de gracia de 200ms (`closeGrace`): cuando `hoveringDashboard` pasa a `false` y el panel sigue abierto, arranca el timer; si `hoveringDashboard` vuelve a `true` antes de que dispare, se cancela. Si dispara, llama `UiState.closeAll()`. El click-afuera (`MouseArea` de siempre) no se tocó — se mantiene como fallback real (navegación por teclado, o cualquier caso donde el mouse nunca se mueve).

**Limitación honesta:** este ambiente no tiene forma de sintetizar hover real de mouse — `wtype` solo hace teclado, y el `hyprctl dispatch` de este Hyprland (capa Lua propia, ver `NIXOS_ARCHITECTURE_HITO_002.md` §1.3) rechaza dispatchers crudos tipo `movecursor X Y` (exige llamadas `hl.dsp.*` ya definidas, y no se encontró ninguna de cursor). El trigger de apertura y el cierre por gracia se verificaron por revisión de código y manejando `dashboardOpen`/`dashboardTab` vía `quickshell ipc call` — no con un mouse real entrando/saliendo de la barra. Queda pendiente una verificación rápida del usuario con su propio mouse.

### 23.3 TabBar: fuente más grande + ancho compartido subido (336→380)

`font.pixelSize: 8→10`, `spacing: 4→3` en `TabBar.qml`. Se probó 11px primero (pedido "aumentar notablemente") y colisionó en vivo: a 5 pestañas, "Performance"/"Workspaces" volvían a elidir en el ancho fijo compartido de Wallpapers/Media/Workspaces (336px de entonces). La solución real no fue solo bajar el número de tamaño — fue subir también ese ancho fijo compartido a 380px (`Dashboard.qml`, `card.activeContentWidth` caso `default` + los 3 `Column` de contenido que antes tenían `width: 336`).

**Bug real encontrado en el camino:** subir el switch de `activeContentWidth` sin subir también los `Column` de contenido interno reabre un bug de "bleed" — `card` se ensancha (el viewport del carrusel sigue su ancho) pero el contenido de la pestaña activa se queda angosto, dejando un hueco donde se filtra visualmente la pestaña vecina del `Row` interno (sin gap entre Flickables). Se vio en vivo antes de corregirlo (captura con "SALIDA"/"ENTRADA" de la pestaña Media superpuesto sobre la grilla de Wallpapers).

### 23.4 Tarjetas de la pestaña Dashboard: color/glow reales

Se mantuvo el layout de tarjetas del Addendum 8 (ya aprobado), pero se le subió el terminado visual: de `Theme.surfaceFaint` plano sin borde a un wash translúcido de `Theme.activeAccent` (`Theme.withAlpha(activeAccent, 0.10)`) + borde acentuado + sombra coloreada (`MultiEffect`, mismo mecanismo que la sombra de `card`/`Bar.qml`, solo recoloreada de negro a `activeAccent` — el "glow" es literalmente esa sombra con blur alto y offset 0). El encabezado "ACCESOS" y el divisor interno pasaron de `textMuted` a `activeAccent`.

**Nota técnica:** `Theme.tintSurface()` no sirve para esto — preserva la *luminosidad* del color base, y `surfaceFaint` es casi blanco/casi transparente (`Qt.rgba(1,1,1,0.03)`, lightness=1), así que teñirlo hacia cualquier hue con esa función es un no-op (HSL con lightness=1 siempre da blanco, sin importar el hue). Se usa `Theme.withAlpha()` directo en su lugar.

### 23.5 Pase visual en Media/Performance/Workspaces

Mismo espíritu que 23.4, aplicado a los otros tres componentes de contenido:
- **`VolumeMixer.qml`**: filas 30→38px, ícono de mute 14→18px, barra 6→9px con su propio glow coloreado, thumb que crece al arrastrar/hoverear (antes cero feedback aparte del ancho de la barra). Encabezados "SALIDA"/"ENTRADA" a `activeAccent`.
- **`PerformanceGauges.qml`**: gauges 92→108px, thickness 6→7, cada anillo proyecta su propio glow coloreado según `ratioColor()`/estado — el gauge de GPU se queda sin glow cuando `SystemStats.gpuAvailable` es falso (no se fuerza ni se esconde, mismo criterio que el Addendum 7).
- **`WorkspacesOverview.qml`**: íconos 20→24px, el workspace activo proyecta glow real en vez de solo fondo+borde tenues, avatares de fallback (sin ícono de tema) recoloreados a `activeAccent`.

### 23.6 Wallpapers deja de ser pestaña — popup standalone

`WallpaperPickerPopup.qml` (nuevo archivo): mismo patrón de ventana que `Dashboard.qml` (centrado bajo la barra, costura sin gap) en vez de top-right como `PowerMenu`/`NotificationCenter` — una grilla se beneficia más del ancho que da centrar. `UiState` gana `wallpaperPickerOpen` + `toggleWallpaperPicker()`, con la misma exclusión mutua que dashboard/notifCenter/powerMenu. `keybinds.lua`: `SUPER+CTRL+W` repuntado de `toggleDashboard` a `toggleWallpaperPicker` (antes abría el dashboard en la pestaña Wallpapers, que ya no existe).

`TabBar` de `Dashboard.qml` baja de 5 a 4 pestañas (`Dashboard/Media/Performance/Workspaces`) — los switches de `activeContentHeight`/`activeContentWidth`/`carousel.contentX` se renumeraron (los índices de Media/Performance/Workspaces bajaron uno).

**Candidatos de referencia estudiados antes de decidir** (`~/reference/caelestia-shell`):
- `modules/launcher/WallpaperList.qml` + `items/WallpaperItem.qml`: el más parecido estructuralmente (keybind → popup propio → browse → seleccionar), pero su `PathView` 3D con preview en vivo depende de `Caelestia.Config`/`Colours`, que no existen acá — se tomó solo la forma ("popup propio, no anidado"), no el mecanismo `PathView`.
- `modules/nexus/pages/wallandstyle/{WallpaperSelect,WallpaperCategory}.qml`: página de una app de settings completa agrupada por carpeta — confirmado que NO encaja para un popup de keybind, descartado.
- `services/Wallpapers.qml`: hubiera sido reusable como servicio de datos, pero `WorkspaceSync.qml` ya cubre ese rol acá (integrado a nuestro pipeline `workspace-wallpaper`+matugen) — no se reemplaza, y su mecanismo de cambio de wallpaper (`caelestia wallpaper`) tampoco se adopta, solo el patrón de UI (grilla + atribución de cuál está activo).

`WallpaperPicker.qml` (el componente `Flow` existente) se reutiliza tal cual dentro del popup nuevo en vez de duplicarse — las miniaturas crecieron 64→88px ahora que no está apretado en una pestaña de 336px, más una insignia de check en la miniatura activa y una línea "Activo: <nombre-de-archivo>" de atribución.

### 23.7 Títulos de ventana en la pestaña Workspaces

`Hypr.qml`: `classesByWorkspace(wsId)` → `clientsByWorkspace(wsId)`, ahora devuelve `{class, title}` por cliente en vez de solo la clase — el campo `title` ya venía en `hyprctl clients -j` sin usarse. Se agrega `"windowtitlev2"` al trigger de refresh de `Connections.onRawEvent` (cambios de título, ej. pestaña de browser, no invalidaban la lista cacheada antes).

`WorkspacesOverview.qml` restructurado: de una fila horizontal de solo íconos a un renglón por ventana (ícono + título elidido) — íconos lado a lado dejó de tener sentido en cuanto cada uno necesita un título al lado. La altura de cada bloque de workspace pasó de fija (48px) a `content.implicitHeight + 20` (variable según cantidad de ventanas).

**Bug real encontrado y corregido en vivo:** el `x: 30` que alinea cada renglón de ventana bajo el ícono del encabezado no venía acompañado de una reducción de `width` equivalente — el punto de elide del `Text` del título quedaba 30px más allá del borde real de `content`, y como `wsRow` no tiene `clip: true` propio, ese sobrante no se recortaba ahí: terminaba filtrando hasta el clip de la pestaña completa, mucho más a la derecha. Se veía como el título "cortado seco" contra el borde de TODA la tarjeta en vez de elidido con "…" contra su propia fila. Corregido con `width: parent.width - x`.

### 23.8 Verificación en vivo

- Los 7 ítems verificados vía `quickshell ipc call uiState <función>` (abrir dashboard/wallpaper-picker, cambiar de pestaña) + capturas `grim` de una copia de prueba en `/tmp` (mismo método de rondas anteriores: exclusiveZone stacking para separarla del `qs` real de producción).
- **Hallazgo de método repetido** (ver también §20.3/§21.4, misma clase de problema): un cambio de ancho (336→380 en las 3 `Column` de contenido) se probó primero con hot-reload de QuickShell (`settings.watchFiles`) y el bug de "bleed" seguía apareciendo en la captura pese a que el archivo en disco ya tenía el fix — un reinicio completo del proceso `qs` de prueba (no solo guardar el archivo) confirmó que el fix sí funcionaba. El hot-reload de QuickShell no es 100% confiable para cambios de layout/ancho — para verificaciones de ese tipo, reiniciar el proceso entero en vez de confiar en el watcher.
- El repunte de `SUPER+CTRL+W` en `keybinds.lua` no es verificable desde este ambiente (requiere `nixos-rebuild switch` + reload real de Hyprland) — pendiente de confirmación del usuario, igual que la verificación real de hover de §23.2.
- Build de Nix (`nixos-rebuild build --flake .`) verde tras los 7 commits.

### 23.9 Pendientes

- Verificación con mouse real de §23.1/23.2 (trigger de hover + auto-cierre) — no sintetizable en este ambiente.
- Verificación del keybind `SUPER+CTRL+W` tras un `nixos-rebuild switch` real.
- `PowerMenu.qml`/`NotificationCenter.qml` siguen sin el mismo pase de color/glow — no fueron parte del pedido de esta ronda.

---

## 25. Addendum 10 — hotzone angosta, Workspaces en pills, atajos nuevos, subsistema de wallpapers reforzado, HDMI, Dolphin+Kvantum, selector de red real

Undécima sesión en la misma rama. Nueve pedidos puntuales (dos de ellos referenciaban explícitamente la ronda anterior, 3caaa87..2855a30, para no rehacer trabajo ya hecho). Nueve commits separados.

### 25.1 Hotzone de hover angostada (revierte parcialmente el follow-up 10 anterior)

El follow-up 10 de la ronda anterior había ensanchado el trigger de apertura por hover a TODA la barra, razonando que un centro sin ningún elemento visual sería un punto ciego. En uso real resultó demasiado sensible — cualquier paso del mouse hacia las cápsulas o los pills abría el dashboard sin querer. Vuelta a una franja central, esta vez de 200px (`Item` + `HoverHandler`, mismo mecanismo, sin inventar nada nuevo). Verificado en vivo con un `Rectangle` de debug rojo temporal (solo en la copia de prueba, nunca tocó el archivo real) confirmando ancho y centrado correctos.

### 25.2 Pestaña Workspaces: verificado primero, SÍ hacía falta rediseñar

El pedido pedía explícitamente verificar antes de tocar nada. Captura real contra ventanas reales confirmó que el follow-up 12 anterior (título completo por ventana, un renglón vertical por ventana) NO leía compacto — títulos largos ocupaban ~70px de alto por una sola línea elidida a la mitad. Rediseñado a "pills" (ícono + nombre corto de la clase) en un `Flow` que empaqueta varias por línea — el caso común (1-3 apps) vuelve a caber en una línea. El título completo no se pierde, aparece en un tooltip propio al hoverear (mismo criterio sin `QtQuick.Controls.Popup` que ya usaba `DndToggle.qml`).

### 25.3 y 25.4 — dos atajos nuevos

- `SUPER+SHIFT+W`: `UiState.openDashboardTab(3)` — abre el dashboard directo en Workspaces, sin togglear+clickear. Genérico por índice, no hardcodeado a "Workspaces" en el nombre de la función.
- `SUPER+CTRL+SHIFT+ALT+Q`: `hyprctl dispatch exit` directo, sin el hold-to-confirm de `PowerMenu.qml`. Requisito de seguridad explícito del pedido: el combo de 4 modificadores ES el mecanismo de seguridad, ya que no hay confirmación de UI en este camino. **No ejecutado en vivo** — mataría la sesión real de Hyprland bajo la que corre esta conversación.

### 25.5 Subsistema de wallpapers — refuerzo en dos commits

**Random + transición por workspace** (`WorkspaceSync.qml`): `wallpaperFor()` sin override ahora cae en un pick al azar cacheado (no un ciclo fijo `wallpapers[(id-1)%n]`) — cacheado la primera vez por workspace para no re-randomizar en cada visita. `transitionTypeFor(id)` hashea el id contra 9 tipos de transición de awww (grow/wipe/outer/wave/left/right/top/bottom/center). Verificado en vivo con un `IpcHandler` de debug temporal (solo en la copia de prueba): hash determinista confirmado para ids 1-10, cache de wallpaperFor() estable en llamadas repetidas, override sobrevive intacto tras seedearlo.

**Popup — 4 refinamientos**: (a) posible bug de centrado reportado por el usuario — no se pudo reproducir en una copia de prueba limpia (682.5px medido vs 683px real), pero se encontró y corrigió un binding loop real (`width: parent.width` circular en la Column de encabezado) que es exactamente el tipo de bug que se comporta distinto según timing — pendiente de reconfirmación real. (b) Anclado al fondo de pantalla en vez del tope. (c) Grilla (`Flow`) → filmstrip horizontal (`Flickable` + flechas que reusan el mismo `Behavior on contentX` del carrusel del Dashboard). (d) Glow de `Theme.activeAccent` en miniatura activa/hovereada y en el card completo.

### 25.6 Dashboard: pase de layout puro

Sin tocar colores (ya aprobados). Se encontró un bug de flow real: `QuickToggles` (4 botones fijos) no entraba en una fila dentro de la tarjeta de 280px, forzando un wrap 3+1 que se leía como bug, no como diseño. Ensanchada a 300px — de paso iguala el ancho con la tarjeta de calendario (antes 280/300 sin razón visible).

### 25.7 Widget de control HDMI (nuevo)

Verificado en vivo ANTES de asumir qué GPU maneja el HDMI: `/sys/class/drm/card1-HDMI-A-{1,2}` resuelven a `pci0000:00:02.0`, el Bus ID documentado del iGPU Intel — confirma que Intel maneja el HDMI, no la dGPU NVIDIA (offload puro, ver NIXOS_ARCHITECTURE_HITO_001.md §1.1). Dos restricciones reales encontradas y sorteadas: `hyprctl monitors -j`/`monitors all -j` no listan conectores sin señal (detección real vía sysfs); `hyprctl keyword monitor` falla ("keyword can't work with non-legacy parsers") en este fork Lua de Hyprland — se usa `wlr-randr` en su lugar, que habla el protocolo wlr-output-management-v1 directo, evitando esa capa. Cápsula oculta por completo sin cable enchufado. Bug real encontrado y corregido en vivo (con un `hdmi-control` falso en PATH, técnica ya establecida en rondas anteriores): el popup con `implicitHeight` fijo (220) recortaba el 4° botón contra el borde de la superficie Wayland — subido a 290. **No verificado**: comportamiento real extender/espejo/solo-TV/solo-laptop contra un TV real (ninguno conectado esta sesión).

### 25.8 Thunar → Dolphin + Kvantum

Paquetes swapeados, clase de ventana verificada en vivo (lanzando Dolphin real: `org.kde.dolphin`, no asumida). Tema Kvantum hecho a mano (`modules/kvantum/NixCyber/`) con los hex exactos de `Theme.qml` — se evaluó y descartó el paquete `catppuccin-kvantum` de nixpkgs (solo empaqueta la variante "frappe-blue", no calza con nuestra paleta Mocha-oscura+lavanda). Hallazgo real probando en vivo (Dolphin real, no solo revisión de código): Kvantum solo no bastaba — las apps KDE pintan su chrome nativo vía KColorScheme (`kdeglobals`), una capa paralela al QPalette del estilo Qt. Se agregó un `kdeglobals` a medida y se reverificó: sidebar y selección sí calcaron después. **Gap real no resuelto**: la vista "Detalles" de Dolphin no calcó el fondo oscuro en una prueba real — documentado, no escondido.

### 25.9 Selector de red WiFi real

Reemplaza `nmApplet.startDetached()` (spawneaba un tray icon externo) por `NetworkMenu.qml`, una lista QML real. Se verificó de nuevo si "D-Bus preferido" era viable antes de asumir que no (la nota vieja de `Network.qml` sobre "no existe Quickshell.Services.NetworkManager" resultó desactualizada) — inspección directa de los `.qmltypes` de quickshell 0.3.0 instalado confirmó que `Quickshell.Networking` SÍ existe, con `WifiNetwork.connect()`/`connectWithPsk()` reales sobre D-Bus/NetworkManager. Dos bugs reales corregidos vía el log (no adivinados): dos `onShownChanged` en el mismo objeto ("Property value set multiple times") y anchors en un hijo directo de `Row` ("Cannot specify ... anchors for items inside Row"). **El ítem mejor verificado de esta ronda**: probado contra hardware/red real de esta sesión — mostró la red conectada real (Xiaomi_F09F) al instante y, tras habilitar el escáner, redes vecinas reales (brian-2.4ghz, LAPLUWA2, BARZOLA 2.4G, brian-5ghz) ordenadas por señal. El flujo de contraseña para redes desconocidas se implementó pero no se ejerció contra una red ajena real (no correspondía intentar unirse a la red de un vecino sin motivo).

### 25.10 Metodología repetida esta ronda

- Debug temporal SOLO en copias de prueba (`/tmp/.../qstestN/`), nunca en el repo real — verificado con `grep` después de cada uso que el archivo real seguía limpio (hotzone roja, `contentX` semilla del filmstrip, `IpcHandler` de debug de `WorkspaceSync`, binario `hdmi-control` falso en PATH).
- Comandos irreversibles/destructivos (matar la sesión de Hyprland) documentados como código pero NO ejecutados — la seguridad del usuario por encima de "verificar todo en vivo a toda costa".
- Antes de escribir/sobreescribir un archivo real del sistema (`~/.config/kdeglobals`, `~/.config/Kvantum/`) se verificó primero que no existiera contenido real del usuario ahí — y se limpiaron los artefactos de prueba al terminar, para no interferir con la gestión de symlinks de home-manager en el próximo `switch`.
- Cuando una nota antigua del propio repo ("no existe tal módulo") contradecía lo que hacía falta, se volvió a verificar en vivo en vez de asumir que seguía vigente — encontró un módulo real (`Quickshell.Networking`) que una ronda anterior no había visto.

### 25.11 Pendientes

- Verificación con mouse real de la hotzone angostada (§25.1).
- Verificación del keybind SUPER+SHIFT+W y SUPER+CTRL+SHIFT+ALT+Q tras `nixos-rebuild switch`.
- Reconfirmación del centrado del wallpaper popup en el escritorio real (§25.5).
- Comportamiento real de HDMI contra un TV físico (§25.7).
- Gap de la vista "Detalles" de Dolphin (§25.8).

---

## 27. Addendum 11 — Dolphin no abría archivos (causa raíz real), sidebar washed-out, HDMI overlap + audio

Duodécima sesión en la misma rama. Cuatro pedidos puntuales sobre bugs reales encontrados en uso — dos de ellos (Dolphin) resultaron en investigaciones profundas de varias horas cada una, documentadas acá en detalle porque el camino recorrido (qué se descartó y por qué) es tan valioso como el fix final.

### 27.1 Dolphin no abría archivos — causa raíz real: `applications.menu` faltante

**Síntoma confirmado en vivo**: doble-click (simulado con `wtype` navegando+Enter sobre el ítem seleccionado, ya que este ambiente no puede sintetizar clicks de mouse) no abría NINGÚN archivo — el diálogo "Select the program you want to use" aparecía con la grilla de apps completamente VACÍA, para CUALQUIER tipo de archivo, no solo asociaciones custom (nvim-foot.desktop/imv.desktop) — hasta `org.kde.dolphin.desktop` mismo salía como "unknown service".

**Hipótesis descartadas con pruebas reales, no supuestas**:
1. Cache de ksycoca desactualizada — se reconstruyó manualmente (`kbuildsycoca6`, `--noincremental`, `--menutest`) múltiples veces, incluyendo forzar que Dolphin la reconstruya por sí solo (borrando el cache antes de lanzar) — la grilla seguía vacía.
2. Falta el demonio `kded6` (normal en una sesión Plasma completa, ausente acá por ser Hyprland) — se lanzó manualmente, sin cambio.
3. Falta `XDG_CURRENT_DESKTOP=KDE` — seteado explícito al lanzar Dolphin, sin cambio.
4. Verificado con `strings -e l` (UTF-16LE, el encoding real que usa QDataStream para las cadenas del cache — `strings` plano no las encuentra) que el cache ksycoca no contenía NINGÚN string `.desktop` de aplicación, ni siquiera de apps del propio cierre de kio/kservice — apuntaba a que el escaneo de aplicaciones fallaba por completo, no solo para nuestras entradas.

**Trampa metodológica real, encontrada y documentada para que no se repita**: Dolphin se registra como servicio D-Bus de instancia única (`org.kde.dolphin-<pid>`, `org.freedesktop.FileManager1`). Matar el PID visible con `pgrep -f "bin/dolphin" | head -1` dejaba OTRAS instancias viejas registradas y vivas en D-Bus, que seguían sirviendo pedidos de "--new-window" nuevos con su entorno ORIGINAL (sin los fixes de la prueba en curso) — esto invalidó silenciosamente varias rondas de prueba (incluyendo la prueba de `kded6` y `XDG_CURRENT_DESKTOP`) hasta que se detectó vía `busctl --user list | grep dolphin` y se mataron TODAS las instancias por PID explícito.

**Causa real, encontrada vía `journalctl --user`** (no vía revisión de código): `kbuildsycoca6`/dolphin logueaban literalmente `"applications.menu" not found in QList("/etc/profiles/per-user/jerimy/etc/xdg/menus", "/run/current-system/sw/etc/xdg/menus")`, seguido de `mimeapps.list specifies unknown service "X.desktop"` para cada entrada. Este sistema no corre Plasma/GNOME/XFCE — ningún paquete instala `/etc/xdg/menus/applications.menu`, el archivo base de la XDG Desktop Menu Specification que `kbuildsycoca6` necesita para indexar CUALQUIER aplicación como KService. Sin ese archivo, el escaneo de aplicaciones simplemente no produce nada, sin importar cuán correcto sea `mimeapps.list`.

**Fix**: `modules/kvantum/applications.menu`, un archivo mínimo hecho a mano (`<Include><All/></Include>` — se probó primero con `<Category>Application</Category>`, que no filtra nada porque "Application" no es un `Category=` válido de la especificación) empaquetado como una derivación chica (`pkgs.runCommand` contribuyendo `etc/xdg/menus/applications.menu`) en vez de traer un paquete completo tipo `gnome-menus`/`plasma-workspace` (ambos atan este archivo a una DE completa, justo lo que este sistema evita). Se agregó también `home.activation.rebuildKSycoca` (pedido explícito del brief: "figure out how to trigger declaratively on activation") — no era la causa real del bug (confirmado por las pruebas de arriba), pero es la práctica correcta de todos modos.

**Verificación final en vivo**: dado que `nixos-rebuild switch` necesita credenciales sudo que esta sesión no tiene, se probó vía un wrapper script que exporta `XDG_CONFIG_DIRS` con el archivo de prueba prepend — confirmado con `/proc/<pid>/environ` que el override SÍ llegaba al proceso real de Dolphin (a diferencia de un intento anterior con `env VAR=x cmd` inline en un comando backgrounded, que NO llegaba — otra trampa metodológica real, sin explicación concluyente de por qué, resuelta con un wrapper script explícito en su lugar). Con el fix activo: seleccionar el archivo de prueba y presionar Enter lanzó `foot -e nvim /tmp/dolphin_open_test.txt` — exactamente el `Exec=` de `nvim-foot.desktop` — confirmado vía lista de procesos real.

### 27.2 Sidebar de Dolphin lavado/bajo contraste

Dos causas reales, encontradas estudiando la arquitectura real de KColorScheme:

1. **`[Colors:Complementary]` faltante** — los paneles empotrados en apps KDE (el "Places Panel" de Dolphin es exactamente esto) no usan `[Colors:Window]`, usan un quinto grupo de color dedicado a chrome tipo panel/dock. Sin definirlo, Dolphin cae al complementary por defecto de su estilo base (gris Breeze genérico) — coincide exacto con el síntoma reportado. Agregado con tinte propio (más lavanda que Window/View).
2. **`qt6ct.conf` no existía en absoluto** — `QT_QPA_PLATFORMTHEME=qt6ct` está seteado (necesario para que `QT_STYLE_OVERRIDE=kvantum` aplique de verdad) pero sin ningún archivo de config, confirmado en vivo (`ls ~/.config/qt6ct/` → "No such file or directory"). Sin config, Qt cae a sus defaults compilados — afecta tanto el estilo como el ícono theme (Papirus-Dark estaba configurado para GTK pero nunca propagaba a Qt/KDE). Agregado explícito.

Encontrado y corregido de paso: `kdeglobals` usaba `;` como prefijo de comentario (convención GTK/INI) en 24 líneas — KConfig solo acepta `#`, confirmado vía los mismos logs de journalctl del bug anterior (`"Invalid entry (missing '=')"` repetido).

Verificado en vivo intercambiando los symlinks gestionados por home-manager (de la ronda anterior) por archivos planos con el contenido nuevo — mismo método usado para probar Kvantum originalmente. Captura antes/después: el sidebar pasó de gris plano a un panel oscuro con tinte lavanda claramente distinguible, con zebra-striping visible en la vista principal.

### 27.3 y 27.4 — HDMI: solape de monitores + audio

Ver commit `d6c0b86` para el detalle completo (documentado extensamente en el propio mensaje de commit, no repetido acá). Resumen:

- **Causa real del solape**: `wlr-randr` posicionaba monitores por fuera del motor de reglas de Hyprland (`monitors.lua`/`hl.monitor()`), corriendo DESPUÉS de que Hyprland ya aplicara su propia regla `position="auto"` al conectar — dos sistemas de posicionamiento sin coordinación. Fix: usar `hl.monitor()` en vivo vía `hyprctl eval` (confirmado real y funcional, no solo un `hyprctl keyword` que ya se sabía roto de la ronda anterior).
- **GPU que maneja HDMI**: reconfirmado en vivo (Intel exclusivo, mismo método que la ronda del widget HDMI) — el perfil híbrido PRIME no agrega una carrera de switch de GPU al problema, no hacía falta una regla explícita en `monitors.lua`.
- **Audio**: `wpctl status` + `set-default` agregado a cada modo, matching por substring de nombre de sink ("hdmi"/"built-in"). Corrección honesta sobre la premisa del pedido: `VolumeMixer.qml` usa la API nativa `Quickshell.Services.Pipewire`, no `wpctl` — el patrón real establecido en el repo para `wpctl` es `keybinds.lua`/`gestures.lua` (teclas de volumen), que sigue siendo la referencia correcta para ESTE script (shell, no QML).
- **Pendiente honesto**: ni el posicionamiento mirror/hdmi-only/laptop-only ni el matching de un sink HDMI real se pudieron verificar contra hardware real — ningún TV conectado esta sesión. Solo la llamada base `hl.monitor()` (sobre eDP-1) y el matching "built-in" (audio real de la sesión) están confirmados en vivo.

### 27.5 Metodología — hallazgos de esta ronda

- **Instancias D-Bus de aplicación única son una trampa de testing real**: matar el PID visible no basta para apps con activación D-Bus (Dolphin, y probablemente cualquier app KDE moderna) — hay que verificar `busctl --user list` y matar TODAS las instancias registradas, o las pruebas subsiguientes quedan silenciosamente confundidas por una instancia vieja respondiendo con su entorno original.
- **`env VAR=x cmd` inline en un comando backgrounded no siempre propaga** el override al proceso final de forma confiable en este ambiente — un wrapper script explícito con `export`+`exec` sí, de forma reproducible. Sin explicación concluyente de la causa raíz de esa discrepancia, pero el workaround es confiable.
- **`journalctl --user`** fue la herramienta que realmente destrabó ambos bugs de Dolphin — mucho más informativa que `strace`, `strings` sobre el cache binario, o los flags de debug de `kbuildsycoca6` (que resultaron no producir salida útil, aparentemente compilados sin logging de debug en este build de nixpkgs).
- Sin `sudo` con credenciales en esta sesión, `nixos-rebuild switch` no es ejecutable directamente — la verificación de fixes que tocan rutas gestionadas por el perfil de Nix (`/etc/profiles/per-user/...`) requirió workarounds (override de `XDG_CONFIG_DIRS`, reemplazo temporal de symlinks de home-manager por archivos planos) en vez de una confirmación end-to-end con el mecanismo real de despliegue.

### 27.6 Pendientes

- Confirmación real post-`nixos-rebuild switch` de todo lo de esta ronda (bloqueado por falta de sudo en esta sesión).
- Comportamiento HDMI real (mirror/hdmi-only/laptop-only, audio) contra un TV físico.

---

## 28. Estado de Ratificación

Snapshot verdadero al cierre del Hito 004 (secciones 1-7) más sus once follow-ups en la misma rama (secciones 8, 10, 12, 14, 16, 18, 20, 21, 23, 25 y 27). Cualquier cambio posterior invalida secciones específicas y debe generar Hito 005. No modificar retroactivamente — versionar hitos.

**FIN DEL DOCUMENTO — Hito 004**
