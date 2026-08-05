import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.services

// Selector manual de wallpaper para el workspace actual (Hito 004 follow-up
// 3). Al clickear, delega en WorkspaceSync.setWallpaperForCurrent() en vez
// de llamar workspace-wallpaper directo — así la elección queda mapeada al
// workspace igual que el ciclo automático (persiste mientras dure el
// proceso qs) y sigue disparando el cacheo de paleta matugen.
//
// Hito 004 follow-up 15 (pedido explícito: "convertir a un slider/filmstrip
// horizontal — Flickable + contentX, reusar el mismo mecanismo que el
// carrusel de pestañas del Dashboard — en vez del layout actual"). Antes
// era un Flow (grilla que envuelve en varias filas). Ahora es un Flickable
// de una sola fila: arrastre nativo (interactive:true, a diferencia del
// carrusel de Dashboard.qml que es interactive:false porque ahí el
// contentX solo lo mueve el click en una tab) MÁS dos flechas (‹ ›) que
// animan `contentX` con el mismo `Behavior` + NumberAnimation(duration:
// Theme.durMed, easing: Theme.easeOutCubic) que ya usa el carrusel del
// Dashboard — la única diferencia real es `enabled: !filmstrip.moving &&
// !filmstrip.dragging` en el Behavior, necesario para que no pelee con el
// arrastre nativo (un Behavior activo mientras el usuario arrastra
// "anima" cada frame del gesto, lo vuelve gomoso — deshabilitarlo durante
// el drag es el patrón estándar de QtQuick para esto).
Item {
    id: root
    implicitHeight: 108

    property var files: []

    readonly property real cardSize: 88
    readonly property real cardSpacing: 12
    readonly property real scrollStep: (cardSize + cardSpacing) * 3

    Process {
        id: lister
        command: ["bash", "-c", "find \"$HOME/Pictures/Wallpapers\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"]
        stdout: StdioCollector {
            onStreamFinished: root.files = text.trim().length > 0 ? text.trim().split("\n") : []
        }
    }

    Component.onCompleted: lister.running = true

    Flickable {
        id: filmstrip
        anchors.fill: parent
        contentWidth: row.implicitWidth
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2000

        Behavior on contentX {
            enabled: !filmstrip.moving && !filmstrip.dragging
            NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic }
        }

        Row {
            id: row
            spacing: root.cardSpacing
            height: filmstrip.height

            Repeater {
                model: root.files

                delegate: Rectangle {
                    id: card
                    required property string modelData
                    readonly property bool isActive: modelData === WorkspaceSync.wallpaperFor(Hypr.activeId)

                    width: root.cardSize
                    height: root.cardSize
                    radius: 14
                    color: Theme.surfaceFaint
                    border.width: isActive ? 2 : 1
                    border.color: isActive ? Theme.activeAccent : Theme.surfaceBorder
                    clip: true

                    scale: hoverArea.containsMouse ? 1.06 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeOutBack } }
                    Behavior on border.color { ColorAnimation { duration: Theme.durMed } }

                    // Hito 004 follow-up 15 (pedido explícito: "glow
                    // basado en Theme.activeAccent en el popup y/o la
                    // miniatura seleccionada/hovereada") — glow persistente
                    // en la miniatura activa, y uno más intenso mientras se
                    // hoverea cualquiera (misma técnica MultiEffect que el
                    // resto del dashboard, recoloreada a activeAccent).
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: card.isActive || hoverArea.containsMouse
                        shadowColor: Theme.activeAccent
                        shadowBlur: hoverArea.containsMouse ? 0.8 : 0.5
                        shadowVerticalOffset: 0
                        shadowHorizontalOffset: 0
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 3
                        source: "file://" + card.modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 176
                        sourceSize.height: 176
                    }

                    // Marca de "activo" — la esquina inferior-derecha, además del
                    // borde acentuado, para que se note incluso al pasar rápido la
                    // mirada por la tira.
                    Rectangle {
                        visible: card.isActive
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 4
                        width: 18
                        height: 18
                        radius: 9
                        color: Theme.activeAccent

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: Theme.surface
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: hoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WorkspaceSync.setWallpaperForCurrent(card.modelData)
                    }
                }
            }
        }
    }

    // Flechas de scroll — visibles solo cuando hay algo hacia ese lado,
    // mismo Behavior on contentX de arriba las anima (no saltan).
    Rectangle {
        id: leftArrow
        visible: filmstrip.contentX > 1
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: 14
        color: Theme.withAlpha(Theme.surface, 0.85)
        border.width: 1
        border.color: Theme.withAlpha(Theme.activeAccent, 0.4)

        Text {
            anchors.centerIn: parent
            text: "‹"
            color: Theme.activeAccent
            font.pixelSize: 16
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: filmstrip.contentX = Math.max(0, filmstrip.contentX - root.scrollStep)
        }
    }

    Rectangle {
        id: rightArrow
        visible: filmstrip.contentX < filmstrip.contentWidth - filmstrip.width - 1
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: 14
        color: Theme.withAlpha(Theme.surface, 0.85)
        border.width: 1
        border.color: Theme.withAlpha(Theme.activeAccent, 0.4)

        Text {
            anchors.centerIn: parent
            text: "›"
            color: Theme.activeAccent
            font.pixelSize: 16
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: filmstrip.contentX = Math.min(filmstrip.contentWidth - filmstrip.width, filmstrip.contentX + root.scrollStep)
        }
    }
}
