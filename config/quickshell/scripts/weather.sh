#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${HOME}/.cache/quickshell"
CACHE_FILE="${CACHE_DIR}/weather.json"
FORCE="${1:-}"
mkdir -p "$CACHE_DIR"

python3 - "$CACHE_FILE" "$FORCE" <<'PY'
import sys, os, json, time, urllib.request

cache_file = sys.argv[1]
force = len(sys.argv) > 2 and sys.argv[2] == "--force"

WMO_MAP = {
    0: ("󰖙", "Clear Sky"),
    1: ("󰖕", "Mostly Clear"),
    2: ("󰖕", "Partly Cloudy"),
    3: ("󰖐", "Cloudy"),
    45: ("󰖑", "Foggy"),
    48: ("󰖑", "Rime Fog"),
    51: ("󰼳", "Light Drizzle"),
    53: ("󰼳", "Drizzle"),
    55: ("󰖗", "Heavy Drizzle"),
    61: ("󰖗", "Light Rain"),
    63: ("󰖗", "Rain"),
    65: ("󰖖", "Heavy Rain"),
    71: ("󰖘", "Light Snow"),
    73: ("󰖘", "Snow"),
    75: ("󰼶", "Heavy Snow"),
    77: ("󰖘", "Snow Grains"),
    80: ("󰼳", "Rain Showers"),
    81: ("󰖗", "Mod. Showers"),
    82: ("󰖖", "Heavy Showers"),
    85: ("󰖘", "Snow Showers"),
    86: ("󰼶", "Heavy Snow"),
    95: ("󰖓", "Thunderstorm"),
    96: ("󰙾", "T-Storm & Hail"),
    99: ("󰙾", "Heavy T-Storm"),
}

WMO_NIGHT_OVERRIDE = {
    0: ("󰖔", "Clear Night"),
    1: ("󰖔", "Mostly Clear"),
    2: ("󰼱", "Partly Cloudy"),
}

def map_wmo(code, is_day=True):
    if not is_day and code in WMO_NIGHT_OVERRIDE:
        return WMO_NIGHT_OVERRIDE[code]
    return WMO_MAP.get(code, ("󰼱", "Partly Cloudy") if not is_day else ("󰖕", "Partly Cloudy"))

DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

def fetch_json(url, timeout=4.0):
    req = urllib.request.Request(url, headers={"User-Agent": "Quickshell-Weather/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))

try:
    if not force and os.path.isfile(cache_file) and (time.time() - os.path.getmtime(cache_file)) < 600:
        with open(cache_file, "r", encoding="utf-8") as f:
            data = json.load(f)
            if "isDay" in data and "hourly" in data and len(data.get("forecast", [])) > 0 and "date" in data["forecast"][0]:
                print(json.dumps(data))
                sys.exit(0)

    lat, lon, city = None, None, "Local"
    try:
        geo = fetch_json("https://ipwho.is/", timeout=2.5)
        if geo and geo.get("success", True) and "latitude" in geo and "longitude" in geo:
            lat = float(geo["latitude"])
            lon = float(geo["longitude"])
            city = str(geo.get("city") or city)
    except Exception:
        pass

    if lat is None or lon is None:
        raise RuntimeError("Location lookup unavailable")

    url = (
        f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
        "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,is_day"
        "&hourly=temperature_2m,weather_code,is_day"
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
        "&timezone=auto&forecast_days=5"
    )
    raw = fetch_json(url, timeout=4.0)
    cur = raw.get("current", {})
    hourly_raw = raw.get("hourly", {})
    daily = raw.get("daily", {})

    local_hour = time.localtime().tm_hour
    is_day = bool(cur.get("is_day", 1 if 6 <= local_hour < 20 else 0))
    code = int(cur.get("weather_code", 0))
    icon, desc = map_wmo(code, is_day)
    temp = round(float(cur.get("temperature_2m", 18)))
    feels = round(float(cur.get("apparent_temperature", temp)))
    hum = round(float(cur.get("relative_humidity_2m", 55)))
    wind = round(float(cur.get("wind_speed_10m", 10)))

    # Build 5-slot hourly forecast starting at current local hour
    h_times = hourly_raw.get("time", [])
    h_temps = hourly_raw.get("temperature_2m", [])
    h_codes = hourly_raw.get("weather_code", [])
    h_is_day = hourly_raw.get("is_day", [])
    now_prefix = time.strftime("%Y-%m-%dT%H:")
    start_idx = 0
    for idx, t_str in enumerate(h_times):
        if t_str.startswith(now_prefix):
            start_idx = idx
            break

    hourly = []
    for k in range(5):
        idx = start_idx + k
        if idx < len(h_times):
            t_part = h_times[idx].split("T")[-1][:5] if "T" in h_times[idx] else f"{(time.localtime().tm_hour + k) % 24:02d}:00"
            h_label = "Now" if k == 0 else t_part
            h_temp = temp if k == 0 else round(float(h_temps[idx]))
            h_code = code if k == 0 else int(h_codes[idx])
            slot_is_day = is_day if k == 0 else (bool(h_is_day[idx]) if idx < len(h_is_day) else (6 <= ((local_hour + k) % 24) < 20))
            h_icon, h_desc = map_wmo(h_code, slot_is_day)
            hourly.append({
                "time": h_label,
                "icon": h_icon,
                "desc": h_desc,
                "temp": f"{h_temp}°"
            })
        else:
            hr = (time.localtime().tm_hour + k) % 24
            hourly.append({
                "time": "Now" if k == 0 else f"{hr:02d}:00",
                "icon": icon,
                "desc": desc,
                "temp": f"{temp}°"
            })

    d_times = daily.get("time", [])
    d_codes = daily.get("weather_code", [])
    d_max = daily.get("temperature_2m_max", [])
    d_min = daily.get("temperature_2m_min", [])
    d_pop = daily.get("precipitation_probability_max", [])

    forecast = []
    for i in range(min(5, len(d_times))):
        try:
            tm = time.strptime(d_times[i], "%Y-%m-%d")
            day_name = "Today" if i == 0 else DAYS[tm.tm_wday]
            date_str = f"{tm.tm_mday:02d}/{tm.tm_mon:02d}"
        except Exception:
            day_name = f"Day {i+1}"
            date_str = ""
        fc_code = int(d_codes[i]) if i < len(d_codes) else 0
        fc_icon, fc_desc = WMO_MAP.get(fc_code, ("󰖕", "Cloudy"))
        hi = round(float(d_max[i])) if i < len(d_max) else temp + 3
        lo = round(float(d_min[i])) if i < len(d_min) else temp - 3
        pop = round(float(d_pop[i])) if i < len(d_pop) and d_pop[i] is not None else 0
        forecast.append({
            "day": day_name,
            "date": date_str,
            "icon": fc_icon,
            "desc": fc_desc,
            "high": f"{hi}°",
            "low": f"{lo}°",
            "highNum": hi,
            "lowNum": lo,
            "pop": pop
        })

    hi_today = forecast[0]["high"] if forecast else f"{temp+3}°"
    lo_today = forecast[0]["low"] if forecast else f"{temp-3}°"

    out = {
        "city": city,
        "temp": f"{temp}°C",
        "tempShort": f"{temp}°",
        "feelsLike": f"{feels}°C",
        "humidity": f"{hum}%",
        "wind": f"{wind} km/h",
        "icon": icon,
        "desc": desc,
        "isDay": is_day,
        "high": hi_today,
        "low": lo_today,
        "hourly": hourly,
        "forecast": forecast
    }
    with open(cache_file, "w", encoding="utf-8") as f:
        json.dump(out, f)
    print(json.dumps(out))
except Exception:
    if os.path.isfile(cache_file):
        with open(cache_file, "r", encoding="utf-8") as f:
            print(f.read().strip())
    else:
        now_tm = time.localtime()
        fallback_hourly = [
            {
                "time": "Now" if k == 0 else f"{(now_tm.tm_hour + k) % 24:02d}:00",
                "icon": "󰖐",
                "desc": "Offline",
                "temp": "--°"
            }
            for k in range(5)
        ]
        fallback_forecast = []
        for i in range(5):
            tm = time.localtime(time.time() + i * 86400)
            fallback_forecast.append({
                "day": "Today" if i == 0 else DAYS[tm.tm_wday],
                "date": f"{tm.tm_mday:02d}/{tm.tm_mon:02d}",
                "icon": "󰖐",
                "desc": "Offline",
                "high": "--°",
                "low": "--°",
                "highNum": 20,
                "lowNum": 10,
                "pop": 0
            })
        fallback = {
            "city": "Offline",
            "temp": "--°C",
            "tempShort": "--°",
            "feelsLike": "--°C",
            "humidity": "--%",
            "wind": "-- km/h",
            "icon": "󰖐",
            "desc": "Offline",
            "isDay": 6 <= now_tm.tm_hour < 20,
            "high": "--°",
            "low": "--°",
            "hourly": fallback_hourly,
            "forecast": fallback_forecast
        }
        print(json.dumps(fallback))
PY
