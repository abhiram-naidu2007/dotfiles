#!/usr/bin/env python3
"""Wallpapers drawn from mathematics, in the desktop's own colour system.

  mathart.py KIND OUT.png [--seed N] [--mode night|day|paper] [--size WxH] [--caption]

  attractor     Clifford strange attractor: where 19 million iterates of a 2-D map land
  harmonograph  two damped pendulums drawing one curve
  julia         Julia set of z -> z^2 + c, coloured by escape time
  sacks         Sacks spiral: the integer n at angle and radius sqrt(n), primes inked
  rose          Maurer rose: a rose curve r = sin(n t), sampled every d degrees

The seed picks the parameters and two hues, so each seed is a different picture
and, once `rice` reads the hues back from it, a different desktop theme.
Colours come from theme/apply.py (OKLCH), so they sit at the same lightness and
chroma as the rest of the palette. Needs numpy, Pillow and pycairo.
"""
import argparse, math, subprocess, sys
from pathlib import Path

import cairo
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "theme"))
from apply import MOODS, oklch  # noqa: E402


class Ink:
    """Background, two stroke colours and a caption colour for one mood and two hues."""

    def __init__(self, mode, hue1, hue2):
        m = MOODS[mode]
        self.dark = mode == "night"
        base_hue = 85 if mode == "paper" else hue1
        self.bg = oklch(m["layers"][2], m["tint"], base_hue)
        self.deep = oklch(m["layers"][0], m["tint"], base_hue)
        chroma = 0.07 if mode == "paper" else 0.13
        light = (0.80, 0.74) if self.dark else (0.46, 0.50)
        self.a = oklch(light[0], chroma, hue1)
        self.b = oklch(light[1], chroma, hue2)
        self.peak = oklch(0.96, 0.03, hue1) if self.dark else oklch(0.22, 0.04, hue1)
        self.caption = oklch(m["dim"][0], 0.02, base_hue)

    def ramp(self, n=1024):
        """n x 3 lookup table: background -> a -> b -> peak (for density and escape-time plots)."""
        stops = np.array([self.bg, self.a, self.b, self.peak])
        at = np.array([0.0, 0.38, 0.72, 1.0])
        t = np.linspace(0, 1, n)
        return np.stack([np.interp(t, at, stops[:, k]) for k in range(3)], axis=1)


def to_image(rgb):
    return Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")


def cairo_canvas(w, h, ink):
    surface = cairo.ImageSurface(cairo.FORMAT_RGB24, w, h)
    ctx = cairo.Context(surface)
    # soft vignette: background in the middle, the deeper layer at the corners
    grad = cairo.RadialGradient(w / 2, h / 2, 0, w / 2, h / 2, math.hypot(w, h) / 2)
    grad.add_color_stop_rgb(0, *ink.bg)
    grad.add_color_stop_rgb(1, *ink.deep)
    ctx.set_source(grad)
    ctx.paint()
    return surface, ctx


def cairo_image(surface):
    w, h = surface.get_width(), surface.get_height()
    return Image.frombuffer("RGBA", (w, h), bytes(surface.get_data()), "raw", "BGRA", surface.get_stride()).convert("RGB")


# ----------------------------------------------------------------- pictures

def attractor(rng, w, h, ink):
    """Clifford attractor: x' = sin(a y) + c cos(a x), y' = sin(b x) + d cos(b y)."""
    def step(x, y, p):
        a, b, c, d = p
        return np.sin(a * y) + c * np.cos(a * x), np.sin(b * x) + d * np.cos(b * y)

    # Most parameter choices collapse to a few points; keep one that fills the plane.
    while True:
        p = rng.uniform(-2.4, 2.4, 4)
        x, y = rng.uniform(-1, 1, (2, 4000))
        for _ in range(60):
            x, y = step(x, y, p)
        cells = np.unique(np.floor(x * 20).astype(int) * 1000 + np.floor(y * 20).astype(int)).size
        if cells > 1500:
            break
    n, rounds = 400_000, 48
    x, y = rng.uniform(-1, 1, (2, n))
    for _ in range(30):
        x, y = step(x, y, p)
    reach = 1 + max(abs(p[2]), abs(p[3]))            # |x|, |y| <= 1 + |c|, 1 + |d|
    scale = min(w, h) * 0.46 / reach
    count = np.zeros(w * h)
    speed = np.zeros(w * h)
    for _ in range(rounds):
        nx, ny = step(x, y, p)
        ix = (w / 2 + nx * scale).astype(np.int64)
        iy = (h / 2 + ny * scale).astype(np.int64)
        ok = (ix >= 0) & (ix < w) & (iy >= 0) & (iy < h)
        cell = iy[ok] * w + ix[ok]
        count += np.bincount(cell, minlength=w * h)
        speed += np.bincount(cell, weights=np.hypot(nx - x, ny - y)[ok], minlength=w * h)
        x, y = nx, ny
    density = np.log1p(count)
    density /= density.max()
    # brightness = how often a pixel is visited; colour = how fast the orbit crosses it
    pace = np.divide(speed, count, out=np.zeros_like(speed), where=count > 0)
    pace = (pace - pace[count > 0].min()) / (np.ptp(pace[count > 0]) + 1e-9)
    a, b, peak, bg = (np.array(c) for c in (ink.a, ink.b, ink.peak, ink.bg))
    colour = a + (b - a) * pace[:, None]
    colour = colour + (peak - colour) * (density[:, None] ** 3)
    rgb = bg + (colour - bg) * (density[:, None] ** 0.55)
    return to_image(rgb.reshape(h, w, 3)), "Clifford attractor   a=%.3f  b=%.3f  c=%.3f  d=%.3f" % tuple(p)


def harmonograph(rng, w, h, ink):
    """x(t), y(t): each the sum of two decaying sines with nearly rational frequencies."""
    ratio = [(2, 3), (3, 4), (1, 2), (3, 5), (4, 5), (2, 5), (5, 6)][rng.integers(7)]
    f = np.array([ratio[0], ratio[1], ratio[0], ratio[1]], float) + rng.normal(0, 0.004, 4)
    phase = rng.uniform(0, 2 * math.pi, 4)
    damp = rng.uniform(0.004, 0.012, 4)
    t = np.linspace(0, 260, 90_000)
    x = np.sin(f[0] * t + phase[0]) * np.exp(-damp[0] * t) + np.sin(f[1] * t + phase[1]) * np.exp(-damp[1] * t)
    y = np.sin(f[2] * t + phase[2]) * np.exp(-damp[2] * t) + np.sin(f[3] * t + phase[3]) * np.exp(-damp[3] * t)
    surface, ctx = cairo_canvas(w, h, ink)
    scale = min(w, h) * 0.22
    px, py = w / 2 + x * scale, h / 2 + y * scale
    ctx.set_line_width(max(1.0, w / 1600))
    ctx.set_line_join(cairo.LINE_JOIN_ROUND)
    chunk = 300
    for i in range(0, len(t) - chunk, chunk):
        k = i / len(t)
        ctx.set_source_rgba(*(ink.a[j] + (ink.b[j] - ink.a[j]) * k for j in range(3)), 0.55)
        ctx.move_to(px[i], py[i])
        for j in range(i + 1, i + chunk + 1):
            ctx.line_to(px[j], py[j])
        ctx.stroke()
    return cairo_image(surface), "harmonograph   %d : %d   detuned %+.4f, %+.4f" % (ratio[0], ratio[1], f[0] - ratio[0], f[1] - ratio[1])


def julia(rng, w, h, ink):
    """Escape time of z -> z^2 + c, smoothed with the usual log-log term."""
    seeds = [(-0.8, 0.156), (-0.4, 0.6), (0.285, 0.01), (-0.70176, -0.3842), (-0.835, -0.2321), (0.355, 0.355),
             (-0.7269, 0.1889), (-0.123, 0.745), (-0.75, 0.11), (0.37, 0.1), (-0.1, 0.651)]
    c = complex(*seeds[rng.integers(len(seeds))]) + complex(*rng.normal(0, 0.004, 2))
    span = 1.55
    xs = np.linspace(-span * w / h, span * w / h, w)
    ys = np.linspace(-span, span, h)
    z = xs[None, :] + 1j * ys[:, None]
    smooth = np.zeros(z.shape)
    alive = np.ones(z.shape, bool)
    limit = 220
    for i in range(limit):
        z[alive] = z[alive] ** 2 + c
        out = alive & (np.abs(z) > 16)
        smooth[out] = i + 1 - np.log2(np.log(np.abs(z[out])))
        alive &= ~out
    # stretch between the far field (most of the picture, stays background) and the slowest escapes
    escaped = smooth[~alive]
    lo, hi = np.percentile(escaped, [40, 99.7])
    value = np.clip((smooth - lo) / (hi - lo + 1e-9), 0, 1) ** 0.6
    ramp = ink.ramp()
    rgb = ramp[(value * (len(ramp) - 1)).astype(int)]
    rgb[alive] = ink.deep                               # the filled set itself
    return to_image(rgb), "Julia set   z -> z^2 + c   c = %.4f %+.4fi" % (c.real, c.imag)


def sacks(rng, w, h, ink):
    """n sits at polar (sqrt n, 2 pi sqrt n): one turn per perfect square. Primes line up on curves."""
    limit = int(rng.integers(26_000, 44_000))
    sieve = np.ones(limit + 1, bool)
    sieve[:2] = False
    for i in range(2, int(limit ** 0.5) + 1):
        if sieve[i]:
            sieve[i * i::i] = False
    n = np.arange(1, limit + 1)
    r = np.sqrt(n)
    theta = 2 * math.pi * r
    scale = min(w, h) * 0.47 / r[-1]
    surface, ctx = cairo_canvas(w, h, ink)
    for is_prime, colour, alpha, size in ((False, ink.caption, 0.16, 0.34), (True, None, 0.95, 0.62)):
        pick = sieve[1:] == is_prime
        for k, (rr, tt) in enumerate(zip(r[pick], theta[pick])):
            if is_prime:
                mix = rr / r[-1]
                ctx.set_source_rgba(*(ink.a[j] + (ink.b[j] - ink.a[j]) * mix for j in range(3)), alpha)
            elif k == 0:
                ctx.set_source_rgba(*colour, alpha)
            ctx.arc(w / 2 + rr * scale * math.cos(tt), h / 2 - rr * scale * math.sin(tt), size * scale, 0, 2 * math.pi)
            ctx.fill()
    return cairo_image(surface), "Sacks spiral   n at (sqrt n, 2 pi sqrt n)   %d primes below %d" % (sieve.sum(), limit)


def rose(rng, w, h, ink):
    """Maurer rose: points of r = sin(n t) taken every d degrees and joined in order."""
    good = [(2, 39), (3, 47), (4, 31), (5, 97), (6, 71), (7, 19), (2, 29), (4, 59), (5, 31), (6, 23), (3, 89), (7, 67)]
    n, d = good[rng.integers(len(good))]
    k = np.arange(361)
    t = np.radians(k * d)
    r = np.sin(n * t)
    surface, ctx = cairo_canvas(w, h, ink)
    scale = min(w, h) * 0.44
    px, py = w / 2 + r * np.cos(t) * scale, h / 2 + r * np.sin(t) * scale
    ctx.set_line_width(max(0.9, w / 2200))
    for i in range(360):
        mix = abs(r[i])
        ctx.set_source_rgba(*(ink.a[j] + (ink.b[j] - ink.a[j]) * mix for j in range(3)), 0.5)
        ctx.move_to(px[i], py[i])
        ctx.line_to(px[i + 1], py[i + 1])
        ctx.stroke()
    # the rose itself, drawn once, a little heavier
    tt = np.linspace(0, 2 * math.pi, 4000)
    rr = np.sin(n * tt)
    ctx.set_source_rgba(*ink.peak, 0.8)
    ctx.set_line_width(max(1.6, w / 1100))
    ctx.move_to(w / 2 + rr[0] * math.cos(tt[0]) * scale, h / 2 + rr[0] * math.sin(tt[0]) * scale)
    for a, b in zip(tt[1:], rr[1:]):
        ctx.line_to(w / 2 + b * math.cos(a) * scale, h / 2 + b * math.sin(a) * scale)
    ctx.stroke()
    return cairo_image(surface), "Maurer rose   r = sin(%d t)   step %d degrees" % (n, d)


KINDS = {"attractor": attractor, "harmonograph": harmonograph, "julia": julia, "sacks": sacks, "rose": rose}


def caption(img, text, ink):
    font_file = subprocess.run(["fc-match", "-f", "%{file}", "JetBrainsMono Nerd Font:style=Regular"],
                               capture_output=True, text=True).stdout
    try:
        font = ImageFont.truetype(font_file, max(13, img.width // 140))
    except OSError:
        return img
    draw = ImageDraw.Draw(img)
    box = draw.textbbox((0, 0), text, font=font)
    pos = (img.width - box[2] - img.width // 50, img.height - box[3] - img.height // 28)
    draw.text(pos, text, font=font, fill=tuple(int(c * 255) for c in ink.caption))
    return img


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("kind", choices=[*KINDS, "random"])
    ap.add_argument("out")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--mode", choices=list(MOODS), default="night")
    ap.add_argument("--size", default="1920x1080")
    ap.add_argument("--caption", action="store_true", help="write the parameters in the bottom right corner")
    args = ap.parse_args()
    seed = args.seed if args.seed is not None else int(np.random.SeedSequence().entropy % 100_000)
    rng = np.random.default_rng(seed)
    kind = args.kind if args.kind != "random" else list(KINDS)[rng.integers(len(KINDS))]
    w, h = (int(v) for v in args.size.split("x"))
    hue1 = float(rng.uniform(0, 360))
    hue2 = (hue1 + rng.choice([-1, 1]) * rng.uniform(75, 150)) % 360
    ink = Ink(args.mode, hue1, hue2)
    # the density plot is drawn at twice the size and reduced, which smooths it
    over = 2 if kind == "attractor" else 1
    img, text = KINDS[kind](rng, w * over, h * over, ink)
    if over > 1:
        img = img.resize((w, h), Image.LANCZOS)
    if args.caption:
        img = caption(img, f"{text}   seed {seed}", ink)
    img.save(args.out)
    print(f"{kind} seed {seed} -> {args.out}")
    print(text, file=sys.stderr)          # the parameters, for whoever wants them


if __name__ == "__main__":
    main()
