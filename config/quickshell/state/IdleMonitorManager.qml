import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

Item {
    id: mgr

    required property var shellState

    IdleMonitor {
        id: screenOffIdleMonitor
        timeout: Math.max(10, mgr.shellState.screenOffTimeoutMin * 60)
        respectInhibitors: true
        enabled: !mgr.shellState.awakeActive && mgr.shellState.screenOffTimeoutMin > 0

        onIsIdleChanged: {
            if (isIdle) {
                mgr.shellState.isScreenOff = true;
                if (mgr.shellState.lockOnScreenOff && !mgr.shellState.locked) {
                    mgr.shellState.lockScreen();
                }
                Quickshell.execDetached([mgr.shellState.script("power-action.sh"), "dpms-off"]);
            } else {
                if (mgr.shellState.isScreenOff) {
                    mgr.shellState.isScreenOff = false;
                    Quickshell.execDetached([mgr.shellState.script("power-action.sh"), "dpms-on"]);
                }
            }
        }
    }

    IdleMonitor {
        id: sleepIdleMonitor
        timeout: Math.max(30, mgr.shellState.sleepTimeoutMin * 60)
        respectInhibitors: true
        enabled: !mgr.shellState.awakeActive && mgr.shellState.sleepTimeoutMin > 0

        onIsIdleChanged: {
            if (isIdle) {
                if (!mgr.shellState.locked) {
                    mgr.shellState.lockScreen();
                }
                Quickshell.execDetached([mgr.shellState.script("power-action.sh"), "suspend"]);
            }
        }
    }
}
