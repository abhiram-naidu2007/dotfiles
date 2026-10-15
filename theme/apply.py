#!/usr/bin/env python3
"""Single source of truth for colours.
wal extracts a palette from the wallpaper; this maps it to fixed roles
(bg, fg, accent, ...) with enforced contrast, then renders every template in
templates/ to the path named on its first line:  # target: ~/.config/x
Usage: apply.py WALLPAPER   |   apply.py --check WALLPAPER (print palette only)
"""
import colorsys, json, os, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
WAL_JSON = Path.home() / ".cache/wal/colors.json"


def rgb(h): h = h.lstrip("#"); return tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
def hexc(c): return "#%02x%02x%02x" % tuple(round(max(0, min(1, v)) * 255) for v in c)


def lum(c):
    f = lambda v: v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = map(f, c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def lighten_to(c, bg, ratio):
    """Raise lightness (keep hue/sat) until contrast with bg >= ratio."""
    h, l, s = colorsys.rgb_to_hls(*c)
    while contrast(c, bg) < ratio and l < 1:
        l = min(1, l + 0.01)
        c = colorsys.hls_to_rgb(h, l, s)
    return c


def sat(c): return colorsys.rgb_to_hls(*c)[2] * (1 - abs(2 * colorsys.rgb_to_hls(*c)[1] - 1))


def palette(wallpaper):
    subprocess.run(["wal", "-i", wallpaper, "-n", "-s", "-t", "-e", "-q"], check=True)
    d = json.loads(WAL_JSON.read_text())
    bg = rgb(d["special"]["background"])
    # clamp background dark so light text is always readable
    h, l, s = colorsys.rgb_to_hls(*bg)
    bg = colorsys.hls_to_rgb(h, min(l, 0.09), min(s, 0.5))
    cols = [rgb(d["colors"][f"color{i}"]) for i in range(1, 7)]
    accent = lighten_to(max(cols, key=sat), bg, 4.5)
    fg = lighten_to(rgb("#d8dee9"), bg, 10)
    surf = colorsys.hls_to_rgb(h, min(1, colorsys.rgb_to_hls(*bg)[1] + 0.06), min(s, 0.4))
    # fixed semantic colours, brightened to stay readable
    p = {
        "bg": bg, "surface": surf, "fg": fg,
        "dim": lighten_to(rgb("#7f8799"), surf, 5.5),
        "accent": accent,
        "ok": lighten_to(rgb("#8fbf7f"), bg, 4.5),
        "warn": lighten_to(rgb("#e5b567"), bg, 4.5),
        "crit": lighten_to(rgb("#e06c75"), bg, 4.5),
    }
    out = {k: hexc(v) for k, v in p.items()}
    out["bg_alpha"] = out["bg"].lstrip("#")  # for #AARRGGBB use: {bg_alpha}
    out["accent_alpha"] = out["accent"].lstrip("#")
    out["_ratio_fg_bg"] = round(contrast(fg, bg), 1)
    out["_ratio_accent_bg"] = round(contrast(accent, bg), 1)
    return out


def render(p):
    for t in sorted((HERE / "templates").glob("*")):
        lines = t.read_text().splitlines()
        if not lines or "target:" not in lines[0]:
            continue
        target = Path(os.path.expanduser(lines[0].split("target:", 1)[1].strip()))
        body = "\n".join(lines[1:]) + "\n"
        for k, v in p.items():
            body = body.replace("{" + k + "}", str(v))
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
