#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${HOME}/.cache/quickshell/show-desktop.json"

python3 - "$STATE_FILE" <<'PY'
import sys, os, json, subprocess

state_file = sys.argv[1]
os.makedirs(os.path.dirname(state_file), exist_ok=True)

USE_LUA = os.path.isfile(os.path.expanduser("~/.config/hypr/hyprland.lua"))

def hypr_json(args):
    try:
        out = subprocess.check_output(["hyprctl", *args, "-j"], stderr=subprocess.DEVNULL)
        return json.loads(out)
    except Exception:
        return None

def run_batch(calls):
    for lua_expr, std_args in calls:
        primary = [lua_expr] if USE_LUA else std_args
        fallback = std_args if USE_LUA else [lua_expr]
        res = subprocess.run(["hyprctl", "dispatch", *primary], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if res.returncode != 0:
            subprocess.run(["hyprctl", "dispatch", *fallback], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

monitors = hypr_json(["monitors"]) or []
active_monitors = [m for m in monitors if not m.get("disabled")]

screen_ws_ids = []
seen_ws = set()
focused_mon_name = ""
focused_ws_id = None
open_specials = []

for m in active_monitors:
    is_focused = bool(m.get("focused"))
    mon_name = m.get("name", "") or ""
    ws_id = m.get("activeWorkspace", {}).get("id")
    if isinstance(ws_id, int) and ws_id > 0:
        if ws_id not in seen_ws:
            seen_ws.add(ws_id)
            screen_ws_ids.append(ws_id)
        if is_focused:
            focused_ws_id = ws_id
    if is_focused:
        focused_mon_name = mon_name
    sw_name = m.get("specialWorkspace", {}).get("name", "") or ""
    if sw_name.startswith("special:"):
        open_specials.append((mon_name, is_focused, sw_name[len("special:"):]))

if not screen_ws_ids:
    active_ws = hypr_json(["activeworkspace"])
    if active_ws and isinstance(active_ws.get("id"), int) and active_ws["id"] > 0:
        screen_ws_ids.append(active_ws["id"])
        focused_ws_id = active_ws["id"]

if not screen_ws_ids:
    sys.exit(0)

clients = hypr_json(["clients"]) or []
active_win = hypr_json(["activewindow"]) or {}
active_addr = active_win.get("address", "")

screen_ws_set = set(screen_ws_ids)
visible_by_ws = {}
for c in clients:
    addr = c.get("address")
    ws_id = c.get("workspace", {}).get("id")
    if c.get("mapped") and addr and ws_id in screen_ws_set:
        visible_by_ws.setdefault(ws_id, []).append(addr)

try:
    with open(state_file, "r") as f:
        state = json.load(f)
    if not isinstance(state, dict):
        state = {}
except Exception:
    state = {}

special_desktop_addrs = {
    c["address"]
    for c in clients
    if c.get("workspace", {}).get("name") == "special:desktop" and c.get("address")
}

def prune_stale_state(st, skip_keys=()):
    removed = False
    for k in list(st.keys()):
        if k in skip_keys:
            continue
        entry = st.get(k)
        if not isinstance(entry, dict):
            del st[k]
            removed = True
            continue
        alive = [a for a in entry.get("windows", []) if a in special_desktop_addrs]
        if not alive:
            del st[k]
            removed = True
        elif len(alive) != len(entry.get("windows", [])):
            entry["windows"] = alive
            if entry.get("active") not in alive:
                entry["active"] = ""
            removed = True
    return removed

if visible_by_ws or open_specials:
    # Hide every visible window across all active screens into special:desktop
    touched_keys = set()
    for ws_id, addrs in visible_by_ws.items():
        ws_key = str(ws_id)
        touched_keys.add(ws_key)
        prev_entry = state.get(ws_key, {}) if isinstance(state.get(ws_key), dict) else {}
        prev_addrs = [a for a in prev_entry.get("windows", []) if a in special_desktop_addrs]
        combined = prev_addrs + [a for a in addrs if a not in prev_addrs]
        prev_active = prev_entry.get("active", "")
        state[ws_key] = {
            "windows": combined,
            "active": active_addr if active_addr in addrs else (prev_active if prev_active in combined else ""),
        }

    prune_stale_state(state, skip_keys=touched_keys)
    with open(state_file, "w") as f:
        json.dump(state, f)

    calls = []
    # Close open special workspaces across all monitors while preserving focus
    for _mon_name, is_focused, sp_name in open_specials:
        if is_focused:
            calls.append((f"hl.dsp.workspace.toggle_special('{sp_name}')", ["togglespecialworkspace", sp_name]))

    switched_monitor = False
    for mon_name, is_focused, sp_name in open_specials:
        if not is_focused and mon_name:
            calls.append((f"hl.dsp.focus({{ monitor = '{mon_name}' }})", ["focusmonitor", mon_name]))
            calls.append((f"hl.dsp.workspace.toggle_special('{sp_name}')", ["togglespecialworkspace", sp_name]))
            switched_monitor = True
    if switched_monitor and focused_mon_name:
        calls.append((f"hl.dsp.focus({{ monitor = '{focused_mon_name}' }})", ["focusmonitor", focused_mon_name]))

    for addrs in visible_by_ws.values():
        for addr in addrs:
            calls.append((
                f"hl.dsp.window.move({{ workspace = 'special:desktop', window = 'address:{addr}', follow = false }})",
                ["movetoworkspacesilent", f"special:desktop,address:{addr}"]
            ))
    run_batch(calls)
else:
    # Restore previously hidden windows back to each monitor's active workspace
    calls = []
    focus_candidate = ""
    fallback_focus = ""
    state_changed = False

    for ws_id in screen_ws_ids:
        ws_key = str(ws_id)
        entry = state.get(ws_key, {})
        if not isinstance(entry, dict):
            entry = {}
        to_restore = [a for a in entry.get("windows", []) if a in special_desktop_addrs]
        saved_active = entry.get("active", "")

        for addr in to_restore:
            calls.append((
                f"hl.dsp.window.move({{ workspace = {ws_id}, window = 'address:{addr}', follow = false }})",
                ["movetoworkspacesilent", f"{ws_id},address:{addr}"]
            ))

        if saved_active and saved_active in to_restore:
            if ws_id == focused_ws_id:
                focus_candidate = saved_active
            elif not fallback_focus:
                fallback_focus = saved_active

        if ws_key in state:
            del state[ws_key]
            state_changed = True

    restore_focus = focus_candidate or fallback_focus
    if restore_focus:
        calls.append((f"hl.dsp.focus({{ window = 'address:{restore_focus}' }})", ["focuswindow", f"address:{restore_focus}"]))

    if calls:
        run_batch(calls)

    if prune_stale_state(state) or state_changed:
        with open(state_file, "w") as f:
            json.dump(state, f)
PY
