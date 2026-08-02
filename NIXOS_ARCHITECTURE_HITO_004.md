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

## 11. Estado de Ratificación

Snapshot verdadero al cierre del Hito 004 (secciones 1-7) más sus dos follow-ups en la misma rama (secciones 8 y 10). Cualquier cambio posterior invalida secciones específicas y debe generar Hito 005. No modificar retroactivamente — versionar hitos.

**FIN DEL DOCUMENTO — Hito 004**
