#!/usr/bin/env python3
"""Real-time 5-band PipeWire/Pulse audio spectrum analyzer for ZaphShell."""

import array
import math
import signal
import subprocess
import sys

SAMPLE_RATE = 16000
CHUNK_SAMPLES = 512
CHUNK_BYTES = CHUNK_SAMPLES * 2
NORM_SCALE = 1.0 / (32768.0 * 110.0)
SILENCE_RMS = 0.00045

BAND_GROUPS = (
    ((60.0, 92.0, 130.0), 0.72),
    ((185.0, 260.0, 355.0), 1.18),
    ((500.0, 720.0, 1020.0), 1.95),
    ((1400.0, 1980.0, 2750.0), 3.05),
    ((3300.0, 4450.0, 5800.0), 4.45),
)

HANN_WINDOW = [
    0.5 * (1.0 - math.cos(2.0 * math.pi * i / (CHUNK_SAMPLES - 1)))
    for i in range(CHUNK_SAMPLES)
]

BAND_COEFFS = [
    ([2.0 * math.cos(2.0 * math.pi * (freq / SAMPLE_RATE)) for freq in freqs], weight)
    for freqs, weight in BAND_GROUPS
]


def goertzel_mag(samples: list[float], coeff: float) -> float:
    q1 = 0.0
    q2 = 0.0
    for x in samples:
        q0 = coeff * q1 - q2 + x
        q2 = q1
        q1 = q0
    power = q1 * q1 + q2 * q2 - coeff * q1 * q2
    return math.sqrt(power) if power > 0.0 else 0.0


def main() -> int:
    cmd = [
        "parec",
        "-d", "@DEFAULT_MONITOR@",
        "--raw",
        "--format=s16le",
        "--channels=1",
        "--rate=" + str(SAMPLE_RATE),
        "--latency-msec=25",
    ]
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        bufsize=CHUNK_BYTES,
    )

    def handle_signal(_signum: int, _frame: object) -> None:
        if proc.poll() is None:
            proc.terminate()
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)

    smooth = [0.0] * len(BAND_COEFFS)
    band_peaks = [0.035] * len(BAND_COEFFS)
    running_peak = 0.045
    sent_zero = False

    try:
        stdout = proc.stdout
        if stdout is None:
            return 1

        while True:
            buf = stdout.read(CHUNK_BYTES)
            if not buf or len(buf) < CHUNK_BYTES:
                break

            pcm = array.array("h")
            pcm.frombytes(buf)

            sq_sum = 0.0
            windowed = [0.0] * CHUNK_SAMPLES
            for i in range(CHUNK_SAMPLES):
                v = pcm[i]
                sq_sum += v * v
                windowed[i] = (v * NORM_SCALE) * HANN_WINDOW[i]

            rms = math.sqrt(sq_sum / CHUNK_SAMPLES) / 32768.0

            if rms < SILENCE_RMS:
                any_nonzero = False
                for b in range(len(smooth)):
                    smooth[b] *= 0.78
                    if smooth[b] < 0.004:
                        smooth[b] = 0.0
                    else:
                        any_nonzero = True
                running_peak = max(0.045, running_peak * 0.985)
                for b in range(len(band_peaks)):
                    band_peaks[b] = max(0.025, band_peaks[b] * 0.988)
                if any_nonzero or not sent_zero:
                    sys.stdout.write(
                        f"{smooth[0]:.3f} {smooth[1]:.3f} {smooth[2]:.3f} {smooth[3]:.3f} {smooth[4]:.3f}\n"
                    )
                    sys.stdout.flush()
                    sent_zero = not any_nonzero
                continue

            raw_bands = [0.0] * len(BAND_COEFFS)
            frame_peak = 0.0
            for b, (coeffs, weight) in enumerate(BAND_COEFFS):
                peak_bin = 0.0
                for coeff in coeffs:
                    mag = goertzel_mag(windowed, coeff)
                    if mag > peak_bin:
                        peak_bin = mag
                val = peak_bin * weight
                raw_bands[b] = val
                if val > frame_peak:
                    frame_peak = val

            running_peak = max(frame_peak, running_peak * 0.986, 0.045)

            for b in range(len(smooth)):
                band_peaks[b] = max(raw_bands[b], band_peaks[b] * 0.992, 0.025)
                denom = 0.48 * running_peak + 0.52 * band_peaks[b]
                norm = min(1.0, max(0.0, raw_bands[b] / max(0.025, denom)))
                target = math.pow(norm, 0.72)
                rate = 0.64 if target > smooth[b] else 0.22
                smooth[b] += (target - smooth[b]) * rate

            sent_zero = False
            sys.stdout.write(
                f"{smooth[0]:.3f} {smooth[1]:.3f} {smooth[2]:.3f} {smooth[3]:.3f} {smooth[4]:.3f}\n"
            )
            sys.stdout.flush()
    except (BrokenPipeError, SystemExit):
        pass
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=1.0)
            except subprocess.TimeoutExpired:
                proc.kill()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
