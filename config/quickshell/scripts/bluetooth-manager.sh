#!/usr/bin/env python3
import subprocess
import json
import sys
import time


def get_bt_rfkill_blocked():
    try:
        out = subprocess.check_output(["rfkill", "-J"], text=True, stderr=subprocess.DEVNULL, timeout=1.5)
        data = json.loads(out)
        devs = data.get("rfkilldevices", [])
        bt_devs = [d for d in devs if d.get("type") == "bluetooth"]
        if not bt_devs:
            return False
        return all(d.get("soft") == "blocked" or d.get("hard") == "blocked" for d in bt_devs)
    except Exception:
        return False


def is_bt_powered():
    if get_bt_rfkill_blocked():
        return False
    try:
        show_out = subprocess.check_output(["bluetoothctl", "show"], text=True, stderr=subprocess.DEVNULL, timeout=1.5)
        return "Powered: yes" in show_out
    except Exception:
        return False


def set_bt_power(enable):
    if enable:
        subprocess.run(["rfkill", "unblock", "bluetooth"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2.0)
        time.sleep(0.25)
        res = subprocess.run(["bluetoothctl", "power", "on"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2.5)
        if res.returncode != 0:
            time.sleep(0.35)
            subprocess.run(["bluetoothctl", "power", "on"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2.5)
    else:
        subprocess.run(["bluetoothctl", "power", "off"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2.5)
        subprocess.run(["rfkill", "block", "bluetooth"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2.0)
        time.sleep(0.15)


def get_bluetooth():
    items = []
    blocked = get_bt_rfkill_blocked()
    powered = False
    try:
        show_out = subprocess.check_output(["bluetoothctl", "show"], text=True, stderr=subprocess.DEVNULL, timeout=1.5)
        powered = (not blocked) and ("Powered: yes" in show_out)
        items.append({
            "id": "adapter",
            "title": "Bluetooth Controller",
            "subtitle": "Powered On • Ready to pair" if powered else "Powered Off",
            "icon": "󰂯" if powered else "󰂲",
            "status": "On" if powered else "Off",
            "active": powered,
            "type": "adapter",
        })
    except Exception:
        powered = not blocked
        items.append({
            "id": "adapter",
            "title": "Bluetooth Controller",
            "subtitle": "Powered On" if powered else "Powered Off",
            "icon": "󰂯" if powered else "󰂲",
            "status": "On" if powered else "Off",
            "active": powered,
            "type": "adapter",
        })

    if powered:
        try:
            dev_out = subprocess.check_output(["bluetoothctl", "devices"], text=True, stderr=subprocess.DEVNULL, timeout=1.5)
            conn_out = subprocess.check_output(["bluetoothctl", "devices", "Connected"], text=True, stderr=subprocess.DEVNULL, timeout=1.5)
            conn_macs = set()
            for line in conn_out.splitlines():
                parts = line.split(" ", 2)
                if len(parts) >= 2:
                    conn_macs.add(parts[1].strip())

            for line in dev_out.splitlines():
                parts = line.split(" ", 2)
                if len(parts) >= 3 and parts[0] == "Device":
                    mac = parts[1].strip()
                    name = parts[2].strip()
                    is_conn = (mac in conn_macs)
                    items.append({
                        "id": mac,
                        "title": name,
                        "subtitle": f"Connected • {mac}" if is_conn else f"Paired / Available • {mac}",
                        "icon": "󰂱" if is_conn else "󰂯",
                        "status": "Disconnect" if is_conn else "Connect",
                        "active": is_conn,
                        "type": "device",
                    })
        except Exception:
            pass

    print(json.dumps(items))


if __name__ == "__main__":
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == "on":
            set_bt_power(True)
        elif cmd == "off":
            set_bt_power(False)
        elif cmd == "toggle":
            set_bt_power(not is_bt_powered())
        elif cmd == "connect" and len(sys.argv) > 2:
            mac = sys.argv[2]
            if not is_bt_powered():
                set_bt_power(True)
            subprocess.Popen(["bluetoothctl", "connect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif cmd == "disconnect" and len(sys.argv) > 2:
            mac = sys.argv[2]
            subprocess.Popen(["bluetoothctl", "disconnect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif cmd == "scan":
            if not is_bt_powered():
                set_bt_power(True)
            subprocess.Popen(["bash", "-c", "bluetoothctl --timeout 5 scan on >/dev/null 2>&1"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    get_bluetooth()
