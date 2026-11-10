#!/usr/bin/env python3
"""Single source of truth for colours.
wal extracts a palette from the wallpaper. Only two things are taken from it:
the hue of the dark tones (tints the neutral base) and the hue of the most
colourful tones (accent, accent2). Lightness and chroma are fixed in OKLCH, so
every wallpaper gives a calm, readable, evenly-weighted theme. Semantic and
ANSI colours use fixed hues at the same pastel weight.
Three moods share the same hues and differ only in lightness and chroma:
  night  near-black base, pastel accents (the default)
  day    near-white base, deeper accents
  paper  warm cream and ink for reading; hues are fixed, the wallpaper is ignored
Every template in templates/ is rendered to the path on its first line:
  # target: ~/.config/x
Usage: apply.py [--mode night|day|paper] WALLPAPER
       apply.py --check ...   print the palette only
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
    """Move OKLCH lightness away from bg (up on dark, down on light) until contrast >= ratio."""
    step = 0.01 if lum(bg) < 0.4 else -0.01
    while contrast(oklch(L, C, H), bg) < ratio and 0.06 < L < 0.98:
        L += step
    return oklch(L, C, H)


def hue_dist(a, b): return min(abs(a - b), 360 - abs(a - b))


# --- palette ----------------------------------------------------------------
# Per mood: lightness of the six base layers (crust, mantle, bg, surface,
# surface1, surface2), their tint chroma, then (lightness, chroma, minimum
# contrast) for each text and accent role. crust is always the layer furthest
# from the text: darkest at night, brightest by day, so "crust on accent" reads
# in every mood.
MOODS = {
    "night": dict(layers=(0.145, 0.165, 0.190, 0.245, 0.310, 0.390), tint=0.018,
                  fg=(0.91, 0.012, 11), subtext=(0.80, 0.015, 7), dim=(0.62, 0.020, 4.5),
                  accent=(0.80, 0.115, 7), accent2=(0.78, 0.100, 6),
                  ansi=(0.78, 0.110, 6), bright=(0.85, 0.095, 8)),
    "day":   dict(layers=(0.985, 0.970, 0.950, 0.912, 0.868, 0.800), tint=0.012,
                  fg=(0.27, 0.022, 11), subtext=(0.41, 0.024, 7), dim=(0.56, 0.024, 4),
                  accent=(0.56, 0.140, 4.6), accent2=(0.58, 0.130, 4.3),
                  ansi=(0.58, 0.130, 4.3), bright=(0.50, 0.140, 5.5)),
    "paper": dict(layers=(0.968, 0.950, 0.930, 0.892, 0.848, 0.780), tint=0.030,
                  fg=(0.27, 0.020, 11), subtext=(0.40, 0.025, 7), dim=(0.55, 0.030, 4),
                  accent=(0.44, 0.070, 6), accent2=(0.48, 0.095, 5),
                  ansi=(0.50, 0.080, 4.5), bright=(0.42, 0.090, 6)),
}
PAPER_HUES = (85, 255, 35)   # cream paper, blue-black ink, sepia


def wallpaper_hues(wallpaper):
    """(hue of the shadows, accent hue, second accent hue) from pywal's palette."""
    subprocess.run(["wal", "-i", wallpaper, "-n", "-s", "-t", "-e", "-q"], check=True)
    d = json.loads(WAL_JSON.read_text())
    tones = [to_oklch(rgb(d["colors"][f"color{i}"])) for i in range(1, 7)]
    dark = [to_oklch(rgb(d["special"]["background"])), to_oklch(rgb(d["colors"]["color8"]))]
    base_h = max(dark, key=lambda t: t[1])[2]
    # Accents: most colourful wallpaper tone, then the most colourful one with
    # a clearly different hue (or a split-complement when there is none).
    # Olive (yellow-green) turns muddy as a pastel UI colour: rank it lower.
    score = lambda t: t[1] * (0.5 if 95 < t[2] < 135 else 1)
    tones.sort(key=score, reverse=True)
    acc_h = tones[0][2]
    far = [t for t in tones if hue_dist(t[2], acc_h) > 70 and t[1] > 0.04]
    return base_h, acc_h, far[0][2] if far else (acc_h + 150) % 360


def palette(wallpaper, mode="night"):
    m = MOODS[mode]
    base_h, acc_h, acc2_h = PAPER_HUES if mode == "paper" else wallpaper_hues(wallpaper)
    dark = mode == "night"
    tint = m["tint"]
    names = ("crust", "mantle", "bg", "surface", "surface1", "surface2")
    # the raised layers carry a little more of the hue than the background
    p = {n: oklch(L, tint * (1 if i < 3 else 1.3), base_h) for i, (n, L) in enumerate(zip(names, m["layers"]))}
    bg = p["bg"]
    role = lambda key, hue, against=bg: readable(m[key][0], m[key][1], hue, against, m[key][2])
    p["fg"] = role("fg", base_h)
    p["subtext"] = role("subtext", base_h)
    p["dim"] = role("dim", base_h, p["surface"])
    p["accent"] = role("accent", acc_h)
    p["accent2"] = role("accent2", acc2_h)

    # Semantic + ANSI hues (OKLCH): fixed, same weight as the accents.
    hues = {"red": 18, "green": 145, "yellow": 88, "blue": 255, "magenta": 320, "cyan": 200}
    for name, h in hues.items():
        L, C, ratio = m["ansi"]
        if name == "cyan":
            C *= 0.77            # cyan reads louder at equal chroma
        if name == "yellow" and not dark:
            h = 70               # yellow has no dark form; amber keeps it readable on paper
        p[name] = readable(L, C, h, bg, ratio)
        p["br" + name] = role("bright", h)
    p["ok"], p["warn"], p["crit"] = p["green"], p["yellow"], p["red"]
    # ANSI 0 / 8: the terminal's "black". By day they are the light greys, so
    # programs that paint bars with them still get dark text on a pale bar.
    # The tray pill of the bar. Tray icons belong to the programs that own them and those keep
    # the pale icons they started with, so by day the pill behind them is ink, not paper.
    p["tray"] = p["surface"] if dark else p["fg"]
    p["ansi0"] = p["surface1"]
    p["ansi8"] = p["surface2"] if dark else p["dim"]

    # faint washes of the diff colours over the background
    mix = lambda a, b, t: tuple(x + (y - x) * t for x, y in zip(a, b))
    p["diff_add"], p["diff_del"], p["diff_chg"] = (mix(bg, p[k], 0.20) for k in ("green", "red", "yellow"))

    out = {k: hexc(v) for k, v in p.items()}
    for k, v in list(out.items()):
        out[k + "_hex"] = v.lstrip("#")                                                 # for #AARRGGBB: #cc{bg_hex}
        out[k + "_rgb"] = ", ".join(str(int(v[i:i+2], 16)) for i in (1, 3, 5))          # for JSON colour arrays
    out.update(
        mode=mode,
        variant="dark" if dark else "light",
        prefer_dark="1" if dark else "0",
        gtk_theme="Adwaita-dark" if dark else "Adwaita",
        icon_theme="Papirus-Dark" if dark else "Papirus-Light",
        shadow_opacity="0.42" if dark else "0.20",
        dim_inactive="0.16" if dark else "0.07",
        glass="d8" if dark else "e6",           # alpha of the launcher panel over the blurred wallpaper
        # paper also runs every window through an e-ink shader (picom/shaders/paper.glsl)
        picom_shader=str(Path.home() / ".config/picom/shaders/paper.glsl") if mode == "paper" else "",
    )
    out["_ratio_fg_bg"] = round(contrast(p["fg"], bg), 1)
    out["_ratio_accent_bg"] = round(contrast(p["accent"], bg), 1)
    out["_ratio_crust_accent"] = round(contrast(p["crust"], p["accent"]), 1)
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
        if target.is_symlink():      # never write through a stow link into the repo
            target.unlink()
        target.write_text(body)
        print("wrote", target)


if __name__ == "__main__":
    args = sys.argv[1:]
    check = "--check" in args
    mode = "night"
    if "--mode" in args:
        mode = args[args.index("--mode") + 1]
        del args[args.index("--mode"):args.index("--mode") + 2]
    wp = [a for a in args if not a.startswith("--")]
    if not wp or mode not in MOODS:
        sys.exit(__doc__)
    pal = palette(os.path.expanduser(wp[0]), mode)
    print(json.dumps({k: v for k, v in pal.items() if not k.endswith(("_hex", "_rgb"))}, indent=1))
    if not check:
        cache = Path.home() / ".cache/theme"
        cache.mkdir(parents=True, exist_ok=True)
        (cache / "palette.json").write_text(json.dumps(pal))
        # the same palette for shell scripts: . ~/.cache/theme/colors.sh; echo $accent
        (cache / "colors.sh").write_text("".join(f"{k.lstrip('_')}='{v}'\n" for k, v in pal.items()))
        render(pal)
