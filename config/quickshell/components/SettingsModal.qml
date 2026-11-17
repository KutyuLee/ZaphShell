import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import ".."

IslandFloatPanel {
    id: root

    open: ShellState.settingsOpen
    modalMode: "settings"
    layerNamespace: "quickshell-settings"
    onCloseRequested: ShellState.settingsOpen = false
    subLayoutRev: settingsCard.activeTab * 37.0
        + tab0Item.opacity * 11.0
        + tab1Item.opacity * 17.0
        + tab2Item.opacity * 23.0
        + tab3Item.opacity * 29.0
        + tab4Item.opacity * 31.0

    // ================= DATA MODELS & BACKEND PROCESSES =================
    ListModel { id: wallpapersModel }
    ListModel { id: stNetModel }
    ListModel { id: stBtModel }
    ListModel { id: monDraftsModel }

    property var sysMonitors: []
    property var monDrafts: []
    property int monDraftsRev: 0
    property bool monLayoutDirty: false
    property bool monConfigDirty: false
    property bool monConfirmPending: false
    property int monConfirmSecondsLeft: 10
    property var monBackupSnapshot: null
    property bool isDraggingMonitor: false
    property int selectedMonitorIdx: 0
    property string selectedMonMode: "preferred"
    property string selectedMonRes: ""
    property string selectedMonScale: "1"
    property string selectedMonPos: "auto"
    property int selectedMonTransform: 0
    property int selectedMonVrr: 0
    property int selectedMonBitdepth: 8
    property string selectedMonCm: "srgb"
    property string selectedMonMirror: ""
    property bool selectedMonDisabled: false

    property string kbLayoutInput: "gb,us"
    property string kbVariantInput: ""
    property string kbOptionsInput: ""
    property string kbActiveName: ShellState.activeKeyboardLayout
    property var xkbLayouts: [
        { label: "English (US)  (us)", value: "us" },
        { label: "English (UK)  (gb)", value: "gb" },
        { label: "Hungarian  (hu)", value: "hu" },
        { label: "German  (de)", value: "de" },
        { label: "French  (fr)", value: "fr" },
        { label: "Spanish  (es)", value: "es" },
        { label: "Italian  (it)", value: "it" },
        { label: "Polish  (pl)", value: "pl" },
        { label: "Russian  (ru)", value: "ru" },
        { label: "Japanese  (jp)", value: "jp" }
    ]
    property var xkbVariantsMap: ({})
    property string kbAddLayoutCode: "us"
    property real inputSensitivity: 0.0
    property bool inputNaturalScroll: false

    Timer {
        id: monRevertTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (!root.monConfirmPending) {
                stop();
                return;
            }
            if (root.monConfirmSecondsLeft > 1) {
                root.monConfirmSecondsLeft--;
            } else {
                stop();
                root.revertMonitorChanges();
            }
        }
    }

    property string stNetActionCmd: ""
    property string stNetActionTarget: ""
    property string stNetActionPassword: ""
    property string stWifiPromptSsid: ""
    property string stWifiError: ""
    property bool stWifiConnecting: false
    property bool stWifiShowPw: false

    property string sysActionArgs: ""

    function parseWallpapers(raw) {
        try {
            const arr = JSON.parse(raw.trim());
            wallpapersModel.clear();
            for (let i = 0; i < arr.length; i++) {
                const it = arr[i];
                wallpapersModel.append({
                    wallPath: String(it.path || ""),
                    wallName: String(it.name || "Wallpaper"),
                    active: Boolean(it.active)
                });
            }
        } catch (e) {}
    }

    function parseSystemInfo(raw) {
        try {
            const obj = JSON.parse(String(raw || "").trim());
            if (Array.isArray(obj.monitors)) {
                root.sysMonitors = obj.monitors;
                if (!root.isDraggingMonitor) {
                    root.resetMonitorDrafts();
                }
                if (root.selectedMonitorIdx >= root.sysMonitors.length) {
                    root.selectedMonitorIdx = 0;
                }
                root.syncSelectedMonitorDraft();
            }
            if (obj.keyboard) {
                root.kbLayoutInput = String(obj.keyboard.layout || "gb,us");
                root.kbVariantInput = String(obj.keyboard.variant || "");
                root.kbOptionsInput = String(obj.keyboard.options || "");
                if (obj.keyboard.activeLayout) {
                    root.kbActiveName = String(obj.keyboard.activeLayout);
                    ShellState.activeKeyboardLayout = root.kbActiveName;
                }
            }
            if (obj.input) {
                root.inputSensitivity = Number(obj.input.sensitivity || 0);
                root.inputNaturalScroll = Boolean(obj.input.naturalScroll);
            }
            if (obj.xkbCatalog && Array.isArray(obj.xkbCatalog.layouts) && obj.xkbCatalog.layouts.length > 0) {
                root.xkbLayouts = obj.xkbCatalog.layouts.map(function(item) {
                    return {
                        label: String(item.name || item.code) + "  (" + String(item.code || "") + ")",
                        value: String(item.code || "")
                    };
                });
                const vMap = {};
                const rawVars = obj.xkbCatalog.variants || {};
                const keys = Object.keys(rawVars);
                for (let i = 0; i < keys.length; ++i) {
                    const k = keys[i];
                    const arr = rawVars[k] || [];
                    vMap[k] = [{ label: "Default (Standard)", value: "" }].concat(arr.map(function(v) {
                        return {
                            label: String(v.name || v.code) + "  (" + String(v.code || "") + ")",
                            value: String(v.code || "")
                        };
                    }));
                }
                root.xkbVariantsMap = vMap;
            }
        } catch (e) {}
    }

    function parsedKbSlots() {
        const rawL = String(root.kbLayoutInput || "").split(",");
        const rawV = String(root.kbVariantInput || "").split(",");
        const slots = [];
        for (let i = 0; i < rawL.length; ++i) {
            const lay = rawL[i].trim();
            if (lay.length === 0) continue;
            const varName = (i < rawV.length) ? rawV[i].trim() : "";
            slots.push({ index: slots.length, layout: lay, variant: varName });
        }
        if (slots.length === 0) {
            slots.push({ index: 0, layout: "us", variant: "" });
        }
        return slots;
    }

    function variantsForLayout(layoutCode) {
        const list = root.xkbVariantsMap[String(layoutCode || "")];
        if (Array.isArray(list) && list.length > 0) return list;
        return [{ label: "Default (Standard)", value: "" }];
    }

    function applyKbSlots(slots) {
        if (!slots || slots.length === 0) return;
        const lays = [];
        const vars = [];
        let hasVar = false;
        for (let i = 0; i < slots.length; ++i) {
            const l = String(slots[i].layout || "").trim();
            if (l.length === 0) continue;
            const v = String(slots[i].variant || "").trim();
            if (v.length > 0) hasVar = true;
            lays.push(l);
            vars.push(v);
        }
        if (lays.length === 0) return;
        root.kbLayoutInput = lays.join(",");
        root.kbVariantInput = hasVar ? vars.join(",") : "";
        root.runSysSet(["set_keyboard", root.kbLayoutInput, root.kbVariantInput, root.kbOptionsInput]);
    }

    function parsedKbOptionsList() {
        return String(root.kbOptionsInput || "")
            .split(",")
            .map(function(s) { return s.trim(); })
            .filter(function(s) { return s.length > 0; });
    }

    function getKbOptionInGroup(prefixes, explicitSet) {
        const opts = parsedKbOptionsList();
        for (let i = 0; i < opts.length; ++i) {
            const o = opts[i];
            if (explicitSet && explicitSet.indexOf(o) !== -1) return o;
            for (let p = 0; p < prefixes.length; ++p) {
                if (o.indexOf(prefixes[p]) === 0) return o;
            }
        }
        return "";
    }

    function setKbOptionGroup(prefixes, explicitSet, nextVal) {
        const opts = parsedKbOptionsList().filter(function(o) {
            if (explicitSet && explicitSet.indexOf(o) !== -1) return false;
            for (let p = 0; p < prefixes.length; ++p) {
                if (o.indexOf(prefixes[p]) === 0) return false;
            }
            return true;
        });
        if (nextVal && String(nextVal).trim().length > 0) {
            opts.push(String(nextVal).trim());
        }
        root.kbOptionsInput = opts.join(",");
        root.runSysSet(["set_keyboard", root.kbLayoutInput, root.kbVariantInput, root.kbOptionsInput]);
    }

    function toggleKbOption(opt) {
        const opts = parsedKbOptionsList();
        const idx = opts.indexOf(opt);
        if (idx !== -1) opts.splice(idx, 1);
        else opts.push(opt);
        root.kbOptionsInput = opts.join(",");
        root.runSysSet(["set_keyboard", root.kbLayoutInput, root.kbVariantInput, root.kbOptionsInput]);
    }

    function applyFastWheel(flick, event, stepPx) {
        if (!flick) return;
        const maxY = Math.max(0, flick.contentHeight - flick.height);
        const d = event.angleDelta.y;
        const p = event.pixelDelta.y;
        const step = (d !== 0 ? (d / 120.0) : (p / 18.0)) * (stepPx || 200);
        if (flick.scrollTargetY === undefined) flick.scrollTargetY = flick.contentY;
        flick.scrollTargetY = Math.max(0, Math.min(maxY, flick.scrollTargetY - step));
        flick.contentY = flick.scrollTargetY;
        event.accepted = true;
    }

    function modeResolutionOf(modeStr) {
        const atIdx = String(modeStr || "").indexOf("@");
        return atIdx > 0 ? String(modeStr).slice(0, atIdx) : "";
    }

    function uniqueResolutionsFor(mon) {
        if (!mon) return [];
        const res = [];
        const seen = {};
        const modes = mon.availableModes || [];
        for (let i = 0; i < modes.length; i++) {
            const r = modeResolutionOf(modes[i]);
            if (r && !seen[r]) {
                seen[r] = true;
                res.push(r);
            }
        }
        if (res.length === 0 && mon.width && mon.height) {
            res.push(mon.width + "x" + mon.height);
        }
        return res;
    }

    function refreshRatesFor(mon, resStr) {
        if (!mon || !resStr) return [];
        const out = [];
        const modes = mon.availableModes || [];
        const prefix = resStr + "@";
        for (let i = 0; i < modes.length; i++) {
            const m = String(modes[i]);
            if (m.indexOf(prefix) === 0) {
                const hzRaw = parseFloat(m.slice(prefix.length));
                const hzLabel = !isNaN(hzRaw)
                    ? (Math.abs(hzRaw - Math.round(hzRaw)) < 0.08 ? Math.round(hzRaw) + " Hz" : hzRaw.toFixed(2) + " Hz")
                    : m.slice(prefix.length);
                out.push({ mode: m, label: hzLabel, hz: isNaN(hzRaw) ? 0 : hzRaw });
            }
        }
        return out;
    }

    function snapshotDraftsArray() {
        const out = [];
        for (let i = 0; i < monDraftsModel.count; i++) {
            const it = monDraftsModel.get(i);
            out.push({
                name: it.monName,
                description: it.monDesc,
                width: it.monW,
                height: it.monH,
                refreshRate: it.monRefresh,
                x: it.monX,
                y: it.monY,
                scale: it.monScale,
                transform: it.monTransform,
                vrr: it.monVrr,
                bitdepth: it.monBitdepth,
                cm: it.monCm,
                mirror: it.monMirror,
                disabled: it.monDisabled,
                supportsHdr: it.monSupportsHdr,
                focused: it.monFocused
            });
        }
        return out;
    }

    function updateDraftProp(idx, propName, val) {
        if (idx < 0 || idx >= monDraftsModel.count) return;
        monDraftsModel.setProperty(idx, propName, val);
        root.monDrafts = snapshotDraftsArray();
        root.monDraftsRev++;
    }

    function enabledMonitorCount() {
        let count = 0;
        for (let i = 0; i < monDraftsModel.count; i++) {
            if (!monDraftsModel.get(i).monDisabled) count++;
        }
        return count;
    }

    function resetMonitorDrafts() {
        monDraftsModel.clear();
        const cloned = [];
        for (let i = 0; i < root.sysMonitors.length; i++) {
            const m = root.sysMonitors[i];
            const copy = Object.assign({}, m);
            cloned.push(copy);
            monDraftsModel.append({
                monName: String(m.name || ""),
                monDesc: String(m.description || ""),
                monW: Number(m.width || 1920),
                monH: Number(m.height || 1080),
                monRefresh: Number(m.refreshRate || 60),
                monX: Number(m.x || 0),
                monY: Number(m.y || 0),
                monScale: Number(m.scale || 1.0),
                monTransform: Number(m.transform || 0),
                monVrr: Number(m.vrr || 0),
                monBitdepth: Number(m.bitdepth || 8),
                monCm: String(m.cm || "srgb"),
                monMirror: String(m.mirror || ""),
                monDisabled: Boolean(m.disabled),
                monSupportsHdr: Boolean(m.supportsHdr),
                monFocused: Boolean(m.focused)
            });
        }
        root.monDrafts = cloned;
        root.monDraftsRev++;
        root.monLayoutDirty = false;
        root.monConfigDirty = false;
        root.syncSelectedMonitorDraft();
    }

    function quickArrangeSelected(dir) {
        if (monDraftsModel.count < 2) return;
        const idx = Math.max(0, Math.min(root.selectedMonitorIdx, monDraftsModel.count - 1));
        let otherIdx = -1;
        for (let i = 0; i < monDraftsModel.count; i++) {
            if (i !== idx && !monDraftsModel.get(i).monDisabled) {
                otherIdx = i;
                break;
            }
        }
        if (otherIdx < 0) otherIdx = (idx === 0 ? 1 : 0);
        const sel = monDraftsModel.get(idx);
        const oth = monDraftsModel.get(otherIdx);
        const sW = ((sel.monTransform % 2 === 1) ? sel.monH : sel.monW) / Math.max(0.5, sel.monScale);
        const sH = ((sel.monTransform % 2 === 1) ? sel.monW : sel.monH) / Math.max(0.5, sel.monScale);
        const oW = ((oth.monTransform % 2 === 1) ? oth.monH : oth.monW) / Math.max(0.5, oth.monScale);
        const oH = ((oth.monTransform % 2 === 1) ? oth.monW : oth.monH) / Math.max(0.5, oth.monScale);

        let nx = oth.monX;
        let ny = oth.monY;
        if (dir === "right") {
            nx = oth.monX + oW;
            ny = oth.monY + Math.round((oH - sH) / 2);
        } else if (dir === "left") {
            nx = oth.monX - sW;
            ny = oth.monY + Math.round((oH - sH) / 2);
        } else if (dir === "above") {
            nx = oth.monX + Math.round((oW - sW) / 2);
            ny = oth.monY - sH;
        } else if (dir === "below") {
            nx = oth.monX + Math.round((oW - sW) / 2);
            ny = oth.monY + oH;
        }
        monDraftsModel.setProperty(idx, "monX", Math.round(nx));
        monDraftsModel.setProperty(idx, "monY", Math.round(ny));
        // Normalize min to (0, 0)
        let minX = monDraftsModel.get(0).monX;
        let minY = monDraftsModel.get(0).monY;
        for (let i = 1; i < monDraftsModel.count; i++) {
            minX = Math.min(minX, monDraftsModel.get(i).monX);
            minY = Math.min(minY, monDraftsModel.get(i).monY);
        }
        for (let i = 0; i < monDraftsModel.count; i++) {
            monDraftsModel.setProperty(i, "monX", Math.round(monDraftsModel.get(i).monX - minX));
            monDraftsModel.setProperty(i, "monY", Math.round(monDraftsModel.get(i).monY - minY));
        }
        const finalItem = monDraftsModel.get(idx);
        root.selectedMonPos = finalItem.monX + "x" + finalItem.monY;
        root.monDrafts = snapshotDraftsArray();
        root.monDraftsRev++;
        root.monLayoutDirty = true;
    }

    function captureCurrentMonitorSnapshot() {
        const src = root.sysMonitors || [];
        const out = [];
        for (let i = 0; i < src.length; ++i) {
            const m = src[i];
            if (!m || !m.name) continue;
            let bestMode = m.width + "x" + m.height + "@" + Number(m.refreshRate || 60).toFixed(2) + "Hz";
            if (m.availableModes) {
                for (let j = 0; j < m.availableModes.length; ++j) {
                    if (m.availableModes[j].indexOf(m.width + "x" + m.height + "@") === 0 &&
                        Math.abs(parseFloat(m.availableModes[j].split("@")[1]) - m.refreshRate) < 1.0) {
                        bestMode = m.availableModes[j];
                        break;
                    }
                }
            }
            out.push({
                name: String(m.name),
                mode: bestMode,
                position: Math.round(m.x || 0) + "x" + Math.round(m.y || 0),
                scale: String(m.scale || 1),
                transform: Number(m.transform || 0),
                vrr: Number(m.vrr || 0),
                bitdepth: Number(m.bitdepth || 8),
                cm: String(m.cm || "srgb"),
                mirror: String(m.mirror || ""),
                disabled: Boolean(m.disabled)
            });
        }
        return out;
    }

    function startMonitorConfirmation(backup) {
        if (!root.monConfirmPending && backup && backup.length > 0) {
            root.monBackupSnapshot = backup;
        }
        if (root.monBackupSnapshot && root.monBackupSnapshot.length > 0) {
            root.monConfirmSecondsLeft = 10;
            root.monConfirmPending = true;
            monRevertTimer.restart();
        }
    }

    function keepMonitorChanges() {
        monRevertTimer.stop();
        root.monConfirmPending = false;
        root.monBackupSnapshot = null;
    }

    function revertMonitorChanges() {
        monRevertTimer.stop();
        root.monConfirmPending = false;
        const snap = root.monBackupSnapshot;
        root.monBackupSnapshot = null;
        if (snap && snap.length > 0) {
            root.monLayoutDirty = false;
            root.monConfigDirty = false;
            root.runSysSet(["restore_monitors", JSON.stringify(snap)]);
        }
    }

    function applyMonitorLayout() {
        if (monDraftsModel.count === 0) return;
        const backup = root.monConfirmPending ? null : captureCurrentMonitorSnapshot();
        const payload = [];
        for (let i = 0; i < monDraftsModel.count; i++) {
            const m = monDraftsModel.get(i);
            payload.push({ name: m.monName, x: Math.round(m.monX), y: Math.round(m.monY) });
        }
        root.runSysSet(["set_monitor_layout", JSON.stringify(payload)]);
        root.monLayoutDirty = false;
        root.startMonitorConfirmation(backup);
    }

    function applySelectedMonitorConfig() {
        const src = root.sysMonitors;
        if (!src || src.length === 0) return;
        const idx = Math.max(0, Math.min(root.selectedMonitorIdx, src.length - 1));
        const mon = src[idx];
        if (!mon) return;
        const backup = root.monConfirmPending ? null : captureCurrentMonitorSnapshot();
        const payload = {
            name: mon.name,
            mode: root.selectedMonMode,
            position: root.selectedMonPos,
            scale: root.selectedMonScale,
            transform: root.selectedMonTransform,
            vrr: root.selectedMonVrr,
            bitdepth: root.selectedMonBitdepth,
            cm: root.selectedMonCm,
            mirror: root.selectedMonMirror,
            disabled: root.selectedMonDisabled
        };
        if (root.monLayoutDirty) {
            const layout = [];
            for (let i = 0; i < monDraftsModel.count; i++) {
                const dm = monDraftsModel.get(i);
                layout.push({ name: dm.monName, x: Math.round(dm.monX), y: Math.round(dm.monY) });
            }
            payload.layout = layout;
        }
        root.runSysSet(["set_monitor_cfg", JSON.stringify(payload)]);
        root.monLayoutDirty = false;
        root.monConfigDirty = false;
        root.startMonitorConfirmation(backup);
    }

    function syncSelectedMonitorDraft() {
        if (!sysMonitors || sysMonitors.length === 0) return;
        const idx = Math.max(0, Math.min(selectedMonitorIdx, sysMonitors.length - 1));
        const m = sysMonitors[idx];
        const dm = (idx < monDraftsModel.count) ? monDraftsModel.get(idx) : null;
        if (!m) return;
        const curMode = m.width + "x" + m.height + "@" + Number(m.refreshRate).toFixed(2) + "Hz";
        selectedMonMode = (m.availableModes && m.availableModes.length > 0) ? m.availableModes[0] : curMode;
        if (m.availableModes) {
            for (let i = 0; i < m.availableModes.length; i++) {
                if (m.availableModes[i].indexOf(m.width + "x" + m.height + "@") === 0 &&
                    Math.abs(parseFloat(m.availableModes[i].split("@")[1]) - m.refreshRate) < 1.0) {
                    selectedMonMode = m.availableModes[i];
                    break;
                }
            }
        }
        selectedMonRes = modeResolutionOf(selectedMonMode) || (m.width + "x" + m.height);
        selectedMonScale = String(dm ? dm.monScale : (m.scale || 1));
        selectedMonPos = Math.round(dm ? dm.monX : m.x) + "x" + Math.round(dm ? dm.monY : m.y);
        selectedMonTransform = Number(dm ? dm.monTransform : (m.transform || 0));
        selectedMonVrr = Number(dm ? dm.monVrr : (m.vrr || 0));
        selectedMonBitdepth = Number(dm ? dm.monBitdepth : (m.bitdepth || 8));
        selectedMonCm = String(dm ? dm.monCm : (m.cm || "srgb"));
        selectedMonMirror = String(dm ? dm.monMirror : (m.mirror || ""));
        selectedMonDisabled = Boolean(dm ? dm.monDisabled : m.disabled);
    }

    function syncListModel(model, mapped) {
        let sameOrder = (model.count === mapped.length);
        if (sameOrder) {
            for (let i = 0; i < mapped.length; i++) {
                if (model.get(i).itemId !== mapped[i].itemId || model.get(i).itemType !== mapped[i].itemType) {
                    sameOrder = false;
                    break;
                }
            }
        }
        if (sameOrder) {
            for (let i = 0; i < mapped.length; i++) {
                const cur = model.get(i);
                const nxt = mapped[i];
                if (cur.title !== nxt.title) model.setProperty(i, "title", nxt.title);
                if (cur.subtitle !== nxt.subtitle) model.setProperty(i, "subtitle", nxt.subtitle);
                if (cur.icon !== nxt.icon) model.setProperty(i, "icon", nxt.icon);
                if (cur.statusText !== nxt.statusText) model.setProperty(i, "statusText", nxt.statusText);
                if (cur.active !== nxt.active) model.setProperty(i, "active", nxt.active);
                if (nxt.hasSecret !== undefined && cur.hasSecret !== nxt.hasSecret) model.setProperty(i, "hasSecret", nxt.hasSecret);
            }
        } else {
            model.clear();
            for (let i = 0; i < mapped.length; i++) model.append(mapped[i]);
        }
    }

    function applyNetJson(raw, fromAction) {
        try {
            const parsed = JSON.parse(String(raw || "").trim());
            const arr = Array.isArray(parsed) ? parsed : (parsed.items || []);
            const err = (!Array.isArray(parsed) && parsed.error) ? String(parsed.error) : "";
            const pwSsid = (!Array.isArray(parsed) && parsed.needsPasswordSsid) ? String(parsed.needsPasswordSsid) : "";
            const mapped = [];
            for (let i = 0; i < arr.length; i++) {
                const it = arr[i];
                mapped.push({
                    itemId: String(it.id || ""),
                    title: String(it.title || "Network"),
                    subtitle: String(it.subtitle || ""),
                    icon: String(it.icon || "󰤨"),
                    statusText: String(it.status || "Connect"),
                    active: Boolean(it.active),
                    itemType: String(it.type || "wifi"),
                    hasSecret: it.hasSecret !== undefined ? Boolean(it.hasSecret) : true
                });
            }
            syncListModel(stNetModel, mapped);
            if (fromAction) {
                stWifiConnecting = false;
                stNetActionPassword = "";
                if (pwSsid.length > 0) {
                    stWifiPromptSsid = pwSsid;
                    stWifiError = err.length > 0 ? err : "Password required";
                } else if (err.length > 0) {
                    stWifiError = err;
                } else {
                    stWifiPromptSsid = "";
                    stWifiError = "";
                }
            }
        } catch (e) {}
    }

    function applyBtJson(raw) {
        try {
            const arr = JSON.parse(String(raw || "").trim());
            const mapped = [];
            for (let i = 0; i < arr.length; i++) {
                const it = arr[i];
                mapped.push({
                    itemId: String(it.id || ""),
                    title: String(it.title || "Bluetooth"),
                    subtitle: String(it.subtitle || ""),
                    icon: String(it.icon || "󰂯"),
                    statusText: String(it.status || "Connect"),
                    active: Boolean(it.active),
                    itemType: String(it.type || "device")
                });
            }
            syncListModel(stBtModel, mapped);
        } catch (e) {}
    }

    Process {
        id: wallListProc
        command: [ShellState.script("wallpaper.sh"), "list"]
        stdout: SplitParser { onRead: data => root.parseWallpapers(data) }
    }

    Process {
        id: sysInfoProc
        command: [ShellState.script("system-settings.sh"), "info"]
        stdout: SplitParser { onRead: data => root.parseSystemInfo(data) }
    }

    Process {
        id: sysSetProc
        command: [ShellState.script("system-settings.sh")]
        stdout: SplitParser { onRead: data => root.parseSystemInfo(data) }
    }

    Process {
        id: stNetProc
        command: [ShellState.script("network-manager.sh")]
        stdout: SplitParser { onRead: data => root.applyNetJson(data, false) }
    }

    Process {
        id: stNetActionProc
        command: root.stNetActionPassword.length > 0
            ? [ShellState.script("network-manager.sh"), root.stNetActionCmd, root.stNetActionTarget, root.stNetActionPassword]
            : [ShellState.script("network-manager.sh"), root.stNetActionCmd, root.stNetActionTarget]
        stdout: SplitParser { onRead: data => root.applyNetJson(data, true) }
    }

    Process {
        id: stBtProc
        command: [ShellState.script("bluetooth-manager.sh")]
        stdout: SplitParser { onRead: data => root.applyBtJson(data) }
    }

    Process {
        id: stBtActionProc
        command: [ShellState.script("bluetooth-manager.sh")]
        stdout: SplitParser { onRead: data => root.applyBtJson(data) }
    }

    Timer {
        id: stBtRefreshTimer
        interval: 1200
        repeat: false
        onTriggered: {
            stBtProc.running = false;
            stBtProc.running = true;
        }
    }

    function runSysSet(args) {
        sysSetProc.running = false;
        sysSetProc.command = [ShellState.script("system-settings.sh")].concat(args);
        sysSetProc.running = true;
    }

    function runBtAction(args) {
        stBtActionProc.running = false;
        stBtActionProc.command = [ShellState.script("bluetooth-manager.sh")].concat(args);
        stBtActionProc.running = true;
    }

    Timer {
        id: wallRefreshAfterSetTimer
        interval: 220
        repeat: false
        onTriggered: {
            wallListProc.running = false;
            wallListProc.running = true;
            ShellState.syncWallpaperFromHyprpaper();
        }
    }

    function selectWallpaper(p) {
        if (!p || p.length === 0) return;
        ShellState.applyWallpaperWithFade(p);
        wallRefreshAfterSetTimer.restart();
    }

    function refreshAllSettingsData() {
        ShellState.syncWallpaperFromHyprpaper();
        wallListProc.running = false;
        wallListProc.running = true;
        sysInfoProc.running = false;
        sysInfoProc.running = true;
        stNetProc.running = false;
        stNetProc.running = true;
        stBtProc.running = false;
        stBtProc.running = true;
    }

    Connections {
        target: ShellState
        function onSettingsOpenChanged() {
            if (ShellState.settingsOpen) {
                root.refreshAllSettingsData();
            } else {
                root.stWifiPromptSsid = "";
                root.stWifiError = "";
                root.stWifiConnecting = false;
            }
        }
        function onActiveKeyboardLayoutChanged() {
            root.kbActiveName = ShellState.activeKeyboardLayout;
        }
    }

    Component.onCompleted: root.refreshAllSettingsData()

    // ================= REUSABLE UI COMPONENTS =================
    component GlassPanelCard: Rectangle {
        property real cornerRadius: 16
        radius: cornerRadius
        color: Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.72) : Qt.rgba(1.0, 1.0, 1.0, 0.055)
        border.color: Theme.glassCardBorder
        border.width: 1
    }

    component ActionPill: Rectangle {
        id: aPill
        property string label: ""
        property string icon: ""
        property bool active: false
        property bool hovered: aMouse.containsMouse
        signal clicked()

        implicitHeight: 28
        implicitWidth: pillRow.implicitWidth + 18
        radius: height / 2
        color: active
            ? (Theme.lightMode ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16) : Qt.rgba(1.0, 1.0, 1.0, 0.14))
            : (hovered
                ? (Theme.lightMode ? Qt.rgba(0.0, 0.0, 0.0, 0.08) : Qt.rgba(1.0, 1.0, 1.0, 0.10))
                : (Theme.lightMode ? Qt.rgba(0.0, 0.0, 0.0, 0.045) : Qt.rgba(1.0, 1.0, 1.0, 0.06)))
        border.color: active ? Theme.accent : Theme.glassCardBorder
        border.width: 1
        scale: aMouse.pressed ? 0.94 : (hovered ? 1.03 : 1.0)
        Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 100); easing.type: ShellState.animPrimaryEase } }
        Behavior on color { ColorAnimation { duration: ShellState.animDur(170, 120) } }
        Behavior on border.color { ColorAnimation { duration: ShellState.animDur(170, 120) } }

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 5
            Text {
                visible: aPill.icon.length > 0
                text: aPill.icon
                font.family: Theme.iconFont
                font.pixelSize: 12
                color: Theme.text
                Behavior on color { ColorAnimation { duration: ShellState.animDur(170, 120) } }
            }
            Text {
                visible: aPill.label.length > 0
                text: aPill.label
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: aPill.active ? Font.Bold : Font.DemiBold
                color: Theme.text
                Behavior on color { ColorAnimation { duration: ShellState.animDur(170, 120) } }
            }
        }

        MouseArea {
            id: aMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: aPill.clicked()
        }
    }

    component GlassDropdown: Item {
        id: dd
        property var options: []
        property var currentValue: ""
        property string fallbackText: "Select..."
        property real maxMenuHeight: 220
        property bool searchable: false
        property string searchPlaceholder: "Search..."
        property string searchQuery: ""
        signal activated(var value, var option)

        readonly property var filteredOptions: {
            const opts = dd.options || [];
            if (!dd.searchable) return opts;
            const q = String(dd.searchQuery || "").trim().toLowerCase();
            if (q.length === 0) return opts;
            const out = [];
            for (let i = 0; i < opts.length; ++i) {
                const it = opts[i];
                if (!it) continue;
                const hay = (String(it.label || "") + " " + String(it.value || "")).toLowerCase();
                if (hay.indexOf(q) !== -1) out.push(it);
            }
            return out;
        }

        readonly property int currentIndex: {
            const opts = dd.options || [];
            for (let i = 0; i < opts.length; ++i) {
                if (opts[i] && opts[i].value === dd.currentValue) return i;
            }
            return -1;
        }
        readonly property string currentLabel: {
            const idx = dd.currentIndex;
            if (idx >= 0 && dd.options && dd.options[idx]) {
                return String(dd.options[idx].label);
            }
            return dd.fallbackText;
        }

        implicitHeight: 30
        implicitWidth: 160
        Layout.fillWidth: true

        Rectangle {
            id: dropBtn
            anchors.fill: parent
            radius: 10
            color: dropPopup.visible
                ? (Theme.lightMode ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : Qt.rgba(1.0, 1.0, 1.0, 0.13))
                : (dropMouse.containsMouse
                    ? (Theme.lightMode ? Qt.rgba(0.0, 0.0, 0.0, 0.08) : Qt.rgba(1.0, 1.0, 1.0, 0.10))
                    : (Theme.lightMode ? Qt.rgba(0.0, 0.0, 0.0, 0.045) : Qt.rgba(1.0, 1.0, 1.0, 0.06)))
            border.color: dropPopup.visible ? Theme.accent : (dropMouse.containsMouse ? Theme.glassHighlight : Theme.glassCardBorder)
            border.width: 1
            scale: dropMouse.pressed ? 0.985 : 1.0
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 9
                spacing: 6

                Text {
                    text: dd.currentLabel
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.text
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: "󰅀"
                    font.family: Theme.iconFont
                    font.pixelSize: 12
                    color: dropPopup.visible ? Theme.accent : Theme.subtext
                    rotation: dropPopup.visible ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: ShellState.animDur(180, 130); easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                }
            }

            MouseArea {
                id: dropMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                property bool wasOpenOnPress: false
                onPressed: wasOpenOnPress = dropPopup.visible
                onClicked: {
                    if (wasOpenOnPress) return;
                    dropPopup.positionPopup();
                    dropPopup.open();
                }
            }
        }

        Popup {
            id: dropPopup
            parent: Overlay.overlay
            modal: false
            focus: true
            padding: 4
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            width: Math.max(dropBtn.width, dd.searchable ? 248 : 0)
            readonly property int optionCount: (dd.filteredOptions && dd.filteredOptions.length) ? dd.filteredOptions.length : 0
            readonly property real searchHeaderH: dd.searchable ? 34 : 0
            readonly property real listBodyH: optionCount > 0 ? (optionCount * 30 + 6) : 34
            readonly property real computedMenuH: Math.min(dd.maxMenuHeight + searchHeaderH, Math.max(40 + searchHeaderH, searchHeaderH + listBodyH))
            height: computedMenuH
            property bool openUpwards: false
            transformOrigin: openUpwards ? Item.Bottom : Item.Top

            function positionPopup() {
                const target = dropPopup.parent;
                if (!target) return;
                const pt = dropBtn.mapToItem(target, 0, 0);
                const cardBottom = (typeof settingsCard !== "undefined" && settingsCard)
                    ? (settingsCard.mapToItem(target, 0, settingsCard.height).y - 10)
                    : (target.height - 16);
                const cardRight = (typeof settingsCard !== "undefined" && settingsCard)
                    ? (settingsCard.mapToItem(target, settingsCard.width, 0).x - 10)
                    : (target.width - 12);
                const menuW = Math.max(dropBtn.width, dd.searchable ? 248 : 0);
                const openUp = (pt.y + dropBtn.height + 4 + computedMenuH) > cardBottom && (pt.y - computedMenuH - 4) >= 24;
                dropPopup.openUpwards = openUp;
                dropPopup.width = menuW;
                dropPopup.x = Math.min(pt.x, Math.max(12, cardRight - menuW));
                dropPopup.y = openUp ? (pt.y - computedMenuH - 4) : (pt.y + dropBtn.height + 4);
            }

            onAboutToShow: {
                dd.searchQuery = "";
                if (ddSearchInput.text.length > 0) ddSearchInput.text = "";
                positionPopup();
                if (dd.searchable) {
                    Qt.callLater(function() {
                        if (dropPopup.visible) ddSearchInput.forceActiveFocus();
                    });
                }
            }

            enter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 130; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "scale"; from: 0.96; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
                }
            }
            exit: Transition {
                NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 95; easing.type: Easing.OutCubic }
            }

            background: Rectangle {
                radius: 12
                color: Theme.lightMode ? Qt.rgba(0.96, 0.97, 0.99, 0.96) : Qt.rgba(0.10, 0.11, 0.15, 0.94)
                border.color: Theme.glassHighlight
                border.width: 1
                layer.enabled: true
                layer.effect: DropShadow {
                    verticalOffset: 4
                    radius: 14
                    samples: 19
                    color: Qt.rgba(0, 0, 0, Theme.lightMode ? 0.18 : 0.48)
                }
            }

            contentItem: ColumnLayout {
                spacing: 4

                Rectangle {
                    visible: dd.searchable
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: 8
                    color: Theme.lightMode ? Qt.rgba(0.0, 0.0, 0.0, 0.055) : Qt.rgba(1.0, 1.0, 1.0, 0.07)
                    border.color: ddSearchInput.activeFocus ? Theme.accent : Theme.glassBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 6
                        spacing: 6

                        Text {
                            text: "󰍉"
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            color: ddSearchInput.activeFocus ? Theme.accent : Theme.subtext
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            TextInput {
                                id: ddSearchInput
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.text
                                clip: true
                                selectByMouse: true
                                onTextChanged: {
                                    dd.searchQuery = text;
                                    optList.contentY = 0;
                                    optList.scrollTargetY = 0;
                                }
                                Keys.onReturnPressed: {
                                    const list = dd.filteredOptions || [];
                                    if (list.length > 0 && list[0]) {
                                        dd.activated(list[0].value, list[0]);
                                        dropPopup.close();
                                    }
                                }
                                Keys.onEscapePressed: dropPopup.close()
                            }
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: dd.searchPlaceholder
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.textDim
                                visible: !ddSearchInput.activeFocus && ddSearchInput.text.length === 0
                            }
                        }

                        Text {
                            visible: ddSearchInput.text.length > 0
                            text: "✕"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.subtext
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ddSearchInput.text = "";
                                    ddSearchInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: optList
                        anchors.fill: parent
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: dd.filteredOptions || []
                        spacing: 2
                        currentIndex: -1

                        property real scrollTargetY: 0
                        Behavior on contentY { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                        onContentHeightChanged: {
                            const maxY = Math.max(0, contentHeight - height);
                            if (scrollTargetY > maxY) scrollTargetY = maxY;
                        }

                        WheelHandler {
                            target: null
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => root.applyFastWheel(optList, event, 165)
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: optList.contentHeight > optList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                            width: 4
                        }

                        delegate: Rectangle {
                            id: optRow
                            required property var modelData
                            required property int index
                            readonly property bool isSel: modelData !== undefined && modelData !== null && modelData.value === dd.currentValue
                            width: optList.width - (optList.contentHeight > optList.height ? 6 : 0)
                            height: 28
                            radius: 8
                            color: isSel
                                ? (Theme.lightMode ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16) : Qt.rgba(1.0, 1.0, 1.0, 0.14))
                                : (optMouse.containsMouse
                                    ? (Theme.lightMode ? Qt.rgba(0.0, 0.0, 0.0, 0.07) : Qt.rgba(1.0, 1.0, 1.0, 0.09))
                                    : "transparent")
                            Behavior on color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 8
                                spacing: 6

                                Text {
                                    text: modelData ? String(modelData.label) : ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: optRow.isSel ? Font.Bold : Font.Medium
                                    color: Theme.text
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: optRow.isSel
                                    text: "󰄬"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 12
                                    color: Theme.accent
                                }
                            }

                            MouseArea {
                                id: optMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    dd.activated(modelData.value, modelData);
                                    dropPopup.close();
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: optList.count === 0
                        text: "No matching options"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDim
                    }
                }
            }
        }
    }

    component ToggleRow: RowLayout {
        id: tRow
        required property string icon
        required property string title
        required property string subtitle
        required property bool checked
        signal toggled()

        Layout.fillWidth: true
        Layout.preferredHeight: 34
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 9
            color: tRow.checked
                ? (Theme.lightMode ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : Qt.rgba(1.0, 1.0, 1.0, 0.12))
                : (Theme.lightMode ? Qt.rgba(0.0, 0.0, 0.0, 0.05) : Qt.rgba(1.0, 1.0, 1.0, 0.05))
            border.color: tRow.checked ? Theme.glassHighlight : Theme.glassCardBorder
            border.width: 1
            Behavior on color { ColorAnimation { duration: ShellState.animDur(200, 140) } }
            Behavior on border.color { ColorAnimation { duration: ShellState.animDur(200, 140) } }

            Text {
                anchors.centerIn: parent
                text: tRow.icon
                font.family: Theme.iconFont
                font.pixelSize: 15
                color: Theme.text
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: tRow.title
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.text
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: tRow.subtitle
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.subtext
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 24
            radius: 12
            color: tRow.checked ? Theme.badgeBgActive : Theme.glassCard
            border.color: tRow.checked ? Theme.badgeBgActive : Theme.glassBorder
            border.width: 1
            scale: tSwitchMouse.pressed ? 0.92 : (tSwitchMouse.containsMouse ? 1.04 : 1.0)
            Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 100); easing.type: ShellState.animPrimaryEase } }
            Behavior on color { ColorAnimation { duration: ShellState.animDur(200, 140) } }
            Behavior on border.color { ColorAnimation { duration: ShellState.animDur(200, 140) } }

            Rectangle {
                width: 18
                height: 18
                radius: 9
                y: 3
                x: tRow.checked ? 23 : 3
                color: tRow.checked ? Theme.badgeFgActive : Theme.text
                Behavior on color { ColorAnimation { duration: ShellState.animDur(200, 140) } }

                Behavior on x {
                    NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                }
            }

            MouseArea {
                id: tSwitchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tRow.toggled()
            }
        }
    }

    component ScratchpadCard: Rectangle {
        id: spCard
        required property string spName
        required property string icon
        required property color iconColor
        required property string title
        required property string hotkey
        required property string defaultCmd
        required property string appCmd
        required property var presets
        signal commandChanged(string newCmd)

        Layout.fillWidth: true
        Layout.preferredHeight: 86
        radius: 16
        color: Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.72) : Qt.rgba(1.0, 1.0, 1.0, 0.055)
        border.color: Theme.glassCardBorder
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 8
                    color: Qt.rgba(spCard.iconColor.r, spCard.iconColor.g, spCard.iconColor.b, 0.18)
                    border.color: Qt.rgba(spCard.iconColor.r, spCard.iconColor.g, spCard.iconColor.b, 0.35)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: spCard.icon
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        color: spCard.iconColor
                    }
                }

                Text {
                    text: spCard.title
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.text
                }

                Rectangle {
                    Layout.preferredHeight: 18
                    implicitWidth: hkText.implicitWidth + 10
                    radius: 6
                    color: Theme.glassSurfaceActive
                    border.color: Theme.glassBorder
                    border.width: 1

                    Text {
                        id: hkText
                        anchors.centerIn: parent
                        text: spCard.hotkey
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: Theme.subtext
                    }
                }

                Item { Layout.fillWidth: true }

                ActionPill {
                    icon: "󰐊"
                    label: "Test"
                    implicitHeight: 22
                    onClicked: {
                        ShellState.settingsOpen = false;
                        Quickshell.execDetached([ShellState.script("scratchpad.sh"), spCard.spName]);
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: 9
                    color: Theme.glassSurfaceActive
                    border.color: cmdInput.activeFocus ? Theme.glassHighlight : Theme.glassBorder
                    border.width: 1

                    TextInput {
                        id: cmdInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.text
                        selectionColor: Theme.accent
                        text: spCard.appCmd
                        clip: true

                        onEditingFinished: {
                            const cleaned = text.trim();
                            if (cleaned.length > 0 && cleaned !== spCard.appCmd) {
                                spCard.commandChanged(cleaned);
                            } else if (cleaned.length === 0) {
                                text = spCard.appCmd;
                            }
                        }

                        Keys.onReturnPressed: {
                            focus = false;
                            const cleaned = text.trim();
                            if (cleaned.length > 0) spCard.commandChanged(cleaned);
                        }
                    }
                }

                Repeater {
                    model: spCard.presets
                    delegate: ActionPill {
                        required property string modelData
                        label: modelData
                        implicitHeight: 24
                        active: spCard.appCmd === modelData
                        onClicked: spCard.commandChanged(modelData)
                    }
                }
            }
        }
    }

    component DefaultAppSlot: Rectangle {
        id: defSlot
        required property string icon
        required property string title
        required property string subtitle
        required property string appCmd
        required property var options
        property bool showXdgFix: false
        signal appChanged(string newCmd)
        signal testClicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 78
        radius: 12
        color: Theme.lightMode ? Qt.rgba(0.0, 0.0, 0.0, 0.035) : Qt.rgba(1.0, 1.0, 1.0, 0.04)
        border.color: Theme.glassBorder
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 9
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 8
                    color: Theme.glassSurfaceActive
                    border.color: Theme.glassBorder
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: defSlot.icon
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        color: Theme.text
                    }
                }

                Text {
                    text: defSlot.title
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.text
                }

                Text {
                    text: "•  " + defSlot.subtitle
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.subtext
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                ActionPill {
                    visible: defSlot.showXdgFix
                    icon: "󰃢"
                    label: "System Default"
                    implicitHeight: 22
                    onClicked: ShellState.setXdgDirectoryHandler(defSlot.appCmd)
                }

                ActionPill {
                    icon: "󰐊"
                    label: "Open"
                    implicitHeight: 22
                    onClicked: defSlot.testClicked()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                GlassDropdown {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitWidth: 120
                    searchable: true
                    searchPlaceholder: "Search apps..."
                    fallbackText: defSlot.appCmd
                    currentValue: defSlot.appCmd
                    options: defSlot.options
                    onActivated: value => defSlot.appChanged(String(value))
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 30
                    radius: 10
                    color: Theme.glassSurfaceActive
                    border.color: defIn.activeFocus ? Theme.accent : Theme.glassBorder
                    border.width: 1

                    TextInput {
                        id: defIn
                        anchors.fill: parent
                        anchors.leftMargin: 9
                        anchors.rightMargin: 9
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.text
                        text: defSlot.appCmd
                        clip: true
                        onEditingFinished: {
                            const c = text.trim();
                            if (c.length > 0 && c !== defSlot.appCmd) defSlot.appChanged(c);
                            else if (c.length === 0) text = defSlot.appCmd;
                        }
                        Keys.onReturnPressed: {
                            focus = false;
                            const c = text.trim();
                            if (c.length > 0) defSlot.appChanged(c);
                        }
                    }
                }
            }
        }
    }

    // ================= MAIN SETTINGS CARD =================
    Item {
        id: settingsCard
        anchors.fill: parent

        // Dedicated higher-contrast readability backing for dense settings pages
        Rectangle {
            anchors.fill: parent
            z: -2
            radius: 22
            color: Theme.lightMode ? Qt.rgba(0.95, 0.96, 0.98, 0.44) : Qt.rgba(0.04, 0.05, 0.08, 0.46)
        }

        property int activeTab: Math.max(0, Math.min(4, ShellState.settingsTab))
        onActiveTabChanged: ShellState.settingsTab = activeTab
        Connections {
            target: ShellState
            function onSettingsTabChanged() {
                settingsCard.activeTab = Math.max(0, Math.min(4, ShellState.settingsTab));
            }
        }

        readonly property var tabs: [
            { icon: "󰔎", label: "Appearance", desc: "Theme, glass effects & wallpaper" },
            { icon: "󰕮", label: "Bar & Island", desc: "Panel layout, widgets & behavior" },
            { icon: "󰍹", label: "Displays", desc: "Monitors, resolution & power" },
            { icon: "󰤨", label: "Network & BT", desc: "Wi-Fi, wired networks & Bluetooth" },
            { icon: "󰌌", label: "Input & Apps", desc: "Keyboard, pointer & applications" }
        ]

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // 1. Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 11
                    color: Theme.lightMode ? Qt.rgba(0.0, 0.0, 0.0, 0.06) : Qt.rgba(1.0, 1.0, 1.0, 0.08)
                    border.color: Theme.glassCardBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: settingsCard.tabs[settingsCard.activeTab].icon
                        font.family: Theme.iconFont
                        font.pixelSize: 17
                        color: Theme.text
                    }
                }

                ColumnLayout {
                    spacing: 1

                    RowLayout {
                        spacing: 8
                        Text {
                            text: "ChromaShell Settings"
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.bold: true
                            color: Theme.text
                        }

                        Rectangle {
                            Layout.preferredHeight: 16
                            implicitWidth: verText.implicitWidth + 10
                            radius: 8
                            color: Theme.glassSurfaceActive
                            border.color: Theme.glassBorder
                            border.width: 1
                            Text {
                                id: verText
                                anchors.centerIn: parent
                                text: ShellState.version
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                color: Theme.subtext
                            }
                        }
                    }

                    Text {
                        text: settingsCard.tabs[settingsCard.activeTab].desc
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.subtext
                    }
                }

                Item { Layout.fillWidth: true }

                ActionPill {
                    label: "Esc ✕"
                    implicitHeight: 30
                    implicitWidth: 64
                    onClicked: ShellState.settingsOpen = false
                }
            }

            // 2. Multi-Page Segmented Navigation Bar (5 Organized Pages)
            Rectangle {
                id: navBar
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 18
                color: Theme.lightMode ? Qt.rgba(0.0, 0.0, 0.0, 0.055) : Qt.rgba(1.0, 1.0, 1.0, 0.045)
                border.color: Theme.glassCardBorder
                border.width: 1

                Rectangle {
                    id: navIndicator
                    width: (parent.width - 6) / 5
                    height: parent.height - 6
                    y: 3
                    x: 3 + settingsCard.activeTab * width
                    radius: 15
                    color: Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.88) : Qt.rgba(1.0, 1.0, 1.0, 0.13)
                    border.color: Theme.glassCardBorder
                    border.width: 1

                    Behavior on x {
                        NumberAnimation {
                            duration: ShellState.animDur(320, 240)
                            easing.type: ShellState.isSnappyAnimations ? Easing.OutBack : Easing.InOutCubic
                            easing.overshoot: ShellState.isSnappyAnimations ? 0.9 : 0.0
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 0

                    Repeater {
                        model: settingsCard.tabs

                        delegate: Item {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            readonly property bool isCur: settingsCard.activeTab === index
                            scale: stTabMouse.pressed ? 0.95 : 1.0
                            Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 105); easing.type: ShellState.animPrimaryEase } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: modelData.icon
                                    font.family: Theme.iconFont
                                    font.pixelSize: 12
                                    color: isCur ? Theme.text : Theme.subtext
                                    Behavior on color { ColorAnimation { duration: ShellState.animDur(180, 130) } }
                                }

                                Text {
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: isCur ? Font.Bold : Font.Medium
                                    color: isCur ? Theme.text : Theme.subtext
                                    Behavior on color { ColorAnimation { duration: ShellState.animDur(180, 130) } }
                                }
                            }

                            MouseArea {
                                id: stTabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsCard.activeTab = index
                            }
                        }
                    }
                }
            }

            // Monitor Change Confirmation Banner (10s Auto-Revert)
            Rectangle {
                id: monConfirmBanner
                visible: root.monConfirmPending
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 54 : 0
                clip: true
                radius: 14
                color: Theme.lightMode ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                border.color: Theme.accent
                border.width: 1

                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    height: 3
                    width: parent.width * Math.max(0, Math.min(1, root.monConfirmSecondsLeft / 10.0))
                    radius: 2
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Text { text: "󰍹"; font.family: Theme.iconFont; font.pixelSize: 16; color: Theme.accent }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: "Keep these display settings?"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: Theme.text
                        }
                        Text {
                            text: "Automatically reverting in " + root.monConfirmSecondsLeft + "s unless confirmed"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.subtext
                        }
                    }

                    ActionPill {
                        icon: "󰜉"
                        label: "Revert Now"
                        implicitHeight: 28
                        onClicked: root.revertMonitorChanges()
                    }

                    ActionPill {
                        icon: "󰄬"
                        label: "Keep Changes (" + root.monConfirmSecondsLeft + "s)"
                        active: true
                        implicitHeight: 28
                        onClicked: root.keepMonitorChanges()
                    }
                }
            }

            // 3. Page Container
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // ================= PAGE 0: APPEARANCE =================
                Item {
                    id: tab0Item
                    anchors.fill: parent
                    opacity: settingsCard.activeTab === 0 ? 1.0 : 0.0
                    visible: opacity > 0.005
                    enabled: settingsCard.activeTab === 0
                    Behavior on opacity { NumberAnimation { duration: ShellState.animDur(250, 170); easing.type: ShellState.animPrimaryEase } }
                    transform: Translate {
                        x: settingsCard.activeTab === 0 ? 0 : (settingsCard.activeTab > 0 ? -18 : 18)
                        Behavior on x { NumberAnimation { duration: ShellState.animDur(300, 210); easing.type: ShellState.animPrimaryEase } }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 288
                            spacing: 12

                            // Left: Theme & Frame
                            GlassPanelCard {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 10

                                    RowLayout {
                                        spacing: 8
                                        Text { text: "󰔎"; font.family: Theme.iconFont; font.pixelSize: 14; color: Theme.text }
                                        Text { text: "Theme & Frame"; font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true; color: Theme.text }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: ShellState.liquidGlassEnabled ? "Appearance Mode (Locked by Liquid Glass)" : "Appearance Mode"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            color: Theme.text
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            opacity: ShellState.liquidGlassEnabled ? 0.45 : 1.0
                                            enabled: !ShellState.liquidGlassEnabled
                                            Behavior on opacity { NumberAnimation { duration: 180 } }

                                            Repeater {
                                                model: [
                                                    { icon: "󰖔", label: "Dark Mode", isLight: false },
                                                    { icon: "󰖙", label: "Light Mode", isLight: true }
                                                ]

                                                delegate: ActionPill {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    implicitHeight: 30
                                                    icon: modelData.icon
                                                    label: modelData.label
                                                    active: Theme.lightMode === modelData.isLight
                                                    onClicked: ShellState.setThemeMode(modelData.isLight)
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: "Animation Style"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            color: Theme.text
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Repeater {
                                                model: [
                                                    { label: "Relaxed", icon: "󰒲", val: "relaxed" },
                                                    { label: "Snappy", icon: "󱐋", val: "snappy" }
                                                ]

                                                delegate: ActionPill {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    implicitHeight: 28
                                                    icon: modelData.icon
                                                    label: modelData.label
                                                    active: ShellState.animationStyle === modelData.val
                                                    onClicked: ShellState.animationStyle = modelData.val
                                                }
                                            }
                                        }
                                    }

                                    ToggleRow {
                                        icon: "󰃨"
                                        title: "Liquid Glass"
                                        subtitle: "Translucent glass blur & refraction"
                                        checked: ShellState.liquidGlassEnabled
                                        onToggled: ShellState.liquidGlassEnabled = !ShellState.liquidGlassEnabled
                                    }

                                    ToggleRow {
                                        icon: "󰝚"
                                        title: "Music Waves"
                                        subtitle: "Reactive ambient glow inside panels"
                                        checked: ShellState.panelWavesEnabled
                                        onToggled: ShellState.panelWavesEnabled = !ShellState.panelWavesEnabled
                                    }

                                    Item { Layout.fillHeight: true }
                                }
                            }

                            // Right: Notifications & Media Announcements
                            GlassPanelCard {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 10

                                    RowLayout {
                                        spacing: 8
                                        Text { text: "󰂚"; font.family: Theme.iconFont; font.pixelSize: 14; color: Theme.text }
                                        Text { text: "Alerts & Media"; font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true; color: Theme.text }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: "Notification Banner Duration"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            color: Theme.text
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Repeater {
                                                model: [
                                                    { label: "3 sec", val: 3 },
                                                    { label: "5 sec", val: 5 },
                                                    { label: "8 sec", val: 8 }
                                                ]

                                                delegate: ActionPill {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    implicitHeight: 28
                                                    label: modelData.label
                                                    active: ShellState.notifTimeoutSec === modelData.val
                                                    onClicked: ShellState.notifTimeoutSec = modelData.val
                                                }
                                            }
                                        }
                                    }

                                    ToggleRow {
                                        icon: "󰂛"
                                        title: "Do Not Disturb"
                                        subtitle: "Silence notification banners"
                                        checked: ShellState.dndActive
                                        onToggled: ShellState.dndActive = !ShellState.dndActive
                                    }

                                    ToggleRow {
                                        icon: "󰎆"
                                        title: "Announce Media Changes"
                                        subtitle: "Show Now Playing banner on track change"
                                        checked: ShellState.announceMediaChanges
                                        onToggled: ShellState.announceMediaChanges = !ShellState.announceMediaChanges
                                    }

                                    ToggleRow {
                                        icon: "󰎈"
                                        title: "Music Apps Only"
                                        subtitle: "Prioritize music players over browsers"
                                        checked: ShellState.musicAppsOnlyOnIsland
                                        onToggled: ShellState.musicAppsOnlyOnIsland = !ShellState.musicAppsOnlyOnIsland
                                    }

                                    Item { Layout.fillHeight: true }
                                }
                            }
                        }

                        // Bottom: Desktop Wallpaper Manager (hyprpaper + ~/Pictures/Wallpapers)
                        GlassPanelCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 196

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text { text: "󰸉"; font.family: Theme.iconFont; font.pixelSize: 15; color: Theme.text }
                                    Text { text: "Wallpaper"; font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true; color: Theme.text }
                                    Text {
                                        text: "~/Pictures/Wallpapers"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: Theme.subtext
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    ActionPill {
                                        icon: "󰃟"
                                        label: "Reset"
                                        implicitHeight: 26
                                        active: ShellState.wallpaperPath.endsWith("/light1.jpg") || ShellState.wallpaperPath.endsWith("/light1.png")
                                        onClicked: {
                                            ShellState.resetWallpaperToDefault();
                                            wallRefreshAfterSetTimer.restart();
                                        }
                                    }

                                    ActionPill {
                                        icon: "󰉋"
                                        label: "Open Folder"
                                        implicitHeight: 26
                                        onClicked: ShellState.openFolder(ShellState.userHome + "/Pictures/Wallpapers")
                                    }

                                    ActionPill {
                                        icon: "󰑐"
                                        label: "Refresh"
                                        implicitHeight: 26
                                        onClicked: {
                                            ShellState.syncWallpaperFromHyprpaper();
                                            wallListProc.running = false;
                                            wallListProc.running = true;
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 12

                                    // Current Active Wallpaper Preview Card
                                    Rectangle {
                                        Layout.preferredWidth: 210
                                        Layout.fillHeight: true
                                        radius: 14
                                        color: "#22000000"
                                        border.width: 1
                                        border.color: Theme.accent

                                        Image {
                                            id: curWallPreviewImg
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            source: ShellState.wallpaperPath ? ("file://" + ShellState.wallpaperPath) : ""
                                            sourceSize.width: 420
                                            sourceSize.height: 280
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            visible: false
                                        }

                                        Rectangle {
                                            id: curWallPreviewMask
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            radius: 13
                                            visible: false
                                        }

                                        OpacityMask {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            source: curWallPreviewImg
                                            maskSource: curWallPreviewMask
                                            visible: curWallPreviewImg.status === Image.Ready
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 6
                                            height: 36
                                            radius: 9
                                            color: "#bb101218"
                                            border.width: 1
                                            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                anchors.topMargin: 4
                                                anchors.bottomMargin: 4
                                                spacing: 1

                                                Text {
                                                    text: "CURRENTLY ACTIVE"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    font.letterSpacing: 0.8
                                                    color: Theme.accent
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: {
                                                        const p = String(ShellState.wallpaperPath || "");
                                                        const idx = p.lastIndexOf("/");
                                                        return idx >= 0 ? p.slice(idx + 1) : (p || "None");
                                                    }
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.DemiBold
                                                    color: "#ffffff"
                                                    elide: Text.ElideMiddle
                                                }
                                            }
                                        }
                                    }

                                    // Gallery from ~/Pictures/Wallpapers
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        ListView {
                                            id: wallListView
                                            anchors.fill: parent
                                            orientation: ListView.Horizontal
                                            spacing: 10
                                            clip: true
                                            topMargin: 2
                                            bottomMargin: 2
                                            leftMargin: 2
                                            rightMargin: 2
                                            model: wallpapersModel
                                            boundsBehavior: Flickable.StopAtBounds
                                            visible: wallpapersModel.count > 0

                                            property real scrollTargetX: 0
                                            Behavior on contentX { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                                            WheelHandler {
                                                target: null
                                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                                onWheel: event => {
                                                    const maxContentX = Math.max(0, wallListView.contentWidth - wallListView.width);
                                                    const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                                                    const p = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.pixelDelta.x;
                                                    const step = (d !== 0 ? (d / 120.0) : (p / 18.0)) * 210;
                                                    wallListView.scrollTargetX = Math.max(0, Math.min(maxContentX, wallListView.scrollTargetX - step));
                                                    wallListView.contentX = wallListView.scrollTargetX;
                                                    event.accepted = true;
                                                }
                                            }

                                            delegate: Rectangle {
                                                id: wallThumbCard
                                                required property var model
                                                required property int index
                                                width: Math.max(150, Math.round(height * 1.58))
                                                height: Math.max(92, wallListView.height - 4)
                                                radius: 14
                                                readonly property bool isCurrent: ShellState.wallpaperPath === model.wallPath
                                                color: "#22000000"
                                                border.width: isCurrent ? 2 : 1
                                                border.color: isCurrent ? Theme.accent : (wallThumbMouse.containsMouse ? Theme.glassHighlight : Theme.glassBorder)
                                                scale: wallThumbMouse.pressed ? 0.96 : (wallThumbMouse.containsMouse ? 1.02 : 1.0)
                                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                                Behavior on border.color { ColorAnimation { duration: ShellState.animDur(180, 130) } }

                                                Image {
                                                    id: thumbImg
                                                    anchors.fill: parent
                                                    anchors.margins: wallThumbCard.isCurrent ? 2 : 1
                                                    source: "file://" + wallThumbCard.model.wallPath
                                                    sourceSize.width: 340
                                                    sourceSize.height: 220
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    visible: false
                                                }

                                                Rectangle {
                                                    id: thumbMask
                                                    anchors.fill: parent
                                                    anchors.margins: wallThumbCard.isCurrent ? 2 : 1
                                                    radius: 12
                                                    visible: false
                                                }

                                                OpacityMask {
                                                    anchors.fill: parent
                                                    anchors.margins: wallThumbCard.isCurrent ? 2 : 1
                                                    source: thumbImg
                                                    maskSource: thumbMask
                                                    visible: thumbImg.status === Image.Ready
                                                }

                                                Rectangle {
                                                    visible: wallThumbCard.isCurrent
                                                    anchors.top: parent.top
                                                    anchors.right: parent.right
                                                    anchors.margins: 7
                                                    width: 22
                                                    height: 22
                                                    radius: 11
                                                    color: Theme.accent
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰄬"
                                                        font.family: Theme.iconFont
                                                        font.pixelSize: 12
                                                        color: Theme.badgeFgActive
                                                    }
                                                }

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    anchors.margins: 6
                                                    height: 24
                                                    radius: 8
                                                    color: "#aa101218"

                                                    Text {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 8
                                                        anchors.rightMargin: 8
                                                        verticalAlignment: Text.AlignVCenter
                                                        text: wallThumbCard.model.wallName
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 10
                                                        font.weight: wallThumbCard.isCurrent ? Font.Bold : Font.Medium
                                                        color: "#ffffff"
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                MouseArea {
                                                    id: wallThumbMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.selectWallpaper(wallThumbCard.model.wallPath)
                                                }
                                            }
                                        }

                                        // Empty State when ~/Pictures/Wallpapers has no images
                                        Rectangle {
                                            anchors.fill: parent
                                            visible: wallpapersModel.count === 0
                                            radius: 14
                                            color: Theme.lightMode ? Qt.rgba(0.0, 0.0, 0.0, 0.03) : Qt.rgba(1.0, 1.0, 1.0, 0.035)
                                            border.color: Theme.glassBorder
                                            border.width: 1

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                Text { Layout.alignment: Qt.AlignHCenter; text: "󰸉"; font.family: Theme.iconFont; font.pixelSize: 22; color: Theme.textDim }
                                                Text { Layout.alignment: Qt.AlignHCenter; text: "No wallpapers found"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                                Text { Layout.alignment: Qt.AlignHCenter; text: "Add images to ~/Pictures/Wallpapers"; font.family: Theme.fontFamily; font.pixelSize: 10; color: Theme.subtext }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ================= PAGE 1: BAR & ISLAND =================
                Item {
                    id: tab1Item
                    anchors.fill: parent
                    opacity: settingsCard.activeTab === 1 ? 1.0 : 0.0
                    visible: opacity > 0.005
                    enabled: settingsCard.activeTab === 1
                    Behavior on opacity { NumberAnimation { duration: ShellState.animDur(250, 170); easing.type: ShellState.animPrimaryEase } }
                    transform: Translate {
                        x: settingsCard.activeTab === 1 ? 0 : (settingsCard.activeTab > 1 ? -18 : 18)
                        Behavior on x { NumberAnimation { duration: ShellState.animDur(300, 210); easing.type: ShellState.animPrimaryEase } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 12

                        GlassPanelCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                RowLayout {
                                    spacing: 8
                                    Text { text: "󰥔"; font.family: Theme.iconFont; font.pixelSize: 14; color: Theme.text }
                                    Text { text: "Top Bar Widgets"; font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true; color: Theme.text }
                                }

                                ToggleRow {
                                    icon: "󰥔"
                                    title: "24-Hour Clock"
                                    subtitle: "Use 24-hour time format"
                                    checked: ShellState.use24HourClock
                                    onToggled: ShellState.use24HourClock = !ShellState.use24HourClock
                                }

                                ToggleRow {
                                    icon: "󱑎"
                                    title: "Show Seconds"
                                    subtitle: "Include seconds in clock"
                                    checked: ShellState.showClockSeconds
                                    onToggled: ShellState.showClockSeconds = !ShellState.showClockSeconds
                                }

                                ToggleRow {
                                    icon: "󰖯"
                                    title: "Active Window Title"
                                    subtitle: "Show focused window in bar center"
                                    checked: ShellState.showWindowTitle
                                    onToggled: ShellState.showWindowTitle = !ShellState.showWindowTitle
                                }

                                ToggleRow {
                                    icon: "󰁹"
                                    title: "Battery Percentage"
                                    subtitle: "Show percentage next to icon"
                                    checked: ShellState.showBatteryPercent
                                    onToggled: ShellState.showBatteryPercent = !ShellState.showBatteryPercent
                                }

                                ToggleRow {
                                    icon: "󰃤"
                                    title: "Debug Menu Button"
                                    subtitle: "Show developer utilities in bar"
                                    checked: ShellState.showDebugButton
                                    onToggled: ShellState.showDebugButton = !ShellState.showDebugButton
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }

                        GlassPanelCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                RowLayout {
                                    spacing: 8
                                    Text { text: "󰍺"; font.family: Theme.iconFont; font.pixelSize: 14; color: Theme.text }
                                    Text { text: "Islands & Multi-Monitor"; font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true; color: Theme.text }
                                }

                                ToggleRow {
                                    icon: "󰍺"
                                    title: "Secondary Displays"
                                    subtitle: "Extend island and status bar to extra displays"
                                    checked: ShellState.secondaryFullBar
                                    onToggled: ShellState.secondaryFullBar = !ShellState.secondaryFullBar
                                }

                                ToggleRow {
                                    icon: "󰅶"
                                    title: "Keep Awake"
                                    subtitle: "Prevent screen blanking and sleep"
                                    checked: ShellState.awakeActive
                                    onToggled: ShellState.awakeActive = !ShellState.awakeActive
                                }

                                ToggleRow {
                                    icon: "󰎈"
                                    title: "Music Apps Only"
                                    subtitle: "Prioritize music players over browsers"
                                    checked: ShellState.musicAppsOnlyOnIsland
                                    onToggled: ShellState.musicAppsOnlyOnIsland = !ShellState.musicAppsOnlyOnIsland
                                }

                                ToggleRow {
                                    icon: "󰎆"
                                    title: "Announce Media Changes"
                                    subtitle: "Show Now Playing banner on track change"
                                    checked: ShellState.announceMediaChanges
                                    onToggled: ShellState.announceMediaChanges = !ShellState.announceMediaChanges
                                }

                                ToggleRow {
                                    icon: "󰃨"
                                    title: "Liquid Glass"
                                    subtitle: "Translucent glass blur & refraction"
                                    checked: ShellState.liquidGlassEnabled
                                    onToggled: ShellState.liquidGlassEnabled = !ShellState.liquidGlassEnabled
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }
                    }
                }

                // ================= PAGE 2: DISPLAYS & POWER =================
                Item {
                    id: tab2Item
                    anchors.fill: parent
                    opacity: settingsCard.activeTab === 2 ? 1.0 : 0.0
                    visible: opacity > 0.005
                    enabled: settingsCard.activeTab === 2
                    Behavior on opacity { NumberAnimation { duration: ShellState.animDur(250, 170); easing.type: ShellState.animPrimaryEase } }
                    transform: Translate {
                        x: settingsCard.activeTab === 2 ? 0 : (settingsCard.activeTab > 2 ? -18 : 18)
                        Behavior on x { NumberAnimation { duration: ShellState.animDur(300, 210); easing.type: ShellState.animPrimaryEase } }
                    }

                    Flickable {
                        id: displayFlick
                        anchors.fill: parent
                        clip: true
                        contentWidth: width
                        contentHeight: displayCol.implicitHeight + 4
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: !root.isDraggingMonitor && contentHeight > height

                        property real scrollTargetY: 0
                        Behavior on contentY { NumberAnimation { duration: 105; easing.type: Easing.OutCubic } }
                        onContentHeightChanged: {
                            const maxY = Math.max(0, contentHeight - height);
                            if (scrollTargetY > maxY) scrollTargetY = maxY;
                        }

                        WheelHandler {
                            target: null
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            enabled: !root.isDraggingMonitor
                            onWheel: event => root.applyFastWheel(displayFlick, event, 210)
                        }

                        ColumnLayout {
                            id: displayCol
                            width: displayFlick.width
                            spacing: 10

                        // Draggable Monitor Arrangement Map (ListModel-backed: zero delegate teardown on drag)
                        GlassPanelCard {
                            Layout.fillWidth: true
                            Layout.preferredHeight: monDraftsModel.count > 1 ? 210 : 178

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 7

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Text { text: "󰍹"; font.family: Theme.iconFont; font.pixelSize: 14; color: Theme.text }
                                    Text { text: "Monitor Arrangement"; font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true; color: Theme.text }
                                    Text {
                                        text: root.monLayoutDirty ? "Unsaved position • snaps to edges" : "Drag displays to arrange"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: root.monLayoutDirty ? Theme.accent : Theme.subtext
                                    }
                                    Item { Layout.fillWidth: true }
                                    ActionPill {
                                        visible: root.monLayoutDirty
                                        icon: "󰜉"
                                        label: "Reset"
                                        implicitHeight: 24
                                        onClicked: root.resetMonitorDrafts()
                                    }
                                    ActionPill {
                                        visible: root.monLayoutDirty
                                        icon: "󰄬"
                                        label: "Apply Layout"
                                        active: true
                                        implicitHeight: 24
                                        onClicked: root.applyMonitorLayout()
                                    }
                                    ActionPill {
                                        icon: "󰈈"
                                        label: "Identify"
                                        implicitHeight: 24
                                        onClicked: ShellState.triggerIdentifyMonitors()
                                    }
                                    ActionPill {
                                        icon: "󰑐"
                                        label: "Detect"
                                        implicitHeight: 24
                                        onClicked: {
                                            sysInfoProc.running = false;
                                            sysInfoProc.running = true;
                                        }
                                    }
                                }

                                Rectangle {
                                    id: monCanvasFrame
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 12
                                    color: Theme.lightMode ? Qt.rgba(0.0, 0.0, 0.0, 0.05) : Qt.rgba(0.0, 0.0, 0.0, 0.24)
                                    border.width: 1
                                    border.color: Theme.glassBorder
                                    clip: true

                                    Item {
                                        id: monCanvas
                                        anchors.fill: parent
                                        anchors.margins: 10

                                        property real snapGuideX: -99999
                                        property real snapGuideY: -99999

                                        function computeBounds() {
                                            const _r = root.monDraftsRev;
                                            if (monDraftsModel.count === 0) return { minX: 0, minY: 0, maxX: 1920, maxY: 1080 };
                                            const m0 = monDraftsModel.get(0);
                                            const w0 = ((m0.monTransform % 2 === 1) ? m0.monH : m0.monW) / Math.max(0.5, m0.monScale);
                                            const h0 = ((m0.monTransform % 2 === 1) ? m0.monW : m0.monH) / Math.max(0.5, m0.monScale);
                                            let minX = m0.monX;
                                            let minY = m0.monY;
                                            let maxX = m0.monX + w0;
                                            let maxY = m0.monY + h0;
                                            for (let i = 1; i < monDraftsModel.count; i++) {
                                                const m = monDraftsModel.get(i);
                                                const lw = ((m.monTransform % 2 === 1) ? m.monH : m.monW) / Math.max(0.5, m.monScale);
                                                const lh = ((m.monTransform % 2 === 1) ? m.monW : m.monH) / Math.max(0.5, m.monScale);
                                                minX = Math.min(minX, m.monX);
                                                minY = Math.min(minY, m.monY);
                                                maxX = Math.max(maxX, m.monX + lw);
                                                maxY = Math.max(maxY, m.monY + lh);
                                            }
                                            return { minX: minX - 240, minY: minY - 180, maxX: maxX + 240, maxY: maxY + 180 };
                                        }

                                        property var frozenBounds: ({ minX: 0, minY: 0, maxX: 1920, maxY: 1080 })
                                        readonly property var activeBounds: root.isDraggingMonitor ? frozenBounds : computeBounds()
                                        readonly property real boundsMinX: activeBounds.minX
                                        readonly property real boundsMinY: activeBounds.minY
                                        readonly property real spanW: Math.max(1, activeBounds.maxX - activeBounds.minX)
                                        readonly property real spanH: Math.max(1, activeBounds.maxY - activeBounds.minY)
                                        readonly property real fitScale: Math.min((width - 8) / spanW, (height - 4) / spanH)
                                        readonly property real offsetX: (width - spanW * fitScale) / 2
                                        readonly property real offsetY: (height - spanH * fitScale) / 2

                                        function normalizeDrafts() {
                                            if (monDraftsModel.count === 0) return;
                                            let minX = monDraftsModel.get(0).monX;
                                            let minY = monDraftsModel.get(0).monY;
                                            for (let i = 1; i < monDraftsModel.count; i++) {
                                                minX = Math.min(minX, monDraftsModel.get(i).monX);
                                                minY = Math.min(minY, monDraftsModel.get(i).monY);
                                            }
                                            for (let i = 0; i < monDraftsModel.count; i++) {
                                                monDraftsModel.setProperty(i, "monX", Math.round(monDraftsModel.get(i).monX - minX));
                                                monDraftsModel.setProperty(i, "monY", Math.round(monDraftsModel.get(i).monY - minY));
                                            }
                                            root.monDrafts = root.snapshotDraftsArray();
                                            root.monDraftsRev++;
                                            if (root.selectedMonitorIdx < monDraftsModel.count) {
                                                const sel = monDraftsModel.get(root.selectedMonitorIdx);
                                                root.selectedMonPos = sel.monX + "x" + sel.monY;
                                            }
                                        }

                                        // Live snap guide lines
                                        Rectangle {
                                            visible: root.isDraggingMonitor && monCanvas.snapGuideX > -90000
                                            x: monCanvas.offsetX + (monCanvas.snapGuideX - monCanvas.boundsMinX) * monCanvas.fitScale
                                            y: 0
                                            width: 1
                                            height: monCanvas.height
                                            color: Theme.accent
                                            opacity: 0.75
                                            z: 30
                                        }
                                        Rectangle {
                                            visible: root.isDraggingMonitor && monCanvas.snapGuideY > -90000
                                            x: 0
                                            y: monCanvas.offsetY + (monCanvas.snapGuideY - monCanvas.boundsMinY) * monCanvas.fitScale
                                            width: monCanvas.width
                                            height: 1
                                            color: Theme.accent
                                            opacity: 0.75
                                            z: 30
                                        }

                                        Repeater {
                                            model: monDraftsModel
                                            delegate: Item {
                                                id: monTile
                                                required property int index
                                                required property string monName
                                                required property string monDesc
                                                required property real monW
                                                required property real monH
                                                required property real monRefresh
                                                required property real monX
                                                required property real monY
                                                required property real monScale
                                                required property int monTransform
                                                required property string monMirror
                                                required property bool monDisabled
                                                required property bool monFocused

                                                readonly property bool isSel: root.selectedMonitorIdx === index
                                                readonly property real logicalW: ((monTransform % 2 === 1) ? monH : monW) / Math.max(0.5, monScale)
                                                readonly property real logicalH: ((monTransform % 2 === 1) ? monW : monH) / Math.max(0.5, monScale)

                                                property bool dragging: false
                                                property bool hasMoved: false
                                                property real dragStartMouseX: 0
                                                property real dragStartMouseY: 0
                                                property real dragStartMonX: 0
                                                property real dragStartMonY: 0

                                                x: monCanvas.offsetX + (monX - monCanvas.boundsMinX) * monCanvas.fitScale
                                                y: monCanvas.offsetY + (monY - monCanvas.boundsMinY) * monCanvas.fitScale
                                                width: Math.max(66, logicalW * monCanvas.fitScale - 2)
                                                height: Math.max(44, logicalH * monCanvas.fitScale - 2)
                                                z: dragging ? 20 : (isSel ? 10 : 1)
                                                opacity: monDisabled ? 0.45 : 1.0

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 10
                                                    color: monTile.dragging ? Theme.glassSurfaceActive : (monTile.isSel ? Theme.glassSurfaceHover : Theme.glassCard)
                                                    border.width: monTile.dragging || monTile.isSel ? 2 : 1
                                                    border.color: monTile.dragging || monTile.isSel ? Theme.accent : Theme.glassBorder
                                                    scale: monTile.dragging ? 1.03 : 1.0
                                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                                    Behavior on border.color { ColorAnimation { duration: 130 } }

                                                    ColumnLayout {
                                                        anchors.centerIn: parent
                                                        spacing: 1
                                                        Text {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            text: (monTile.monName === Theme.mainMonitorName ? "★ " : "") + monTile.monName + (monTile.monDisabled ? " (Off)" : (monTile.monMirror.length > 0 ? (" → " + monTile.monMirror) : ""))
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 11
                                                            font.bold: true
                                                            color: Theme.text
                                                        }
                                                        Text {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            text: Math.round(monTile.monW) + "×" + Math.round(monTile.monH) + " @ " + Math.round(monTile.monRefresh) + "Hz"
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 9
                                                            color: Theme.subtext
                                                        }
                                                        Text {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            text: Math.round(monTile.monX) + ", " + Math.round(monTile.monY) + " • " + monTile.monScale + "x" + (monTile.monTransform !== 0 ? (" • " + (monTile.monTransform * 90) + "°") : "")
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 9
                                                            font.weight: monTile.dragging ? Font.Bold : Font.Normal
                                                            color: monTile.dragging ? Theme.accent : Theme.textDim
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: monTile.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                                    preventStealing: true

                                                    onPressed: mouse => {
                                                        root.selectedMonitorIdx = monTile.index;
                                                        root.syncSelectedMonitorDraft();
                                                        monCanvas.frozenBounds = monCanvas.computeBounds();
                                                        monCanvas.snapGuideX = -99999;
                                                        monCanvas.snapGuideY = -99999;
                                                        const pt = mapToItem(monCanvas, mouse.x, mouse.y);
                                                        monTile.dragStartMouseX = pt.x;
                                                        monTile.dragStartMouseY = pt.y;
                                                        monTile.dragStartMonX = monTile.monX;
                                                        monTile.dragStartMonY = monTile.monY;
                                                        monTile.hasMoved = false;
                                                        monTile.dragging = true;
                                                        root.isDraggingMonitor = true;
                                                    }

                                                    onPositionChanged: mouse => {
                                                        if (!monTile.dragging) return;
                                                        const pt = mapToItem(monCanvas, mouse.x, mouse.y);
                                                        if (!monTile.hasMoved && Math.abs(pt.x - monTile.dragStartMouseX) <= 3 && Math.abs(pt.y - monTile.dragStartMouseY) <= 3) {
                                                            return;
                                                        }
                                                        monTile.hasMoved = true;
                                                        const invScale = 1.0 / Math.max(0.005, monCanvas.fitScale);
                                                        let newX = monTile.dragStartMonX + (pt.x - monTile.dragStartMouseX) * invScale;
                                                        let newY = monTile.dragStartMonY + (pt.y - monTile.dragStartMouseY) * invScale;

                                                        const snapDist = 18 * invScale;
                                                        const myW = monTile.logicalW;
                                                        const myH = monTile.logicalH;
                                                        let gx = -99999;
                                                        let gy = -99999;

                                                        for (let i = 0; i < monDraftsModel.count; i++) {
                                                            if (i === monTile.index) continue;
                                                            const o = monDraftsModel.get(i);
                                                            const oW = ((o.monTransform % 2 === 1) ? o.monH : o.monW) / Math.max(0.5, o.monScale);
                                                            const oH = ((o.monTransform % 2 === 1) ? o.monW : o.monH) / Math.max(0.5, o.monScale);

                                                            if (Math.abs(newX - (o.monX + oW)) < snapDist) { newX = o.monX + oW; gx = o.monX + oW; }
                                                            else if (Math.abs((newX + myW) - o.monX) < snapDist) { newX = o.monX - myW; gx = o.monX; }
                                                            else if (Math.abs(newX - o.monX) < snapDist) { newX = o.monX; gx = o.monX; }
                                                            else if (Math.abs((newX + myW) - (o.monX + oW)) < snapDist) { newX = o.monX + oW - myW; gx = o.monX + oW; }

                                                            if (Math.abs(newY - o.monY) < snapDist) { newY = o.monY; gy = o.monY; }
                                                            else if (Math.abs((newY + myH) - (o.monY + oH)) < snapDist) { newY = o.monY + oH - myH; gy = o.monY + oH; }
                                                            else if (Math.abs((newY + myH / 2) - (o.monY + oH / 2)) < snapDist) { newY = o.monY + (oH - myH) / 2; gy = o.monY + oH / 2; }
                                                            else if (Math.abs(newY - (o.monY + oH)) < snapDist) { newY = o.monY + oH; gy = o.monY + oH; }
                                                            else if (Math.abs((newY + myH) - o.monY) < snapDist) { newY = o.monY - myH; gy = o.monY; }
                                                        }

                                                        monCanvas.snapGuideX = gx;
                                                        monCanvas.snapGuideY = gy;
                                                        const rx = Math.round(newX);
                                                        const ry = Math.round(newY);
                                                        monDraftsModel.setProperty(monTile.index, "monX", rx);
                                                        monDraftsModel.setProperty(monTile.index, "monY", ry);
                                                        root.selectedMonPos = rx + "x" + ry;
                                                        root.monLayoutDirty = true;
                                                    }

                                                    function finishDrag() {
                                                        if (!monTile.dragging) return;
                                                        monTile.dragging = false;
                                                        root.isDraggingMonitor = false;
                                                        monCanvas.snapGuideX = -99999;
                                                        monCanvas.snapGuideY = -99999;
                                                        if (monTile.hasMoved) {
                                                            monCanvas.normalizeDrafts();
                                                        }
                                                    }

                                                    onReleased: finishDrag()
                                                    onCanceled: finishDrag()
                                                }
                                            }
                                        }
                                    }
                                }

                                // Quick multi-monitor alignment strip
                                RowLayout {
                                    visible: monDraftsModel.count > 1
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Text {
                                        text: "Quick Snap Selected:"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: Theme.subtext
                                    }
                                    Repeater {
                                        model: [
                                            { label: "Left Of", dir: "left" },
                                            { label: "Right Of", dir: "right" },
                                            { label: "Above", dir: "above" },
                                            { label: "Below", dir: "below" }
                                        ]
                                        delegate: ActionPill {
                                            required property var modelData
                                            label: modelData.label
                                            implicitHeight: 22
                                            onClicked: root.quickArrangeSelected(modelData.dir)
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                            }
                        }

                        // Selected Monitor Configuration (KDE / GNOME style controls)
                        GlassPanelCard {
                            id: dispSettingsCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: dispSettingsCol.implicitHeight + 24

                            readonly property var curMon: (root.sysMonitors && root.sysMonitors.length > 0)
                                ? root.sysMonitors[Math.max(0, Math.min(root.selectedMonitorIdx, root.sysMonitors.length - 1))]
                                : null

                            ColumnLayout {
                                id: dispSettingsCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 12
                                spacing: 8

                                // Display Header + Enable Switch + Apply Button
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text { text: "󰒓"; font.family: Theme.iconFont; font.pixelSize: 14; color: Theme.text }
                                    Text {
                                        text: dispSettingsCard.curMon ? ("Display: " + dispSettingsCard.curMon.name + " (" + dispSettingsCard.curMon.description + ")") : "No display detected"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: Theme.text
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    RowLayout {
                                        visible: root.sysMonitors.length > 1
                                        spacing: 5
                                        Text {
                                            text: root.selectedMonDisabled ? "Disabled" : "Enabled"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            color: root.selectedMonDisabled ? Theme.textDim : Theme.text
                                        }
                                        Rectangle {
                                            readonly property bool canDisable: !root.selectedMonDisabled ? (root.enabledMonitorCount() > 1) : true
                                            Layout.preferredWidth: 38
                                            Layout.preferredHeight: 20
                                            radius: 10
                                            opacity: canDisable ? 1.0 : 0.45
                                            color: !root.selectedMonDisabled ? Theme.badgeBgActive : Theme.glassCard
                                            border.color: !root.selectedMonDisabled ? Theme.badgeBgActive : Theme.glassBorder
                                            border.width: 1
                                            Behavior on color { ColorAnimation { duration: ShellState.animDur(180, 130) } }
                                            Rectangle {
                                                width: 14
                                                height: 14
                                                radius: 7
                                                y: 3
                                                x: !root.selectedMonDisabled ? 21 : 3
                                                color: !root.selectedMonDisabled ? Theme.badgeFgActive : Theme.text
                                                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.0 } }
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: parent.canDisable
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: {
                                                    root.selectedMonDisabled = !root.selectedMonDisabled;
                                                    root.updateDraftProp(root.selectedMonitorIdx, "monDisabled", root.selectedMonDisabled);
                                                    root.monConfigDirty = true;
                                                }
                                            }
                                        }
                                    }
                                    ActionPill {
                                        visible: dispSettingsCard.curMon !== null && !root.selectedMonDisabled
                                        icon: (dispSettingsCard.curMon && dispSettingsCard.curMon.name === Theme.mainMonitorName) ? "󰓎" : "󰓏"
                                        label: (dispSettingsCard.curMon && dispSettingsCard.curMon.name === Theme.mainMonitorName) ? "Main Display" : "Set as Main"
                                        active: dispSettingsCard.curMon !== null && dispSettingsCard.curMon.name === Theme.mainMonitorName
                                        onClicked: {
                                            if (dispSettingsCard.curMon) {
                                                ShellState.setMainMonitor(dispSettingsCard.curMon.name);
                                            }
                                        }
                                    }
                                    ActionPill {
                                        icon: "󰄬"
                                        label: (root.monLayoutDirty || root.monConfigDirty) ? "Apply Changes" : "Apply Display"
                                        active: true
                                        onClicked: root.applySelectedMonitorConfig()
                                    }
                                }

                                // Resolution & Refresh Rate Dropdowns
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    visible: !root.selectedMonDisabled

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        spacing: 4
                                        Text { text: "Resolution"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                        GlassDropdown {
                                            fallbackText: root.selectedMonRes ? root.selectedMonRes.replace("x", "×") : "Select resolution"
                                            currentValue: root.selectedMonRes
                                            options: root.uniqueResolutionsFor(dispSettingsCard.curMon).map(function(r) {
                                                return { label: r.replace("x", "×"), value: r };
                                            })
                                            onActivated: value => {
                                                root.selectedMonRes = value;
                                                const rates = root.refreshRatesFor(dispSettingsCard.curMon, value);
                                                if (rates.length > 0) {
                                                    root.selectedMonMode = rates[0].mode;
                                                    root.updateDraftProp(root.selectedMonitorIdx, "monRefresh", rates[0].hz);
                                                }
                                                const parts = String(value).split("x");
                                                if (parts.length === 2) {
                                                    root.updateDraftProp(root.selectedMonitorIdx, "monW", Number(parts[0]));
                                                    root.updateDraftProp(root.selectedMonitorIdx, "monH", Number(parts[1]));
                                                }
                                                root.monConfigDirty = true;
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        spacing: 4
                                        Text { text: "Refresh Rate"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                        GlassDropdown {
                                            fallbackText: "Select rate"
                                            currentValue: root.selectedMonMode
                                            options: root.refreshRatesFor(dispSettingsCard.curMon, root.selectedMonRes).map(function(r) {
                                                return { label: r.label, value: r.mode, hz: r.hz };
                                            })
                                            onActivated: (value, opt) => {
                                                root.selectedMonMode = String(value);
                                                if (opt && typeof opt.hz === "number") {
                                                    root.updateDraftProp(root.selectedMonitorIdx, "monRefresh", opt.hz);
                                                }
                                                root.monConfigDirty = true;
                                            }
                                        }
                                    }
                                }

                                // Scale & Orientation Dropdowns
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    visible: !root.selectedMonDisabled

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        spacing: 4
                                        Text { text: "Scale"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                        GlassDropdown {
                                            fallbackText: Math.round(Number(root.selectedMonScale || 1) * 100) + "%"
                                            currentValue: {
                                                const s = Number(root.selectedMonScale || 1);
                                                if (Math.abs(s - 1.0) < 0.02) return "1";
                                                if (Math.abs(s - 1.25) < 0.02) return "1.25";
                                                if (Math.abs(s - 1.5) < 0.02) return "1.5";
                                                if (Math.abs(s - 1.75) < 0.02) return "1.75";
                                                if (Math.abs(s - 2.0) < 0.02) return "2";
                                                return String(root.selectedMonScale);
                                            }
                                            options: [
                                                { label: "100% (Native)", value: "1" },
                                                { label: "125%", value: "1.25" },
                                                { label: "150%", value: "1.5" },
                                                { label: "175%", value: "1.75" },
                                                { label: "200%", value: "2" }
                                            ]
                                            onActivated: value => {
                                                root.selectedMonScale = String(value);
                                                root.updateDraftProp(root.selectedMonitorIdx, "monScale", Number(value));
                                                root.monConfigDirty = true;
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        spacing: 4
                                        Text { text: "Orientation"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                        GlassDropdown {
                                            fallbackText: "Landscape"
                                            currentValue: root.selectedMonTransform
                                            options: [
                                                { label: "Landscape (0°)", value: 0 },
                                                { label: "Portrait (90°)", value: 1 },
                                                { label: "Landscape Flipped (180°)", value: 2 },
                                                { label: "Portrait Flipped (270°)", value: 3 }
                                            ]
                                            onActivated: value => {
                                                root.selectedMonTransform = Number(value);
                                                root.updateDraftProp(root.selectedMonitorIdx, "monTransform", Number(value));
                                                root.monConfigDirty = true;
                                            }
                                        }
                                    }
                                }

                                // Adaptive Sync (VRR) & Color Profile Dropdowns
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    visible: !root.selectedMonDisabled

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        spacing: 4
                                        Text { text: "Adaptive Sync (VRR)"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                        GlassDropdown {
                                            fallbackText: "Off"
                                            currentValue: root.selectedMonVrr
                                            options: [
                                                { label: "Off", value: 0 },
                                                { label: "Always On", value: 1 },
                                                { label: "Fullscreen Only", value: 2 }
                                            ]
                                            onActivated: value => {
                                                root.selectedMonVrr = Number(value);
                                                root.updateDraftProp(root.selectedMonitorIdx, "monVrr", Number(value));
                                                root.monConfigDirty = true;
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        spacing: 4
                                        Text { text: "Color & Dynamic Range"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                        GlassDropdown {
                                            fallbackText: "8-bit sRGB"
                                            currentValue: root.selectedMonCm === "hdr"
                                                ? "hdr10"
                                                : (root.selectedMonBitdepth === 10 ? "wide10" : "srgb8")
                                            options: {
                                                const opts = [
                                                    { label: "8-bit sRGB", value: "srgb8" },
                                                    { label: "10-bit Wide Gamut", value: "wide10" }
                                                ];
                                                if ((dispSettingsCard.curMon && dispSettingsCard.curMon.supportsHdr) || root.selectedMonCm === "hdr") {
                                                    opts.push({ label: "HDR (10-bit)", value: "hdr10" });
                                                }
                                                return opts;
                                            }
                                            onActivated: value => {
                                                if (value === "hdr10") {
                                                    root.selectedMonBitdepth = 10;
                                                    root.selectedMonCm = "hdr";
                                                } else if (value === "wide10") {
                                                    root.selectedMonBitdepth = 10;
                                                    root.selectedMonCm = "wide";
                                                } else {
                                                    root.selectedMonBitdepth = 8;
                                                    root.selectedMonCm = "srgb";
                                                }
                                                root.updateDraftProp(root.selectedMonitorIdx, "monBitdepth", root.selectedMonBitdepth);
                                                root.updateDraftProp(root.selectedMonitorIdx, "monCm", root.selectedMonCm);
                                                root.monConfigDirty = true;
                                            }
                                        }
                                    }
                                }

                                // Mirroring Dropdown (Multi-monitor only)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    visible: !root.selectedMonDisabled && root.sysMonitors.length > 1
                                    Text { text: "Display Mode & Mirroring"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                    GlassDropdown {
                                        fallbackText: "Extend (Independent)"
                                        currentValue: root.selectedMonMirror
                                        options: {
                                            const opts = [{ label: "Extend (Independent)", value: "" }];
                                            const cur = dispSettingsCard.curMon;
                                            const curName = cur ? cur.name : "";
                                            for (let i = 0; i < root.sysMonitors.length; i++) {
                                                if (root.sysMonitors[i].name !== curName && !root.sysMonitors[i].disabled) {
                                                    opts.push({ label: "Mirror " + root.sysMonitors[i].name, value: root.sysMonitors[i].name });
                                                }
                                            }
                                            return opts;
                                        }
                                        onActivated: value => {
                                            root.selectedMonMirror = String(value);
                                            root.updateDraftProp(root.selectedMonitorIdx, "monMirror", String(value));
                                            root.monConfigDirty = true;
                                        }
                                    }
                                }
                            }
                        }

                        // Power & Display Inactivity Timeouts
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            GlassPanelCard {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 74
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 5
                                    Text { text: "Turn Off Screen When Inactive"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Repeater {
                                            model: [
                                                { label: "3 min", val: 3 },
                                                { label: "5 min", val: 5 },
                                                { label: "10 min", val: 10 },
                                                { label: "Never", val: 0 }
                                            ]
                                            delegate: ActionPill {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                implicitHeight: 26
                                                label: modelData.label
                                                active: ShellState.screenOffTimeoutMin === modelData.val
                                                onClicked: ShellState.screenOffTimeoutMin = modelData.val
                                            }
                                        }
                                    }
                                }
                            }

                            GlassPanelCard {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 74
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 5
                                    Text { text: "Suspend System When Inactive"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Repeater {
                                            model: [
                                                { label: "10 min", val: 10 },
                                                { label: "15 min", val: 15 },
                                                { label: "30 min", val: 30 },
                                                { label: "Never", val: 0 }
                                            ]
                                            delegate: ActionPill {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                implicitHeight: 26
                                                label: modelData.label
                                                active: ShellState.sleepTimeoutMin === modelData.val
                                                onClicked: ShellState.sleepTimeoutMin = modelData.val
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        }
                    }
                }

                // ================= PAGE 3: NETWORK & BLUETOOTH =================
                Item {
                    id: tab3Item
                    anchors.fill: parent
                    opacity: settingsCard.activeTab === 3 ? 1.0 : 0.0
                    visible: opacity > 0.005
                    enabled: settingsCard.activeTab === 3
                    Behavior on opacity { NumberAnimation { duration: ShellState.animDur(250, 170); easing.type: ShellState.animPrimaryEase } }
                    transform: Translate {
                        x: settingsCard.activeTab === 3 ? 0 : (settingsCard.activeTab > 3 ? -18 : 18)
                        Behavior on x { NumberAnimation { duration: ShellState.animDur(300, 210); easing.type: ShellState.animPrimaryEase } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 12

                        // Left: Network & Wi-Fi
                        GlassPanelCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "󰤨"; font.family: Theme.iconFont; font.pixelSize: 14; color: Theme.text }
                                    Text { text: "Network & Wi-Fi"; font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true; color: Theme.text }
                                    Item { Layout.fillWidth: true }
                                    ActionPill {
                                        icon: "󰑐"
                                        label: "Rescan"
                                        implicitHeight: 24
                                        onClicked: {
                                            Quickshell.execDetached([ShellState.script("network-manager.sh"), "rescan"]);
                                            stNetProc.running = false;
                                            stNetProc.running = true;
                                        }
                                    }
                                    ActionPill {
                                        icon: "󰒓"
                                        label: "nmtui"
                                        implicitHeight: 24
                                        onClicked: {
                                            ShellState.settingsOpen = false;
                                            ShellState.launchTerminal("nmtui");
                                        }
                                    }
                                }

                                // Inline Wi-Fi password bar in Settings
                                Rectangle {
                                    id: stPwBox
                                    readonly property bool showPw: root.stWifiPromptSsid.length > 0 || root.stWifiError.length > 0
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: showPw ? (root.stWifiPromptSsid.length > 0 ? (root.stWifiError.length > 0 ? 78 : 58) : 26) : 0
                                    opacity: showPw ? 1.0 : 0.0
                                    visible: Layout.preferredHeight > 0.5 || opacity > 0.005
                                    clip: true
                                    radius: 12
                                    color: Theme.glassSurfaceActive
                                    border.color: Theme.glassHighlight
                                    border.width: 1
                                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 160 } }

                                    function submitStPw() {
                                        if (root.stWifiPromptSsid.length === 0) return;
                                        root.stWifiConnecting = true;
                                        root.stWifiError = "";
                                        root.stNetActionCmd = "connect";
                                        root.stNetActionTarget = root.stWifiPromptSsid;
                                        root.stNetActionPassword = stWifiPwInput.text;
                                        stNetActionProc.running = false;
                                        stNetActionProc.running = true;
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 4

                                        RowLayout {
                                            Layout.fillWidth: true
                                            visible: root.stWifiPromptSsid.length > 0
                                            spacing: 6

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 26
                                                radius: 8
                                                color: Theme.glassCard
                                                border.width: 1
                                                border.color: stWifiPwInput.activeFocus ? Theme.accent : Theme.glassBorder

                                                TextInput {
                                                    id: stWifiPwInput
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 8
                                                    anchors.rightMargin: 8
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 10
                                                    color: Theme.text
                                                    echoMode: root.stWifiShowPw ? TextInput.Normal : TextInput.Password
                                                    clip: true
                                                    Keys.onReturnPressed: stPwBox.submitStPw()
                                                    Text {
                                                        anchors.fill: parent
                                                        verticalAlignment: Text.AlignVCenter
                                                        text: "Password for " + root.stWifiPromptSsid
                                                        font: parent.font
                                                        color: Theme.textDim
                                                        visible: parent.text.length === 0
                                                    }
                                                }
                                            }

                                            ActionPill {
                                                label: root.stWifiConnecting ? "..." : "Join"
                                                active: true
                                                implicitHeight: 26
                                                onClicked: stPwBox.submitStPw()
                                            }
                                            ActionPill {
                                                label: "✕"
                                                implicitHeight: 26
                                                onClicked: {
                                                    root.stWifiPromptSsid = "";
                                                    root.stWifiError = "";
                                                    stWifiPwInput.text = "";
                                                }
                                            }
                                        }

                                        Text {
                                            visible: root.stWifiError.length > 0
                                            text: root.stWifiError
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: "#F87171"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                ListView {
                                    id: stNetList
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 6
                                    model: stNetModel
                                    boundsBehavior: Flickable.StopAtBounds

                                    property real scrollTargetY: 0
                                    Behavior on contentY { NumberAnimation { duration: 105; easing.type: Easing.OutCubic } }
                                    onContentHeightChanged: {
                                        const maxY = Math.max(0, contentHeight - height);
                                        if (scrollTargetY > maxY) scrollTargetY = maxY;
                                    }

                                    WheelHandler {
                                        target: null
                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                        onWheel: event => root.applyFastWheel(stNetList, event, 200)
                                    }

                                    delegate: Rectangle {
                                        id: stNetRow
                                        required property var model
                                        required property int index
                                        width: ListView.view.width
                                        height: 52
                                        radius: 12
                                        color: model.active ? Theme.glassSurfaceActive : (stNetMouse.containsMouse ? Theme.glassSurfaceHover : Theme.glassCard)
                                        border.color: model.active ? Theme.glassHighlight : Theme.glassBorder
                                        border.width: 1
                                        scale: stNetMouse.pressed ? 0.98 : 1.0
                                        Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 105); easing.type: ShellState.animPrimaryEase } }
                                        Behavior on color { ColorAnimation { duration: ShellState.animDur(170, 120) } }
                                        Behavior on border.color { ColorAnimation { duration: ShellState.animDur(170, 120) } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 10

                                            Text { text: stNetRow.model.icon; font.family: Theme.iconFont; font.pixelSize: 16; color: Theme.text }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text { Layout.fillWidth: true; text: stNetRow.model.title; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true; color: Theme.text; elide: Text.ElideRight }
                                                Text { Layout.fillWidth: true; text: stNetRow.model.subtitle; font.family: Theme.fontFamily; font.pixelSize: 9; color: Theme.subtext; elide: Text.ElideRight }
                                            }

                                            Rectangle {
                                                implicitWidth: 70
                                                implicitHeight: 24
                                                radius: 12
                                                color: stNetRow.model.active ? Theme.badgeBgActive : Theme.glassCard
                                                border.color: Theme.glassBorder
                                                border.width: 1
                                                Behavior on color { ColorAnimation { duration: ShellState.animDur(180, 130) } }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: stNetRow.model.statusText
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    color: stNetRow.model.active ? Theme.badgeFgActive : Theme.text
                                                    Behavior on color { ColorAnimation { duration: ShellState.animDur(180, 130) } }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: stNetMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (stNetRow.model.itemType === "ethernet") {
                                                    root.stNetActionCmd = stNetRow.model.active ? "eth_off" : "eth_on";
                                                    root.stNetActionTarget = stNetRow.model.itemId;
                                                    root.stNetActionPassword = "";
                                                    stNetModel.setProperty(stNetRow.index, "statusText", "...");
                                                    stNetActionProc.running = false;
                                                    stNetActionProc.running = true;
                                                } else if (stNetRow.model.itemType === "wifi") {
                                                    root.stNetActionCmd = stNetRow.model.active ? "off" : "on";
                                                    root.stNetActionTarget = "";
                                                    root.stNetActionPassword = "";
                                                    stNetModel.setProperty(stNetRow.index, "statusText", "...");
                                                    stNetActionProc.running = false;
                                                    stNetActionProc.running = true;
                                                } else if (stNetRow.model.itemType === "ssid") {
                                                    if (stNetRow.model.active) {
                                                        root.stNetActionCmd = "disconnect";
                                                        root.stNetActionTarget = stNetRow.model.itemId;
                                                        root.stNetActionPassword = "";
                                                        stNetActionProc.running = false;
                                                        stNetActionProc.running = true;
                                                    } else if (!stNetRow.model.hasSecret) {
                                                        root.stWifiError = "";
                                                        root.stWifiPromptSsid = stNetRow.model.itemId;
                                                        stWifiPwInput.text = "";
                                                        stWifiPwInput.forceActiveFocus();
                                                    } else {
                                                        root.stNetActionCmd = "connect";
                                                        root.stNetActionTarget = stNetRow.model.itemId;
                                                        root.stNetActionPassword = "";
                                                        stNetModel.setProperty(stNetRow.index, "statusText", "...");
                                                        stNetActionProc.running = false;
                                                        stNetActionProc.running = true;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Right: Bluetooth
                        GlassPanelCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "󰂯"; font.family: Theme.iconFont; font.pixelSize: 14; color: Theme.text }
                                    Text { text: "Bluetooth"; font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true; color: Theme.text }
                                    Item { Layout.fillWidth: true }
                                    ActionPill {
                                        icon: "󰑐"
                                        label: "Scan"
                                        implicitHeight: 24
                                        onClicked: {
                                            root.runBtAction(["scan"]);
                                            stBtRefreshTimer.restart();
                                        }
                                    }
                                    ActionPill {
                                        icon: "󰒓"
                                        label: "Console"
                                        implicitHeight: 24
                                        onClicked: {
                                            ShellState.settingsOpen = false;
                                            ShellState.launchTerminal("bluetoothctl");
                                        }
                                    }
                                }

                                ListView {
                                    id: stBtList
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 6
                                    model: stBtModel
                                    boundsBehavior: Flickable.StopAtBounds

                                    property real scrollTargetY: 0
                                    Behavior on contentY { NumberAnimation { duration: 105; easing.type: Easing.OutCubic } }
                                    onContentHeightChanged: {
                                        const maxY = Math.max(0, contentHeight - height);
                                        if (scrollTargetY > maxY) scrollTargetY = maxY;
                                    }

                                    WheelHandler {
                                        target: null
                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                        onWheel: event => root.applyFastWheel(stBtList, event, 200)
                                    }

                                    delegate: Rectangle {
                                        id: stBtRow
                                        required property var model
                                        required property int index
                                        width: ListView.view.width
                                        height: 52
                                        radius: 12
                                        color: model.active ? Theme.glassSurfaceActive : (stBtMouse.containsMouse ? Theme.glassSurfaceHover : Theme.glassCard)
                                        border.color: model.active ? Theme.glassHighlight : Theme.glassBorder
                                        border.width: 1
                                        scale: stBtMouse.pressed ? 0.98 : 1.0
                                        Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 105); easing.type: ShellState.animPrimaryEase } }
                                        Behavior on color { ColorAnimation { duration: ShellState.animDur(170, 120) } }
                                        Behavior on border.color { ColorAnimation { duration: ShellState.animDur(170, 120) } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 10

                                            Text { text: stBtRow.model.icon; font.family: Theme.iconFont; font.pixelSize: 16; color: Theme.text }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text { Layout.fillWidth: true; text: stBtRow.model.title; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true; color: Theme.text; elide: Text.ElideRight }
                                                Text { Layout.fillWidth: true; text: stBtRow.model.subtitle; font.family: Theme.fontFamily; font.pixelSize: 9; color: Theme.subtext; elide: Text.ElideRight }
                                            }

                                            Rectangle {
                                                implicitWidth: 70
                                                implicitHeight: 24
                                                radius: 12
                                                color: stBtRow.model.active ? Theme.badgeBgActive : Theme.glassCard
                                                border.color: Theme.glassBorder
                                                border.width: 1
                                                Behavior on color { ColorAnimation { duration: ShellState.animDur(180, 130) } }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: stBtRow.model.statusText
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    color: stBtRow.model.active ? Theme.badgeFgActive : Theme.text
                                                    Behavior on color { ColorAnimation { duration: ShellState.animDur(180, 130) } }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: stBtMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (stBtRow.model.itemType === "adapter") {
                                                    root.runBtAction([stBtRow.model.active ? "off" : "on"]);
                                                } else {
                                                    root.runBtAction([stBtRow.model.active ? "disconnect" : "connect", stBtRow.model.itemId]);
                                                    stBtRefreshTimer.restart();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ================= PAGE 4: INPUT, KEYBOARD & APPS =================
                Item {
                    id: tab4Item
                    anchors.fill: parent
                    opacity: settingsCard.activeTab === 4 ? 1.0 : 0.0
                    visible: opacity > 0.005
                    enabled: settingsCard.activeTab === 4
                    Behavior on opacity { NumberAnimation { duration: ShellState.animDur(250, 170); easing.type: ShellState.animPrimaryEase } }
                    transform: Translate {
                        x: settingsCard.activeTab === 4 ? 0 : 18
                        Behavior on x { NumberAnimation { duration: ShellState.animDur(300, 210); easing.type: ShellState.animPrimaryEase } }
                    }

                    Flickable {
                        id: tab4Flick
                        anchors.fill: parent
                        clip: true
                        contentWidth: width
                        contentHeight: tab4Col.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        property real scrollTargetY: 0
                        Behavior on contentY { NumberAnimation { duration: 105; easing.type: Easing.OutCubic } }
                        onContentHeightChanged: {
                            const maxY = Math.max(0, contentHeight - height);
                            if (scrollTargetY > maxY) scrollTargetY = maxY;
                        }

                        WheelHandler {
                            target: null
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => root.applyFastWheel(tab4Flick, event, 210)
                        }

                        ColumnLayout {
                            id: tab4Col
                            width: parent.width
                            spacing: 10

                            // 1. Keyboard Layouts & Priority Stack
                            GlassPanelCard {
                                Layout.fillWidth: true
                                Layout.preferredHeight: kbStackCol.implicitHeight + 24

                                ColumnLayout {
                                    id: kbStackCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 12
                                    spacing: 9

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Text { text: "󰌌"; font.family: Theme.iconFont; font.pixelSize: 15; color: Theme.text }
                                        ColumnLayout {
                                            spacing: 1
                                            Text { text: "Keyboard Layouts"; font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true; color: Theme.text }
                                            Text { text: "Ordered by switch priority"; font.family: Theme.fontFamily; font.pixelSize: 10; color: Theme.subtext }
                                        }
                                        Item { Layout.fillWidth: true }
                                        Rectangle {
                                            Layout.preferredHeight: 22
                                            implicitWidth: activeKbLbl.implicitWidth + 14
                                            radius: 11
                                            color: Theme.glassSurfaceActive
                                            border.color: Theme.glassBorder
                                            border.width: 1
                                            Text {
                                                id: activeKbLbl
                                                anchors.centerIn: parent
                                                text: "Active: " + root.kbActiveName
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: Theme.text
                                            }
                                        }
                                        ActionPill {
                                            icon: "󰌌"
                                            label: "Switch Next"
                                            implicitHeight: 24
                                            onClicked: ShellState.nextKeyboardLayout()
                                        }
                                    }

                                    // Stacked Layout Slots
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            model: root.parsedKbSlots()
                                            delegate: Rectangle {
                                                id: kbSlotRow
                                                required property var modelData
                                                required property int index
                                                readonly property int totalSlots: root.parsedKbSlots().length
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 38
                                                radius: 10
                                                color: Theme.lightMode ? Qt.rgba(0.0, 0.0, 0.0, 0.035) : Qt.rgba(1.0, 1.0, 1.0, 0.04)
                                                border.color: Theme.glassBorder
                                                border.width: 1

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 8
                                                    anchors.rightMargin: 8
                                                    spacing: 7

                                                    Rectangle {
                                                        Layout.preferredWidth: 46
                                                        Layout.preferredHeight: 22
                                                        radius: 7
                                                        color: kbSlotRow.index === 0 ? Theme.badgeBgActive : Theme.glassCard
                                                        border.color: kbSlotRow.index === 0 ? Theme.badgeBgActive : Theme.glassBorder
                                                        border.width: 1
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: kbSlotRow.index === 0 ? "#1 Main" : ("#" + (kbSlotRow.index + 1))
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 9
                                                            font.bold: true
                                                            color: kbSlotRow.index === 0 ? Theme.badgeFgActive : Theme.subtext
                                                        }
                                                    }

                                                    GlassDropdown {
                                                        Layout.fillWidth: true
                                                        Layout.preferredWidth: 3
                                                        searchable: true
                                                        searchPlaceholder: "Search languages..."
                                                        fallbackText: kbSlotRow.modelData.layout
                                                        currentValue: kbSlotRow.modelData.layout
                                                        options: root.xkbLayouts
                                                        onActivated: value => {
                                                            const slots = root.parsedKbSlots();
                                                            if (kbSlotRow.index < slots.length) {
                                                                slots[kbSlotRow.index].layout = String(value);
                                                                slots[kbSlotRow.index].variant = "";
                                                                root.applyKbSlots(slots);
                                                            }
                                                        }
                                                    }

                                                    GlassDropdown {
                                                        Layout.fillWidth: true
                                                        Layout.preferredWidth: 2
                                                        searchable: true
                                                        searchPlaceholder: "Search variant..."
                                                        fallbackText: kbSlotRow.modelData.variant.length > 0 ? kbSlotRow.modelData.variant : "Default (Standard)"
                                                        currentValue: kbSlotRow.modelData.variant
                                                        options: root.variantsForLayout(kbSlotRow.modelData.layout)
                                                        onActivated: value => {
                                                            const slots = root.parsedKbSlots();
                                                            if (kbSlotRow.index < slots.length) {
                                                                slots[kbSlotRow.index].variant = String(value);
                                                                root.applyKbSlots(slots);
                                                            }
                                                        }
                                                    }

                                                    ActionPill {
                                                        icon: "󰅃"
                                                        implicitHeight: 26
                                                        implicitWidth: 26
                                                        visible: kbSlotRow.index > 0
                                                        onClicked: {
                                                            const slots = root.parsedKbSlots();
                                                            const i = kbSlotRow.index;
                                                            if (i > 0 && i < slots.length) {
                                                                const tmp = slots[i - 1];
                                                                slots[i - 1] = slots[i];
                                                                slots[i] = tmp;
                                                                root.applyKbSlots(slots);
                                                            }
                                                        }
                                                    }

                                                    ActionPill {
                                                        icon: "󰅀"
                                                        implicitHeight: 26
                                                        implicitWidth: 26
                                                        visible: kbSlotRow.index < (kbSlotRow.totalSlots - 1)
                                                        onClicked: {
                                                            const slots = root.parsedKbSlots();
                                                            const i = kbSlotRow.index;
                                                            if (i >= 0 && i + 1 < slots.length) {
                                                                const tmp = slots[i + 1];
                                                                slots[i + 1] = slots[i];
                                                                slots[i] = tmp;
                                                                root.applyKbSlots(slots);
                                                            }
                                                        }
                                                    }

                                                    ActionPill {
                                                        icon: "󰅖"
                                                        implicitHeight: 26
                                                        implicitWidth: 26
                                                        visible: kbSlotRow.totalSlots > 1
                                                        onClicked: {
                                                            const slots = root.parsedKbSlots();
                                                            if (slots.length > 1) {
                                                                slots.splice(kbSlotRow.index, 1);
                                                                root.applyKbSlots(slots);
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Add Layout to Stack Row
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: "Add Layout:"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            color: Theme.subtext
                                        }

                                        GlassDropdown {
                                            Layout.fillWidth: true
                                            searchable: true
                                            searchPlaceholder: "Search layouts..."
                                            fallbackText: "Choose language / layout..."
                                            currentValue: root.kbAddLayoutCode
                                            options: root.xkbLayouts
                                            onActivated: value => root.kbAddLayoutCode = String(value)
                                        }

                                        ActionPill {
                                            icon: "󰐕"
                                            label: "Add to Stack"
                                            active: true
                                            implicitHeight: 30
                                            onClicked: {
                                                const slots = root.parsedKbSlots();
                                                slots.push({ layout: root.kbAddLayoutCode || "us", variant: "" });
                                                root.applyKbSlots(slots);
                                            }
                                        }
                                    }

                                    // Quick Stack Presets
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Text {
                                            text: "Quick Stacks"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            color: Theme.subtext
                                        }
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            Repeater {
                                                model: [
                                                    { label: "US", lay: "us", varStr: "" },
                                                    { label: "UK", lay: "gb", varStr: "" },
                                                    { label: "UK + US", lay: "gb,us", varStr: "" },
                                                    { label: "UK + HU", lay: "gb,hu", varStr: "" },
                                                    { label: "US + HU", lay: "us,hu", varStr: "" },
                                                    { label: "US + DE", lay: "us,de", varStr: "" },
                                                    { label: "US + FR", lay: "us,fr", varStr: "" },
                                                    { label: "US Colemak-DH", lay: "us", varStr: "colemak_dh" },
                                                    { label: "US Dvorak", lay: "us", varStr: "dvorak" },
                                                    { label: "US Int'l", lay: "us", varStr: "intl" }
                                                ]
                                                delegate: ActionPill {
                                                    required property var modelData
                                                    label: modelData.label
                                                    implicitHeight: 24
                                                    active: root.kbLayoutInput === modelData.lay && root.kbVariantInput === modelData.varStr
                                                    onClicked: {
                                                        root.kbLayoutInput = modelData.lay;
                                                        root.kbVariantInput = modelData.varStr;
                                                        root.runSysSet(["set_keyboard", root.kbLayoutInput, root.kbVariantInput, root.kbOptionsInput]);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 2. XKB Switcher Shortcut, Modifier & Keymap Options
                            GlassPanelCard {
                                Layout.fillWidth: true
                                Layout.preferredHeight: kbOptsCol.implicitHeight + 24

                                ColumnLayout {
                                    id: kbOptsCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 12
                                    spacing: 10

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Text { text: "󰘳"; font.family: Theme.iconFont; font.pixelSize: 15; color: Theme.text }
                                        Text { text: "Shortcuts & Modifiers"; font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true; color: Theme.text }
                                    }

                                    // Row A: Switcher Hotkey + Caps Lock
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            spacing: 4
                                            Text { text: "Switch Shortcut"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                            GlassDropdown {
                                                searchable: true
                                                searchPlaceholder: "Search shortcut..."
                                                fallbackText: "Hyprland Bind Only (SUPER+Space)"
                                                currentValue: root.getKbOptionInGroup(["grp:"])
                                                options: [
                                                    { label: "Hyprland Bind Only (SUPER+Space)", value: "" },
                                                    { label: "Alt + Shift", value: "grp:alt_shift_toggle" },
                                                    { label: "Ctrl + Shift", value: "grp:ctrl_shift_toggle" },
                                                    { label: "Ctrl + Alt", value: "grp:ctrl_alt_toggle" },
                                                    { label: "Super + Space", value: "grp:win_space_toggle" },
                                                    { label: "Alt + Space", value: "grp:alt_space_toggle" },
                                                    { label: "Ctrl + Space", value: "grp:ctrl_space_toggle" },
                                                    { label: "Both Shifts", value: "grp:shifts_toggle" },
                                                    { label: "Both Alts", value: "grp:alts_toggle" },
                                                    { label: "Both Ctrls", value: "grp:ctrls_toggle" },
                                                    { label: "Caps Lock", value: "grp:caps_toggle" },
                                                    { label: "Shift + Caps Lock", value: "grp:shift_caps_toggle" },
                                                    { label: "Alt + Caps Lock", value: "grp:alt_caps_toggle" },
                                                    { label: "Right Alt", value: "grp:toggle" },
                                                    { label: "Left Alt", value: "grp:lalt_toggle" },
                                                    { label: "Left Super / Win", value: "grp:lwin_toggle" },
                                                    { label: "Right Super / Win", value: "grp:rwin_toggle" },
                                                    { label: "Menu Key", value: "grp:menu_toggle" },
                                                    { label: "Left Ctrl + Left Win", value: "grp:lctrl_lwin_toggle" },
                                                    { label: "Scroll Lock", value: "grp:sclk_toggle" }
                                                ]
                                                onActivated: value => root.setKbOptionGroup(["grp:"], null, String(value))
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            spacing: 4
                                            Text { text: "Caps Lock Key"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                            GlassDropdown {
                                                fallbackText: "Standard Caps Lock"
                                                currentValue: root.getKbOptionInGroup(["caps:"], ["ctrl:nocaps", "ctrl:swapcaps"])
                                                options: [
                                                    { label: "Standard Caps Lock", value: "" },
                                                    { label: "Acts as Escape", value: "caps:escape" },
                                                    { label: "Escape (Shift+Caps = Normal)", value: "caps:escape_shifted_capslock" },
                                                    { label: "Swap Caps Lock & Escape", value: "caps:swapescape" },
                                                    { label: "Acts as Ctrl", value: "ctrl:nocaps" },
                                                    { label: "Swap Caps Lock & Left Ctrl", value: "ctrl:swapcaps" },
                                                    { label: "Acts as Backspace", value: "caps:backspace" },
                                                    { label: "Acts as Super / Win", value: "caps:super" },
                                                    { label: "Acts as Menu", value: "caps:menu" },
                                                    { label: "Acts as Return", value: "caps:return" },
                                                    { label: "Disable Caps Lock", value: "caps:none" }
                                                ]
                                                onActivated: value => root.setKbOptionGroup(["caps:"], ["ctrl:nocaps", "ctrl:swapcaps"], String(value))
                                            }
                                        }
                                    }

                                    // Row B: Compose Key + Alt/Win Swaps
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            spacing: 4
                                            Text { text: "Compose Key"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                            GlassDropdown {
                                                fallbackText: "Disabled"
                                                currentValue: root.getKbOptionInGroup(["compose:"])
                                                options: [
                                                    { label: "Disabled", value: "" },
                                                    { label: "Right Alt", value: "compose:ralt" },
                                                    { label: "Right Ctrl", value: "compose:rctrl" },
                                                    { label: "Left Ctrl", value: "compose:lctrl" },
                                                    { label: "Right Super / Win", value: "compose:rwin" },
                                                    { label: "Left Super / Win", value: "compose:lwin" },
                                                    { label: "Menu Key", value: "compose:menu" },
                                                    { label: "Caps Lock", value: "compose:caps" },
                                                    { label: "< > Key (ISO)", value: "compose:102" }
                                                ]
                                                onActivated: value => root.setKbOptionGroup(["compose:"], null, String(value))
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            spacing: 4
                                            Text { text: "Alt & Super Keys"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                            GlassDropdown {
                                                fallbackText: "Standard PC Layout"
                                                currentValue: root.getKbOptionInGroup(["altwin:"])
                                                options: [
                                                    { label: "Standard PC Layout", value: "" },
                                                    { label: "Swap Left Alt & Left Super", value: "altwin:swap_lalt_lwin" },
                                                    { label: "Swap Right Alt & Right Super", value: "altwin:swap_ralt_rwin" },
                                                    { label: "Swap All Alt & Super", value: "altwin:swap_alt_win" },
                                                    { label: "Map Menu Key to Super", value: "altwin:menu_win" },
                                                    { label: "Map Ctrl to Super (Dual)", value: "altwin:ctrl_win" },
                                                    { label: "PrtSc as Right Super", value: "altwin:prtsc_rwin" },
                                                    { label: "Alt as Meta / Super swap", value: "altwin:alt_super_win" }
                                                ]
                                                onActivated: value => root.setKbOptionGroup(["altwin:"], null, String(value))
                                            }
                                        }
                                    }

                                    // Row C: Extra Modifier & Numpad Toggles
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Text {
                                            text: "Additional Options"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            color: Theme.subtext
                                        }
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            Repeater {
                                                model: [
                                                    { label: "3rd-Level RAlt", opt: "lv3:ralt_switch" },
                                                    { label: "Swap L-Alt & L-Ctrl", opt: "ctrl:swap_lalt_lctl" },
                                                    { label: "Swap R-Alt & R-Ctrl", opt: "ctrl:swap_ralt_rctl" },
                                                    { label: "macOS Numpad", opt: "numpad:mac" },
                                                    { label: "Windows Numpad", opt: "numpad:microsoft" }
                                                ]
                                                delegate: ActionPill {
                                                    required property var modelData
                                                    label: modelData.label
                                                    implicitHeight: 24
                                                    active: root.parsedKbOptionsList().indexOf(modelData.opt) !== -1
                                                    onClicked: root.toggleKbOption(modelData.opt)
                                                }
                                            }
                                        }
                                    }

                                    // Row D: Direct Raw XKB String Override (Power User)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: "Raw XKB:"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            color: Theme.textDim
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            Layout.preferredHeight: 26
                                            radius: 8
                                            color: Theme.glassSurfaceActive
                                            border.color: kbCustomIn.activeFocus ? Theme.accent : Theme.glassBorder
                                            border.width: 1
                                            TextInput {
                                                id: kbCustomIn
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                verticalAlignment: TextInput.AlignVCenter
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: Theme.text
                                                text: root.kbLayoutInput
                                                clip: true
                                                onEditingFinished: root.kbLayoutInput = text
                                                Keys.onReturnPressed: {
                                                    root.kbLayoutInput = text;
                                                    root.runSysSet(["set_keyboard", root.kbLayoutInput, root.kbVariantInput, root.kbOptionsInput]);
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            Layout.preferredHeight: 26
                                            radius: 8
                                            color: Theme.glassSurfaceActive
                                            border.color: kbVarIn.activeFocus ? Theme.accent : Theme.glassBorder
                                            border.width: 1
                                            TextInput {
                                                id: kbVarIn
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                verticalAlignment: TextInput.AlignVCenter
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: Theme.text
                                                text: root.kbVariantInput
                                                clip: true
                                                onEditingFinished: root.kbVariantInput = text
                                                Keys.onReturnPressed: {
                                                    root.kbVariantInput = text;
                                                    root.runSysSet(["set_keyboard", root.kbLayoutInput, root.kbVariantInput, root.kbOptionsInput]);
                                                }
                                            }
                                            Text {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "variant (e.g. ,intl)"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: Theme.textDim
                                                visible: !kbVarIn.activeFocus && kbVarIn.text.length === 0
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            Layout.preferredHeight: 26
                                            radius: 8
                                            color: Theme.glassSurfaceActive
                                            border.color: kbOptIn.activeFocus ? Theme.accent : Theme.glassBorder
                                            border.width: 1
                                            TextInput {
                                                id: kbOptIn
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                verticalAlignment: TextInput.AlignVCenter
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: Theme.text
                                                text: root.kbOptionsInput
                                                clip: true
                                                onEditingFinished: root.kbOptionsInput = text
                                                Keys.onReturnPressed: {
                                                    root.kbOptionsInput = text;
                                                    root.runSysSet(["set_keyboard", root.kbLayoutInput, root.kbVariantInput, root.kbOptionsInput]);
                                                }
                                            }
                                            Text {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "options"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: Theme.textDim
                                                visible: !kbOptIn.activeFocus && kbOptIn.text.length === 0
                                            }
                                        }

                                        ActionPill {
                                            icon: "󰄬"
                                            label: "Apply"
                                            implicitHeight: 26
                                            active: true
                                            onClicked: {
                                                root.kbLayoutInput = kbCustomIn.text;
                                                root.kbVariantInput = kbVarIn.text;
                                                root.kbOptionsInput = kbOptIn.text;
                                                root.runSysSet(["set_keyboard", root.kbLayoutInput, root.kbVariantInput, root.kbOptionsInput]);
                                            }
                                        }
                                    }
                                }
                            }

                            // Pointer & Touchpad
                            GlassPanelCard {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 62

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    Text { text: "󰍽"; font.family: Theme.iconFont; font.pixelSize: 15; color: Theme.text }
                                    Text { text: "Pointer Sensitivity"; font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true; color: Theme.text }

                                    RowLayout {
                                        spacing: 4
                                        Repeater {
                                            model: [-0.5, -0.25, 0.0, 0.25, 0.5]
                                            delegate: ActionPill {
                                                required property real modelData
                                                label: (modelData > 0 ? "+" : "") + modelData.toFixed(2).replace(".00", "")
                                                implicitHeight: 25
                                                active: Math.abs(root.inputSensitivity - modelData) < 0.05
                                                onClicked: {
                                                    root.inputSensitivity = modelData;
                                                    root.runSysSet(["set_input", String(modelData), String(root.inputNaturalScroll)]);
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    ActionPill {
                                        icon: "󰌗"
                                        label: root.inputNaturalScroll ? "Natural Scroll: On" : "Natural Scroll: Off"
                                        implicitHeight: 26
                                        active: root.inputNaturalScroll
                                        onClicked: {
                                            root.inputNaturalScroll = !root.inputNaturalScroll;
                                            root.runSysSet(["set_input", String(root.inputSensitivity), String(root.inputNaturalScroll)]);
                                        }
                                    }
                                }
                            }

                            // 4. Default Shell Applications
                            GlassPanelCard {
                                Layout.fillWidth: true
                                Layout.preferredHeight: defAppsCol.implicitHeight + 24

                                ColumnLayout {
                                    id: defAppsCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 12
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Text { text: "󰀻"; font.family: Theme.iconFont; font.pixelSize: 15; color: Theme.text }
                                        ColumnLayout {
                                            spacing: 1
                                            Text { text: "Default Applications"; font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true; color: Theme.text }
                                            Text { text: "Preferred applications across the desktop"; font.family: Theme.fontFamily; font.pixelSize: 10; color: Theme.subtext }
                                        }
                                    }

                                    DefaultAppSlot {
                                        icon: "󰉋"
                                        title: "File Manager"
                                        subtitle: "Default file browser"
                                        appCmd: ShellState.fileManagerApp
                                        showXdgFix: true
                                        options: [
                                            { label: "Thunar (thunar)", value: "thunar" },
                                            { label: "Dolphin (dolphin)", value: "dolphin" },
                                            { label: "Files / Nautilus (nautilus)", value: "nautilus" },
                                            { label: "Nemo (nemo)", value: "nemo" },
                                            { label: "PCManFM (pcmanfm)", value: "pcmanfm" },
                                            { label: "Yazi (terminal)", value: "yazi" }
                                        ]
                                        onAppChanged: newCmd => ShellState.fileManagerApp = newCmd
                                        onTestClicked: ShellState.openFolder(ShellState.userHome)
                                    }

                                    DefaultAppSlot {
                                        icon: "󰞷"
                                        title: "Terminal Emulator"
                                        subtitle: "Default terminal"
                                        appCmd: ShellState.terminalApp
                                        options: [
                                            { label: "Kitty (kitty)", value: "kitty" },
                                            { label: "Alacritty (alacritty)", value: "alacritty" },
                                            { label: "Foot (foot)", value: "foot" },
                                            { label: "WezTerm (wezterm)", value: "wezterm" },
                                            { label: "Ghostty (ghostty)", value: "ghostty" },
                                            { label: "Konsole (konsole)", value: "konsole" }
                                        ]
                                        onAppChanged: newCmd => ShellState.terminalApp = newCmd
                                        onTestClicked: ShellState.launchTerminal("")
                                    }

                                    DefaultAppSlot {
                                        icon: "󰈹"
                                        title: "Web Browser"
                                        subtitle: "Default web browser"
                                        appCmd: ShellState.browserApp
                                        options: [
                                            { label: "Firefox (firefox)", value: "firefox" },
                                            { label: "Zen Browser (zen-browser)", value: "zen-browser" },
                                            { label: "Chromium (chromium)", value: "chromium" },
                                            { label: "Brave (brave)", value: "brave" },
                                            { label: "LibreWolf (librewolf)", value: "librewolf" },
                                            { label: "Google Chrome (google-chrome-stable)", value: "google-chrome-stable" }
                                        ]
                                        onAppChanged: newCmd => ShellState.browserApp = newCmd
                                        onTestClicked: ShellState.launchDefaultApp(ShellState.browserApp)
                                    }

                                    DefaultAppSlot {
                                        icon: "󰨞"
                                        title: "Text Editor"
                                        subtitle: "Default code & text editor"
                                        appCmd: ShellState.editorApp
                                        options: [
                                            { label: "VSCodium (codium)", value: "codium" },
                                            { label: "VS Code (code)", value: "code" },
                                            { label: "Neovim (nvim)", value: "nvim" },
                                            { label: "Kate (kate)", value: "kate" },
                                            { label: "Zed (zeditor)", value: "zeditor" },
                                            { label: "GNOME Text Editor (gnome-text-editor)", value: "gnome-text-editor" }
                                        ]
                                        onAppChanged: newCmd => ShellState.editorApp = newCmd
                                        onTestClicked: ShellState.launchDefaultApp(ShellState.editorApp)
                                    }
                                }
                            }

                            // 5. Scratchpad Applications
                            ScratchpadCard {
                                spName: "music"
                                icon: "󰝚"
                                iconColor: "#63b3ed"
                                title: "Music Workspace"
                                hotkey: "SUPER + M"
                                defaultCmd: "spotify"
                                appCmd: ShellState.musicApp
                                presets: ["spotify", "cider", "amberol"]
                                onCommandChanged: newCmd => ShellState.musicApp = newCmd
                            }

                            ScratchpadCard {
                                spName: "comm"
                                icon: "󰭹"
                                iconColor: "#f6ad55"
                                title: "Communication Workspace"
                                hotkey: "SUPER + D"
                                defaultCmd: "discord"
                                appCmd: ShellState.commApp
                                presets: ["discord", "vesktop", "telegram-desktop"]
                                onCommandChanged: newCmd => ShellState.commApp = newCmd
                            }

                            ScratchpadCard {
                                spName: "sysmon"
                                icon: "󰍛"
                                iconColor: "#68d391"
                                title: "System Monitor"
                                hotkey: "Ctrl + Shift + Esc"
                                defaultCmd: "kitty -e btop"
                                appCmd: ShellState.sysmonApp
                                presets: ["kitty -e btop", "kitty -e htop", "mission-center"]
                                onCommandChanged: newCmd => ShellState.sysmonApp = newCmd
                            }

                            ScratchpadCard {
                                spName: "magic"
                                icon: "󰵉"
                                iconColor: Theme.accent
                                title: "Special Scratchpad"
                                hotkey: "SUPER + S"
                                defaultCmd: "kitty"
                                appCmd: ShellState.specialApp
                                presets: ["kitty", "alacritty", "foot"]
                                onCommandChanged: newCmd => ShellState.specialApp = newCmd
                            }
                        }
                    }
                }
            }

            // 4. Footer Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "󰆓  ChromaShell " + ShellState.version
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.subtext
                }

                Item { Layout.fillWidth: true }

                ActionPill {
                    icon: "󰑐"
                    label: "Reset Defaults"
                    implicitHeight: 28
                    onClicked: ShellState.resetSettingsToDefaults()
                }
            }
        }
    }
}
