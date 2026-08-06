# NixOS + Hyprland — Mapa de Arquitectura del Sistema
## Jerimy's Laptop | Hito 005 — File Manager Kirigami+KIO (reemplazo de Dolphin)

**Fecha del hito:** 2026-08-06 (Fase 1, investigación) — Fase 2 (implementación) en curso.
**Estado:** Fase 2 en progreso, verificada en vivo paso a paso. Dolphin sigue siendo el file manager activo (`keybinds.lua`/`xdg.mimeApps` sin tocar) — `nixfm` se instala en paralelo para probar sin reemplazar nada, misma disciplina que QuickShell en Hito 004.
**Precede a:** `NIXOS_ARCHITECTURE_HITO_004.md` (2026-08-01 en adelante) y `NIXOS_FILEMANAGER_HITO05_PLAN.md` (2026-08-06, Fase 1 — plan de investigación aprobado antes de tocar código). Este documento asume ambos.
**Por qué un documento nuevo y no un addendum a Hito 004:** Hito 004 documenta QuickShell (QML/Qt, sin C++ compilado, sin KIO). Hito 005 es un subsistema técnicamente distinto — primer C++ compilado en este flake, primera dependencia de KDE Frameworks (KIO) más allá de Dolphin como app ya empaquetada — mezclarlo en el documento de QuickShell habría hecho más difícil encontrar cualquiera de los dos temas después. Mismo criterio que separó Hito 004 de Hito 001-003.
**Uso:** Adjuntar junto a `NIXOS_FILEMANAGER_HITO05_PLAN.md` y `NIXOS_ARCHITECTURE_HITO_004.md` al inicio de cualquier sesión futura que toque `modules/filemanager/` o `hosts/laptop/filemanager.nix`.

---

## 0. Resumen ejecutivo (se actualiza por paso)

Fase 2 sigue la secuencia numerada acordada explícitamente antes de escribir código (ver plan §8): scaffold desnudo → navegación/Places → tema matugen → operaciones de archivo → animación. Cada paso se verifica en vivo (no solo `nixos-rebuild build`) y se commitea por separado — igual disciplina que Hito 004.

- **Paso 1 (§1, completo):** scaffold Kirigami desnudo compila y lanza. Riesgo más alto del proyecto (primer C++ del flake) aislado y superado — dos bugs reales encontrados y corregidos en el camino, ninguno relacionado con KIO/tema/features (ver §1.2).
- **Paso 2 (§2, completo):** listado real de carpeta (KCoreDirLister) + sidebar de Places (KFilePlacesModel) — verificado en vivo con screenshot real contra la sesión Hyprland.
- **Paso 3 (§3, completo):** Kirigami.Theme sigue el acento matugen-derivado del workspace activo, vía un archivo compartido nuevo (`active-accent.json`) que escribe QuickShell y lee nixfm. Verificado en vivo con dos colores reales distintos — pero NO vía cambio de workspace real (bug real de Hyprland encontrado en esta sesión, ver §3.3, no relacionado con este código).
- Pasos 4-5: pendientes, se documentan acá a medida que se completan.

---

## 3. Paso 3 — Integración de tema matugen (COMPLETO)

### 3.1 Qué se construyó

- **Lado QuickShell** (`modules/quickshell/services/WorkspaceSync.qml`): al cambiar `Theme.activeAccent` (ya sea por cambio de workspace o porque matugen terminó en background), se persiste el valor a `~/.cache/quickshell/active-accent.json` como `{"hex":"#rrggbb"}`, vía un `Process` (`printf ... > archivo`) disparado desde `Connections { target: Theme; function onActiveAccentChanged() }`. Este archivo es nuevo — deliberadamente separado de `palette.json` (que es cache interna de QuickShell, keyed por ruta de wallpaper, con su propia lógica de aleatoriedad/overrides en memoria que un proceso aparte no puede reproducir, ver plan §3.2). `active-accent.json` es un contrato mínimo y deliberado entre los dos procesos: "acá está el color YA resuelto ahora mismo", nada más.
- **Lado nixfm** (`src/PaletteWatcher.h`/`.cpp`): `QFileSystemWatcher` sobre ese archivo (vigilando también el directorio contenedor, para notar cuándo el archivo se crea si `nixfm` arranca antes de que QuickShell haya escrito nada; re-vigilando el archivo tras cada rewrite atómico, que es como escribe el `Process` de arriba — un simple `addPath` no sobrevive un unlink+create). Expuesto a QML como tipo instanciable con una property `accent` (QColor).
- `Main.qml`: `Kirigami.Theme.{highlightColor,focusColor,hoverColor}` pisados en la raíz del `Kirigami.ApplicationWindow` — son propiedades adjuntas, se heredan por todo el árbol QML hijo sin tocar cada componente individualmente (confirmado, no solo documentado — ver verificación abajo). Se agregó también un círculo de color chico en la toolbar como indicador visual real del acento activo (feature legítima, no solo código de prueba).

### 3.2 Verificación en vivo

Reiniciada la instancia de QuickShell corriendo en la sesión real (`nix shell nixpkgs#quickshell -c qs -p modules/quickshell`, apuntando al checkout local con el cambio) para que recogiera el `WorkspaceSync.qml` editado — la instancia previa (desplegada por el último `nixos-rebuild switch` del usuario) no lo tenía. Confirmado un único proceso QuickShell corriendo (se encontró y corrigió un problema propio de esta verificación: dos instancias corriendo en paralelo a la vez tras un primer intento fallido de relanzarla con `nohup ... & disown`, que el sandboxing de este agente mata al terminar la llamada de shell aunque tenga `disown` — la forma correcta fue con el propio mecanismo de background del agente).

Con una sola instancia corriendo:
- `~/.cache/quickshell/active-accent.json` se escribió solo, con un color real derivado de matugen (`#ff9a70`, ni el lavender de fallback ni ningún core-accent fijo — confirma que sí está leyendo el cache de matugen real).
- `nixfm` lanzado en vivo: screenshot real confirma el círculo de la toolbar en ese mismo naranja/coral.
- Forzado un segundo valor real y distinto editando `~/.cache/quickshell/palette.json` (todas las entradas a un azul de prueba `#1a1aff`, restaurado al valor original después) — esto dispara `WallpaperPalette.onCacheChanged` → `WorkspaceSync.applyAccent()` → `Theme.activeAccent` cambia → se reescribe `active-accent.json` → `PaletteWatcher` (ya corriendo, SIN relanzar `nixfm`) lo detecta solo → el círculo de la toolbar cambia a azul en la siguiente captura. Confirma la cadena completa end-to-end, incluyendo que el file-watching en vivo funciona (no solo la lectura al arrancar).
- `palette.json` restaurado a su contenido original byte a byte (`diff` limpio) antes de seguir — no se dejó contaminado el cache real de matugen del usuario.

### 3.3 Gap honesto + un bug real de Hyprland encontrado (no de este código)

El pedido explícito era verificar "across at least two different **workspace** accent colors" — es decir, cambiando de workspace de verdad, no editando el cache a mano. Se intentó extensamente (más de 7 variantes reales, no solo una): `hl.dsp.focus({workspace="N"})` (la sintaxis real ya usada en `keybinds.lua` para los binds numéricos), con `workspace` como string y como número, `hl.dsp.focus({window="class:firefox"})` para forzar el cambio indirectamente, `hyprctl reload` como intento de recuperación (mismo mecanismo que sí resolvió el bug de "cero monitores habilitados" documentado en Hito 004 §29.2), y finalmente una tecla `SUPER+2` **real, sintética** vía `wtype` (no `hyprctl eval`, sino el mismo bind que usa el usuario a diario) — ninguno cambió el workspace activo (`hyprctl activeworkspace -j` siguió reportando el mismo id en todos los casos), pese a que todas las llamadas devolvían `"ok"` sin error. Introspeccionado `hl.dsp`/`hl.dsp.focus`/`hl.dsp.workspace` en vivo (forzando un `error()` de Lua para poder leer el valor de retorno) para confirmar que `focus({workspace=...})` es realmente el mecanismo correcto y no un error de sintaxis de este agente.

**Esto es un problema real de la sesión de Hyprland de esta máquina, no de `nixfm` ni de `WorkspaceSync.qml`** — probablemente relacionado con haber matado/relanzado QuickShell varias veces durante esta verificación (o preexistente). Vale la pena que el usuario lo confirme la próxima vez que use la máquina normalmente (¿los binds `SUPER+1..9` cambian de workspace?) — si el problema persiste tras un login nuevo, es un hallazgo aparte digno de su propia sesión de diagnóstico, no algo para resolver como parte de Hito 005.

La verificación alternativa (§3.2, forzando el cambio vía `palette.json` en vez de vía workspace) ejercita exactamente la misma cadena de código que un cambio de workspace real dispararía — la única diferencia es qué evento dispara `Theme.activeAccent = ...`, no qué pasa después. Confianza alta en que esto funciona igual con un cambio de workspace real una vez que ese problema aparte se resuelva, pero queda como el único punto no confirmado literalmente tal como se pidió.

### 3.4 Estado de Dolphin

Sin cambios — mismo estado que §1.4/§2.4.

---

## 2. Paso 2 — Browsing + sidebar de Places (COMPLETO)

### 2.1 Qué se construyó

- `FolderModel` (`src/FolderModel.h`/`.cpp`): `QAbstractListModel` propio respaldado por `KCoreDirLister` (de `KIOCore` — deliberadamente NO `KDirLister`/`KIOWidgets`, que arrastra QtWidgets sin necesidad). Property `folder` (QUrl, navegable reasignándola), roles `name`/`iconName`/`isDir`/`url`/`size`/`mimeType`.
- `KFilePlacesModel` expuesto directo sin wrapper — ya es un `QAbstractItemModel` de KIO, solo hace falta registrarlo como tipo QML instanciable.
- Ambos registrados vía `qmlRegisterType` en `main.cpp` bajo el URI propio `org.nixos.filemanager` (KIO no tiene un módulo QML de fábrica, ver plan §1.5 — este es exactamente ese puente delgado).
- `CMakeLists.txt`: `find_package(KF6 REQUIRED COMPONENTS KIO)`, linkea `KF6::KIOCore` + `KF6::KIOFileWidgets` (esta última es donde vive `KFilePlacesModel`, y sí trae QtWidgets transitivamente — inevitable, no hay forma de usar el Places model real de KIO sin eso).
- QML: `RowLayout` con sidebar (`ListView` sobre `PlacesModel`) + panel principal (`ListView` sobre `FolderModel`, con un botón "Subir" simple). Navegación real por `PageRow`/breadcrumb animado queda para el paso 5 (animación) — acá el objetivo era solo "los datos son reales".

### 2.2 Bug real encontrado en vivo

`Kirigami.BasicListItem` no existe en esta versión de Kirigami (6.28) — error QML en vivo: `"Kirigami.BasicListItem is not a type"`. Reemplazado por `QQC2.ItemDelegate` (API de `QtQuick.Controls`, estable independientemente de qué delegates exponga esta versión puntual de Kirigami). Nota para el paso 5 (animación): revisar en ese momento qué delegates de alto nivel SÍ expone esta versión de Kirigami antes de asumir cualquier nombre de la documentación general — ya van dos bugs de este tipo (ver también §1.2) en dos pasos, así que no es casualidad, es real que hay que verificar contra la versión instalada, no contra memoria genérica de "cómo es Kirigami".

### 2.3 Verificación en vivo

Screenshot real tomado con `grim` contra la sesión Hyprland real (no una captura simulada) — requirió enfocar el workspace donde Hyprland tiló la ventana antes de poder capturarla (`hl.dsp.focus({workspace="N"})`, la misma sintaxis Lua real de este fork ya usada en `keybinds.lua`, no la sintaxis clásica `hyprctl dispatch workspace N`, que falla en este fork). Contenido confirmado:
- Listado de carpeta: archivos reales de `$HOME` con nombres reales, e iconos correctos por tipo de archivo (PDF, HTML, imagen, xlsx) — confirma que `KFileItem::iconName()` + la resolución de tema de iconos (Papirus, vía el mismo `QT_QPA_PLATFORMTHEME=qt6ct` que ya configura el resto del sistema) funcionan sin configuración adicional.
- Sidebar de Places: entradas reales — Home, Downloads, Pictures, Trash, Network, entradas de línea de tiempo ("Modified Today"/"Modified Yesterday"), y un dispositivo montado real ("3.9 GiB Internal Drive...") — confirma que `KFilePlacesModel` está leyendo el estado real del sistema (Solid), no una lista estática.
- **Gap honesto**: click-to-navigate no se probó con un click sintético (no había `ydotool`/`wlrctl` instalados en esta sesión, y no se agregaron solo para esto). Lo que sí está probado en vivo: el mismo camino de código que un click dispararía (`folderModel.folder = <url>`) ya se ejecuta al arrancar la app (`FolderModel`'s constructor llama `setFolder()` con `$HOME`), y el resultado (listado+título correctos) está confirmado — el binding QML del `onClicked` en sí (una línea, sin lógica propia) es el único tramo no ejercitado literalmente por un click real.
- `nixos-rebuild build --flake .`: pasó completo.

### 2.4 Estado de Dolphin

Sin cambios — mismo estado que §1.4.

---

## 1. Paso 1 — Scaffold desnudo (COMPLETO)

### 1.1 Qué se construyó

- `modules/filemanager/` — `CMakeLists.txt` (boilerplate ECM estándar: `find_package(ECM)`, `KDEInstallDirs`, `KDECMakeSettings`, `KDECompilerSettings`), `src/main.cpp` (arranca `QGuiApplication`+`QQmlApplicationEngine`, carga el módulo QML), `qml/Main.qml` (`Kirigami.ApplicationWindow` vacía, un `Kirigami.Page` con un label).
- `hosts/laptop/filemanager.nix` — `stdenv.mkDerivation` convencional (no `mkKdeDerivation`, confirmando en la práctica el hallazgo del plan §1.3). Todos los paquetes Qt6/KF6 tomados del scope `kdePackages` (no mezclado con `pkgs.qt6.*`) para evitar dos instancias de Qt6 potencialmente distintas vía splicing.
- `home.nix` — `nixfm` agregado a `home.packages`, instalado en paralelo a Dolphin.

### 1.2 Dos bugs reales encontrados verificando en vivo (el build solo no los habría detectado)

**Bug 1 — Qt suprime su propio output de error bajo journald.** El binario salía con código 255 sin imprimir absolutamente nada, ni con `2>&1` a un archivo, ni con `QT_DEBUG_PLUGINS=1`/`QML_IMPORT_TRACE=1`. La causa: `JOURNAL_STREAM` estaba seteado en el entorno (systemd conecta stderr al journal), y Qt detecta eso y cambia su logging por defecto a modo estructurado-journal en vez de texto plano por stderr — silencioso a menos que se sepa buscarlo. Diagnosticado forzando `QT_LOGGING_TO_CONSOLE=1` (deprecado en Qt6 pero todavía funcional, con warning), que reveló el error real de Qt debajo. **Nota para verificación futura de este mismo binario**: si algo parece fallar "sin ningún output", probar primero con `QT_LOGGING_TO_CONSOLE=1` antes de asumir que no hay error — es fácil perder tiempo pensando que el proceso no llegó a ejecutar nada.

**Bug 2 — mismatch entre `qt_add_qml_module` y `loadFromModule` (la causa real del bug 1).** Una vez visible el error (`Module "org.nixos.filemanager" contains no type named "Main"`), la causa real: `qt_add_qml_module(QML_FILES qml/Main.qml)` preserva por defecto la subcarpeta `qml/` del árbol fuente dentro del recurso Qt compilado (queda en `:/.../filemanager/qml/Main.qml`), pero `engine.loadFromModule(uri, "Main")` asume siempre la convención documentada `qrc:/qt/qml/<uri>/<Type>.qml` — sin esa subcarpeta. Además, el `RESOURCE_PREFIX` real usado por default resultó depender de una política de CMake/Qt no fijada explícitamente en este proyecto (quedó en `:/org/nixos/filemanager/`, no en `:/qt/qml/org/nixos/filemanager/`) — confirmado inspeccionando el binario compilado con `strings` (línea `prefer :/...` del qmldir embebido). Fix de dos partes en `CMakeLists.txt`:
```cmake
set_source_files_properties(qml/Main.qml PROPERTIES QT_RESOURCE_ALIAS "Main.qml")

qt_add_qml_module(nixfm
    URI org.nixos.filemanager
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES qml/Main.qml
)
```

### 1.3 Verificación en vivo (no solo build)

- `nix build` standalone de la derivation: pasó a la primera (antes de los fixes de arriba, que se encontraron recién al lanzar el binario — el build en sí nunca falló, los bugs eran de runtime).
- Binario lanzado contra la sesión Hyprland real (`WAYLAND_DISPLAY=wayland-1`, la sesión real de la máquina, no un Xvfb/headless): confirmado vía `hyprctl clients -j` una ventana real, `title: "nixfm — Hito 005 (scaffold)"`, proceso vivo, sale limpio al matarlo.
- `nixos-rebuild build --flake .`: pasó completo (exit 0, "Done.") con `nixfm` ya en `home.packages` — valida que el derivation nuevo no rompe la evaluación del resto del flake.
- Nota de proceso: los archivos nuevos no eran visibles para Nix hasta `git add` (flakes solo evalúan contenido trackeado por git) — no es un bug, es el comportamiento esperado y ya conocido de rondas anteriores de este proyecto, mencionado acá solo para que quede registrado el paso.

### 1.4 Estado de Dolphin

Sin cambios. `keybinds.lua` (`fileManager = "dolphin"`) y `xdg.mimeApps` (`inode/directory = org.kde.dolphin.desktop`) siguen intactos. `nixfm` no tiene `.desktop`, no tiene bind de teclado, no tiene regla en `window-rules.lua` — se lanza solo manualmente para verificación, tal como especifica el paso 1 del plan.

---

*(Este documento se sigue completando a medida que avanzan los pasos 2-5 — ver NIXOS_FILEMANAGER_HITO05_PLAN.md §8 para la secuencia completa acordada.)*
