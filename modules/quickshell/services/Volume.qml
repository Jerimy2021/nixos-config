pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property real volume: (sink && sink.audio) ? sink.audio.volume : 0
    readonly property bool muted: (sink && sink.audio) ? sink.audio.muted : false

    property list<var> playbackNodes: []
    property list<var> captureNodes: []

    function refreshNodes() {
        var pb = [];
        var cap = [];
        var values = Pipewire.nodes.values;
        for (var i = 0; i < values.length; i++) {
            var node = values[i];
            if (node.isStream || !node.audio) continue;
            if (node.isSink) pb.push(node); else cap.push(node);
        }
        root.playbackNodes = pb;
        root.captureNodes = cap;
    }

    function setVolume(node, v) {
        if (!node || !node.audio) return;
        node.audio.muted = false;
        node.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute(node) {
        if (!node || !node.audio) return;
        node.audio.muted = !node.audio.muted;
    }

    function nodeLabel(node) {
        if (!node) return "?";
        return node.description || node.name || "Dispositivo";
    }

    Component.onCompleted: refreshNodes()

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { root.refreshNodes(); }
    }

    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.playbackNodes, root.captureNodes).filter(function (n) { return !!n; })
    }
}
