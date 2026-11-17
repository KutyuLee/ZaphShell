#!/usr/bin/env bash
# Extracts a clean, vibrant pastel/accent hex color from an album art URL or file path
set -euo pipefail

ART_URL="${1:-}"
if [[ -z "$ART_URL" ]]; then
    echo "#F4F4F6"
    exit 0
fi

# Strip file:// prefix if local path
INPUT_PATH="${ART_URL#file://}"

python3 - "$INPUT_PATH" <<'PY'
import subprocess, sys, colorsys

src = sys.argv[1]
try:
    raw = subprocess.check_output(
        ["ffmpeg", "-v", "quiet", "-i", src, "-vf", "scale=12:12", "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        timeout=2.5
    )
except Exception:
    print("#F4F4F6")
    sys.exit(0)

if not raw or len(raw) < 3:
    print("#F4F4F6")
    sys.exit(0)

best_r, best_g, best_b = 0.95, 0.95, 0.96
best_score = -1.0
sum_r = sum_g = sum_b = weight_total = 0.0

for i in range(0, len(raw) - 2, 3):
    r, g, b = raw[i] / 255.0, raw[i+1] / 255.0, raw[i+2] / 255.0
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    # Prefer saturated, non-black, non-white pixels
    mid_l = 1.0 - abs(l - 0.52) * 1.6
    if mid_l < 0.05:
        continue
    w = (s ** 1.4) * mid_l + 0.05
    if w > best_score:
        best_score = w
        best_r, best_g, best_b = r, g, b

h, l, s = colorsys.rgb_to_hls(best_r, best_g, best_b)
if s < 0.12:
    # Monochrome / grayscale album art -> crisp silver-white
    print("#F4F4F6")
else:
    # Ensure clean, luminous legibility on dark glass
    s = min(0.92, max(0.55, s * 1.15))
    l = min(0.78, max(0.64, l))
    rr, gg, bb = colorsys.hls_to_rgb(h, l, s)
    print(f"#{int(rr*255):02X}{int(gg*255):02X}{int(bb*255):02X}")
PY
