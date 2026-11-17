#!/usr/bin/env bash
set -euo pipefail

NAME="${1:-magic}"
STATE_FILE="${HOME}/.cache/quickshell/state.json"

python3 - "$NAME" "$STATE_FILE" <<'PY'
import sys, os, json, subprocess

name = sys.argv[1].lower() if len(sys.argv) > 1 else "magic"
state_file = sys.argv[2] if len(sys.argv) > 2 else ""

# Default commands & class patterns
defaults = {
    "music": {"cmd": "spotify", "class": "spotify"},
    "comm": {"cmd": "discord", "class": "discord"},
    "sysmon": {"cmd": "kitty -e btop", "class": "kitty"},
    "magic": {"cmd": "kitty", "class": "kitty"}
}

cmd = defaults.get(name, {}).get("cmd", "kitty")
app_class = defaults.get(name, {}).get("class", name)

# Override from state.json if present
if state_file and os.path.isfile(state_file):
    try:
        with open(state_file, "r") as f:
            st = json.load(f)
            custom_cmd = st.get(f"{name}App", "").strip()
            if not custom_cmd and name == "magic":
                custom_cmd = st.get("specialApp", "").strip()
            if custom_cmd:
                cmd = custom_cmd
                app_class = custom_cmd.split()[0].split("/")[-1].lower()
    except Exception:
        pass

target_ws = f"special:{name}"
use_lua = os.path.isfile(os.path.expanduser("~/.config/hypr/hyprland.lua"))

def hypr_dispatch(lua_expr, std_args):
    primary = [lua_expr] if use_lua else std_args
    fallback = std_args if use_lua else [lua_expr]
    res = subprocess.run(["hyprctl", "dispatch", *primary], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if res.returncode != 0:
        subprocess.run(["hyprctl", "dispatch", *fallback], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# Query monitors
try:
    monitors = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], stderr=subprocess.DEVNULL))
except Exception:
    monitors = []

focused_mon = next((m for m in monitors if m.get("focused")), None)
is_currently_open = False
if focused_mon:
    sw = focused_mon.get("specialWorkspace", {})
    if sw.get("name") == target_ws:
        is_currently_open = True

# If already open on focused monitor, hide it
if is_currently_open:
    hypr_dispatch(f"hl.dsp.workspace.toggle_special('{name}')", ["togglespecialworkspace", name])
    sys.exit(0)

# Query clients
try:
    clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"], stderr=subprocess.DEVNULL))
except Exception:
    clients = []

# Check if client exists in special workspace
client_in_sp = next((c for c in clients if c.get("workspace", {}).get("name") == target_ws), None)

if client_in_sp:
    # Client is already in special workspace, just toggle it open on focused monitor
    hypr_dispatch(f"hl.dsp.workspace.toggle_special('{name}')", ["togglespecialworkspace", name])
    sys.exit(0)

# Check if client is running elsewhere on a normal workspace
client_running = next((c for c in clients if app_class in c.get("class", "").lower() or app_class in c.get("initialClass", "").lower()), None)

if client_running:
    addr = client_running.get("address", "")
    if addr:
        # Move client to special workspace silently
        hypr_dispatch(
            f"hl.dsp.window.move({{ workspace = '{target_ws}', window = 'address:{addr}', silent = true }})",
            ["movetoworkspacesilent", f"{target_ws},address:{addr}"]
        )
    # Bring up special workspace
    hypr_dispatch(f"hl.dsp.workspace.toggle_special('{name}')", ["togglespecialworkspace", name])
    sys.exit(0)

# Not running: toggle into special workspace and spawn the app
hypr_dispatch(f"hl.dsp.workspace.toggle_special('{name}')", ["togglespecialworkspace", name])
safe_cmd = cmd.replace("'", "\\'")
hypr_dispatch(f"hl.dsp.exec_cmd('{safe_cmd}')", ["exec", cmd])

PY
