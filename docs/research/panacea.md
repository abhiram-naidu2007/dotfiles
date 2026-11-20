# Panacea: study report for loka

**Repo:** EnsixD/Panacea, version 1.0.24 (commit `2d68047`). It is a Quickshell (QML) shell for Hyprland with a Lua config; Niri support is experimental. About 45k lines of QML plus about 7k lines of shell and Python. The code comments are in Russian (a few in Italian).

**How much I read.** I read every line of `shell.qml` (7.9k), `lock.qml`, every small component, all motion and theme code, and every system script under `panacea/scripts` and `bin/`. For the largest views (FilesView, the back half of ControlsView, LaunchpadView, MediaView, the Set* pages, `install.sh`, `update.sh`) I read every comment and every animation line, and read in full only the sections that matter for this report. I skipped binaries, wallpapers, `.pf2` fonts and `Translations.qml`.

**What is not in the repo:**
- There are no `.frag` or GLSL files. The only shader is generated at runtime by `vibrance.sh`.
- `adaptive-colors.py` is referenced but missing.
- There is no idle daemon: the lid switch triggers the lock, and nothing else does.

---

## 1. Architecture

**One process, one root object.** `panacea/shell.qml` is a `ShellRoot` holding one full-screen `PanelWindow` (layer Overlay) that contains the island, plus sibling layer windows:
- wallpaper crossfade (Bottom layer)
- overview, launchpad, wallpaper carousel and keys sheet (lazy, Overlay)
- "What's new"
- file-operation progress
- weather details
- desktop widgets (Bottom layer)
- a scratchpad dismiss layer (Background)
- the screenshot freeze frame (one window per screen)
- floating file-manager windows

**Shared state lives on `root`.** Every view gets `sys: root` and reads and writes root properties. The root owns every long-lived `Process`. Pages are created by a Loader and destroyed on collapse, so a Process inside a page died before pkexec or the lock screen could start. The comments document this bug many times; that is why commands run from the root or through `Compositor.exec` (`hyprctl dispatch exec`).

**Pages.** `root.page` is a string (`main|wifi|bt|battery|netmenu|traymenu|launcher|settings|clip|power|notif|audio|cal|record|files|media|quickfile|auth|vault|vaultsave|agents|chat|vpn`). One `Loader` (`shell.qml:6965`) maps it to `*View.qml`. `expanded`, `holdOpen` (pinned, keyboard Exclusive, full input mask) and `settingsMode` (panel leaves the edge and centres) control the geometry.

**Config.**
- `~/.config/panacea/settings.json` is loaded through `FileView` with `watchChanges` and a `JsonAdapter` that declares every key with a default (`shell.qml:37-331`).
- `writeAdapter()` saves; the `onSaved` signal triggers dependent generators (`genbinds.sh`, `geninput.sh`) so they never read a half-written file.
- `defaultCfg` drives the "reset all" button.
- The installer merges user and default settings with `jq`.
- `feat*` flags gate both the UI and the services: with `featNotifications=false` the NotificationServer is never created, so mako or dunst keeps the bus. Polkit works the same way.

**Theming.**
- `Themes.js` (shared with `lock.qml`) has one theme, "nothing": bg `#000000`, fg `#ffffff`, on `#ffffff`, crit `#d71921`.
- An optional `~/.cache/panacea/adaptive-colors.json` overrides background, text, accent, secondary and error. Its values are validated against `^#[0-9a-f]{6}([0-9a-f]{2})?$` and the file is watched, so it recolours live.
- Derived colours: `colMuted = fg α cfg.mutedAlpha(0.45)`, `colLine = colHover = fg α0.10`. `fgOn(c)` picks ink by Rec.709 luma > 0.6.
- Terminal and editor colours come from a separate `hypr/palette.conf`, spread by `palette.sh`. Changing the wallpaper never recolours anything.
- The SDDM greeter cannot read `~`, so the shell writes `/var/lib/panacea/accent.qml` and `locale.qml` as tiny QtObject files, which the greeter loads with a Loader.

**Compositor abstraction.** `Compositor.qml` (singleton) exposes `workspaces`, `focusedWorkspace`, `focusedMonitor`, `toplevels`, `isFullscreen`, `keyboardLayout` and the actions `focusWorkspace`, `exec`, `closeActive`, `switchLayout` and `exit`:
- Hyprland branch: `Quickshell.Hyprland` plus `hyprctl`, with the Lua dispatcher `hl.dsp.*` and a fallback to the legacy syntax. The fallback is decided by output text, because both parsers exit 0 even on failure.
- Niri branch: the `niri msg --json event-stream` CLI, chosen over the raw socket because the CLI is the stable public contract.

**IPC.** `IpcHandler { target: "pill" }`. Scripts call `qs -c ~/.config/panacea ipc call pill <fn> [args]`. Functions:
- open pages: `launcher overview launchpad controls chat chatService wifi bluetooth settings settingsAt shortcuts clipboard powermenu weather weatherClose notifications audio calendar theme record files filesAt passwords agents media`
- actions: `smartClose cancelCapture freeze unfreeze shotCopied mediaCrop recordToggle dnd brightness motion nightlight themeReload widgets close`
- voice: `voxListening voxTranscribing voxDone voxUnavailable`
- tests: `testBtToast testWifiToast testBtLowBatt`

Scripts answer in `key=value` lines or `a|b|c` rows. Error codes, not prose, cross the boundary so the UI can translate them.

**Privileges.** `/usr/local/lib/panacea/panacea-root` (owned by root) runs through `pkexec`. Its polkit action uses `auth_admin_keep`, so you enter the password once and further requests pass for a few minutes. Verbs: `sddm, self, update, charge-threshold, timezone, ntp, settime, locale, boot`, each with strict argument regexes. The legacy path is a plain `pkexec <script>`.

**Lifecycle.**
- `panacea-shell.service` (`Restart=on-failure`) runs `start.sh`, which preloads `webengine-argv.so`, a C++ shim that fixes an empty argv for QtWebEngine.
- `restart.sh` runs outside the service cgroup.
- `genmonitors.sh` writes `monitors_data.lua` so the refresh rate is set before Qt starts. Qt binds its animation timer to the refresh rate of the first window; without this the shell animated at 60 Hz on a 144 Hz panel.

## 2. Feature inventory

**Island and core (`shell.qml`)**
- Collapsed bar (Nothing layout): recording dot, workspace dots, optional weather, centred dot-matrix clock, optional CPU/GPU load, LAN or Wi-Fi glyph, flipping keyboard-layout letters, volume with dot digits, battery with dot digits.
- Vertical island at the left or right edge: text stacked letter by letter, never rotated (`VertText`).
- Island position top, bottom, left or right; expansion always grows towards the centre.
- Island drag-to-edge: grab handle, edge highlight, snap to the nearest edge within 25 % of the screen.
- Auto-hide: a 4 px reveal strip at the edge. Overlay mode (no exclusive zone). "Keep visible": the panel opens as a separate floating card.
- Hides over fullscreen windows; Hyprland events plus a 5 s poll as backup.
- Collapsed-state cards: notification toast, agent approval toast, Bluetooth toast, Wi-Fi toast, AC/low-battery toast with wave, monitor picker for recording, voice-dictation capsule, OSD bar, night-light OSD.
- Drag a file onto the island: dashed drop outline, a 130/260 ms "absorb" animation, then Quick File actions (`QuickFileView.qml`, `quick-file.py`: copy, compress, extract and so on).
- Mascot (`Mascot.qml`): two pill-shaped eyes follow the cursor, blink, glance around when idle, and sleep.
- Global tooltip drawn by the root, because the panel clips its own children.
- Tabs Home, Chat and VPN in quick settings (`IslandTabIcon.qml`).

**Pages (`panacea/*View.qml`)**
- `ControlsView.qml`, quick settings. Block order is user-defined (`ccLayout`): clock (opens the calendar), toggles (Wi-Fi or LAN, BT, sound card), sliders (brightness per display plus night-light button), media card, power (record card plus battery tile or load card), quick row (keep-awake, lock, notifications with badge, settings), tray. Sub-pages: wifi, netmenu, bt, battery, traymenu.
- `LauncherView.qml`: app search (prefix matches first, recents when the query is empty), built-in rows (Agents), calculator, web search as the last row, boot into another OS. The "ask AI" row is currently disabled (`isAsk: false`).
- `LaunchpadView.qml`: full-screen app grid over a blurred screenshot, pages, folders made by drag-and-drop, right-click menu, layout saved in `~/.local/share/panacea/launchpad.json`.
- `OverviewView.qml`: live previews of every workspace through `ScreencopyView`; arrows or digits to switch.
- `WallpapersView.qml`: carousel for stills and videos, parallax, add your own, delete your own, open the live-wallpaper folder.
- `NotificationsView.qml`: one history list, DND button, clear-all, click invokes the "default" action and focuses the app.
- `ClipboardView.qml`: cliphist history, type detection (hex colour swatch with RGB/HSL copy, URL, file, image thumbnail), pins in `clipboard_pins.json`, link to the vault.
- `CalendarView.qml`: always 42 cells so the grid never jumps; Monday first; today highlighted; "back to today".
- `PowerView.qml`: press once to arm, press again to confirm. Lock is instant. Sleep is drawn as a "zZz" triangle.
- `AudioView.qml`: master volume, output device picker, per-app mixer (`audio_streams.sh` parses `pactl list sink-inputs`).
- `RecordView.qml`: FPS, folder, system audio, mic toggle and device, timer, open folder.
- `FilesView.qml`: file manager with bookmarks, disks and removables (udev push), sort/order/dirs-first, list or grid, hidden files, trash with count, archives, properties, multi-select bar, copy/cut/paste shared across windows, system drag-and-drop, conflict dialog, "open with" list. Also usable as a separate window or a picker.
- `MediaView.qml`: image, GIF and video viewer; crop rectangle with handles; video trim with in/out markers; save via ffmpeg (`media.sh`); OCR button (`ocr.sh`).
- `QuickFileView.qml`: actions on dropped files.
- `AuthView.qml`: polkit password prompt inside the island; refocuses after a wrong attempt.
- `VaultView.qml` and `VaultSaveView.qml`: password manager; clipboard-capture prompt "save this password?".
- `AgentsView.qml`: AI-agent plan and rate-limit bars (`agents.sh` reads the local files of AI coding agents). Never prints account email or IDs, because the island may be visible during screen sharing.
- `ChatView.qml`: OpenAI-compatible chat with attachments (`chat.py`, `chat-paste-image.py`); `IslandWebView.qml` wraps QtWebEngine.
- `VpnView.qml`: NetworkManager VPN profiles, a client toggle for the Happ app (`happ_control.py` drives its tray menu over DBus), and a GeoIP country code on the tab.
- `WeatherDetailsView.qml`: hourly and 7-day forecast (`weather_forecast.sh`, with cache).
- `WidgetsView.qml` and `MusicWidget.qml`: desktop cards. Date card (dot number, red weekend), analog clock with 12- or 24-dot dial, red second hand and "donut" hub (toggles to a dot digital clock), weather card, concentric RAM and SSD rings, a 24-segment day / 12-segment year "life bar" with the current hour pulsing, a music card with a spinning vinyl, and a scratchpad with autosave.
- `WhatsNewView.qml`: shown once after an update. Translated commit titles, missing or obsolete packages with a copyable command, list of user-edited files kept.
- `SettingsView.qml` plus `Set*.qml`: sections searchable by keyword, browser-like back and forward history, a live desktop mock-up (`PillMock.qml`), and the real ControlsView as a drag-reorder preview. Sections:
  - Bar & Island (notch mode, flare, sizes, gap, radius)
  - Clock (12/24 h, seconds, weekday, timezone, date format, NTP, set time)
  - Appearance (language, widgets, terminal alpha, fonts, sounds with preview)
  - Motion
  - Launcher (search engine, AI URL, model and key)
  - Notifications
  - Control Center
  - Lock
  - Display (mode, rate, scale, transform, VRR, position, brightness per screen, vibrance, night light with schedule, which screen gets the island)
  - Input (mouse sensitivity, flat acceleration, xkb layouts, variants and options validated by regex)
  - Media, VPN
  - System (live load, update, default browser, machine info, two-press reset)
- `SetKeys.qml` in its own full-screen layer (Super+/): every binding, rebindable, `capture.sh` empties Hyprland's submap while a key is recorded.

**Separate programs**
- `panacea/lock.qml`: `WlSessionLock` lock screen.
- `sddm/panacea/Main.qml`: login theme (capsule, session picker, power buttons, hand-drawn spinner).
- `grub/panacea/`: theme plus `make_assets.py` (darkened, vignetted background; capsule highlight 9-slices).

**Background services inside the shell:** notification server, polkit agent, MPRIS selection, UPower, PipeWire, BlueZ, system tray host, udev monitor, cliphist watcher (vault capture), update checker (45 s after start, then every 6 h), weather (every 15 min), load (2 s open, 5 s closed), Wi-Fi status (4 s open, 15 s closed), power profile (10 s / 30 s), VPN (4–15 s), GeoIP (3 min).

**Helpers in `bin/` and `hypr/`**
- `smart_volume.sh` / `smart_brightness.sh`: steps that accelerate while the key is held.
- `battery_mode.sh`: 120 Hz with VRR, no effects, reduce motion.
- `notify`: an agent "waiting" notifier.
- `amd_s2idle.py`: vendored AMD suspend diagnostic.
- `pack_workspaces.sh`: renumber workspaces to close gaps.
- `live_wallpaper.sh`: mpvpaper.
- `switch_theme.sh`: wallpaper only.
- `palette.sh`: one palette to foot, fish, btop, nvim, zed, fastfetch and the greeter.
- Fish prompt, foot server config, fastfetch, nano.

## 3. Motion and feel

**Tokens** (`shell.qml:1592-1603`, user-tunable in `SetMotion.qml`):

| token | default | slider range | use |
|---|---|---|---|
| `animMs` (animMove) | 230 ms | 80–900 | size and position |
| `animFade` | 200 ms | 40–600 | opacity, colour |
| `animHover` | 150 ms | 20–400 | hover |
| `animFast` | 0.52·animMs ≈ 120 ms | – | content cross-fades |
| `animQuick` | 0.48·animMs ≈ 110 ms | – | height changes inside a page |
| `animBounce` | 0 % in `defaultCfg` (79 % in the adapter) | 0–100 | OutBack overshoot = bounce·1.7 |

"Reduce motion" sets every duration to 0: motion disappears instead of speeding up. Battery mode calls `ipc motion off`.

**Island morph** (`shell.qml:5379-5395`)
- Width: `OutBack` when bounce > 0, otherwise `InOutCubic`, over `animMs`.
- Height: while `morphing` (page or expand change) it uses `animMs` with InOutCubic. Otherwise, for a page growing in place, it uses `animQuick` with OutCubic. `morphing` stays true for `animMs + 140` ms, because the new page reports its height a frame or two late.
- Height coalescing: `contentSettle` waits 24 ms to merge multi-pass layout heights. Changes under 8 px are ignored, because each new target restarts the Behavior and the growth would become steps.
- Corner radii and edge margins: InOutCubic, `animMs`. Collapsed radius = pillH/2; open radius = 26.
- Content: opacity in `animFast` with OutCubic, out in 90 ms. Content width is taken from the target panel, not the animated capsule, so text never reflows mid-morph.
- Concave corners hide at once and reappear only `animMs + 40` ms after the island lands, so they never look like stickers flying in.
- Even-pixel width rounding (`evenUp`) and `Math.round` corner x positions prevent a half-pixel grey seam.
- Detached panel: opacity `animFade` (×0.75 on close), scale 0.96→1, 10 px translate towards the island; OutBack or OutCubic.

**Hover logic** (`shell.qml:5400-5496`)
- Expand on hover after 0 ms; collapse after 180 ms off. If the panel is still morphing, the collapse timer restarts, because Wayland sends spurious leave events while the input mask changes.
- After you click a notification, drop a drag, or the island slides out of hiding, hover-expand is disarmed. It re-arms after 450 ms off the island, or after the pointer moves 12 px (Manhattan) from the point where it was disarmed.
- `hoverPad` keeps the collapsed pill's footprint in the input mask while expanded. Without it, a wide pill under a still cursor would flap between bar and panel forever.
- With auto-hide on, hover only reveals the island; a click expands it.

**Small motions**

| element | numbers |
|---|---|
| Buttons | scale 0.9 pressed, 1.06–1.08 hover, 130–140 ms OutBack; colours 150–180 ms |
| Tooltips | opacity 130–140 ms, scale 0.92→1, 150–160 ms OutBack, origin at the anchor side |
| `FlipText` (layout letters) | 190 ms: old text up and out in 45 % with InCubic; swap; new text up from below in 55 % with OutCubic; width InOutCubic |
| Workspace dot | width 6→17 px over `animMs` OutCubic, opacity 1 / 0.6 hover / 0.3; animation disabled until `Component.onCompleted`, so a new dot does not "slide in" |
| Recording dot | opacity 1↔0.25, 620 ms InOutSine, loop |
| Voice mic glyph | opacity 1↔0.35, 500 ms InOutSine while transcribing |
| Charging bolt | opacity 1↔0.4, 750 ms |
| Life bar current hour | 1↔0.30, 750 ms InOutQuad |
| Ring fill (BT battery, Wi-Fi quality) | 0→level, 900 ms OutCubic; 3.5 px stroke, round cap, from −90°, track at α0.22, red at ≤20 % (BT) or ≤25 % (Wi-Fi) |
| OSD | 1700 ms life; bar width Behavior 120 ms OutCubic; suppressed for the first 1500 ms after start and for 700 ms after a sink change |
| Toasts | Bluetooth and Wi-Fi 2500 ms, low battery 3500 ms, AC 2300 ms |
| Loading placeholder | opacity 0.35↔1, 620 ms |
| Image fade-in | 260 ms OutCubic |
| Spinners | 700 ms (VPN arc) and 900 ms (refresh, lock spinner) per turn |

**Equaliser bars** (`WaveBars.qml`, `CavaSource.qml`)
- One cava process, reference-counted, killed 20 s after the last viewer leaves.
- 32 bars, 60 fps, sensitivity 140, monstercat 2.2, noise reduction 0.45, ascii 0–100, gain ×1.25.
- Height = `pow(level, 0.6)·H`, so quiet passages stay visible. A 90 ms OutCubic Behavior smooths between the 33 ms frames. Opacity = 0.55 + 0.45·h/H.
- No cava: two out-of-phase sines, `0.45 + 0.34 sin(t + 0.85i) + 0.18 sin(1.7t + 1.9i)`.
- On pause: levels decay ×0.92 per 33 ms, floor 0.08.
- Microphone version: 16 bars, sensitivity 260, gain 1.4, 2.5 s linger, 60 ms OutQuad.

**Sliders** (`ControlsView.Track`)
- The fill is the handle.
- The value you set is held for 400 ms, so slow PipeWire or DDC confirmations cannot snap the fill backwards.
- Wheel steps of 5 % are counted from the slider's own mark, kept for 260 ms between ticks.
- No animation while dragging or during the first 260 ms after creation.
- Hardware writes are debounced: brightness 180 ms, vibrance 160 ms, terminal alpha 180 ms, night-light temperature 180 ms. Only the value where the hand stops is sent.

**Media seek bar.** Between 500 ms MPRIS polls the position animates linearly for 520 ms. The position is sent only on release, because the MPRIS client fights intermediate seeks. The bar is the spectrum itself: 46 bars, with the played part as an accent copy clipped to the playback fraction.

**Full-screen overlays grow out of the island.** The keys sheet and the wallpaper backdrop start at `pillRect{X,Y,W,H}` with radius h/2 and animate x, y, w, h and radius over `animMs` with OutQuint to the full card. The card content fades in after it. `WeatherDetails` uses scale 0.92→1 with OutBack (overshoot 1.15) over 250 ms, y offset 28 px, opacity 200 ms, and a 0.65 scrim.

**Wallpaper carousel**
- Position: 420 ms OutQuint.
- Each card: scale `max(0.5, 1 − 0.16|d|)`, opacity `1 − 0.34|d|`, darkening `min(0.55, 0.3|d|)`.
- Parallax: the image is 1.28× the card width and offset `−0.14W + d·step·0.22`.
- Wheel accumulator: one step per 120 units, capped at ±240, with a cooldown; it resets when the direction changes.
- Wallpaper change: a snapshot of the old wallpaper appears instantly on the Bottom layer, then fades out over 700 ms with InOutCubic. This gives a true crossfade with hyprpaper.

**Launchpad**
- Paging: target `pagePos` with 460 ms OutQuart. The displayed position follows it every frame with `k = 1 − exp(−dt·26)`.
- Rubber band: movement ×0.3 past the edges, clamped to ±0.35 page.
- Flick: velocity EMA 0.5/0.5; changes page if |v| > 0.9 pages/s or the drag moved more than 0.12 page.
- Intro wave: 560 ms. Tile delay = `(row + col)/(rows + cols − 2)·0.45`, local window 0.55, cubic-out; scale 0.82→1. Backdrop fade 220 ms OutCubic; grid revealed 40 ms after the screenshot is captured.
- Pages away from the current one: opacity `1 − 0.45·dist`. Page dots: width `8 + 14·near`.
- Folder opens with OutBack, overshoot 0.8. The merge target scales 1.08, then 1.18 when armed.

**Lock screen**
- Idle state: sharp wallpaper, dim 0.35. Typing state: blur 0→1 over 420 ms OutCubic (`blurMax = lockBlur 32`, multiplier 0.85), dim 0.55, clock block rises 60 px.
- Capsule: width 150→420, 380 ms OutBack, scale 0.92→1.
- Each password dot pops in: scale 0→1, 180 ms OutBack.
- Wrong password: shake −9 → +9 → 0 px, 55 ms per step, 2 loops; the border turns red.
- "Press Enter" breathes: scale 1.04 over 1100 ms InOutSine.
- After a successful unlock it waits 220 ms (so the compositor can drop the lock), then quits.

**Mascot.** Eyes 7×21 px rounded rectangles; sleeping eyes 11×3. Blink every 3.7 s for 150 ms. Gaze follows `hyprctl cursorpos`, polled every 60 ms (±4 px x, ±3 px y, 85 ms OutCubic). Random glance after 4.5 s idle. Awake 150 s, then asleep for 120–360 s.

**Hyprland window curves** (`hypr/lua/animations.lua`): `myBezier (0.05,0.9,0.1,1.05)`, `easeOutQuint (0.23,1,0.32,1)`, `liquid (0.16,1,0.3,1)`; windows use "popin 80%".

**What makes it feel finished:**
- One geometry: every page is the same capsule at another size.
- Separate duration tokens for travel, colour and hover.
- Coalescing of layout jitter (24 ms, 8 px).
- Animation never runs on first appearance (`settled`, `primed`, `live` flags).
- Values shown under the hand ahead of hardware confirmation.
- Reserved widths: `TextMetrics` sized for the widest string, five workspace slots always reserved, a fixed-width OSD icon. Nothing jitters as values change.

## 4. Visual techniques

**Shader.** The only one is `vibrance.frag`, written by `vibrance.sh` and passed to Hyprland's `screen_shader`:
- `lum = dot(rgb, Rec709)`, `sat = max − min`, `out = mix(lum, rgb, 1 + S·(1 − sat))`, with `S = (pct − 50)/50`.
- Already-saturated colours move less, which is the difference between vibrance and plain saturation.
- The GLSL dialect is chosen by grepping the Hyprland binary for `#version 300 es`. The file is ASCII only, because NVIDIA's compiler rejects non-ASCII bytes even in comments. Writes are tmp-then-rename, so Hyprland never reads a half-written file. At 50 the shader is removed entirely, so "off" costs nothing.

**Shapes**
- `NotchCorner.qml` (Canvas) and `NotchShape.qml` (Shape, used inside layer-masked mock-ups, where a Canvas never paints): an r×r square minus a quarter circle centred on the outer bottom corner, with r = `notchFlare` 12. Mirrored with `Scale` for bottom or side edges.
- Capsule: square corners on the screen edge, rounded on the free side. Collapsed radius = pillH/2, expanded radius 26, all corners 26 in centred settings mode.
- The drop outline uses `PathQuad` corners so the dash pattern continues around the corners.
- `LanGlyph` draws a wired-network icon from rectangles with an integer stroke (1 px when ≤20 px tall), because the Nerd Font glyph's crossbar reads as a smear.
- `IslandTabIcon` holds hand-written SVG paths for home and chat.

**Dot-matrix type** (`DotText.qml`)
- Glyphs on a 5×7 grid: digits plus `: . - % ° space A P M`, drawn as circles because square dots look like an 80s pixel font.
- Dot diameter `d = size/(7 + 6g)`. The gap ratio g is the font weight: 0.4 sparse, 0.22 regular, 0.1 bold.
- Width is computed from columns, not from the last lit dot, so "1" and "7" do not change the width.
- `DotIcon.qml`: 13×7 weather silhouettes (clear, clear night, few clouds, cloud, rain, snow, storm, mist). The cloud is asymmetric (left bump lower, right side one dot taller) so it does not read as a brick. Unknown codes fall back to the cloud.

**Canvas effects**
- Charge wave: two filled sines. `y = base + 3.2 sin(kx + φ + off) + 1.6 sin(1.9kx − 0.7φ)`, with k 0.055 and 0.041, off 0 and 0.7π, alpha 0.16 and 0.11. The phase advances 0.16 every 45 ms. The level is clamped to 0.12–0.92. Each wave is clipped to the capsule's actual corner radii with `arcTo`.
- Analog widget clock: 12-dot dial with a double dot at 12; hour hand 0.38r capsule, minute hand 0.78r; red second hand with counterweight; donut hub with a red centre.
- RAM and SSD as concentric arcs (r 31 and 21, 4 px wide).

**Masks and blur**
- Rounded image masks: the source in an invisible `layer.enabled` item, a white rounded Rectangle as the mask, `MultiEffect maskEnabled` (`MaskedShot.qml`). `clip` only clips to the bounding box, which left sharp corners on album art and wallpaper cards.
- Blur: Launchpad uses `ScreencopyView` (one persistent capture; it only asks for a new frame) into `MultiEffect` with blurMax 64, multiplier 1.2, saturation 0.15, plus black at 0.32. The lock screen uses blur on the wallpaper. Hyprland's own blur is off in `theme.lua`.

**Typography.** JetBrainsMono Nerd Font everywhere (body and display fonts can be changed; the icon font is always the Nerd Font). Base 15 px, icons 17 px. Labels −3 to −5 px. Section captions 9 px uppercase with letter-spacing 1.2. Bold for titles. `Glyph.qml` centres Nerd Font icons by their ink box (`tightBoundingRect` relative to the baseline), at rounded positions, with full hinting.

**Colour**
- Monochrome on purpose: meaning comes from brightness. `tint()` returns fg for every state colour. Red `#d71921` is reserved for recording, low battery and errors.
- An "on" tile fills solid with the accent and inverts its ink using `fgOn`.
- Dot sizes are offsets from the font size, not ratios: big +10, clock −1, small −3, tiny −5.
- No palette is generated from the wallpaper inside the repo; the adaptive JSON is an external hook.

## 5. System integration

| Area | How |
|---|---|
| Lock | `lock.qml` in its own quickshell process: `WlSessionLock` (ext-session-lock), `PamContext config:"swaylock"`. `lock.sh` caches a 1920-wide wallpaper copy (`thumbs.sh lockbg`), keeps a step log in `~/.cache/panacea/lock.log`, guards against a second instance, sets `QSG_RENDER_LOOP=threaded`. The lid switch triggers it. No idle timer. |
| Keep awake | `systemd-inhibit --what=idle:sleep:handle-lid-switch sleep infinity` while the toggle is on. |
| Polkit | Quickshell `PolkitAgent` in a Loader, prompt in `AuthView`; only one agent per session. |
| Notifications | Quickshell `NotificationServer`: body markup, images, actions, persistence. History capped at 50. A `transient` hint or own screenshots skip history. An app closing a notification removes it from history. Toast queue; critical notifications pass DND; notifications from AI coding agents also feed the agent event list. |
| Agent approval | `agent-approval.py` is a `PermissionRequest` hook for AI coding agents. Only for single-line shell commands ≤75 characters, and only when the agent's terminal is not focused (checks ancestry of `hyprctl activewindow` PID). Sends `notify-send` with `panacea-allow` / `panacea-deny` actions and a 30 s expiry; the island shows ✓ and × plus a countdown bar. `setup-agent-hooks.py` merges the hook into existing settings. |
| Media | Quickshell `Mpris`. Sticky player: the playing one wins, else the previous one if still alive, else any. Remembers the last non-empty art URL per track so art does not flicker on pause. |
| Network | `wifi.sh` supports NetworkManager (`nmcli`) or iwd (`iwctl`/`iw`/`rfkill`). Retry polling at 800 ms ×15 after connect. Wired detection: sysfs `type==1 && carrier==1`, skipping docker, veth, br, virbr, tun, tap, wg, zt and tailscale. Captive portal: `curl generate_204` up to 4 tries, then `notify-send -A open=Log in` and `xdg-open`. |
| VPN | `vpn.py`: NM profiles of type vpn/wireguard, geo country, Happ tray-menu control. |
| Bluetooth | Quickshell `Bluetooth`: `rfkill unblock bluetooth` before powering on (250 ms delay), `pairable=true` plus discovery for 12 s, trust then pair then connect. Device type guessed from icon and name; battery ring; low-battery toast at ≤20 % (re-arms above 25 %). |
| Audio | Quickshell `Pipewire` (default sink/source, volume, mute, sinks). Per-app mixer through `pactl` sink-inputs. OSD on any volume change, not only on key presses. |
| Volume and brightness keys | `smart_volume.sh` and `brightness.sh up/down`: step 5 %, 10 % after 4 repeats, 20 % after 10, repeat gap <280 ms. Snaps to multiples of the step (wpctl relative steps keep values like 43→48). Volume up unmutes. |
| Brightness | Backlight through `brightnessctl`, else DDC/CI through `ddcutil` with a cached bus-to-connector map and an explicit `--bus`. Monitors that do not answer VCP 0x10 are hidden. |
| Power | UPower `displayDevice`; real-battery detection via `isLaptopBattery` (mouse batteries excluded). Profiles via `busctl` to `net.hadess.PowerProfiles` (works with tlp-pd or power-profiles-daemon), polled after set because tlp-pd applies asynchronously. Charge thresholds through the root helper. `battery-info.py` keeps a 24 h history at 5 min resolution in `~/.local/state`. |
| Screenshots | `shot.sh`: `grim -t ppm` to tmpfs → `ipc freeze` shows that frame on every screen (scaled into logical bounds) → `slurp` → `shotcrop.py` crops the original file (no second capture, so night-light and vibrance cannot leak in) → `wl-copy` → `ipc shotCopied` → notification using the shot as its icon; clicking it opens the media viewer; shutter sound. Falls back to the live screen. |
| Recording | `record.sh` with wf-recorder: codec fallback chain x264 → vp9 → vpx → default, each attempt checked alive after 0.5 s. System+mic mix through a temporary `module-null-sink` and two loopbacks. Pause = SIGSTOP/SIGCONT with paused-time bookkeeping. State file, so the shell can restart mid-recording. Stop = SIGINT and wait up to 5 s. Finalize: silent AAC track if there is no audio (messengers treat silent mp4 as GIF) plus `+faststart`. Monitor picker card when there are several screens. |
| Clipboard | `cliphist` (`wl-paste --watch cliphist store`, trimmed to 500 entries), pins JSON. |
| Vault | AES-256-CBC with PBKDF2 at 240k iterations via `openssl`; password through a 0600 tmpfs file, never argv or env; verified with PAM first; JSON array checked with `jq`. Locks after 15 min idle; pending saves flushed before forgetting the key. `wl-copy --sensitive-data` and clipboard cleared after 60 s. Clipboard watcher suggests saving strings that look like passwords (8–128 chars, no spaces, not a URL, path, number, single word or e-mail, ≥3 of 4 character classes) and labels them with the active window class. Imports from Firefox (libnss3) and Chromium (Secret Service key). |
| Wallpaper | hyprpaper and `switch_theme.sh`; `mpvpaper` for video (posters from a mid-frame); ffmpeg thumbnails 1100 px cached by mtime. |
| Night light | `nightlight.sh`: hyprsunset (`hyprctl hyprsunset temperature/identity`) or wlsunset on Niri; 2500–6500 K; schedule window that wraps past midnight, checked every 30 s, switches only on window edges so a manual toggle is not undone. |
| Weather | OpenWeatherMap when a key is set, else Open-Meteo with geocoding (no key); WMO codes mapped to OWM icon codes; 15 min interval; refetched on language change. |
| OCR | `ocr.sh`: tesseract with rus+eng chosen automatically. Pillow preprocessing: EXIF transpose, alpha on white, upscale to ~12 MP (cap ×3), grayscale, contrast 1.5, unsharp mask; PSM 6 for wide short strips, else 3. |
| Voice | voxtype (whisper.cpp, Silero VAD) on Right Alt held; island capsule with a mic cava; start and done sounds; 8 s guard. |
| Removables | `udevadm monitor --udev --subsystem-match=block` → automount (700 ms) and a disk-list refresh (250 ms); udiskie; safe eject refused while a write is in progress. |
| Files | `files.sh` (places, trash, archives, mounts, open-with via .desktop); progress protocol `PROGRESS pct done total / FILE / PHASE sync / SYNC / ERROR code / CANCELLED`; speed EMA 0.7/0.3; ETA; FAT32 4 GB and "into itself" checks. |
| Dual boot | `bootos.sh`: os-prober GRUB entries via `grub-reboot`, else EFI `BootNext`; one-shot; never listed in an empty launcher or in recents. |
| Update | `update.sh check/apply` against GitHub (API or ls-remote), clone with real `dl=NN` percent, a checksum manifest so user-edited files are kept (new copy as `.panacea-new`), changelog filtered (version bumps and README commits removed), two snapshots kept. |
| Locale | `locale.sh` via pkexec writes `/etc/locale.conf`; the shell's own language switches at once (Russian source strings, en/tr dictionaries). |
| Sounds | `pw-play` or `paplay` with `~/.config/panacea/sounds/{charge,connect,disconnect,screenshot,voice_start,voice_done}.wav`. |

## 6. Polish details

**Empty and unknown states.** Missing measurements are hidden instead of shown as 0: load −1 means the row is hidden, and a desktop gets no battery block instead of "0%". The agent page distinguishes "agent does not report limits" from "no data yet" and gives `/usage` as the fix. Launchpad shows "Nothing found"; the wallpaper carousel shows a pulse placeholder; no cava means a synthetic wave instead of dead bars.

**Error handling as UI.**
- Scripts return codes; the UI translates them (update errors, file-op errors, recorder `already/no-recorder/failed`).
- `bootos` failures raise a critical notification, because a silent failure looks like an ignored click.
- The lock screen keeps a step log. The DDC and empty-EDID cases explain themselves in Display settings.
- `check.sh` runs qmllint before you reload the shell.

**Keyboard**
- Esc first asks the page's `goBack()`, then collapses the panel.
- Super+Q closes Panacea overlays first (`smartClose`) and only then kills a window.
- `FocusGrabber` retries focus every 16 ms for up to 30 tries, because layer focus arrives a frame late.
- Arrows, Enter and digits in the overview. Grid arrow keys move by row. The "open with" list has its own selection.
- Settings search: Enter opens the first match. Back and forward history in settings.

**Destructive actions need two steps:** power menu (except lock), reset all, vault lock waits for pending saves. Boot into another OS uses the password prompt itself as the confirmation, with no extra dialog.

**Hover and feedback.** Every clickable item gets a hover colour and scale. The tooltip is a black capsule with OutBack. A refresh icon spins while busy. The "Check for updates" button shows a spinner so a "no change" result still visibly happened. Notifications pause while the cursor rests on the card (rechecked every 1.2 s).

**Timing courtesy**
- Notifications arriving while the panel is open are queued, and shown 260 ms after it closes; entries older than 60 s are dropped.
- The first update check waits 45 s for the network; one notification per version (kept in config across restarts).
- The volume OSD does not appear at startup or on device switch.
- The file-op window appears only after 400 ms (short copies never flash) and stays 1.2 s after completion.

**First run and updates.** The installer offers an AUR helper and each optional step one prompt at a time. Generated files are rebuilt if missing (`binds_data.lua` self-heals). "What's new" can only be closed with its button, never by a click outside. Missing packages are shown as a copyable command.

**Small touches.**
- An update notification leads to Settings → System; a screenshot notification opens the viewer.
- Notification icons go through `iconPath(name, true)` so a missing theme icon never shows the checkered "broken image".
- The record card timer is greyed until recording starts. The layout letters flip so a blind Alt+Shift is noticed.
- Launchpad and wallpaper layers are pre-built a few seconds after start, so the first open is instant. Icons are resolved 3 per 50 ms in the background.
- Images get a `sourceSize` everywhere, so 75 MP wallpapers decode at all.

**Privacy.** The agents page hides account identity. Vault passwords stay out of cliphist. Notification bodies render as StyledText (Telegram sends `<b>`).

**Weak spots to avoid copying:**
- The mascot spawns `hyprctl cursorpos` every 60 ms.
- The calculator evaluates `Function()` behind a character whitelist.
- `tint()` is dead code; the AI ask row is disabled.
- `adaptive-colors.py` is missing.
- Status is polled with timers instead of DBus signals: Wi-Fi every 4/15 s, power every 10/30 s.

## 7. Port list for loka

What loka already has (I checked the source): springs plus tokens (`anim.rs`), the notch flare as one path with no seam (`island.rs:340`), a dot-matrix clock with a per-digit flip (420 ms OutBack 1.4), an OSD (1.4 s), toasts with ring and action button, Wi-Fi/BT/charge/low-battery toasts with sounds, captive check, two-press power menu, coffee toggle, clipboard with images, `record.sh` with silent-track finalize, battery history, tray menus, a peek view with media, stowing over fullscreen, hover arming (`enter_pt`), keyboard focus ring, wheel 5 % steps, and a wallpaper card carousel on a spring.

Ordered by value divided by effort (S = under a day, M = a few days, L = a week or more):

| # | Idea | Why it is good | loka today | Effort | Where |
|---|---|---|---|---|---|
| 1 | Toast queue, hover-to-hold, drop entries older than 60 s, show 260 ms after the panel closes | Notifications are never lost or cut off mid-read | `Island::show` replaces the current toast; expanded panel drops it | S | `island.rs` (`show`, `tick`), `app.rs` `Msg::Notify` |
| 2 | Slider "held value" for 400 ms plus wheel steps counted from its own mark (260 ms) | No snap-back while PipeWire or DDC catch up | Slider shows the model value | S | `ui.rs` `slider`, `app.rs` `slider()` |
| 3 | Debounce hardware writes (brightness 180 ms, temperature 180 ms) | DDC/xrandr calls stop queueing and flickering | Direct set | S | `services.rs` `set_brightness`, `app.rs` |
| 4 | Content-height coalescing: ignore <8 px, merge 24 ms | Panel grows once, not in steps | Retargets on any >0.5 px change | S | `island.rs` `render`/`retarget` |
| 5 | Wired-Ethernet override (sysfs `type==1 && carrier`, skip virtual interfaces) | Correct icon when a cable is plugged in | Wi-Fi only | S | `services.rs`, `bar.rs`, `pages.rs` |
| 6 | Volume and brightness acceleration: 5/10/20 % after 4 and 10 repeats, gap 280 ms, snap to step | Fast long presses; clean numbers | Fixed steps | S | `app.rs` key handling |
| 7 | Charge wave behind the AC toast and battery tile (two sines, the numbers in §4) | Charging state you see without reading | Ring only | S | `island.rs` `draw_collapsed`, `pages.rs` battery |
| 8 | Workspace pill: animate only after the first frame (`settled` guard), 5 slots reserved | No slide-in on new workspaces; bar never shifts | Tweened `ws_w`; check first-appear and reserve | S | `bar.rs` |
| 9 | Notification click: invoke `default`, then focus the app window (`i3-msg [class=…] focus`, else launch the .desktop) | One click reaches the chat | `default_action` invoked, no focus step | S | `app.rs`, `i3.rs` |
| 10 | Notification hygiene: skip history for `transient`, cap 50, remove when the app closes it, critical sticky until answered (configurable) | History stays meaningful | Critical fixed at 10 s; check transient | S | `notify.rs`, `app.rs` |
| 11 | Global reduce-motion and a duration scale (move/fade/hover) | Accessibility; battery mode | Fixed tokens | S | `anim.rs` (scale `Motion.dur`), `config.rs` |
| 12 | Wallpaper card parallax (image 1.28×, offset d·step·0.22), side darkening min(0.55, 0.3\|d\|), rounded mask | Depth for free | Scale and opacity only, PNG outline | S | `walls.rs` render |
| 13 | Overlay grows out of the island (rect and radius from pill to full, OutQuint) | Carousel reads as the island unfolding | Fades in | M | `walls.rs`, `app.rs` (pass the pill rect) |
| 14 | Stagger intro wave for grids (delay (r+c)/(R+C−2)·0.45, scale 0.82→1, 560 ms) | Grids feel alive on open | None | S | new helper in `anim.rs`; use in `walls.rs`, clipboard grid |
| 15 | Exponential follow (k = 1−e^(−26·dt)) plus rubber band (×0.3, ±0.35) for scrolling and paging | Smooth touchpad input from uneven events | Springs only | S | `anim.rs` `Follow`, scroll code |
| 16 | Freeze-frame screenshot: `maim` full frame → show it in an override-redirect loka window → `slop` → crop the original | Lets you capture menus and tooltips; no colour drift | `maim` + `slop` on the live screen | M | `loka/scripts/shot.sh`, `x11.rs` (fullscreen surface), IPC `freeze/unfreeze` |
| 17 | OCR on a region (tesseract with the Pillow preprocessing pipeline) | Copy text from anything | None | S | `loka/scripts/ocr.sh`; capture menu action |
| 18 | Agent approval toast (✓/× actions, 30 s countdown bar) plus the PermissionRequest hook, shown only when the agent's terminal is not focused | You approve agent commands from the island | Action button exists, single action | S | `island.rs` (two actions plus bar), adapt `agent-approval.py` to i3 focus |
| 19 | Multi-monitor record picker card | No guessing which output | Check `record.sh` for `-o` | S | `island.rs`, `app.rs` |
| 20 | Media seek bar = live spectrum; played part in accent, clipped; shared cava with refcount and 20 s linger | Distinctive, informative | Thin progress bar | M | new `cava.rs` (spawn raw ascii), `pages.rs`/`island.rs` |
| 21 | Mascot eyes (blink 3.7 s/150 ms, gaze from `QueryPointer`, sleep cycle) | Personality; costs nothing on X11 (no process spawning) | None | S | `island.rs` collapsed draw, `x11.rs` QueryPointer |
| 22 | Night light with schedule (wraps past midnight; switch only on window edges) | Evening comfort | None | M | `services.rs` via `xsct`/`redshift -P -O` or XRandR gamma ramps with x11rb |
| 23 | Digital vibrance | Punchier colours | Paper shader only | S | picom shader (same formula) or `nvidia-settings DigitalVibrance` |
| 24 | Keyboard-layout letters with a flip | Blind layout switches get confirmed | None | S | `bar.rs` (XKB group events through x11rb `xkb`) |
| 25 | Weather on the island with 13×7 dot icons; Open-Meteo without a key | Glanceable, no API key | None | M | `dot.rs` (icon grids), new `weather.rs`, `bar.rs`/`island.rs` |
| 26 | Desktop widgets: dot clock or analog 12-dot dial, life bar (24 h / 12 months), RAM/SSD rings | Nothing-style desktop | mathwall only | M | new `widgets.rs` (below-windows X11 window) |
| 27 | Polkit agent in the island | Unified look | External agent | M–L | new `polkit.rs` (zbus `AuthenticationAgent` plus `polkit-agent-helper-1`) |
| 28 | Lock-screen capsule (blurred wallpaper, dots pop, shake) | Matching lock | `lock.sh` (external) | L, risky | Safer: theme i3lock-color with the same values. A native X11 locker needs full grabs, DPMS and crash safety |
| 29 | Vault (openssl PBKDF2 240k, PAM, 15 min idle, password-shaped clipboard capture) | Integrated passwords | None | L | new `vault.rs`; security review required |
| 30 | Launchpad grid with folders and drag-merge | Visual app finder | rofi/evry | L | new `launchpad.rs` |
| 31 | One-shot boot into another OS (`grub-reboot` via a pkexec helper) | Dual-boot convenience | None | S | rofi mode or launcher row plus a root helper |
| 32 | Root helper with `auth_admin_keep` polkit action | One password for many privileged actions | Ad-hoc | S | `loka/bin/loka-root` plus `.policy` |
| 33 | File-op progress card (EMA speed, ETA, sync phase) | Long copies become visible | None | M | only if loka adds file operations |
| 34 | Update checker and "What's new" for the dotfiles repo | You know what changed | None | M | `app.rs` timer plus a git script |
| 35 | Live workspace previews | Overview | — | **Wayland-only** (ScreencopyView). X11 can only show last-seen snapshots | — |
| 36 | Layer-shell exclusive zone, ext-session-lock, hyprsunset, Hyprland `screen_shader`, wf-recorder, grim/slurp, `wl-paste --watch`, mpvpaper, Hyprland window rules | — | — | **Wayland-only**; X11 equivalents: struts, i3lock, xsct, picom shader, ffmpeg x11grab, maim/slop, XFixes selection, xwinwrap | — |

Start with rows 1–12: each is under a day, and together they give most of the "finished" feel.

## 8. License

**MIT, © 2026 EnsixD** (`LICENSE`). The README says MIT covers "the configs, the QML and the scripts". Wallpapers, fonts and other bundled third-party files keep their authors' terms.

**What MIT allows:**
- **Ideas, layouts, timings and formulas** (durations, easings, slider rules, the vibrance formula, the dot grids as a concept): free to reimplement in Rust. Plain numbers and techniques carry no meaningful copyright, and MIT allows this anyway.
- **Copying code or files:** allowed, including modification and commercial use, provided the copyright notice and licence text travel with the copied parts. loka already does this with `loka/LICENSE-panacea`, and its README credits `loka/scripts`, `loka/sounds` and `card-outline.png`. Keep that file and add any newly copied scripts (`ocr.sh`, `shot.sh`, `agent-approval.py`, a vault script) under the same notice.
- **Dot-glyph tables** (DotText/DotIcon grids): if you copy the bitmaps verbatim, keep the notice. Hand-drawn equivalents need nothing.
- **Do not take** `wallpapers/` or `grub/panacea/wallpaper.jpg`: those belong to their photographers (ilyamiro/shell-wallpapers, HyDE, matteogini). The README does not state where the `.wav` sounds come from, and they are not explicitly covered by MIT. loka already ships them, so ask the author or replace them.
- **No warranty.** That matters for anything security-related you port, such as the vault, the lock screen or the pkexec helper: review it yourself.
