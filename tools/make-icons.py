#!/usr/bin/env python3
"""Generate TimeBridge PWA icons (pure stdlib — no dependencies).

Draws the app mark: a clock whose ring is split orange (Denver) / green
(Lagos), hands pointing at 9 and 4 — i.e. 9 AM Denver = 4 PM Lagos.

Usage: python3 tools/make-icons.py
"""
import math
import struct
import zlib
from pathlib import Path

BG = (0x17, 0x14, 0x12, 255)
RING_BASE = (0x3B, 0x34, 0x2E, 255)
ORANGE = (0xF9, 0x73, 0x16, 255)
GREEN = (0x4A, 0xDE, 0x80, 255)
WHITE = (0xFA, 0xF7, 0xF5, 255)
TRANSPARENT = (0, 0, 0, 0)

SS = 3  # supersampling factor per axis


def dist_segment(px, py, ax, ay, bx, by):
    abx, aby = bx - ax, by - ay
    apx, apy = px - ax, py - ay
    denom = abx * abx + aby * aby
    t = 0.0 if denom == 0 else max(0.0, min(1.0, (apx * abx + apy * aby) / denom))
    dx, dy = px - (ax + abx * t), py - (ay + aby * t)
    return math.hypot(dx, dy)


def rounded_rect_inside(px, py, size, radius):
    x = min(px, size - px)
    y = min(py, size - py)
    if x < 0 or y < 0:
        return False
    if x >= radius or y >= radius:
        return True
    return math.hypot(radius - x, radius - y) <= radius


def hand_tip(cx, cy, length, clock_hour):
    ang = math.radians(clock_hour * 30.0)
    return cx + length * math.sin(ang), cy - length * math.cos(ang)


def sample(px, py, size, full_bleed):
    s = size
    scale = 0.80 if full_bleed else 1.0  # keep art inside the maskable safe zone
    cx = cy = s / 2.0
    r_ring = 0.30 * s * scale
    w_ring = 0.075 * s * scale
    w_hand = 0.050 * s * scale
    gap = 0.022 * s * scale

    if full_bleed:
        color = BG
    else:
        if not rounded_rect_inside(px, py, s, 0.22 * s):
            return TRANSPARENT
        color = BG

    dx, dy = px - cx, py - cy
    d_center = math.hypot(dx, dy)

    # split ring: orange left half, green right half, small gaps top/bottom
    if abs(d_center - r_ring) <= w_ring / 2.0:
        if abs(dx) < gap:
            color = RING_BASE
        elif dx < 0:
            color = ORANGE
        else:
            color = GREEN

    # hands: 9 o'clock (into the orange half) and 4 o'clock (into the green half)
    for hour, length in ((9, 0.195 * s * scale), (4, 0.185 * s * scale)):
        tx, ty = hand_tip(cx, cy, length, hour)
        if dist_segment(px, py, cx, cy, tx, ty) <= w_hand / 2.0:
            color = WHITE

    if d_center <= 0.042 * s * scale:
        color = WHITE

    return color


def render(size, full_bleed):
    rows = []
    step = 1.0 / SS
    for y in range(size):
        row = bytearray()
        for x in range(size):
            r = g = b = a = 0
            for sy in range(SS):
                for sx in range(SS):
                    c = sample(x + (sx + 0.5) * step, y + (sy + 0.5) * step, size, full_bleed)
                    r += c[0] * c[3]
                    g += c[1] * c[3]
                    b += c[2] * c[3]
                    a += c[3]
            n = SS * SS
            if a == 0:
                row += bytes((0, 0, 0, 0))
            else:
                row += bytes((round(r / a), round(g / a), round(b / a), round(a / n)))
        rows.append(bytes(row))
    return rows


def write_png(path, size, rows):
    def chunk(tag, data):
        payload = tag + data
        return struct.pack('>I', len(data)) + payload + struct.pack('>I', zlib.crc32(payload))

    raw = b''.join(b'\x00' + row for row in rows)
    png = (
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(raw, 9))
        + chunk(b'IEND', b'')
    )
    path.write_bytes(png)
    print(f'wrote {path} ({size}x{size})')


def main():
    out = Path(__file__).resolve().parent.parent / 'icons'
    out.mkdir(exist_ok=True)
    for name, size, full_bleed in (
        ('icon-192.png', 192, False),
        ('icon-512.png', 512, False),
        ('maskable-512.png', 512, True),
        ('apple-touch-icon.png', 180, True),
    ):
        write_png(out / name, size, render(size, full_bleed))


if __name__ == '__main__':
    main()
