cmake_minimum_required(VERSION 3.16)
project(nixfm VERSION 0.1.0 LANGUAGES CXX)

# Hito 005 — Fase 2, paso 1: scaffold desnudo. Deliberadamente sin KIO/KF6
# todavía (ver NIXOS_FILEMANAGER_HITO05_PLAN.md §1.3/§1.5 y el pedido
# explícito de la sesión: "bare scaffold first, nothing else" — aislar el
# riesgo del primer build C++ de este flake de cualquier feature real).
# Boilerplate ECM estándar de cualquier app KF6, tal como se documentó en
# el plan — no es un template externo, es la receta genérica.

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)

# Paso 2: KCoreDirLister vive en KIOCore (sin QtWidgets); KFilePlacesModel
# vive en KIOFileWidgets (histórico — sí liga QtWidgets transitivamente,
# aunque esta app no use ningún QWidget propio; no hay forma de evitarlo
# y usar el Places model real de KIO, ver plan §1.5/§5.1). Ambos vienen
# del mismo paquete nixpkgs `kio`, un solo find_package.
find_package(KF6 REQUIRED COMPONENTS KIO)

qt_add_executable(nixfm
    src/main.cpp
    src/FolderModel.cpp
    src/PaletteWatcher.cpp
    src/FileOperations.cpp
)

# QT_RESOURCE_ALIAS: sin esto, qt_add_qml_module preserva la subcarpeta
# "qml/" del árbol fuente dentro del recurso compilado (queda en
# .../filemanager/qml/Main.qml), pero engine.loadFromModule(uri, "Main")
# busca .../filemanager/Main.qml (sin "qml/") — mismatch real encontrado
# en vivo (ver commit): el módulo cargaba, pero "no tenía ningún tipo
# llamado Main". Este alias aplana la ruta del recurso sin mover el
# archivo físico (se mantiene organizado en qml/ en el árbol fuente).
set_source_files_properties(qml/Main.qml PROPERTIES
    QT_RESOURCE_ALIAS "Main.qml"
)

# RESOURCE_PREFIX explícito: sin esto, el prefijo real del recurso
# compilado depende de una política de CMake/Qt no fijada acá (quedó en
# ":/org/nixos/filemanager/" en vez de ":/qt/qml/org/nixos/filemanager/"
# — encontrado en vivo con `strings` sobre el binario), pero
# `engine.loadFromModule(uri, type)` SIEMPRE asume la convención
# "qrc:/qt/qml/<uri>/<Type>.qml" (documentado así en Qt) sin importar esa
# política. Fijarlo acá hace que las dos partes coincidan sin depender de
# qué versión de CMake/Qt decida el default.
qt_add_qml_module(nixfm
    URI org.nixos.filemanager
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES
        qml/Main.qml
)

target_link_libraries(nixfm PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    KF6::KIOCore
    KF6::KIOGui
    KF6::KIOFileWidgets
)

install(TARGETS nixfm ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
