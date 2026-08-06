# NixOS + Hyprland — Plan de Investigación: File Manager Kirigami+KIO
## Jerimy's Laptop | Hito 005 — Reemplazo de Dolphin (FASE 1: solo investigación, sin código)

**Fecha:** 2026-08-06
**Estado:** Documento de planificación. **No se tocó ningún archivo de configuración, no se agregó ningún paquete, no se escribió QML ni Nix de implementación.** Dolphin+Kvantum siguen intactos y en uso.
**Precede a:** `NIXOS_ARCHITECTURE_HITO_004.md` (2026-08-01 en adelante). Este documento asume ese baseline — en particular la arquitectura de QuickShell (§1), el pipeline de paleta matugen→`palette.json`→`WallpaperPalette.qml`→`Theme.qml`→`WorkspaceSync.qml` (§29 addendum), y las convenciones de `hosts/laptop/home.nix`/`scripts.nix`.
**Disciplina aplicada:** misma que la adopción de QuickShell al inicio de Hito 004 — investigar, escribir el plan, parar, esperar aprobación explícita antes de Fase 2 (implementación). El sistema desplegado hoy no cambia por este documento.

---

## 0. Resumen ejecutivo

El pedido: reemplazar Dolphin por un file manager real, construido sobre Kirigami (QML) + KIO (el backend de operaciones de archivos de KDE), con la misma disciplina de animación que ya tiene QuickShell — no un reskin de Dolphin, una app nueva que se sienta parte de la misma familia visual.

Investigación hecha contra el nixpkgs real de este flake (no memoria genérica): se leyó el derivation de `kdePackages.dolphin`, el helper `mkKdeDerivation` que lo construye, y la tabla de dependencias generada (`generated/dependencies.json`) que usa internamente. Hallazgo central: **`mkKdeDerivation` no sirve para una app nueva fuera del árbol de KDE** — está atado a una base de datos generada de fuentes/dependencias por `pname`, poblada solo con proyectos oficiales de KDE Gear/Frameworks/Plasma que nixpkgs ya conoce. Una app propia del flake necesita un derivation CMake convencional (`stdenv.mkDerivation` + `extra-cmake-modules`), no ese helper. Esto es factible — es exactamente cómo cientos de apps KDE fuera de nixpkgs se compilan contra un nixpkgs con Qt6/KF6 — pero es más trabajo de Nix que "agregar un paquete a la lista", y hay que planearlo así.

Recomendación de arquitectura (§2): **aplicación standalone**, no panel de QuickShell. Razón técnica concreta, no preferencia: drag-and-drop real entre esta app y otras (subir un archivo a un navegador, arrastrar una imagen a GIMP, arrastrar a la papelera) depende de que la ventana participe del protocolo `xdg_toplevel` normal del compositor — las superficies `layer-shell` (que es lo que QuickShell usa para la barra/dashboard) tienen semántica de foco/input restringida y drag-and-drop entre shells distintos es terreno frágil en Wayland. Ver §2 para el detalle.

La integración de tema (§3) es viable sin depender de Kvantum: Kirigami expone `Kirigami.Theme.*` como propiedades adjuntas que se heredan por el árbol QML igual que cualquier propiedad adjunta normal — se pueden pisar en la raíz (`Kirigami.ApplicationWindow`) leyendo el mismo `palette.json` que ya escribe matugen, con un lector `FileView` calcado del que ya existe en `WallpaperPalette.qml` (proceso QML separado, no puede importar el singleton de QuickShell directamente — comparten archivo, no memoria).

Scope de v1 propuesto en §5: navegar (C++ delgado sobre `KDirLister`/`KFilePlacesModel`, ver §1.5/§1.6), abrir con `xdg.mimeApps` existente, copiar/mover/eliminar/renombrar/papelera **vía shell+coreutils por `Process`** (revisado esta ronda — ver §1.6/§5.1: se investigó `kioclient` como intermediario pedido y se confirmó que **no existe** en este nixpkgs/KF6, ni como binario ni como paquete separado; el objetivo real detrás del pedido —v1 sin C++ nuevo para operaciones, mismo patrón `writeShellScriptBin`+`Process` que `hdmi-control`— se logra igual, solo que directo con coreutils + una implementación bash del spec de papelera de freedesktop.org, no con `kioclient`). Explícitamente afuera: red (sftp/smb), búsqueda/baloo, tabs, previews de archivos comprimidos, tags.

Plan de migración (§6, para ejecutar recién cuando v1 esté aprobado y probado en vivo) — con una advertencia real encontrada durante la investigación: `QT_STYLE_OVERRIDE=kvantum`/`QT_QPA_PLATFORMTHEME=qt6ct` en `home.nix` son variables de **sesión completa**, no específicas de Dolphin — antes de borrar `modules/kvantum/` hay que confirmar que ninguna otra app Qt6 del sistema (QuickShell mismo usa qt6ct para sus diálogos nativos, según el comentario ya existente en `home.nix:30-32`) depende de ellas.

---

## 1. Feasibility en NixOS/nixpkgs

### 1.1 Qué existe hoy en este nixpkgs (verificado, no supuesto)

El flake está fijado a `nixpkgs/nixos-unstable` rev `241313f4e8e5...` (2026, ya con KDE Frameworks 6 / Qt6). Se inspeccionó directamente el árbol fetched en `/nix/store/.../pkgs/kde/` de este mismo checkout. Confirmado que existen como atributos independientes bajo `kdePackages.*`:

- `extra-cmake-modules` (ECM) — los módulos CMake que todo proyecto KDE usa para configurar instalación, i18n, etc.
- `kirigami` — Framework de UI QML. En este nixpkgs el paquete real se llama `kirigami` (no `kirigami2`, que era el nombre KF5). Dato importante encontrado en el derivation: `kirigami` en nixpkgs es un **wrapper** que propaga tanto el Kirigami "unwrapped" como `qqc2-desktop-style` — Kirigami tiene una dependencia circular real con `qqc2-desktop-style` (el estilo QQC2 que hace que los controles se vean "nativos KDE" en vez de QQC2 genérico), y nixpkgs la resuelve compilando `qqc2-desktop-style` contra el Kirigami sin envolver y reexportando ambos juntos. Consecuencia práctica: **basta con depender de `kdePackages.kirigami`** — no hace falta listar `qqc2-desktop-style` aparte, ya viene incluido.
- `kio`, `kcoreaddons`, `ki18n`, `kconfig`, `kiconthemes`, `kconfigwidgets`, `breeze-icons` — todos existen como paquetes propios.

### 1.2 La cadena de dependencias real de Dolphin (referencia, leída de `generated/dependencies.json` de este nixpkgs)

```
kio         -> extra-cmake-modules, karchive, kbookmarks, kcolorscheme, kcompletion,
               kconfig, kcoreaddons, kcrash, kdbusaddons, kdoctools, kguiaddons,
               ki18n, kiconthemes, kitemviews, kjobwidgets, knotifications,
               kservice, kwallet, kwidgetsaddons, kwindowsystem, solid

dolphin     -> baloo, baloo-widgets, extra-cmake-modules, kbookmarks, kcmutils,
               kcodecs, kcolorscheme, kcompletion, kconfig, kcoreaddons, kcrash,
               kdbusaddons, kdoctools, kfilemetadata, ki18n, kiconthemes, kio,
               kio-extras, knewstuff, knotifications, kparts, ktextwidgets,
               kuserfeedback, kwindowsystem, packagekit-qt,
               selenium-webdriver-at-spi, solid

qqc2-desktop-style -> extra-cmake-modules, kcolorscheme, kiconthemes, kirigami, sonnet
```

Esto es información real (no genérica) y define qué subconjunto necesitamos: `kio` ya trae `kbookmarks` (para Places), `solid` (detección de dispositivos/montajes — también necesario para Places), `kjobwidgets` (progreso de operaciones), `kiconthemes` (iconos de carpeta/archivo coherentes con el tema de iconos activo — ya usamos `papirus-icon-theme`), `knotifications` (avisos de "copia terminada", etc.). De la lista de Dolphin, lo que NO necesitamos para v1: `baloo`/`baloo-widgets`/`kfilemetadata` (búsqueda/metadatos indexados), `knewstuff` ("get new stuff", descargas), `kuserfeedback` (telemetría), `packagekit-qt` (instalar paquetes desde el explorador), `selenium-webdriver-at-spi` (solo tests), `ktextwidgets`/`kparts`/`kcmutils` (Dolphin embebe un editor de texto y páginas de configuración tipo KCM que no necesitamos).

### 1.3 Por qué `mkKdeDerivation` NO sirve para esto (hallazgo central)

Se leyó `pkgs/kde/lib/mk-kde-derivation.nix` completo. Es el helper que construye Dolphin, Kirigami, KIO, etc. en nixpkgs. Su firma real:

```nix
{ pname, version ? self.sources.${pname}.version, src ? self.sources.${pname}, ... }:
let
  depNames = dependencies.${pname} or [ ];   # <- generated/dependencies.json, indexado por pname
  ...
```

`dependencies`, `src` y los metadatos de licencia/descripción se leen todos de tres JSON generados (`generated/dependencies.json`, `generated/projects.json`, `generated/sources/*.json`) que un bot de nixpkgs mantiene escaneando los proyectos oficiales de KDE Gear/Frameworks/Plasma. Si `pname` no está en esas tablas —que es exactamente el caso de una app propia de este flake, sin repo en `invent.kde.org`— `mkKdeDerivation` no tiene de dónde sacar ni el `src` ni la lista de dependencias. **No es una opción para nuestra app**, ni con `excludeDependencies`/`extraPropagatedBuildInputs` (esos parámetros ajustan la lista ya encontrada por `pname`, no la reemplazan desde cero).

Lo que sí es el camino correcto — patrón estándar de cualquier app KDE/ECM fuera de nixpkgs, sin necesidad de plantilla externa:

```nix
{ stdenv, cmake, ninja, extra-cmake-modules, qt6, kirigami, kio, kcoreaddons,
  ki18n, kconfig, kiconthemes, ... }:
stdenv.mkDerivation {
  pname = "nuestro-file-manager";
  version = "0.1";
  src = ./.;                       # CMakeLists.txt + src/ viven en este flake

  nativeBuildInputs = [ cmake ninja extra-cmake-modules qt6.wrapQtAppsHook ];
  buildInputs = [ qt6.qtbase qt6.qtdeclarative
    kirigami kio kcoreaddons ki18n kconfig kiconthemes ];
}
```
(pseudocódigo ilustrativo — no se escribió el derivation real, esto es solo para documentar que el camino existe y es directo, ya que era la pregunta de esta sección).

El `CMakeLists.txt` en sí sigue el boilerplate ECM estándar de cualquier app KF6 (`find_package(ECM ... NO_MODULE)`, `include(KDEInstallDirs)`, `include(KDECompilerSettings)`, `find_package(Qt6 REQUIRED COMPONENTS Core Quick Gui)`, `find_package(KF6 REQUIRED COMPONENTS Kirigami CoreAddons I18n KIO Config IconThemes)`) — no hace falta un "template de Kirigami" externo, es la misma receta que usa cualquier app KDE nueva.

### 1.4 Prior art real a estudiar (no reinventar)

El proyecto más cercano a lo que se pide, dentro del propio ecosistema KDE, es **Index** — el file manager de Plasma Mobile, escrito específicamente como Kirigami sobre KIO (frontend QML + modelos C++ que envuelven `KIO`/`KFilePlacesModel` para exponerlos a QML). Vale la pena leer su fuente (`invent.kde.org/plasma-mobile/index`) antes de escribir la primera línea de C++ en Fase 2 — es exactamente el mismo problema (KIO no tiene bindings QML "de fábrica" listos para usar; hace falta una capa C++ delgada de por medio, ver §1.5) ya resuelto una vez por gente que mantiene esto activamente.

### 1.5 KIO no es QML nativo — hace falta una capa C++ delgada, pero **acotada a navegación**, no a operaciones (revisado, ver §1.6)

Dato importante para dimensionar el trabajo de Fase 2: KIO (`KIO::Job`, `KIO::CopyJob`, `KDirLister`, `KFilePlacesModel`) son clases `QObject`/`QAbstractItemModel` en C++. Son *usables* desde QML (`qmlRegisterType`, o exponerlas como propiedades de contexto), pero no existe un módulo `import org.kde.kio` con componentes QML de alto nivel listos para poner en una `ListView` — a diferencia de, por ejemplo, `Quickshell.Services.Pipewire`, que sí es una API QML de primera clase.

Esto seguía siendo cierto tras la revisión pedida en §1.6: **para navegar/listar carpetas y para la sidebar de Places** (`KDirLister`/`KFilePlacesModel`) no hay atajo sin C++ que dé un modelo dinámico con roles/iconos/mimetypes correctos — reemplazar eso por `ls`+`Process` sería posible en teoría (mismo patrón que `hdmi-control`) pero perdería justo lo que un `QAbstractItemModel` da gratis (actualización incremental, roles tipados, orden/filtrado en el modelo en vez de en el proceso), y no fue lo que se pidió reevaluar esta ronda — se deja fuera de este documento, no descartado, simplemente no evaluado.

**Lo que SÍ cambia con §1.6**: las operaciones de escritura (copiar/mover/eliminar/renombrar/crear carpeta) ya NO necesitan pasar por `KIO::CopyJob`/`KIO::DeleteJob` en C++ — ver §5.1 revisado. Eso reduce la capa C++ de Fase 2 a: `main.cpp` (registro de tipos + `QGuiApplication`+`QQmlApplicationEngine`) + un modelo que envuelva `KDirLister` + un modelo que envuelva `KFilePlacesModel`. Sigue sin ser "solo QML" como fue QuickShell, pero es menos superficie C++ que la versión anterior de este plan.

### 1.6 `kioclient` — investigado, confirmado AUSENTE en este nixpkgs (no es cuestión de agregar un paquete)

Pedido explícito de esta ronda: evaluar `kioclient5`/`kioclient6` como mecanismo de v1 para operaciones de archivo vía `Process`, en vez de la capa C++. Investigado contra binarios reales, no memoria:

- `kdePackages.kio` (versión 6.28.0 en este nixpkgs, la misma que ya está construida y en uso por Dolphin/kio-extras en este sistema) tiene **tres outputs**: `out`, `dev`, `devtools`. Se inspeccionaron los tres — `out` ya estaba realizado localmente (dependencia de Dolphin), `dev` y `devtools` se trajeron directo de `cache.nixos.org` (sin rebuild, unos segundos) específicamente para esta verificación.
- `out/bin/` contiene `ktrash6` y `ktelnetservice6`. **No contiene `kioclient6`.**
- `devtools` solo contiene un plugin de Qt Designer (`kio6widgets.so`) — nada de binarios.
- `dev` solo contiene headers/cmake/pkgconfig — nada de binarios ejecutables.
- Búsqueda de "kioclient" en las tres rutas completas: cero coincidencias (ni binario, ni página de documentación — compárese con `kioworker6`, que sí tiene documentación empaquetada en `share/doc/HTML/*/kioworker6/`).
- Búsqueda en las bases de datos generadas de nixpkgs (`generated/dependencies.json`, `generated/projects.json`) por cualquier paquete `kio*`: existen `kio`, `kio-admin`, `kio-extras`, `kio-fuse`, `kio-gdrive`, `kio-gopher`, `kio-mtp`, `kio-s3`, `kio-stash`, `kio-upnp-ms`, `kio-zeroconf` — **ninguno es ni contiene `kioclient`**.
- Confirmación adicional, y algo irónica: se corrió `ktrash6 --help` en vivo (binario real, ya en el store). Su propio texto de ayuda dice textualmente: *"Note: to move files to the trash, do not use ktrash, but 'kioclient move url trash:/'"* — es decir, el propio KIO 6.28.0 todavía documenta a `kioclient` como la herramienta correcta para mandar algo a la papelera, pero **esa herramienta no está empaquetada** en este build. No es una limitación de nixpkgs específicamente (no hay ningún paquete separado `kioclient` en la base de datos de KDE tampoco) — todo indica que upstream dejó de instalarlo/mantenerlo como parte del port a KF6, y ni nixpkgs ni el propio `kio` lo compensan con un paquete alternativo.

**Conclusión de esta sección**: no es que el "command surface" de `kioclient` sea insuficiente para el v1 definido en §5 — es que la herramienta directamente no existe en este entorno, y no hay forma de agregarla como paquete porque no hay de dónde tomarla en el nixpkgs actual. Esto invalida la premisa original de usar `kioclient` como intermediario, pero no invalida el objetivo real detrás del pedido ("v1 sin C++ nuevo, mismo patrón `writeShellScriptBin`+`Process`") — ver la revisión de §5.1, que logra ese objetivo por otro camino.

---

## 2. Decisión de arquitectura: app standalone vs. módulo de QuickShell

### 2.1 Cómo funciona realmente el drag-and-drop de KIO/Wayland

Investigado en vez de asumido, tal como se pidió. El drag-and-drop entre aplicaciones en Wayland pasa por el protocolo `wl_data_device` del compositor: la app origen ofrece datos con un MIME type (KIO/Dolphin usan `text/uri-list`, más algunos MIME propios de KDE como `application/x-kde-cutselection` para distinguir cortar de copiar), el compositor arbitra el drag mientras el puntero se mueve sobre superficies de otras apps, y la superficie destino acepta el drop y lee los datos. Esto es el mecanismo por el cual "arrastrar un archivo desde el explorador a un adjunto de correo/upload de navegador/GIMP" funciona hoy con Dolphin.

Las superficies de QuickShell (barra, dashboard) usan el protocolo `wlr-layer-shell-unstable-v1`, no `xdg_toplevel`. Layer-shell existe específicamente para paneles/overlays: tiene su propio modelo de anchoring/exclusive-zone y, crucialmente, un modelo de foco de teclado/input más restringido (`keyboard-interactivity: none/exclusive/on-demand`) pensado para paneles que normalmente NO deberían robarle foco a la ventana que el usuario está usando. El protocolo `wl_data_device` para drag-and-drop fue diseñado y se implementa en la práctica alrededor de superficies `xdg_toplevel`/`xdg_popup` — iniciar o aceptar un drag en una superficie layer-shell es terreno que varios compositores (incluyendo wlroots, la base de Hyprland) no tratan como caso de primera clase, y el comportamiento real varía o directamente no funciona de forma confiable según versión de compositor.

### 2.2 Por qué esto importa para un file manager específicamente

Un file manager real no es solo "mostrar una lista de archivos que reacciona a clicks" (eso sí podría vivir en un panel). Sus casos de uso centrales incluyen arrastrar archivos **hacia y desde otras ventanas normales**: subir un archivo a un formulario web, arrastrar una imagen a un editor, arrastrar un archivo a la papelera, arrastrar entre dos carpetas abiertas en ventanas distintas. Meter esto en una superficie layer-shell apuesta contra el caso de uso principal de la app, por una ganancia estética (que "viva dentro" de QuickShell) que no compensa el riesgo.

Hay una segunda razón, más simple: espacio de ventana. QuickShell hoy son paneles finos (barra) y un dashboard desplegable pensado para overlays cortos — ninguno de los dos está diseñado para ocupar la pantalla completa con contenido denso y navegable (grillas de miniaturas, listas largas, breadcrumbs) de forma sostenida, que es como se usa un file manager en la práctica.

### 2.3 Recomendación

**Aplicación standalone**, ventana `xdg_toplevel` normal — lanzada igual que Dolphin hoy (`.desktop` propio, bind de teclado, `window-rules.lua` si necesita alguna regla de tamaño/flotante inicial). Esto es además el único camino consistente con la disciplina "no reemplazar Dolphin hasta que la app nueva esté probada en vivo": una app standalone puede coexistir con Dolphin sin tocar nada del setup actual (a diferencia de un módulo de QuickShell, que competiría por espacio/atención en la misma superficie que la barra y el dashboard ya probados).

Esto no excluye continuidad visual — ver §3 y §4: la app comparte paleta y curvas de animación con QuickShell, solo no comparte proceso ni superficie Wayland.

---

## 3. Integración de tema (matugen / `Theme.qml` → Kirigami)

### 3.1 Cómo se propaga el color en Kirigami (mecanismo real, no supuesto)

`Kirigami.Theme` se expone como **propiedad adjunta** (`attached property`) en cada `Item`, con roles como `Kirigami.Theme.textColor`, `highlightColor`, `backgroundColor`, `positiveTextColor`, `negativeTextColor`, `hoverColor`, `focusColor`, etc. Por defecto esos valores se resuelven leyendo el color scheme activo del sistema (`kdeglobals`/KColorScheme) según el `Kirigami.Theme.colorSet` del item (`View`, `Window`, `Button`, `Selection`, `Complementary`, ...). Lo importante para este proyecto: **son propiedades adjuntas normales, se pueden pisar explícitamente**, y una vez pisadas en un nodo del árbol QML, el valor nuevo se hereda hacia todos los hijos que no lo pisen ellos mismos — el mismo mecanismo de herencia de cualquier propiedad adjunta en QML. Esto significa que alcanza con fijar los colores una sola vez en la raíz (`Kirigami.ApplicationWindow`) para que toda la app los herede, sin tener que tocar cada componente individualmente.

### 3.2 El puente con matugen

`WorkspaceSync.qml`/`WallpaperPalette.qml` ya resuelven este problema una vez para QuickShell: `workspace-wallpaper` (en `scripts.nix`) corre matugen y escribe `~/.cache/quickshell/palette.json`; `WallpaperPalette.qml` lo lee con un `FileView` con `watchChanges: true` y expone `colorFor(wallpaperPath)`.

Restricción real a documentar: la app nueva es **un proceso QML separado** (su propio `QQmlApplicationEngine`, no el de `qs`) — no puede importar el singleton `WallpaperPalette` de QuickShell directamente, porque viven en procesos distintos sin memoria compartida. El camino correcto es el mismo patrón que ya usa este proyecto para comunicación entre procesos: **archivo compartido**, no IPC nuevo. Un componente análogo a `WallpaperPalette.qml` (mismo `FileView` sobre el mismo `~/.cache/quickshell/palette.json`, misma lógica `vividize()` para forzar saturación/luminosidad vívida) vive dentro del árbol QML de la nueva app y expone el color derivado; en la raíz `Kirigami.ApplicationWindow` se pisan las propiedades adjuntas relevantes:

```qml
Kirigami.Theme.highlightColor: LocalPalette.activeAccent
Kirigami.Theme.focusColor: LocalPalette.activeAccent
Kirigami.Theme.hoverColor: Qt.rgba(LocalPalette.activeAccent.r, ..., 0.15)
```

(ilustrativo, no implementado — el punto es que el mecanismo existe y es directo, sin necesitar tocar `Theme.qml`/`WallpaperPalette.qml` existentes).

Nota sobre "seguir al workspace activo": tiene sentido que la app arranque con el acento del workspace donde se lanzó (leyendo `palette.json` + algún medio de saber el workspace activo — probablemente vía `hyprctl activeworkspace -j` en un `Process` al arrancar, ya que esta app no tiene el wrapper `Hypr.qml` de QuickShell disponible en su proceso). Actualización en vivo mientras la ventana está abierta y el usuario cambia de workspace es un nice-to-have, no un requisito de v1 — se puede lograr más adelante escuchando el mismo evento si hace falta, pero no bloquea la Fase 2.

### 3.3 Nota importante: esto NO pasa por Kvantum

Kvantum (`modules/kvantum/`) reestiliza apps **QWidget** (Dolphin es QWidget) vía el plugin de estilo Qt (`QT_STYLE_OVERRIDE=kvantum`). Kirigami/QQC2 son **Qt Quick** — sus controles no usan plugins de estilo QWidget en absoluto; usan el sistema de estilos QQC2 (`org.kde.desktop`, provisto por `qqc2-desktop-style`, que como se vio en §1.1 ya viene incluido al depender de `kdePackages.kirigami`). Kvantum no tiene ningún efecto sobre esta app, en ningún sentido — ni hay que integrarlo, ni hay riesgo de que "se filtre" un look no deseado. Es una buena noticia doble: confirma que el look de la nueva app va a ser 100% el que definamos vía `Kirigami.Theme` + QML propio (consistente con el objetivo de este hito), y simplifica el plan de migración (§6) — Kvantum no necesita ningún puente ni conversión, solo eventualmente eliminarse si nada más lo necesita.

---

## 4. Animación y glow — qué es Kirigami nativo y qué es custom

Pedido explícito: no asumir que todo mapea a un primitivo de Kirigami — decir honestamente qué es nativo y qué habría que construir igual que en QuickShell.

| Patrón ya usado en QuickShell (`Theme.qml`) | Primitivo Kirigami/QQC2 real | Nativo o custom |
|---|---|---|
| `durFast`=140/`durMed`=240/`durSlow`=420 | `Kirigami.Units.shortDuration` (~150ms), `Kirigami.Units.longDuration` (~300ms), `Kirigami.Units.veryLongDuration` (~600ms) — constantes reales de Kirigami, no exactamente nuestros valores | **Nativo, pero valores distintos** — decisión pendiente para Fase 2: adoptar las constantes de Kirigami tal cual (más "KDE nativo") o pisarlas para que coincidan exacto con `Theme.qml` (más continuidad 1:1 con QuickShell). Recomendación: pisar — la continuidad visual con el resto del sistema es el requisito explícito de este hito, más que "sentirse KDE stock". |
| `easeOutCubic`/`easeOutBack`/`easeInOutQuad` | `Easing.OutCubic`/`OutBack`/`InOutQuad` — son del motor QML (`PropertyAnimation.easing.type`), no de Kirigami específicamente | **Nativo (a nivel QML, no Kirigami)** — se reutilizan tal cual, sin cambios. |
| Hover-scale de cápsulas/workspaces (`Bar.qml`/`Capsule.qml`) | `Behavior on scale` + `NumberAnimation`, disparado desde `HoverHandler`/`MouseArea.containsMouse` — patrón QML genérico que Kirigami no reemplaza ni mejora | **No es un primitivo Kirigami** — se reimplementa igual que en QuickShell (mismo patrón, no hay atajo Kirigami específico para esto). Aplica directo a delegates de la grilla/lista de archivos. |
| Glow de proximidad (halo detrás de íconos activos) | No existe equivalente en Kirigami — es un efecto custom en QuickShell (gradiente radial + blur detrás del ícono) | **100% custom, ninguna diferencia de esfuerzo** respecto a como ya se construyó en QuickShell — se portaría el mismo componente (o uno equivalente) tal cual, no hay "versión Kirigami" de esto que ahorre trabajo. |
| Selección de ítems (fila/celda resaltada) | `Kirigami.Theme.highlightColor` + estados nativos de `QQC2.ItemDelegate`/`Kirigami.BasicListItem` (`highlighted`, `hovered`) con transición de color ya integrada | **Nativo** — este es el caso donde Kirigami sí da más "gratis" que QQC2 puro: `Kirigami.BasicListItem`/`Kirigami.SwipeListItem` traen highlight+hover animado de fábrica, solo hace falta que `Kirigami.Theme.highlightColor` esté bien pisado (§3.2) para que el color sea el correcto. |
| Transiciones de navegación (entrar/salir de una carpeta) | `Kirigami.PageRow` (pila de páginas tipo breadcrumb/master-detail) trae transiciones de push/pop animadas de fábrica | **Nativo** — este es el primitivo Kirigami pensado exactamente para "navegar hacia adelante/atrás en una jerarquía", que es literalmente lo que es navegar carpetas. Vale la pena construir la navegación de carpetas sobre `PageRow` en vez de reinventar breadcrumbs a mano. |
| Apertura de archivo (feedback visual al hacer doble-click/Enter) | No hay primitivo Kirigami para "flash de apertura" | **Custom**, mismo patrón de animación corta (scale-down + fade, `durFast`) que el resto del sistema. |

Conclusión de esta sección: aproximadamente la mitad de los patrones de interacción tienen un primitivo Kirigami real que conviene usar tal cual (transiciones de navegación, selección/hover de listas) — la otra mitad (glow de proximidad, flash de apertura, hover-scale de grilla) es trabajo custom idéntico en esfuerzo al que ya se hizo para QuickShell, portado componente por componente. Ninguna sorpresa que bloquee el plan, pero listarlo así evita subestimar Fase 2 asumiendo que "Kirigami ya anima todo".

---

## 5. Scope propuesto para v1

### 5.1 Adentro

- **Navegación**: `Kirigami.PageRow` con una página por nivel de carpeta (o una sola página que recarga el modelo — a decidir en Fase 2 según cómo se sienta la animación de `PageRow` en la práctica), breadcrumb de ruta, atrás/adelante.
- **Listado**: modelo respaldado por `KDirLister`/`KIO::ListJob` (vía la capa C++ delgada de §1.5), vista lista y vista grilla con miniatura básica de ícono (no video/PDF en v1 — eso es `kdegraphics-thumbnailers`/`ffmpegthumbs`, que Dolphin ya usa pero que no es necesario para un v1 funcional).
- **Apertura de archivos**: usando el mismo `xdg.mimeApps` que ya está declarado en `home.nix` — vía `KIO::ApplicationLauncherJob` o `KApplicationTrader` (leen la misma base `~/.config/mimeapps.list` que home-manager ya escribe), no una tabla de asociaciones paralela.
- **Operaciones básicas — revisado esta ronda, ver §1.6**: dado que `kioclient` no existe (§1.6), copiar/mover/renombrar/crear-carpeta se implementan con **coreutils vía `Process`**, mismo patrón que `hdmi-control`/`sidepad-toggle` (`writeShellScriptBin`): `cp -r`, `mv`, `mkdir -p`, `rm -rf` (para eliminar permanente, no papelera — ver abajo). Esto ya cumple el objetivo real detrás del pedido original (v1 sin C++ nuevo para operaciones) sin necesitar `kioclient`. Dos concesiones honestas frente a `KIO::CopyJob` real, aceptadas explícitamente para v1:
  - **Progreso**: coreutils no reporta porcentaje. v1 muestra un indicador indeterminado (spinner) mientras el `Process` corre, no una barra con `%` real. Progreso real (vía señales de `KJob`) queda para la capa C++ de v2 si esto resulta insuficiente en uso real (archivos grandes/carpetas grandes).
  - **Cruce de sistema de archivos**: `mv` de GNU coreutils ya hace fallback automático a copy+delete si el `rename()` cruza filesystems (p. ej. mover de `/home` a un USB montado aparte) — no hay que implementarlo a mano, es comportamiento estándar de coreutils.
  - **Errores/permisos**: el script captura `stderr`+código de salida del `Process` y lo sube a la UI como mensaje — no hay diálogos de reintento/autenticación tipo KIO (p. ej. "esta operación necesita permisos de administrador"), fuera de scope v1.
- **Papelera — revisado esta ronda**: como se documentó en §1.6, ni `kioclient` ni `ktrash6` mueven un archivo a la papelera (`ktrash6` solo vacía/restaura). La papelera de escritorio (freedesktop.org Trash spec — `~/.local/share/Trash/{files,info}` + un `.trashinfo` por archivo con la ruta original y fecha) es un formato simple y estable, implementable directo en el mismo script bash sin ninguna librería (mover el archivo a `files/`, escribir el `.trashinfo` en `info/`) — sigue siendo shell puro, cero C++. Limitación explícita de v1: solo soporta trashear archivos en el mismo filesystem que `$HOME` (que es el spec real — para otros mounts el spec pide un `.Trash/$uid` en la raíz de ese mount, que v1 no implementa); en ese caso v1 cae a confirmar un delete permanente en vez de silenciosamente hacer algo incorrecto. Alternativa descartada por ahora pero anotada: `gio trash` (de `glib`/`gio-utils`) implementa el mismo spec y ya es robusto/probado — si el bash a mano da problemas en Fase 2, es el reemplazo más simple, a costo de una dependencia nueva no-KDE.
- **Sidebar de Places**: `KFilePlacesModel` — es el mismo modelo que usan Dolphin y los diálogos nativos de abrir/guardar de KDE, así que Home/Trash/dispositivos montados aparecen consistentes con el resto del sistema sin trabajo extra. Esto sigue siendo C++ (§1.5) — no se reevaluó esta ronda, es lectura de modelo, no una operación de escritura.

### 5.2 Afuera de v1 (explícito, no solo "todo lo demás")

- Sitios de red (sftp/smb/ftp vía KIO slaves) — Dolphin los tiene, pero añaden superficie de configuración/autenticación que no es núcleo de "navegar mis archivos locales".
- Búsqueda indexada (Baloo) — búsqueda simple por nombre en el listado actual sí, indexación de contenido no.
- Tabs / vista dividida.
- Preview/extracción inline de archivos comprimidos (integración con `ark`).
- Miniaturas de video/PDF (`ffmpegthumbs`/`kdegraphics-thumbnailers`) — ícono genérico por tipo en v1.
- Tags/ratings (Baloo).
- Vista de propiedades avanzada (permisos Unix detallados, ACLs) — un diálogo básico de "info" (nombre, tamaño, tipo, modificado) alcanza para v1.
- Integración con PackageKit ("abrir con..." que ofrece instalar una app nueva).

---

## 6. Plan de migración (para ejecutar DESPUÉS de que v1 esté aprobado y probado en vivo — no ahora)

Listado ahora, tal como se pidió, para que esté listo cuando llegue el momento — ninguno de estos pasos se ejecuta en esta fase.

1. **`hosts/laptop/home.nix`** — quitar de `home.packages`: `kdePackages.dolphin`. Evaluar caso por caso (no asumir "todo junto"):
   - `kdePackages.kio-extras`, `kdePackages.ffmpegthumbs`, `kdePackages.kdegraphics-thumbnailers`: solo si el file manager nuevo no los termina necesitando también (si en Fase 2 se decide agregar miniaturas de video/PDF más adelante, estos se quedan).
   - `kdePackages.ark`: depende de si el nuevo file manager integra extraer/comprimir (fuera de scope v1 según §5.2) — mientras no lo tenga, Ark puede quedarse como app standalone independiente para abrir archivos comprimidos manualmente, o migrarse también. Decidir junto con el scope real de v2.
   - `kdePackages.kimageformats`: **no depende de Dolphin** — es usado también por `imv` (visor de imágenes ya declarado por separado) para formatos no nativos de Qt. No tocar.
   - `kdePackages.qtstyleplugin-kvantum`, `kdePackages.qt6ct`: **verificar primero** qué otra app Qt6 del sistema depende de `QT_QPA_PLATFORMTHEME=qt6ct`/`QT_STYLE_OVERRIDE=kvantum` antes de quitarlas — el comentario ya existente en `home.nix` indica que QuickShell mismo usa qt6ct para sus diálogos nativos. Esto no es automáticamente seguro de borrar solo porque Dolphin se fue.
   - `kdePackages.kservice`: es dependencia transitiva de `kio` (ver §1.2) — si el nuevo file manager depende de `kio`, esto se queda de todos modos, ya no es "solo para Dolphin".
   - `applicationsMenu` (el derivation que instala `/etc/xdg/menus/applications.menu`, `modules/kvantum/applications.menu`): este arreglaba un bug real de Dolphin (menú de aplicaciones roto sin `applications.menu`, ver Hito 004 §27). Confirmar en Fase 2 si el file manager nuevo (o cualquier otra app KDE que se agregue) tiene el mismo requisito antes de quitarlo — no asumir que era 100% específico de Dolphin.
2. **`modules/kvantum/`** completo (`kdeglobals`, `qt6ct.conf`, `applications.menu`, `NixCyber/`) — borrar solo después de resolver el punto anterior sobre qt6ct/QuickShell.
3. **`xdg.mimeApps`** en `home.nix`: cambiar `"inode/directory" = "org.kde.dolphin.desktop"` al `.desktop` de la app nueva.
4. **`modules/hyprland/core/keybinds.lua`**: `local fileManager = "dolphin"` → nombre/comando de la app nueva.
5. **`modules/hyprland/core/window-rules.lua`**: la regla `dolphin-float` (`match = { class = "^(org.kde.dolphin)$" }`) → nueva regla con la clase real de la app nueva (verificar en vivo, no asumir el nombre — mismo error que ya se cometió una vez con esta regla, ver comentario existente en el archivo sobre "verificar antes de asumir org.kde.dolphin a ciegas").
6. **Confirmación final**: dejar Dolphin instalado pero no como default un tiempo (rollback fácil) antes de borrarlo del todo, siguiendo la misma disciplina que se usó al retirar Thunar y waybar en Hito 004 — no es parte de esta lista de archivos, es una nota de proceso.

---

## 7. Riesgos / incertidumbre abierta (honesto, no se investigó todo)

- El tamaño real de la capa C++ (§1.5, ahora acotada a navegación/Places tras §1.6) no está prototipado — sigue siendo la parte de mayor incertidumbre de esfuerzo de Fase 2, a diferencia de QuickShell (que fue casi 100% QML). Recomiendo que la primera entrega de Fase 2 sea deliberadamente chica: listar una carpeta y navegar, sin operaciones de escritura todavía, para validar que la capa KIO↔QML funciona antes de construir el resto encima.
- La implementación bash del spec de papelera (§5.1) no se probó en vivo esta ronda — es un spec simple y bien documentado, pero "simple sobre el papel" y "sin bugs con nombres de archivo raros/colisiones/permisos" no es lo mismo; validar temprano en Fase 2 con casos límite reales (nombres con espacios/unicode, un archivo que ya existe en `Trash/files/` con el mismo nombre) antes de confiar en que reemplaza a `kioclient` sin pérdida.
- El progreso indeterminado (spinner, no `%` real) para operaciones grandes vía coreutils (§5.1) es una concesión aceptada, no probada contra un caso real de "copiar una carpeta de varios GB" — si en uso real se siente insuficiente, es la señal concreta para adelantar la capa `KIO::CopyJob` de v2 en vez de vivir con coreutils indefinidamente.
- No se probó en vivo ningún build real de un CMakeLists.txt propio contra `kdePackages.kirigami`/`kio` de este nixpkgs — §1.3 es análisis de los derivations reales de nixpkgs, no una compilación de prueba. Recomiendo que el primer paso de Fase 2 sea justamente eso: un "hola mundo" Kirigami que compila y corre vía `nix build`, antes de tocar KIO.
- `PageRow` para navegación de carpetas (§4) es una recomendación basada en para qué está diseñado el componente, no en una prueba en vivo de que se sienta bien con jerarquías de carpetas profundas — validar temprano en Fase 2, tiene salida de emergencia (breadcrumb a mano + `StackView`) si no convence.
- No hay confirmación en vivo (sesión sin `sudo`, misma limitación que Hito 004) de que `nixos-rebuild build` acepte un derivation CMake nuevo sin fricciones de sandboxing (permisos de red durante configure/build, por ejemplo) — riesgo estándar de cualquier derivation nuevo, no específico de este proyecto, pero vale mencionarlo como primer chequeo de Fase 2.

---

## 8. Qué sigue

Este documento es el final de Fase 1. Falta aprobación explícita antes de:
- Agregar cualquier paquete `kdePackages.*` nuevo a `home.nix`.
- Escribir el primer `CMakeLists.txt`/`main.cpp`/QML de la app nueva.
- Tocar `xdg.mimeApps`, `keybinds.lua`, `window-rules.lua`, o `modules/kvantum/`.

Dolphin sigue siendo el file manager activo del sistema hasta que la Fase 2 entregue una v1 probada en vivo y se apruebe explícitamente el corte, siguiendo §6.
