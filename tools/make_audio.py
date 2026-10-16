"""Synthesised sounds for the fights, written to assets/audio/*.wav (22050 Hz,
16-bit mono). No samples are used: everything is sine, noise and envelopes.
`reveal.wav` is the sting for an anomaly's entrance, `cry_<kind>.wav` the
call that follows it, `uncanny.wav` the short static hit for the uncanny."""
import math
import os
import random
import struct
import wave

RATE = 22050


def write(name, samples):
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", name)
    with wave.open(out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32000)) for s in samples))


def env(t, a, d, total):
    if t < a:
        return t / a
    if t > total - d:
        return max(0.0, (total - t) / d)
    return 1.0


def reveal():
    total = 3.2
    out = []
    rnd = random.Random(1)
    for i in range(int(RATE * total)):
        t = i / RATE
        # a low drone that swells, with a fifth above it
        drone = math.sin(2 * math.pi * 55 * t) * 0.5 + math.sin(2 * math.pi * 82.4 * t) * 0.25
        drone *= env(t, 1.2, 1.0, total)
        # a rising shimmer that lands at the moment of the reveal (t = 1.6)
        f = 300 + 900 * min(1.0, t / 1.6) ** 2
        shimmer = math.sin(2 * math.pi * f * t) * 0.18 * (1.0 if t < 1.6 else max(0.0, 1.0 - (t - 1.6) * 2))
        # a hit at the reveal
        hit = 0.0
        if t >= 1.6:
            k = t - 1.6
            hit = (math.sin(2 * math.pi * 48 * k) + (rnd.random() * 2 - 1) * 0.3) * math.exp(-k * 5) * 0.8
        out.append(drone + shimmer + hit)
    return out


def cry(kind):
    """A short call: a frequency sweep with a tremor, different per kind."""
    rnd = random.Random(hash(kind) & 0xFFFF)
    total = 0.9
    out = []
    if kind == "anomaly":
        f0, f1, trem, noise = 160, 70, 18, 0.25
    elif kind == "animal":
        f0, f1, trem, noise = 420, 260, 30, 0.15
    else:
        f0, f1, trem, noise = 900, 1400, 50, 0.5
    for i in range(int(RATE * total)):
        t = i / RATE
        f = f0 + (f1 - f0) * (t / total)
        v = math.sin(2 * math.pi * f * t + 2.0 * math.sin(2 * math.pi * trem * t))
        v = v * (1 - noise) + (rnd.random() * 2 - 1) * noise
        out.append(v * env(t, 0.05, 0.3, total) * 0.6)
    return out


def uncanny():
    rnd = random.Random(5)
    total = 0.5
    out = []
    for i in range(int(RATE * total)):
        t = i / RATE
        v = (rnd.random() * 2 - 1) * 0.5 + math.sin(2 * math.pi * 1200 * t) * 0.15
        out.append(v * env(t, 0.01, 0.35, total))
    return out


if __name__ == "__main__":
    write("reveal.wav", reveal())
    write("uncanny.wav", uncanny())
    for k in ("anomaly", "animal", "uncanny"):
        write("cry_%s.wav" % k, cry(k))
    print("audio written")
