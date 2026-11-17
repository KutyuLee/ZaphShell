#!/usr/bin/env python3
import subprocess
import json
import sys
import time


def nm_running():
    try:
        res = subprocess.run(
            ["nmcli", "-t", "-f", "RUNNING", "general"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=1.5,
        )
        return res.returncode == 0 and "running" in res.stdout.lower()
    except Exception:
        return False


def get_nm_dev_states():
    states = {}
    try:
        out = subprocess.check_output(
            ["nmcli", "-t", "-f", "DEVICE,STATE,CONNECTION", "dev", "status"],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=1.5,
        )
        for line in out.splitlines():
            parts = line.split(":", 2)
            if len(parts) >= 2:
                states[parts[0].strip()] = {
                    "state": parts[1].strip().lower(),
                    "connection": parts[2].strip() if len(parts) > 2 else "",
                }
    except Exception:
        pass
    return states


def get_saved_wifi_profiles():
    """Map SSID -> {name, has_secret} for saved 802-11-wireless NetworkManager profiles."""
    profiles = {}
    try:
        out = subprocess.check_output(
            ["nmcli", "-t", "-f", "NAME,TYPE", "con", "show"],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=1.5,
        )
        for line in out.splitlines():
            parts = line.split(":", 1)
            if len(parts) != 2:
                continue
            name, ctype = parts[0].strip(), parts[1].strip()
            if ctype != "802-11-wireless" or not name:
                continue
            try:
                details = subprocess.check_output(
                    ["nmcli", "-s", "-g", "802-11-wireless.ssid,802-11-wireless-security.key-mgmt,802-11-wireless-security.psk", "con", "show", name],
                    text=True,
                    stderr=subprocess.DEVNULL,
                    timeout=1.5,
                ).splitlines()
                ssid = details[0].strip() if len(details) > 0 else name
                key_mgmt = details[1].strip() if len(details) > 1 else ""
                psk = details[2].strip() if len(details) > 2 else ""
                has_secret = (key_mgmt in ("", "none")) or (bool(psk) and psk != "--")
                if ssid and (ssid not in profiles or has_secret):
                    profiles[ssid] = {"name": name, "has_secret": has_secret}
            except Exception:
                pass
    except Exception:
        pass
    return profiles


def get_wifi_rfkill_blocked():
    try:
        out = subprocess.check_output(["rfkill", "-J"], text=True, stderr=subprocess.DEVNULL, timeout=1.5)
        data = json.loads(out)
        devs = data.get("rfkilldevices", [])
        wlan_devs = [d for d in devs if d.get("type") == "wlan"]
        if not wlan_devs:
            return False
        return all(d.get("soft") == "blocked" or d.get("hard") == "blocked" for d in wlan_devs)
    except Exception:
        return False


def set_wifi_radio(enable):
    state = "on" if enable else "off"
    if nm_running():
        res = subprocess.run(
            ["nmcli", "radio", "wifi", state],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=3.0,
        )
        if res.returncode == 0:
            time.sleep(0.25)
            return

    action = "unblock" if enable else "block"
    subprocess.run(["rfkill", action, "wifi"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2.0)
    time.sleep(0.2)


def set_ethernet_state(iface, enable):
    if not iface:
        return ""
    if nm_running():
        cmd = ["nmcli", "dev", "connect" if enable else "disconnect", iface]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=8.0)
        time.sleep(0.25)
        if res.returncode != 0:
            return (res.stderr or res.stdout or "Failed to change Ethernet state").strip()
        return ""
    action = "up" if enable else "down"
    res = subprocess.run(["pkexec", "networkctl", action, iface], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=15.0)
    time.sleep(0.25)
    if res.returncode != 0:
        return "Permission denied (enable NetworkManager for passwordless toggle)"
    return ""


def connect_wifi(ssid, password=""):
    if not ssid:
        return ("", False)
    if not nm_running():
        return ("NetworkManager is not running", False)

    saved = get_saved_wifi_profiles()
    existing = saved.get(ssid)

    if password:
        # Remove broken/secretless profile with same name so nmcli writes the new password cleanly
        if existing and not existing["has_secret"]:
            subprocess.run(["nmcli", "con", "delete", existing["name"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3.0)
        cmd = ["nmcli", "dev", "wifi", "connect", ssid, "password", password]
    elif existing and existing["has_secret"]:
        cmd = ["nmcli", "con", "up", existing["name"]]
    else:
        cmd = ["nmcli", "dev", "wifi", "connect", ssid]

    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=18.0)
    if res.returncode != 0:
        err = (res.stderr or res.stdout or "Connection failed").strip()
        err_low = err.lower()
        needs_pw = ("secret" in err_low or "password" in err_low or "psk" in err_low or "key" in err_low or "802-11-wireless-security" in err_low)
        # Clean up empty secretless profile created by failed attempt without password
        if needs_pw and not password:
            refreshed = get_saved_wifi_profiles().get(ssid)
            if refreshed and not refreshed["has_secret"]:
                subprocess.run(["nmcli", "con", "delete", refreshed["name"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3.0)
        return (err, needs_pw)
    time.sleep(0.25)
    return ("", False)


def disconnect_wifi_dev():
    if not nm_running():
        return ""
    states = get_nm_dev_states()
    for dev, info in states.items():
        if dev.startswith("wl") and info["state"] in ("connected", "connecting"):
            subprocess.run(["nmcli", "dev", "disconnect", dev], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5.0)
            time.sleep(0.2)
    return ""


def get_networks(error_msg="", needs_pw_ssid=""):
    items = []
    has_nm = nm_running()
    nm_states = get_nm_dev_states() if has_nm else {}
    saved_wifi = get_saved_wifi_profiles() if has_nm else {}
    wifi_blocked = get_wifi_rfkill_blocked()

    try:
        out = subprocess.check_output(["ip", "-j", "addr"], text=True, stderr=subprocess.DEVNULL, timeout=1.5)
        ifaces = json.loads(out)
        for iface in ifaces:
            name = iface.get("ifname", "")
            if name == "lo":
                continue
            oper = iface.get("operstate", "DOWN").upper()
            flags = iface.get("flags", [])
            is_up = ("UP" in flags) and (oper in ("UP", "UNKNOWN"))

            ipv4 = ""
            for a in iface.get("addr_info", []):
                if a.get("family") == "inet":
                    ipv4 = a.get("local", "")
                    break

            if name.startswith("en") or name.startswith("eth"):
                nm_info = nm_states.get(name, {})
                nm_state = nm_info.get("state", "")
                if has_nm and nm_state:
                    eth_active = nm_state in ("connected", "connecting")
                    if nm_state == "connected":
                        subtitle = f"Connected • {ipv4}" if ipv4 else "Connected"
                    elif nm_state == "connecting":
                        subtitle = "Connecting..."
                    elif nm_state == "unavailable":
                        subtitle = "Cable Unplugged"
                    else:
                        subtitle = "Disconnected"
                else:
                    eth_active = bool(ipv4)
                    subtitle = f"Connected • {ipv4}" if ipv4 else ("Link Up (Unmanaged)" if is_up else "Disconnected / Down")

                items.append({
                    "id": name,
                    "title": f"Wired Ethernet ({name})",
                    "subtitle": subtitle,
                    "icon": "󰌗",
                    "status": "Disable" if eth_active else "Enable",
                    "active": eth_active,
                    "type": "ethernet",
                    "security": "",
                    "hasSecret": True,
                })
            elif name.startswith("wl"):
                radio_on = not wifi_blocked
                nm_info = nm_states.get(name, {})
                nm_conn = nm_info.get("connection", "")
                if not radio_on:
                    subtitle = "Radio Off"
                    status = "Enable"
                    icon = "󰤭"
                elif ipv4:
                    subtitle = f"{nm_conn + ' • ' if nm_conn else 'Connected • '}{ipv4}"
                    status = "Disable"
                    icon = "󰤨"
                elif not has_nm:
                    subtitle = "NetworkManager inactive (no Wi-Fi service)"
                    status = "Disable"
                    icon = "󰤯"
                else:
                    subtitle = "Enabled • Disconnected" if "UP" in flags else "Enabled • Standby"
                    status = "Disable"
                    icon = "󰤯"

                items.append({
                    "id": name,
                    "title": f"Wi-Fi Adapter ({name})",
                    "subtitle": subtitle,
                    "icon": icon,
                    "status": status,
                    "active": radio_on,
                    "type": "wifi",
                    "security": "",
                    "hasSecret": True,
                })
    except Exception:
        pass

    if has_nm and not wifi_blocked:
        try:
            nm_out = subprocess.check_output(
                ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "no"],
                text=True,
                stderr=subprocess.DEVNULL,
                timeout=2.0,
            )
            seen = set()
            for line in nm_out.splitlines():
                parts = line.split(":")
                if len(parts) >= 4:
                    in_use = (parts[0].strip() == "*")
                    ssid = parts[1].strip()
                    sig = parts[2].strip()
                    sec = parts[3].strip() or "Open"
                    if not ssid or ssid in seen:
                        continue
                    seen.add(ssid)
                    is_open = (sec.lower() in ("open", "--", ""))
                    prof = saved_wifi.get(ssid)
                    has_secret = is_open or bool(prof and prof.get("has_secret"))
                    items.append({
                        "id": ssid,
                        "title": ssid,
                        "subtitle": f"{sec} • Signal {sig}%" + (" • Saved" if (prof and prof.get("has_secret") and not in_use) else ""),
                        "icon": "󰤨",
                        "status": "Disconnect" if in_use else "Connect",
                        "active": in_use,
                        "type": "ssid",
                        "security": sec,
                        "hasSecret": has_secret,
                    })
        except Exception:
            pass

    print(json.dumps({
        "items": items,
        "error": error_msg,
        "needsPasswordSsid": needs_pw_ssid,
    }))


if __name__ == "__main__":
    err_msg = ""
    pw_ssid = ""
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == "on":
            set_wifi_radio(True)
        elif cmd == "off":
            set_wifi_radio(False)
        elif cmd == "toggle":
            set_wifi_radio(get_wifi_rfkill_blocked())
        elif cmd == "eth_on" and len(sys.argv) > 2:
            err_msg = set_ethernet_state(sys.argv[2], True)
        elif cmd == "eth_off" and len(sys.argv) > 2:
            err_msg = set_ethernet_state(sys.argv[2], False)
        elif cmd == "rescan" and nm_running():
            subprocess.run(["nmcli", "dev", "wifi", "rescan"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4.0)
        elif cmd == "connect" and len(sys.argv) > 2:
            target_ssid = sys.argv[2]
            pw = sys.argv[3] if len(sys.argv) > 3 else ""
            err_msg, needs_pw = connect_wifi(target_ssid, pw)
            if needs_pw:
                pw_ssid = target_ssid
        elif cmd == "disconnect":
            err_msg = disconnect_wifi_dev()
    get_networks(err_msg, pw_ssid)
