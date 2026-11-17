#!/usr/bin/env python3
import sys
import subprocess
import json

def get_sinks():
    try:
        out = subprocess.check_output(["pactl", "-f", "json", "list", "sinks"], text=True, stderr=subprocess.DEVNULL)
        default_sink = subprocess.check_output(["pactl", "get-default-sink"], text=True, stderr=subprocess.DEVNULL).strip()
        sinks = json.loads(out)
        result = []
        for s in sinks:
            name = s.get("name", "")
            desc = s.get("description", "")
            props = s.get("properties", {})
            nick = props.get("node.nick", "") or props.get("alsa.name", "")
            
            # Clean human-readable title & subtitle
            title = desc
            subtitle = "Audio Output"
            icon = "󰓃"
            
            low_desc = (desc + " " + name + " " + nick).lower()
            if "headset" in low_desc or "g733" in low_desc:
                icon = "󰋎"
                if "g733" in low_desc:
                    title = "G733 Gaming Headset"
                    subtitle = "Wireless / USB Headset"
                else:
                    subtitle = "Headset Output"
            elif "headphone" in low_desc:
                icon = "󰋋"
                subtitle = "Headphones Output"
            elif "hdmi" in low_desc or "displayport" in low_desc:
                icon = "󰍹"
                if nick and nick != "USB Audio":
                    title = f"{nick} (HDMI)"
                subtitle = "Monitor / HDMI Audio"
            elif "spdif" in low_desc or "s/pdif" in low_desc or "iec958" in low_desc:
                icon = "󰤽"
                subtitle = "Digital Optical (S/PDIF)"
            elif "speaker" in low_desc:
                icon = "󰓃"
                subtitle = "Desktop Speakers"

            vol_dict = s.get("volume", {})
            vol_pct = "100%"
            for k, v in vol_dict.items():
                if isinstance(v, dict) and "value_percent" in v:
                    vol_pct = v["value_percent"].strip()
                    break

            is_default = (name == default_sink)
            result.append({
                "id": int(s.get("index", 0)),
                "name": name,
                "title": title,
                "subtitle": f"{subtitle} • {vol_pct}",
                "icon": icon,
                "active": is_default
            })
        # Sort so active is first, or keep stable hardware order
        print(json.dumps(result))
    except Exception as e:
        print("[]")

def set_sink(target_name, target_id=""):
    try:
        if target_name:
            subprocess.run(["pactl", "set-default-sink", target_name], stderr=subprocess.DEVNULL)
            # Also move all active streams to the new sink immediately
            inputs_out = subprocess.check_output(["pactl", "list", "short", "sink-inputs"], text=True, stderr=subprocess.DEVNULL)
            for line in inputs_out.splitlines():
                parts = line.split()
                if parts:
                    subprocess.run(["pactl", "move-sink-input", parts[0], target_name], stderr=subprocess.DEVNULL)
        if target_id:
            subprocess.run(["wpctl", "set-default", str(target_id)], stderr=subprocess.DEVNULL)
    except Exception:
        pass

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "set":
        name_arg = sys.argv[2] if len(sys.argv) > 2 else ""
        id_arg = sys.argv[3] if len(sys.argv) > 3 else ""
        set_sink(name_arg, id_arg)
        get_sinks()
    else:
        get_sinks()
