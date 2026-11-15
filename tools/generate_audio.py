import math
import random
import struct
import wave
from pathlib import Path


OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RATE = 22050
random.seed(811)


def write_wave(name, duration, sample_fn):
    frames = bytearray()
    count = int(RATE * duration)
    for i in range(count):
        t = i / RATE
        value = max(-1.0, min(1.0, sample_fn(t, duration)))
        frames.extend(struct.pack("<h", int(value * 32767)))
    with wave.open(str(OUT / name), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(frames)


def envelope(t, duration, attack=0.005, release=0.12):
    return min(1.0, t / attack) * max(0.0, 1.0 - t / duration) ** (1 / max(0.05, release))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    write_wave(
        "kick.wav", 0.22,
        lambda t, d: envelope(t, d, release=0.10)
        * (0.55 * math.sin(2 * math.pi * (110 - 42 * t / d) * t)
           + 0.24 * random.uniform(-1, 1)),
    )
    write_wave(
        "bounce.wav", 0.18,
        lambda t, d: envelope(t, d, release=0.08)
        * (0.60 * math.sin(2 * math.pi * (210 - 100 * t / d) * t)
           + 0.12 * math.sin(2 * math.pi * 430 * t)),
    )
    write_wave(
        "goal_whistle.wav", 0.75,
        lambda t, d: envelope(t, d, attack=0.03, release=0.32)
        * (0.38 * math.sin(2 * math.pi * 960 * t)
           + 0.24 * math.sin(2 * math.pi * 1270 * t)
           + 0.16 * math.sin(2 * math.pi * 1510 * t)),
    )
    write_wave(
        "card_select.wav", 0.12,
        lambda t, d: envelope(t, d, attack=0.008, release=0.07)
        * (0.38 * math.sin(2 * math.pi * (620 + 440 * t / d) * t)),
    )
    write_wave(
        "undo.wav", 0.24,
        lambda t, d: envelope(t, d, attack=0.01, release=0.13)
        * (0.42 * math.sin(2 * math.pi * (760 - 330 * t / d) * t)),
    )
    print(f"Generated five synthesized WAV effects in {OUT}")


if __name__ == "__main__":
    main()
