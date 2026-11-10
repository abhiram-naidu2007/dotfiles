#!/usr/bin/env python3
"""Data for the browser's new-tab page: Pokémon sprites as pixel grids, and the lines of mathematics.

  sprites.py OUT.js [COUNT]

Reads the terminal sprites in ~/.local/share/pokemon-colorscripts (half-block characters with
24-bit colours: each character is two pixels, one above the other) and writes
  const SPRITES = [{n: name, w, h, p: [colours], d: "one character per pixel"}, ...]
  const MATH = [[formula, name], ...]
COUNT (default 386, the first three generations) is how many sprites are included.
"""
import json, re, sys
from pathlib import Path

HOME = Path.home()
SPRITES = HOME / ".local/share/pokemon-colorscripts"
MATH = HOME / ".local/share/rice/math.txt"
TOKEN = re.compile(r"\x1b\[([0-9;]*)m|(.)", re.S)
DIGITS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"


def pixels(text):
    """Rows of colours (None = transparent)."""
    rows = []
    for line in text.splitlines():
        top, bottom, fg, bg = [], [], None, None
        for code, char in TOKEN.findall(line):
            if char == "":
                parts = code.split(";")
                if code in ("", "0"):
                    fg = bg = None
                elif parts[:2] == ["38", "2"]:
                    fg = "#%02x%02x%02x" % tuple(int(v) for v in parts[2:5])
                elif parts[:2] == ["48", "2"]:
                    bg = "#%02x%02x%02x" % tuple(int(v) for v in parts[2:5])
                continue
            pair = {"▀": (fg, bg), "▄": (bg, fg), "█": (fg, fg)}.get(char, (bg, bg))
            top.append(pair[0])
            bottom.append(pair[1])
        rows += [top, bottom]
    width = max((len(r) for r in rows), default=0)
    rows = [r + [None] * (width - len(r)) for r in rows]
    # trim the empty border
    rows = [r for r in rows if any(r)] if rows else rows
    cols = [x for x in range(width) if any(r[x] for r in rows)]
    return [r[cols[0]:cols[-1] + 1] for r in rows] if cols else []


def encode(name, rows):
    palette = sorted({c for r in rows for c in r if c})
    if not rows or len(palette) > len(DIGITS):
        return None
    index = {c: DIGITS[i] for i, c in enumerate(palette)}
    return {"n": name, "w": len(rows[0]), "h": len(rows), "p": palette,
            "d": "".join(index.get(c, ".") for r in rows for c in r)}


def main():
    out = Path(sys.argv[1])
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 386
    sprites = []
    if (SPRITES / "pokemon.json").exists():
        for entry in json.loads((SPRITES / "pokemon.json").read_text())[:count]:
            f = SPRITES / "colorscripts/small/regular" / entry["name"]
            if f.exists():
                s = encode(entry["name"], pixels(f.read_text()))
                if s:
                    sprites.append(s)
    math = [line.split("\t") for line in MATH.read_text().splitlines() if "\t" in line] if MATH.exists() else []
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("const SPRITES = %s;\nconst MATH = %s;\n" % (
        json.dumps(sprites, separators=(",", ":")), json.dumps(math, ensure_ascii=False, separators=(",", ":"))))
    print(f"{len(sprites)} sprites, {len(math)} lines -> {out} ({out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
