import QtQuick
import qs.services

// Fila de toggles rápidos: wifi, bluetooth, no-molestar, mute. Flow en vez
// de Row: DndToggle puede expandirse a ~200px por su acordeón de
// duraciones, y en el ancho fijo del dashboard eso no cabe junto a los
// otros 3 toggles sin reflow — Flow los baja de línea en vez de recortarlos
// (el Flickable del dashboard tiene clip:true, así que un overflow de Row
// se vería directamente cortado, no desbordado visible).
Flow {
    id: root
    spacing: 10

    component ToggleButton: Rectangle {
        id: btn
        property string icon: "?"
        property bool active: false
        property color accent: Theme.activeAccent
        signal clicked

        width: 56
        height: 56
        radius: 16
        color: active ? Theme.withAlpha(accent, 0.18) : Theme.surfaceFaint
        border.width: 1.4
        border.color: active ? accent : Theme.surfaceBorder

        Behavior on color { ColorAnimation { duration: Theme.durMed } }
        Behavior on border.color { ColorAnimation { duration: Theme.durMed } }

        Text {
            anchors.centerIn: parent
            text: btn.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 20
            color: btn.active ? btn.accent : Theme.textMuted

            Behavior on color { ColorAnimation { duration: Theme.durMed } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }

        scale: mouseAreaScale.containsMouse ? 1.06 : 1
        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeOutBack } }

        MouseArea {
            id: mouseAreaScale
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    ToggleButton {
        icon: Network.wifiEnabled ? "󰖩" : "󰤭"
        active: Network.wifiEnabled
        accent: Theme.blue
        onClicked: Network.toggleWifi()
    }

    ToggleButton {
        icon: BluetoothStatus.icon()
        active: BluetoothStatus.powered
        accent: Theme.lavender
        onClicked: BluetoothStatus.toggle()
    }

    // DND es un componente propio (no ToggleButton genérico): necesita el
    // acordeón de duraciones, ver DndToggle.qml.
    DndToggle {}

    ToggleButton {
        icon: Volume.muted ? "󰝟" : "󰕾"
        active: !Volume.muted
        accent: Theme.pink
        onClicked: Volume.toggleMute(Volume.sink)
    }
}
