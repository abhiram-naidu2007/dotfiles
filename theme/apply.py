#!/usr/bin/env python3
"""Single source of truth for colours.
wal extracts a palette from the wallpaper. Only two things are taken from it:
the hue of the dark tones (tints the neutral base) and the hue of the most
colourful tones (accent, accent2). Lightness and chroma are fixed in OKLCH, so
every wallpaper gives a calm, readable, evenly-weighted theme. Semantic and
ANSI colours use fixed hues at the same pastel weight.
Every template in templates/ is rendered to the path on its first line:
  # target: ~/.config/x
Usage: apply.py WALLPAPER   |   apply.py --check WALLPAPER (print palette only)
"""
import json, math, os, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
WAL_JSON = Path.home() / ".cache/wal/colors.json"


# --- sRGB <-> OKLab/OKLCH -------------------------------------------------
def rgb(h): h = h.lstrip("#"); return tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
def hexc(c): return "#%02x%02x%02x" % tuple(round(max(0, min(1, v)) * 255) for v in c)
def _lin(v): return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
def _gam(v): return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055


def to_oklch(c):
    r, g, b = map(_lin, c)
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return L, math.hypot(A, B), math.degrees(math.atan2(B, A)) % 360


def _from_oklch(L, C, H):
    A, B = C * math.cos(math.radians(H)), C * math.sin(math.radians(H))
    l = (L + 0.3963377774 * A + 0.2158037573 * B) ** 3
    m = (L - 0.1055613458 * A - 0.0638541728 * B) ** 3
    s = (L - 0.0894841775 * A - 1.2914855480 * B) ** 3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    b = -0.0041960863 * l - 0.7034186147 * m + 1.7076926083 * s
    return r, g, b


def oklch(L, C, H):
    """OKLCH -> sRGB, reducing chroma until the colour fits the gamut."""
    while C > 0:
        c = _from_oklch(L, C, H)
        if all(-1e-4 <= v <= 1 + 1e-4 for v in c):
            break
        C -= 0.002
    return tuple(_gam(max(0, min(1, v))) for v in _from_oklch(L, max(C, 0), H))


def lum(c):
    r, g, b = map(_lin, c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def readable(L, C, H, bg, ratio):
    """Raise OKLCH lightness until contrast with bg >= ratio."""
    while contrast(oklch(L, C, H), bg) < ratio and L < 0.98:
        L += 0.01
    return oklch(L, C, H)


def hue_dist(a, b): return min(abs(a - b), 360 - abs(a - b))


# --- palette ----------------------------------------------------------------
def palette(wallpaper):
    subprocess.run(["wal", "-i", wallpaper, "-n", "-s", "-t", "-e", "-q"], check=True)
    d = json.loads(WAL_JSON.read_text())
    tones = [to_oklch(rgb(d["colors"][f"color{i}"])) for i in range(1, 7)]
    dark = [to_oklch(rgb(d["special"]["background"])), to_oklch(rgb(d["colors"]["color8"]))]

    # Base hue: the wallpaper's shadows, but only as a faint tint.
    base_h = max(dark, key=lambda t: t[1])[2]
    tint = 0.018
    base = lambda L, C=tint: oklch(L, C, base_h)

    # Accents: most colourful wallpaper tone, then the most colourful one with
    # a clearly different hue (or a split-complement when there is none).
    # Olive (yellow-green) turns muddy as a pastel UI colour: rank it lower.
    score = lambda t: t[1] * (0.5 if 95 < t[2] < 135 else 1)
    tones.sort(key=score, reverse=True)
    acc_h = tones[0][2]
    far = [t for t in tones if hue_dist(t[2], acc_h) > 70 and t[1] > 0.04]
    acc2_h = far[0][2] if far else (acc_h + 150) % 360

    p = {
        "crust":    base(0.145),
        "mantle":   base(0.165),
        "bg":       base(0.190),
        "surface":  base(0.245, tint * 1.3),
        "surface1": base(0.310, tint * 1.3),
        "surface2": base(0.390, tint * 1.2),
    }
    bg = p["bg"]
    p["fg"] = readable(0.91, 0.012, base_h, bg, 11)
    p["subtext"] = readable(0.80, 0.015, base_h, bg, 7)
    p["dim"] = readable(0.62, 0.020, base_h, p["surface"], 4.5)
    p["accent"] = readable(0.80, 0.115, acc_h, bg, 7)
    p["accent2"] = readable(0.78, 0.100, acc2_h, bg, 6)

    # Semantic + ANSI hues (OKLCH): fixed, same pastel weight as the accents.
    hues = {"red": 18, "green": 145, "yellow": 88, "blue": 255, "magenta": 320, "cyan": 200}
    for name, h in hues.items():
        c = 0.085 if name == "cyan" else 0.110   # cyan reads louder at equal chroma
        p[name] = readable(0.78, c, h, bg, 6)
        p["br" + name] = readable(0.85, 0.095, h, bg, 8)
    p["ok"], p["warn"], p["crit"] = p["green"], p["yellow"], p["red"]

    out = {k: hexc(v) for k, v in p.items()}
    for k in ("bg", "crust", "mantle"):
        out[k + "_hex"] = out[k].lstrip("#")  # for #AARRGGBB use: #cc{bg_hex}
    out["_ratio_fg_bg"] = round(contrast(p["fg"], bg), 1)
    out["_ratio_accent_bg"] = round(contrast(p["accent"], bg), 1)
    return out


def render(p):
    # longest key first, so {bg_hex} is not eaten by {bg}
    keys = sorted(p, key=len, reverse=True)
    for t in sorted((HERE / "templates").glob("*")):
        lines = t.read_text().splitlines()
        if not lines or "target:" not in lines[0]:
            continue
        target = Path(os.path.expanduser(lines[0].split("target:", 1)[1].strip()))
        body = "\n".join(lines[1:]) + "\n"
        for k in keys:
            body = body.replace("{" + k + "}", str(p[k]))
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(body)
        print("wrote", target)


if __name__ == "__main__":
    args = sys.argv[1:]
    check = "--check" in args
    wp = [a for a in args if not a.startswith("--")]
    if not wp:
        sys.exit(__doc__)
    pal = palette(os.path.expanduser(wp[0]))
    print(json.dumps(pal, indent=1))
    if not check:
        Path.home().joinpath(".cache/theme").mkdir(parents=True, exist_ok=True)
        (Path.home() / ".cache/theme/palette.json").write_text(json.dumps(pal))
        render(pal)
