import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: volMon

    required property var shellState

    property real lastKnownVolume: -1
    property bool lastKnownMuted: false
    property bool initialized: false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Timer {
        interval: 1000
        running: true
        repeat: false
        onTriggered: {
            const sink = Pipewire.defaultAudioSink;
            if (sink && sink.audio) {
                volMon.lastKnownVolume = sink.audio.volume;
                volMon.lastKnownMuted = sink.audio.muted;
            }
            volMon.initialized = true;
        }
    }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumeChanged() {
            if (!volMon.initialized) return;
            const sink = Pipewire.defaultAudioSink;
            if (sink && sink.audio) {
                if (Math.abs(sink.audio.volume - volMon.lastKnownVolume) > 0.005) {
                    volMon.lastKnownVolume = sink.audio.volume;
                    volMon.shellState.triggerVolumeOsd();
                }
            }
        }
        function onMutedChanged() {
            if (!volMon.initialized) return;
            const sink = Pipewire.defaultAudioSink;
            if (sink && sink.audio) {
                volMon.lastKnownMuted = sink.audio.muted;
                volMon.shellState.triggerVolumeOsd();
            }
        }
    }
}
