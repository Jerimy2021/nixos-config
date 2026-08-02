import QtQuick
import QtQuick.Shapes
import qs.services

// Anillo de progreso con extremos redondeados — el valor real anima
// suavemente por el arco (Behavior + NumberAnimation), nunca un redibujado
// instantáneo. Genérico: cualquier capsule/widget con un valor 0..1 puede
// usarlo (batería hoy, volumen mañana si hace falta) sin duplicar lógica.
Item {
    id: root

    property real value: 0 // 0..1
    property color trackColor: Theme.surfaceBorder
    property color progressColor: Theme.activeAccent
    property real thickness: 2.4

    readonly property real _clamped: Math.max(0, Math.min(1, value))
    property real _animValue: _clamped
    // 359.9 en vez de 360: a 360 exactos Qt Shapes a veces colapsa el arco
    // (los extremos redondeados se pisan y el círculo "desaparece").
    Behavior on _animValue { NumberAnimation { duration: Theme.durSlow; easing.type: Theme.easeOutCubic } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.thickness
            strokeColor: root.trackColor
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - root.thickness
                radiusY: root.height / 2 - root.thickness
                startAngle: -90
                sweepAngle: 359.9
            }
        }

        ShapePath {
            strokeWidth: root.thickness
            strokeColor: root.progressColor
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - root.thickness
                radiusY: root.height / 2 - root.thickness
                startAngle: -90
                sweepAngle: root._animValue * 359.9
            }

            Behavior on strokeColor { ColorAnimation { duration: Theme.durMed } }
        }
    }
}
