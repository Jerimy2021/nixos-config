// Hito 005 — Fase 2, paso 1: ventana vacía, solo para verificar que el
// binario compila y lanza de verdad contra Kirigami real. Navegación,
// tema matugen y animación llegan en los pasos siguientes (ver
// NIXOS_FILEMANAGER_HITO05_PLAN.md §8).
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root
    title: "nixfm — Hito 005 (scaffold)"
    width: 900
    height: 600
    visible: true

    pageStack.initialPage: Kirigami.Page {
        title: "Paso 1: scaffold"

        QQC2.Label {
            anchors.centerIn: parent
            text: "Compila y lanza. Sin funcionalidad todavía."
        }
    }
}
