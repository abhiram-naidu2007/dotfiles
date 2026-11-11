# evry

Instant file-name search over the whole disk for Linux, after voidtools' Everything.
No daemon: `evry index` walks the disk into one flat file, each query memory-maps it and scans every name.

On an i5-13420H with ~865 000 entries: index 45 MB, built in 2.7 s; a query takes about 10 ms, a loose (fuzzy) one 20–30 ms.

## Build

Needs Rust 1.89+. For the rofi modes also gcc, rofi 2.0 headers (`rofi-dev`), `libglib2.0-dev`, `libx11-dev`.

```
make install        # evry -> ~/.local/bin; files.so calc.so -> ~/.local/lib/rofi; act.sh -> ~/.local/lib/evry
evry index          # first index; refresh it from a timer or cron (see below)
```

Only the command line: `cargo build --release` and copy `target/release/evry`.

## Use

```
evry thesis pdf             all words must match, at least one in the file name
evry notes/ todo            notes/ = inside a folder named like that
evry pdf: koopman           filters: pdf: doc: img: vid: audio: code: zip: dir: file: home: sys:  ext:rs  *.png
evry Makefile               a capital makes a word case sensitive
evry pdf:                   no plain word: newest first
evry open PATH              open with xdg-open (or $EVRY_OPENER) and remember it
evry stat                   index size and age
```

Piped output is one absolute path per line; `--tsv` gives `kind  path  size  age  bytes  ~`, `-0` NUL-separated paths, `-l N` the row count.

Ranking: whole name > name prefix > start of a word > anywhere; name matches beat folder matches; your own files beat system files and package caches; recent and often-opened files rise.

When exact search finds fewer than 10 rows, loose matches are added below them: the letters in order inside one name, the first letter at a word start (`ctlcfg` finds `controller_config.yaml`, `mathwll` finds `mathwall`). Words under 3 letters never match loosely. Loose rows are marked `~`.

Case folding covers ASCII and accented letters (`école` finds `ÉCOLE.pdf`).

## Settings

`~/.config/evry/config`, one `key value` per line:

```
root /              where the walk starts
skip PATH           never listed
skip-name NAME      listed, never entered (.git, node_modules ... by default)
junk-name NAME      entered, ranked low (site-packages, target, venv ... by default)
mount PATH          also walk this file system
threads N
```

/proc, /sys, /tmp, caches and the trash are skipped; only real file systems (ext4, btrfs, xfs, ntfs, vfat ...) are walked.

## Keep the index fresh

systemd user timer:

```
# ~/.config/systemd/user/evry-index.service
[Service]
Type=oneshot
Nice=19
IOSchedulingClass=idle
ExecStart=%h/.local/bin/evry index

# ~/.config/systemd/user/evry-index.timer
[Timer]
OnStartupSec=1min
OnUnitActiveSec=20min
[Install]
WantedBy=timers.target
```

`systemctl --user enable --now evry-index.timer`. `evry index --if-older 900` rebuilds only when the index is older than 15 minutes.

## rofi

Two modes that answer while you type:

- `files`: this search. `=2^10` calculates, `?words` searches the web.
- `calc`: every keystroke goes to `qalc`; Enter copies the result.

```
ROFI_PLUGIN_PATH=~/.local/lib/rofi rofi -modes files,calc -show files -sort -sorting-method fzf \
  -kb-custom-1 Control+y -kb-custom-2 Control+t -kb-custom-3 Control+o
```

Enter opens, Shift+Enter shows the folder, Ctrl+Y copies the path, Ctrl+T opens a terminal there, Ctrl+O edits.
What each key does is `~/.local/lib/evry/act.sh` (or `$EVRY_ACT`); it uses `$TERMINAL` (default ghostty), `$EDITOR`, `xdg-open`, `xclip`, `notify-send`, `qalc` and `jq`.

## fzf

```
fzf --disabled --delimiter '\t' --with-nth '{6} {2}' \
    --bind 'start:reload:evry --tsv -l 300 -- {q}' --bind 'change:reload:evry --tsv -l 300 -- {q}'
```
