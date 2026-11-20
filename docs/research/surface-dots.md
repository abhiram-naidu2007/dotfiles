Reading finished. The report follows.

# surface-dots: study report

**Scope.** I read ~200 source files under `.config/quickshell/`, `.config/hypr/`, `sddm/`, `.source_codes/`, `utilities/` and the root. These I read in full: every QML file in `lib/`, `hub/`, `bars/`, `dock/`, `desktop/` and `utils/`; all GLSL; the Lua, shell and Python scripts; and the Rust in `wallpaper_panel`. These I only skimmed (grep plus key parts): `hub/top/*` (near-copies of `hub/*`), legacy `lib/WifiMenu.qml`, `.config/ags/hub.tsx` (legacy), the pixel SDDM `Main.qml`, the installer's Rust, `now_playing/main.dart`, Firefox `codex-stellarium/script.js` and `custom_homes/*`, the rofi `.rasi`, Kvantum/qt6ct/colour-scheme/kitty colour files, and spicetify/userChrome CSS. I skipped binaries, images, fonts, cursors, `venv311/` and the `.tar.gz` files. Repo HEAD is `9eba777 sound panel in the hub`. I modified nothing.

---

## 1. Architecture

**Stack.** Hyprland (Lua config, `hyprland.lua` + `shader.lua`) and Quickshell (QML, Qt 6), launched as plain `qs`. Helper processes: `papel` (Rust thumbnailer), `now_playing` (Flutter), a Tauri installer, `matugen`, `cliphist`, `nmcli`, `khal`.

**Entry point.** `.config/quickshell/shell.qml`. One `ShellRoot`, then a `Variants` over `Quickshell.screens`. Each screen gets its own `ThemeEngine`, a `ScreenBorder`, a bar `Loader` (TaskBar or TopBar, held until `Configuration.ready`), `HubWindow`, a `MonitorPrompt` loader (one screen only), the three OSDs, `Drawer` and `WideDrawer`. Global shortcuts (`hubToggle`, `drawerToggle`, `monitorPicker`) are bound per screen but act only when `v.focused`.

**Singletons (services) in `lib/`:**

| Singleton | Backing |
|---|---|
| `Configuration` | `lib/usersettings.json` via `FileView`. ~45 properties. `save()` debounced 60 ms. Migrates old keys. |
| `ThemeState` | Owns dark/light. Watches `~/.cache/quickshell/theme_mode`. `_toggling` ignores the watcher echo for 500 ms after its own write. |
| `PaletteService` | `utils/palette-gen.sh` (matugen + jq). Watches `wallpaper_changed`. |
| `Notifs` | Quickshell `NotificationServer`, history, stacks. |
| `Audio` | `Quickshell.Services.Pipewire`, default sink, `PwObjectTracker`. |
| `Brightness` | Watches the sysfs `/sys/class/backlight/*/brightness` file; writes with `brightnessctl`; `IpcHandler "brightness"`. |
| `Battery` | `Quickshell.Services.UPower`, display device plus the real cell for health. |
| `Clipboard` | `cliphist` plus its own `wl-paste --watch` processes. |
| `MonitorService` | `hyprctl monitors all -j`, Hyprland raw events, `monitors.json`. |
| `Motion`, `PopupStyle`, `Shell` | Tokens and helpers. |

**Theming flow.** `ThemeState.isDarkMode` feeds every `ThemeEngine` instance. Each colour has three possible sources, in priority order:
1. A wallpaper role from `PaletteService.role(role, dark)`, if `useWallpaperColors` is on.
2. A custom accent/background.
3. Hard-coded Everforest values.

Every public colour is a `_x` property with `Behavior ColorAnimation 300`. Derived surfaces (`_elevate`) read the *target* colour, not the animated one, so they do not chase the fade. `theme.js` is legacy constants that are being phased out.

**IPC and signalling.** Mostly files and processes:
- **Files in `~/.cache/quickshell/`**: `theme_mode`, `theme_osd`, `reading_mode`, `night_light`, `wallpaper_changed`, `volume`, `brightness`, `wifi_status.json`, `weather.json`, `power_menu_style`, `power_menu_colors`. `FileView watchChanges` picks them up.
- **Hyprland global shortcuts**: `hl.dsp.global("quickshell:hubToggle")`.
- **Quickshell IPC**: `qs ipc call brightness notify` (sent from `brightnesscontrol.sh`).
- **Unix socket**: `$XDG_RUNTIME_DIR/papel.sock` carries JSON lines out (one thumbnail each) and `apply:<path>` lines in.
- **Power menu**: a separate `quickshell -p utils/PowerMenu.qml` process. Alt+F4 launches it, guarded by `hyprctl layers | grep -q power-menu`.

**State files.** `usersettings.json`, `monitors.json`, `notification-history.json` (`Quickshell.statePath`), `.cache/favorites.json`, `.cache/blacklist.txt`, and `.cache/applist.cache` plus a timestamp (invalidated by directory mtime).

**Layout modes.** `barStyle` is `task` or `top`. TaskBar switches itself between dock mode (no windows) and workspace mode. The hub lays out `TaskCards` (2 columns, 520 px) or `TopCards` (1 column, 320 px).

---

## 2. Feature inventory

**Bars and desktop**
- `bars/TaskBar.qml`: bottom bar.
  - Dock mode: Arch launcher, 4 pinned apps with tooltips, clock, battery.
  - Workspace mode: launcher, 10 workspace slots with per-window Nerd glyphs (60-class map), active and hover pills, media-or-title text, pacman updates pill (`checkupdates` every 30 min, click runs `kitty -e sudo pacman -Syu`), tray, battery, clock.
  - Auto-hide; low-battery `notify-send` at 20% and 10%.
- `bars/TopBar.qml` + `TopBarItem.qml`: top variant with pills that shimmer on hover, a "power surge" ring when the charger is plugged in, and a clock shimmer. Right-clicking the Arch glyph toggles the theme.
- `desktop/ScreenBorder.qml`: frame of 1–20 px around the screen with inverted Canvas corners. Hidden when windows exist. Exclusive zone 38.
- `dock/Drawer.qml`: dock-mode app grid (720×550) with search and a context menu (open / hide app).
- `dock/WideDrawer.qml`: 860×520 launcher with Programs / Shaders / Clipboard tabs. Up to 6 pinned favourites, full keyboard navigation, type-to-search from any focus, live watch of `.desktop` directories, an icon-cache warm-up, and a blacklist.
- `dock/applist.sh`: `.desktop` parser and icon resolver, cached.

**Hub (`hub/`)**
- `HubWindow.qml`: overlay with one content panel at a time, letter hotkeys, input mask with a hole over the clock, an in-panel toast, and window borders hidden while open.
- `Header.qml`: avatar, name, buttons for stats, settings, displays and snapshot (closes the hub, then runs the capture script 320 ms later).
- `ButtonsSlidersCard.qml`: Wi-Fi, BT, performance (auto-cpufreq, rolls back on failure) and DND tiles; vertical brightness and volume sliders.
- `CalendarWeatherCard.qml` + `CalendarGrid.qml`: big date, month grid, weather. Click opens EverCal.
- `Events.qml`: next khal events; an event stays until it ends; `maxEvents` setting.
- `MediaCard.qml`: MPRIS card with art, dominant-colour background, wavy seekable progress, 60 s "recently paused" grace. Click opens the Flutter widget.
- `BatteryHealthCard.qml`: kernel, CPU/RAM tiles, battery %, health bar, cycles, time remaining.
- `NotificationsCard.qml` + `NotifItem.qml`: history, count, Clear with a wipe animation, expand/collapse, ripple, overscroll glow.
- `WifiPanel.qml`: radio switch, current connection, saved/available lists, password and PEAP forms, forget confirmation, advanced editor.
- `BluetoothPanel.qml`: connected / paired / nearby, scan only while visible, pair then connect, forget confirmation.
- `SoundPanel.qml`: sink picker plus mute.
- `MonitorsPanel.qml`: layout tiles, resolution dropdown, refresh chips, scale chips (1/1.25/1.33/1.5/2), rotation, position slots, apply, forget.
- `WallpaperPanel.qml`: papel-backed 3-column grid, apply, 6 sampled swatches (click copies hex).
- `PalettePanel.qml`: matugen seeds, 9 schemes with colour strips, per-role overrides.
- `SettingsPanel.qml`: appearance, wallpaper colours, weather API, power-menu skin and accent, layout/taskbar, screen borders, profile and events.
- `hub/top/*`: top-layout versions of the cards (blurred-art media card, inline events).

**Popups and services (`lib/`)**
- `NotifPopups.qml` + `NotifToastCassini.qml` / `NotifToastRounded.qml`: two toast skins, stacked per app.
- `VolumeOSD.qml`, `BrightnessOSD.qml`, `ThemeOSD.qml` via `OsdCard` → `OsdCardCassini.qml` / `OsdCardRounded.qml`.
- `MonitorPrompt.qml`: hotplug card with pick / confirm (10 s revert) / toast phases.
- `ColorPicker.qml`: swatch, hex field, H/S/L gradient sliders.
- `ExpressiveButton.qml`, `ExpressiveSlider.qml`, `MediaButton.qml`, `Card.qml`, `TopCard.qml`, `Chip.qml`, `Ripple.qml`, `ClickRipple.qml`, `WavyProgress.qml`, `WavyLine.qml`: widgets.
- `CommandPoll.qml`: process poller with busy flag and 5 s hang guard; emits only when the value changes.
- `MonitorLayout.js` (+ `tests/monitor-layout.test.js`, node:test): pure layout math.
- `weather.sh`: OpenWeatherMap with a 30 min cache.
- `WifiMenu.qml`: legacy standalone network applet.

**Power menu (`utils/`)**: `PowerMenu.qml` (window, reads the cache files), `PowerMenuController.qml` (logic and keys), skins `Livingthings.qml` and `Cassini.qml`. `theme-mode.sh` is the global dark/light switch; `palette-gen.sh` builds the palettes.

**Hyprland**
- `hyprland.lua`: config, binds, window rules, lid switch, monitor-hotplug wallpaper redraw, startup sound.
- `shader.lua`: shader manager. Complex modes (Reading, Night Light, CRT) change theme, wallpaper, gaps, animations and damage tracking.
- `shaders/*.glsl`: 15 active and 5 old screen shaders.
- `scripts/`: audio/brightness/media control, screenshot (grimblast + swappy), wallpaper, wallpaper daemon, lock clock/moon/weather, weather.
- `screenshots/*.sh`.
- `hypridle.conf`.
- `hyprlock/{stellarium,pixel}`.

**Other**
- SDDM themes: `stellarium` (8 files) and `pixel` (with and without the face-unlock animation, `PixelDots`).
- `.source_codes/wallpaper_panel/*.rs`: papel.
- `.source_codes/now_playing/main.dart`: Flutter MPRIS widget.
- `.source_codes/installer_src/`: Tauri installer with preflight, backups, rollback, a single pkexec SDDM step, and a sandbox script with a fake pkexec.
- Firefox: `codex-stellarium` new tab (canvas starfield, orbits, comets, moon phase, sidereal time, sun elevation, Open-Meteo), `custom_homes`, `userChrome.css`.
- Other configs: waybar (used as the CRT-mode bar), rofi (launcher, shader menu, Google mode), dunst/mako (fallbacks), kitty, starship, zathura, fastfetch, khal, vdirsyncer, spicetify, Kvantum, qt6ct.
- `utilities/crt_gen.py` (bakes CRT effects into an image), `utilities/figures.py` (attractor wallpapers via odeint), `cursor/` (Saturnian XCursor + hyprcursor).

---

## 3. Motion and feel

**Spring tokens (`lib/Motion.qml`).** All are Qt `SpringAnimation` with mass 1.0.

| Token | spring | damping | epsilon | Reduce-motion value | Used for |
|---|---|---|---|---|---|
| snappy | 7.0 | 0.40 | 0.005 | 19.0 / 1.0 | hover/press scale, small y offsets, chevron rotation, segment indicators |
| bouncy | 5.0 | 0.20 | 0.005 | 16.0 / 1.0 | icon release after press, launcher spin back, OSD pulse return |
| smooth | 5.0 | 0.55 | 0.01 | 14.0 / 1.0 | panel width/height, list `displaced`, toggle knob x, workspace active pill, card heights |
| gentle | 5.5 | 0.75 | 0.01 | 11.0 / 1.0 | OSD slide-in y, monitor-prompt scale and translate |

- Position properties override epsilon to **0.25** (stop at a quarter pixel).
- Reduce motion does not turn animation off. It makes every spring critically damped and stiffer: no overshoot, shorter.
- Qt's `spring`/`damping` are not loka's (response, ζ). This mapping is my own estimate, to be tuned by eye: snappy ≈ `Spring::new(v, 0.22, 0.6)`, bouncy ≈ `(0.32, 0.4)`, smooth ≈ `(0.35, 0.85)`, gentle ≈ `(0.45, 1.0)`.

**Hub open/close (`HubWindow.qml`).**
- Open, all OutCubic: panel y from ±panel height to 0 in 320 ms; opacity 0→1 in 280 ms; scale 0.97→1 in 320 ms. Scale origin is bottom-centre for the taskbar layout, top for the top layout.
- Content fades in 230 ms after a **70 ms pause**.
- Close: content fades out first (140 ms), then the panel moves only 20 px (260 ms), fades (250 ms) and scales to 0.97 (260 ms). `visible=false` is set in `onFinished`.
- `layer.enabled` is on only during these animations. The shadow item copies the panel's transforms.
- Between modes, panel width springs (smooth) through 320/520/460/540/560/620. Content height springs (smooth). Panels cross-fade over 160 ms OutCubic.
- Loaders are created on first open and kept alive (`_xEverOpened`).
- The wallpaper panel turns off its per-thumbnail blur and mask layers for 300 ms around transitions (`live=false`).

**Toasts.**
- Enter: `appear` 0→1 in 300 ms OutCubic. Opacity is `appear` (×0.82 for low urgency); x offset is `(1-appear)*56` px.
- Exit: `appear`→0 in 220 ms InCubic, then clip, then height→0 in 240 ms OutQuint, using `ListView.delayRemove`.
- `displaced` uses the smooth spring. Timeout is a `FrameAnimation` that adds `frameTime`. It runs only when fully shown, not hovered and not dragged.
- Rounded skin: hover scale 1.01, press 0.985; shadow y 12→16 over 180 ms and ×1.25 opacity on hover.
- Drag X: release past 40% of width dismisses; otherwise it springs back (smooth).

**OSDs.**
- Fade in 160 ms OutQuad, fade out 320 ms InCubic. Slide 22 px with the gentle spring. Hide after 2600 ms; the window unmaps 350 ms later.
- ThemeOSD: 140/230 ms, 20 px slide, 5000 ms hold.
- Value change pulse: icon scale →1.2 in 80 ms OutQuad, then bouncy back to 1. Glyph swap: snappy spring from 0.7 to 1.
- Rounded bar thickens 8→10 px while dragging (120 ms); the fill width animates 120 ms OutQuad, but 0 ms while dragging.

**Bar.**
- Launcher press: `pressScale`→0.86 and `iconPressScale`→0.82 in 110 ms OutCubic. Release: snappy for the button, bouncy for the icon.
- Burst: a flash rectangle goes scale 0.35→1 (340 ms OutQuad) and opacity 0.42→0 (400 ms OutCubic); the icon jumps to −9° and springs back (bouncy).
- When the drawer is toggled from the keyboard, the same press → 70 ms pause → burst plays (`pulse()`).
- Active workspace pill: x and width on the smooth spring, with the animation suppressed on first layout (`pillReady` via `callLater`).
- Hover pill: separate layer with an accent gradient at alpha 0.35/0.55/0.35, snappy x/width, 140 ms fade. Press pill: 10% text colour, 90 ms.
- Hovered workspace item: y −2, scale 1.10. Pressed: y +1, scale 0.96.
- Urgent window glyph flashes `#e67e80`↔`#dbbc7f`, 200 ms each.
- Auto-hide: `hiddenPx` 0↔40 in 240 ms OutCubic; leaving keeps it up for 450 ms (`hoverHeld`). The reveal trigger is a 3 px strip.
- Dock↔workspace mode cross-fade: 300 ms OutQuart. Battery at ≤10%: opacity blinks 0.3↔1, 500 ms each way.
- TopBar: shimmer gradient sweeps across on hover entry (800 ms InOutQuad); plug-in ring scale 1→1.45 with fade, 520 ms OutCubic.

**Lists and scrolling.**
- Wheel: each event adds to the current target (`base = anim.running ? anim.to : contentY`). Step is `|Δ|·1.1 + 20` (24 in some views); 480–520 ms OutExpo. The app grid then snaps to a row in 160 ms OutCubic.
- Clipboard rows: staggered entry of `35 ms × min(index, 8)`, 240 ms OutQuart, rising 8 px. Removal: height→0 in 220 ms OutQuint plus opacity in 160 ms. Copying flashes the row (accent at 0.32 alpha, 110 ms), and the drawer closes 170 ms later.
- Hub notification list: add = opacity 300 ms OutSine + scale 0.9→1 (smooth). Remove = opacity 250 ms OutQuad + scale →0.5 in 250 ms InQuad. Clear all: opacity →0 in 300 ms and contentY −40 in 400 ms, both OutExpo, then the model clears.
- WideDrawer reveal: clipped `activeHeight` 0→520 in 320 ms OutCubic (the comment says a spring "crawled the last pixels"); opacity 220 ms OutQuart. Tab indicator x on snappy; grid highlight moves in 130 ms.

**Other surfaces.**
- Power menu: intro 0→1 in 220 ms OutCubic (opacity plus 24 px rise); outro 180 ms, then the action runs, then `Qt.quit()`.
- Monitor prompt: scale 0.97→1 and translate by the card height, both gentle; opacity 280 ms OutCubic in, 230 ms InCubic out; size springs (smooth) between phases.
- SDDM stellarium:
  - Lock→login: pages slide −12% / from +100% over 700 ms OutCubic, opacity 500 ms. Wallpaper zooms 1.0→1.06 (900 ms); a 0.35 dim fades in over 700 ms.
  - Wrong password: card shakes ±6/±4 px in 80 ms steps; the emblem shakes x and rotation in 90 ms steps, and a "meteor" falls for 700 ms OutQuad.
  - Success: bloom scale 0.4→1.15 (336 ms), then →1 (224 ms); 12 rays drawn with 0.05 stagger over 600 ms.
  - Each typed character pops in with OutBack (240 ms).
- Hyprland: windows in on a spring (stiffness 350, damping 35), out 320/32, move 300/30, `popin 85%`. Workspaces `slidefade 15%` with MD3 decel/accel béziers.

**Why it feels finished**
1. One motion vocabulary everywhere: four springs plus a handful of durations.
2. Springs on anything that can be interrupted, so retargeting mid-flight is smooth.
3. Content and container are choreographed separately: content lags on open and leads on close.
4. Exits are short and small (20 px, 0.97 scale) compared with entries.
5. Every pointer state has a response: hover tint, press squash, release bounce.
6. Anti-jitter work:
   - local value hold of 400 ms during OSD drag and wheel;
   - 300 ms slider hold until PipeWire echoes the new value;
   - brightness writes throttled to 40 ms;
   - 450 ms hover hold on the auto-hide bar;
   - first-layout animation suppressed;
   - OSD ignores level changes for 500 ms after a sink switch or startup.
7. Windows unmap only after their fade ends, and input masks exclude shadow padding.

**Compared with loka today (`anim.rs`).** loka has FADE 150 ms OutCubic, STANDARD 250 ms OutQuint (unused), SLOW 400 ms OutExpo, and a closed-form Spring. The island uses `Spring(0.42, 0.82)`, hover uses FADE, and the clock flips with OutBack(1.4) over 420 ms. It has **no** press scale, staggered list entry, row collapse, reduce-motion switch or theme cross-fade.

---

## 4. Visual techniques

**Screen shaders** (`hypr/shaders/`; Hyprland `decoration.screen_shader`; one texture sample per pixel so damage tracking still works, unless noted)

| Shader | What it does and the math |
|---|---|
| `main` | Display grade: contrast `(c−.5)·1.08+.5`; vibrance `mix(luma,c,1+0.07(1−sat)(1−skin))` where skin = `smoothstep(.3,.6,r)·smoothstep(.6,.3,g)·.5`; saturation 1.03. Run at startup. |
| `night` | Warm gain `(1.06,.96,.52)` mixed by `pow(luma,0.6)·0.72`, then ×0.88. Bright pixels warm a lot, darks barely. |
| `reading_mode` | E-ink: gray → `pow(1.2)` → `smoothstep(.08,.92)` + mid boost. 5-octave hash paper grain + directional grain + 4×4 Bayer (0.025), masked to brights; vignette; maps ink `(.10,.10,.12)` → paper `(.94,.92,.86)`. |
| `crt_mode` | Barrel warp `uv += dc·|dc|²·(.015,.01)`; RGB split ±0.001; `sin(y·1.5)` scanlines; every 3rd column ×0.8; vignette `pow(16uv(1−uv),0.15)`; ×1.2. Needs damage tracking off. |
| `amano` | Three-zone tone (ink→wash→paper by luma); warm-hue isolation ("heat" from red dominance) boosted to sat 1.6; upper-midtone desaturation; hash grain in shadows and mids. |
| `art_canvas` | Remaps to the pigment range `[.12, .92]`; sat 0.75; canvas heightmap = sin weave + hash; bump against the (−1,+1) neighbour as fake directional light; AO ×(0.92+0.08h); vignette. |
| `dither` | 4×4 Bayer, 6 levels per channel: `floor((v+(t−.5)/5)·5+.5)/5`. |
| `fuji_acros` | Mono weights (.18,.74,.08), toe/mid/shoulder smoothstep curve, grain heavier in midtones. |
| `vhs` | Sine tracking band, hash chroma noise in green, sat 1.18, noise heavier at top and bottom edges, `sin(y·π)` scan, vignette. |
| `gameboy` | Luma + Bayer×0.25 quantised to 4 greens. |
| `silent_hill` | Sat 0.25; greens pulled to khaki; fog peak at luma 0.48 mixed 55%; reds kept (sat 1.5, g×0.75); "ash" sparkle where `step(.97,n)`; fog-coloured vignette. |
| `smart_invert` | RGB→HSL, `L=1−L`, `smoothstep(.02,.98)`, back to RGB. |
| `greens` | Keeps hue within 0.08–0.16 of 0.33, needs sat and value thresholds, grey elsewhere. |
| `outdoor` | Gamma 0.75, contrast 1.22, midtone "clarity", sat 0.85. |
| `cinema` | Lift / gamma / gain plus an `fwidth` acutance term, mixed at 70% strength. |
| `soft` | Watercolour: granulation desaturation, dilution toward paper, hash "sizing", warm shift. |
| old/ | `night_vision`, `matte`, `focus` (circular spotlight), `clarity_inefficient` (CAS sharpen; neighbour samples break damage tracking), `IBM5151` (amber phosphor ramp). |

The hash used everywhere is Dave Hoskins' "Hash without Sine": `p3=fract(p.xyx·.1031); p3+=dot(p3,p3.yzx+33.33); fract((p3.x+p3.y)·p3.z)`.

**Shapes and masks**
- Rounded clipping is done with a `MultiEffect` mask on a hidden rounded `Rectangle` (`maskThresholdMin .5`, `maskSpreadAtMin 1`), because Qt `clip` ignores radius.
- Icon tinting: the SVG is used as a mask over a solid colour rectangle, giving an exact tint for any fill. Notes in the code say colorize "can't multiply black" and "would dim the blue".
- The SVG texture is rendered at 2× so hover zoom stays sharp.
- Screen border inner corners: a Canvas square with an arc cut out.
- Cassini OSD ruler: 11 one-pixel ticks (majors at every 5th), a 3 px level line, a triangle marker from a `Shape` with CurveRenderer, labels 0/50/100. Tick positions are integer pixels (`span=floor(width)−1`).
- `WavyProgress`: Canvas sine `y = mid + sin(x·0.15 + phase)·2.5`, sampled every `max(2, w/180)` px, phase +0.22 per tick at 24 fps. Wave only left of the playhead; flat remaining track after a 6 px gap; the wave animates only while playing.
- Stellarium `ShapeGlyph`: 20 Canvas astronomy glyphs (star, crescent via destination-out, saturn with a split back/front ring, comet, atom, vortex spiral, nebula béziers…). Typed password characters use glyph `(i·5 + (i%4)·3 + 1) % 9`.
- Pixel SDDM `PixelDots`: 8 shapes that cycle, scaled by `6/count` once more than 6 are shown.
- Input masks: `Region` with an `Intersection.Subtract` hole over the bar toggle, so a full-screen overlay never blocks its own toggle button. Shadow padding is click-through.

**Shadows and blur**
- Rounded toast skin: two layers.
  - Ambient: blur 1.0, y 12 (16 on hover), opacity 0.42 dark / 0.2 light.
  - Contact: blur 0.25, y 2, opacity 0.5 / 0.22.
- The shadow source is inset 1 px under the card so no halo shows at the edge.
- Cassini skin: blur `16·1.7/64`, blurMax 64, y 8, `rgba(0,0,0,.55/.30)`.
- Hub: `#70000000`, blur `26·1.7/64`, y 12, 30 px spread.
- Top-layout media card: album art downsampled to 256, blurred (blur 1.0, blurMax 64), covered with 65% black plus 8% of the average art colour.
- Hyprland window blur: size 5, 2 passes.

**Typography**
- Manrope for UI; JetBrainsMono Nerd Font for icons; Newsreader serif for Cassini, OSD values, the "Displays" and "Programs" titles; EB Garamond and CMU Typewriter for lock screens and Cassini; DM Mono for hex values and toasts; Inter in Living Things.
- Uppercase labels with tracking 0.9–1.5. OSD value: big serif number with a small sans unit, both aligned to a hidden "0" baseline, so changing digits never moves the layout.
- `pixelSize` stays an integer (a comment notes 10.5 rounds to 11). `renderType: NativeRendering` on the Cassini skin. Hairlines are 0.5 px in dark and 1 px in light.

**Colour generation**
- `palette-gen.sh`:
  - Runs `matugen image --show-source-colors` to get seeds, then 9 schemes (tonal-spot, vibrant, expressive, fidelity, content, neutral, monochrome, rainbow, fruit-salad) in parallel.
  - Keeps 12 roles × dark/light and validates 216 hex values.
  - Cache key is `sha1(path + mtime)` per seed index; files are written atomically (cp then mv).
- `PaletteService`:
  - A cycle counter discards output from killed processes; a 20 s guard; changes are debounced 300 ms after `wallpaper_changed`.
  - On failure the old palette is kept.
  - Per-role per-mode user overrides survive wallpaper changes.
- Custom background: derived surfaces are the background with HSV value raised by +0.051/+0.133/+0.173 in dark, lowered in light (`_elevate`).
- `flatHex` alpha-composites the accent over the background so colour pickers show the real opaque colour. `PopupStyle.solid` tints a colour over an opaque surface so translucent accents never let a shadow show through.
- Media card: averages a 10×10 grid of art samples; accent = mix toward white 0.55 (dark) or black 0.25 (light); title colour = 0.85 further; overlay `#1e2327`@55% or white@75%; 400 ms colour fade; LRU of 40 URLs.
- Flutter widget: `palette_generator`. Background is darkMuted with lightness clamped to 0.05–0.11. Accent is vibrant with saturation +0.35 and lightness +0.15 (clamped 0.48–0.88), then `ColorScheme.fromSeed(fidelity)`.
- Wallpaper panel swatches: 3×2 grid samples taken from the thumbnail.

---

## 5. System integration

| Area | Implementation |
|---|---|
| Lock | `hyprlock`. Two themes copy the SDDM looks; the clock is Pango markup from `lock-clock.sh`; moon phase from `lock-moon.sh` (local synodic maths, JD 2451550.1, 29.53058867 d); weather from the shell's cache; battery from sysfs. Power menu runs `hyprlock`. |
| Idle | `hypridle`: 2 min → `brightnessctl -s set 10%` and keyboard backlight 0 (restored with `-r`); 3 min `loginctl lock-session`; 6 min DPMS off; 20 min `systemctl suspend`; `before_sleep_cmd` locks. |
| Polkit | `hyprpolkitagent`, falling back to `polkit-gnome` at startup. The installer checks for an agent before its single `pkexec bash -c` call. |
| Notifications | Quickshell `NotificationServer` (body, markup, links, actions, images, persistence; `keepOnReload`). Toasts stack per app, max 4 stacks; covered toasts expire after 2 s; criticals never stack or drop. DND expires non-critical at once. History of 50 rows saved to JSON. A `busctl` PID check finds a foreign owner of the bus name (5 s re-poll while one exists). Markup allow-list: `b i u br a href=http(s)|mailto`, everything else escaped. Links are opened only for web and mail. Dunst/mako configs are fallbacks; `dunst/alert.sh` plays sounds. |
| Media | Quickshell MPRIS. Player pick order: playing > paused > first, every 1.5 s. Time units (s/ms/µs/ns) guessed by plausibility scoring. A rewind of more than 30 s means a new track. Firefox art: `playerctl … xesam:url` → YouTube `mqdefault.jpg` (top layout copies the newest file from `~/.mozilla/firefox/firefox-mpris/`). Flutter widget uses playerctl follow plus DBus art, interpolates position with a ticker, and resyncs every 7 s. |
| Network | `nmcli` throughout. Status script; saved profiles via `nmcli -g` (one line per field); scan with `--rescan yes`; escaped `\:` parsed; keeps the best BSSID per SSID; PEAP/MSCHAPv2 via `connection add … 802-1x.*`; "Secrets were required" → password form; status cached to JSON; 20 s watchdog message; `nm-connection-editor` link. |
| Bluetooth | Quickshell.Bluetooth (BlueZ DBus): adapter enable, discovery only while the panel is live, pair → connect on `pairedChanged`, `forget`, battery. Hub tile uses `rfkill` with an optimistic flip and a 3.5 s lock. No BlueZ agent, so PIN pairing needs blueman. |
| Audio | Quickshell.Pipewire: default sink volume/mute, `preferredDefaultAudioSink` for switching, BT sink detected by the `bluez_` prefix. Keys run `pamixer ±5`. |
| Brightness | sysfs file watch (watches `brightness`; a comment says `actual_brightness` sends no inotify) plus `brightnessctl set N%` with a floor of 1%. |
| Power | UPower display device and cell (health, rates). Performance button: `sudo -n auto-cpufreq --force=…` with rollback on non-zero exit (the README explains `-n` avoids `pam_faillock` lockouts). Power menu: `systemctl suspend/reboot/poweroff`, `hl.dsp.exit()`. |
| Displays | `hyprctl monitors all -j`; raw events (`monitoradded/removed[v2]`, `configreloaded`) with a 600 ms settle; `hyprctl eval 'hl.monitor{…}'` batched into one eval; remembers by description (or name), per-setup order and rotation; revert snapshot; known/guest/pair prompts; laptop-lid binds. |
| Screenshots | `grimblast copysave area|screen|output` (+`--freeze`) → `swappy`; `captureArea.sh` = `slurp` + `grim`, `wl-copy`, shutter sound, swappy overwrites the file, copied again. Hub snapshot waits 320 ms after closing the hub. |
| Recording | None. |
| Clipboard | `cliphist` with two `wl-paste --watch` watchers (text, image) started unless one already runs (pgrep). Previews classified by regex. Image thumbnails decoded to `~/.cache/quickshell/clip/<id>.png` (≤30, 7-day prune, failures remembered). IDs passed as argv, never put into the script string. |
| Wallpaper | `awww` (wipe from centre, step 90, 1.2 s). `papel` (Rust: walkdir, `image::resize_to_fill(256,256,Triangle)`, SHA-256 cache names, threaded socket streaming). `wallpaper.sh` sets each monitor, with an optional per-monitor override. Separate wallpapers for theme, reading mode and CRT mode via `wallpapers.conf`. |
| Weather | OpenWeatherMap `/data/2.5/weather` with curl `--max-time 5`, 30 min cache, cached fallback when offline, Nerd glyph by condition id and day/night. Also `wttr.in` in scripts and the pixel hyprlock; Open-Meteo in the Firefox page. |
| Calendar | Google → `vdirsyncer` → `.ics` → `khal list today 30d --format …`; past events filtered out by parsing the end time (AM/PM). EverCal app on click. |
| OCR | External `lens --no-decorations --sniper` on Super+S. Not in the repo. |
| Theme switch | `theme-mode.sh`: GTK3 ini, GTK4 symlinks, gsettings, cursor (GTK, gsettings, `~/.local/share/icons/default`, kcminputrc, xfconf, `hyprctl setcursor`), Plasma colour scheme, Kvantum, KDE icons, Dolphin/Thunar restart, kitty `SIGUSR1`, awww wallpaper, then touches `wallpaper_changed` and `theme_osd`. |
| Apps | `applist.sh` → `hyprctl dispatch hl.dsp.exec_cmd(...)`. Terminal apps run in kitty. |
| Updates | `checkupdates` (skipped while the pacman db is locked), click opens a kitty upgrade. |

---

## 6. Polish details

- **Empty states everywhere**:
  - Clipboard: "Nothing copied yet" / "No matches" / "cliphist is not installed" with the install command.
  - Network: "No networks in range" / "Turn Wi-Fi on to scan".
  - Bluetooth: "Looking for devices…" / "No new devices found" / "Unblock with rfkill…".
  - Sound: "No other outputs".
  - Notifications: "Another notification daemon is running".
  - Palette: "matugen not found" card with the install command.
  - Wallpaper: "starting backend…".
- **Destructive confirmations**: forget network or device uses an overlay card with No/Yes (Yes in red). Clipboard Clear needs a second click within 3 s ("Click again to clear"). Power menu has its own confirm mode with Yes selected by default.
- **Keyboard**:
  - Hub letters: d, l, n, s, w, m, i, t, a, b, Esc.
  - Drawer: type anywhere to search (Delete `\x7f` filtered out), Tab/Shift-Tab between tabs, arrows leave the grid at its edges back to search, Enter launches the first result.
  - Clipboard: Delete removes, Enter copies.
  - Monitor prompt: keys 1–4 pick a layout. Power menu: arrows, Tab, Enter, Space.
  - Stellarium SDDM: any key advances from the lock view.
  - Hint line at the bottom of the clipboard tab: "Enter copy   Del remove   Tab switch".
- **Hover**: age text swaps to a close glyph on toasts; trash button appears on hovered clipboard rows; hex tooltip on swatches; dock tooltips (opacity 150 ms, scale 0.9→1, y −4→0); every card gets a border on hover.
- **Feedback**: Material ripple on notification items; launcher flash; wallpaper "pulse ring"; refresh icon spins 360° in 600 ms; copy flash; check badge on the applied wallpaper; shimmer while thumbnails load.
- **Correctness touches**:
  - Expire vs dismiss: senders are told the truth.
  - A notification updated in place keeps its stack slot and history row.
  - A newer notification restarts the countdown.
  - Volume OSD shows a headphone icon for BT or headphone sinks; muted uses the critical colour.
  - Brightness changed by scripts (reading mode) stays silent; only user changes raise the OSD.
  - Optimistic toggles roll back.
  - Monitor apply sends the exact refresh rate (143.85 Hz, not 144).
  - Monitor prompt goes away when the screen is unplugged during pick.
- **Startup**:
  - Wi-Fi card paints from the cache before the first nmcli result.
  - App list loads 1.2 s after start, away from shell startup, and icons are warmed into the cache.
  - The bar waits for settings to load.
  - Power menu seeds a default style file.
- **Sounds**: startup wav, screenshot shutter, dunst notification and critical alert sounds.
- **Errors**: `[PaletteService]` warns once; the Wi-Fi panel shows the last 10 lines of nmcli output in a red box; installer error codes (E-61 etc.) with remedies.
- **Cursor nudge**: after any overlay maps or unmaps, the pointer is warped onto its own position so hover state updates.
- **Window borders** are hidden while the hub or rofi is open.

---

## 7. Port list for loka

Ordered by value ÷ effort. Effort means Rust on X11 with tiny-skia and x11rb.

| # | Idea | Why it is good | loka today (checked in source) | Effort | loka file |
|---|---|---|---|---|---|
| 1 | Toast timer counts only while the toast is fully shown and not hovered; a newer notification restarts it | Users can read and act; standard behaviour | `Toast.until` is a fixed `Instant`; expires under the cursor | S | `island.rs`, `app.rs` |
| 2 | Emit `NotificationClosed` reason 1 on expiry and 2 on dismiss; under DND, expire immediately; clamp sender timeout to 10 s | Firefox, Slack and others track state correctly | `closed()` only on action invoke or CloseNotification; toast timeout emits nothing | S | `notify.rs`, `app.rs` |
| 3 | Save history to JSON (≤50, write debounced 500 ms); relative age "now / 5m / 2h / 3d"; collapse per app with a count | Survives restart; compact list | In-memory `Vec`, time shown as `HH:MM` | S | `notify.rs`, `model.rs`, `pages.rs` |
| 4 | Detect a foreign owner of `org.freedesktop.Notifications` and say so in the empty state | Explains silent failure | Retries every 3 s silently | S | `notify.rs`, `pages.rs` |
| 5 | Spring token set (snappy / bouncy / smooth / gentle) next to FADE / STANDARD / SLOW | Same vocabulary for springs as tweens | One ad-hoc `Spring(0.42, 0.82)` | S | `anim.rs` |
| 6 | Reduce-motion setting: every spring becomes ζ = 1 with a shorter response | Accessibility at almost no cost | None | S | `anim.rs`, `config.rs`, `pages.rs` (settings) |
| 7 | Panel choreography: content fades in 70 ms after the panel; on close content leaves first (140 ms) and the panel only moves 20 px and scales to 0.97 | Text never slides with the frame; closing feels instant | FADE on content plus the size springs | S | `island.rs` |
| 8 | 300 ms colour cross-fade on world or mood change; derived colours read the target, not the animated value | World switches look intentional | `set_theme` swaps the palette instantly | S | `theme.rs` (Rgba lerp), `island.rs`, `bar.rs` |
| 9 | OSD anti-jitter: ignore level changes for 500 ms after a sink switch or start; hold the local value 400 ms during drag or wheel; throttle brightness writes to 40 ms | No false OSDs, no slider flicker | OSD on any level change > 0.004 | S | `app.rs`, `audio.rs`, `services.rs` |
| 10 | OSD icon pulse (scale 1.2 in 80 ms, bouncy back); glyph swap 0.7→1 | Each step is visible at a glance | Static glyph | S | `island.rs` |
| 11 | Ruler-style OSD: 11 ticks with majors at 0/50/100, triangle marker, large number with a small baseline-aligned unit | Elegant; suits the dot-matrix look | Bar/ring | S | `island.rs`, `dot.rs` |
| 12 | Press feedback: scale 0.90–0.95 about the centre on press, snappy back; icon on bouncy | The strongest "finished" cue | Colour-only hover tween (`ui.rs` `hv`) | M | `ui.rs` (`Hit` press state, `Transform::from_scale` about centre), `island.rs`, `bar.rs` |
| 13 | Letter hotkeys while the island is open (w, t, a, n, s, b, d/l) | Sub-second, no mouse | Tab/arrows/Enter/Esc only | S | `app.rs` (`key`) |
| 14 | Warp the pointer onto itself after an overlay maps or unmaps | Fixes stale hover | None | S | `x11.rs` (`WarpPointer`) |
| 15 | Smooth wheel scrolling with target accumulation (`|Δ|·1.1+20`, 500 ms OutExpo, grids snap to a row in 160 ms) plus a thin auto-hiding scrollbar | Long lists become usable | Pages truncate (`take(10)` / `take(12)`); no scrolling | M | `island.rs` (content offset), `pages.rs` |
| 16 | Staggered row entry (35 ms × min(i, 8), 240 ms OutQuart, 8 px rise); deleting collapses the row (height→0, 220 ms OutQuint) | Lists feel alive; deletions are legible | Rows appear and vanish at once | M | `pages.rs`, `ui.rs` (per-key appear map) |
| 17 | Notification stacks per app with an "N messages" pill; covered toasts expire after 2 s; criticals never stack; at most 4 | Survives message bursts | One toast slot; a new one replaces the old | M | `island.rs`, `app.rs` |
| 18 | Drag a toast right past 40% to dismiss; middle-click closes; otherwise it springs back | Natural with a mouse | Click only | M | `island.rs` |
| 19 | Clipboard kinds (image / link / colour / path / code / text) by regex: filter chips with counts, colour swatch, link host in accent, mono for code and paths; "Click again to clear" with a 3 s window; Delete key; copy flash then close | Faster to scan; safer clearing | Text rows plus image thumbnails; clear has no second-click guard | M | `clip.rs`, `pages.rs` |
| 20 | Album-art tint: average of 10×10 samples, mixed toward white 0.55 (dark) or black 0.25 (light), 400 ms fade | Media view matches the cover | Art thumbnail only | S | `island.rs`, `icons.rs` |
| 21 | Wavy progress line (amplitude 2.5 px, 0.15 rad/px, phase +0.22 per tick at 24 fps, only while playing; flat track after a 6 px gap); click or drag to seek, wheel ±5 s | Playing state readable; seek without opening an app | Flat progress, no seek | M | `island.rs`, `mpris.rs` (`SetPosition`) |
| 22 | MPRIS robustness: 60 s "recently paused" grace; optimistic play/pause with a 1.4 s lock; detect a new track by a rewind > 30 s | Browsers report noisy state | `mpris.rs` `pick()` / `same()` are basic | S | `mpris.rs`, `app.rs` |
| 23 | Night light: per-channel gain R 1.06, G 0.96, B 0.52 at strength 0.72 and ×0.88 dim, via RandR CRTC gamma ramps. Gamma ramps cannot do Hyprland's luma mask; a picom window shader can. | Native and cheap; no redshift | None | S | new `gamma.rs` (x11rb randr `set_crtc_gamma`) or `picom/.config/picom/shaders/night.glsl` + `rice` |
| 24 | More moods from these shaders as picom window shaders: Fuji Acros, Gameboy, dither, Silent Hill, Amano, greens, outdoor, cinema, smart invert | `rice mode` plumbing already exists; low cost | Night and paper moods only | S each | `picom/.config/picom/shaders/`, `rice` |
| 25 | Wi-Fi: paint the cached last status before the first nmcli result; PEAP/MSCHAPv2 profile creation; "Secrets were required" → password field; nmcli `-w` timeouts plus a 20 s watchdog message; forget confirmation | Fewer dead ends; works on campus networks | `wifi.rs` has connect, disconnect, forget | M | `wifi.rs`, `pages.rs` |
| 26 | Bluetooth: name equal to the MAC → "Unnamed device"; icon by device class; discovery only while the page is open; pair then auto-connect; forget confirmation | Cleaner list; no stray scans | BT page exists | S | `services.rs` (`bt_*`), `pages.rs` |
| 27 | Calendar page: next khal events (an event shows until it ends) and weather with a 30 min cache and offline fallback | At-a-glance day | Month grid only (`pages.rs` `calendar`) | M | `services.rs`, `pages.rs` |
| 28 | Bar launcher burst: flash 0.35→1 in 340 ms plus icon −9° springing back; the same pulse when the island is toggled from the keyboard | Links key actions to the bar | No equivalent | S | `bar.rs` |
| 29 | Workspace hover pill that slides between items (snappy), separate from the active pill; no animation on first layout; urgent glyph flash | Livelier bar | Width tween plus opacity | M | `bar.rs` |
| 30 | Power page: arrow/Tab navigation, explicit Yes/No step with Yes as default, destructive actions in red, header "@user · up 3 h" | Consistent with the rest | Second click arms ("Again") | S | `pages.rs` (`power`) |
| 31 | Monitor hotplug card: Extend / Duplicate / Laptop / External (keys 1–4), "remember this screen", 10 s Keep/Revert countdown with snapshot, toast for known screens, per-setup order and rotation, with two externals pick "externals only" after 15 s | Docking without a terminal, with safe revert | `RandrScreenChangeNotify` only resizes the bar | L | new `monitors.rs` (x11rb randr or `xrandr`), new island page |
| 32 | Locker ideas: a random astronomy glyph per typed character (OutBack pop 240 ms); emblem states idle / typing (3.4 s orbit) / auth (1.2 s orbit) / ok (sun bloom) / wrong (shake plus meteor); moon phase footer computed locally | Delightful lock screen | `lockscreen/lock.sh` | L | separate binary, not loka (security-sensitive input grab) |
| — | **Wayland-only, cannot port as-is:** Hyprland full-frame `screen_shader` (closest X11 match is picom per-window shaders); layer-shell namespaces and layerrules; `hyprctl eval` monitors (use RandR); Hyprland global shortcuts (use i3 `bindsym` → `loka msg`); hyprlock/hypridle (xss-lock or xidlehook); `wl-paste --watch`/cliphist (loka already uses XFixes + xclip); grimblast (maim/slop already used); awww transitions (mathwall already has its own); Hyprland spring window animations (picom); hyprcursor. | | | | |

Not added because loka already has it: battery health, cycles and history (`pages.rs` `battery`, `services.rs` `battery_details`); sink, source and stream mixer (`audio.rs`); charging, connect and low-battery toasts with sounds (`app.rs`); captive-portal check; clock flip.

---

## 8. Licence

- **No LICENSE file anywhere in the repo.** By default, copyright stays with the author (@snes19xx): all rights reserved.
- **README "Reuse Note"**: *"Feel free to copy/steal whatever you want as long as you cite me and more importantly the listed media sources in the credits/references where applicable."* This is informal, conditional permission: use it with attribution. It is not a standard licence. It says nothing on warranty, sublicensing or redistribution terms, so treat its scope as uncertain.
- **Third-party parts it cannot grant**:
  - Everforest GTK (Fausto-Korpsvart), Kvantum materia-everforest, Everforest Pro VS Code theme: check each upstream licence.
  - `PixelDots.qml` (based on mahaveergurjar).
  - Unsplash/Flickr/Pexels photos (their own licences); Pinterest rofi images (owners unknown; do not reuse).
  - Cassini photos (source not stated).
  - CMU Typewriter (SIL OFL).
  - Dave Hoskins' "Hash without Sine" (MIT on Shadertoy; keep the notice).
- **What this allows in practice**:
  - **Ideas, behaviours, timings, curve choices and numbers** (everything in sections 3–7): free to use. These are not copyrightable expression.
  - **Re-implementing in Rust** for loka is a new work; crediting surface-dots in the README is still polite and matches the stated condition.
  - **Porting the GLSL shaders to picom** is a derivative of the code. It is covered only by the reuse note: put a header crediting @snes19xx in each ported shader, plus the Hoskins MIT notice for the hash.
  - **Do not copy assets** (wallpapers, Cassini plates, cursors, SVG icons, fonts) without checking each one's own licence.
