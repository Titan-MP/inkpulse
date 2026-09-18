#!/usr/bin/env python3
"""Generates a placeholder AppIcon (1024x1024 PNG) for Inkpulse: a glowing
blue ring on a deep-reef gradient. Pure stdlib, no dependencies."""
import math, struct, zlib

W = H = 1024

def lerp(a, b, t):
    return a + (b - a) * t

def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

TOP = hexrgb("#0E4A66")
BOT = hexrgb("#052033")
RING = hexrgb("#28C8FF")
RING2 = hexrgb("#8CE8FF")

rings = [
    # (cx, cy, radius, thickness, color, strength)
    (512, 470, 300, 64, RING, 1.0),
    (300, 760, 120, 30, RING2, 0.7),
    (740, 780, 90, 24, RING2, 0.7),
    (790, 250, 70, 20, RING2, 0.6),
]

def pixel(x, y):
    t = y / (H - 1)
    r = lerp(TOP[0], BOT[0], t)
    g = lerp(TOP[1], BOT[1], t)
    b = lerp(TOP[2], BOT[2], t)
    glow = 0.0
    for cx, cy, rad, th, col, s in rings:
        d = math.hypot(x - cx, y - cy)
        band = abs(d - rad)
        # bright core + soft glow falloff
        core = max(0.0, 1.0 - band / (th * 0.5))
        halo = max(0.0, 1.0 - band / (th * 3.0)) ** 2 * 0.5
        k = min(1.0, core + halo) * s
        if k > 0:
            r = lerp(r, col[0], k)
            g = lerp(g, col[1], k)
            b = lerp(b, col[2], k)
            glow = max(glow, k)
    return int(r), int(g), int(b)

raw = bytearray()
for y in range(H):
    raw.append(0)  # filter type 0
    for x in range(W):
        r, g, b = pixel(x, y)
        raw += struct.pack("BBB", r, g, b)

def chunk(typ, data):
    c = struct.pack(">I", len(data)) + typ + data
    c += struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF)
    return c

png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(bytes(raw), 6))
png += chunk(b"IEND", b"")

out = "/home/hatch/workspace/bluering/BlueRing/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
with open(out, "wb") as f:
    f.write(png)
print("wrote", out, len(png), "bytes")
