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
- Pasos 2-5: pendientes, se documentan acá a medida que se completan.

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
