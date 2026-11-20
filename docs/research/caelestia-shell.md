# caelestia-shell: study report for loka

**How much I read.** I read these files in full: shell.qml, every components/ file except filedialog/, services/ except Nmcli and VPN, daemons/, utils/, modules/drawers, the bar core and popout wrappers, the dashboard core, launcher, notifications, osd, session, toasts, lock core, background, areapicker, Config/anim, tokens and enums, 9 of the 27 transition shaders, blob.frag with the blob physics, and the plugin's session manager, cava, beat tracker, image analyser, network usage, wavy line, visualiser bars and rounded mask.

I only searched (signatures, strings, comments) these: Nmcli.qml (70 KB), VPN.qml, the other 18 shaders, the nexus pages, sidebar Notif*, the lock sub-widgets, filedialog/, I18n, the Settings internals, lazylistview, animatedrepeater, lyrics.cpp, gpu/sensors, and the CI files.

I skipped vendored code: rgbcx, fzf.js and fuzzysort.js. I changed no files.

---

## 1. Architecture

- **Stack.** The shell runs on Quickshell (Qt 6 QML) and is tied to Hyprland. A C++20 QML plugin (`plugin/src/Caelestia/*`) supplies these modules: `Caelestia.Config`, `.Settings`, `.Blobs`, `.Components`, `.Services`, `.Shaders`, `.Multimedia`, `.Images`, `.Models`, `.I18n` and `.State`. `extras/version.cpp` prints the version. A separate `caelestia` CLI (not in this repo) does the scheme, wallpaper and record work.
- **Entry point.** `shell.qml` creates `Background`, `Drawers`, `AreaPicker` and `Lock`, plus 5 daemons: `Shortcuts`, `BatteryMonitor`, `GameMode`, `IdleInhibit` and `IdleMonitors`. At start it forces `Notifs`, `Players` and `Brightness` to load and calls `Weather.reload()`. It sets `QSG_RENDER_LOOP=threaded` and `QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000`.
- **Windows.** Each screen gets one fullscreen layer-shell window, `ContentWindow` (`modules/drawers/ContentWindow.qml`), that holds every panel: bar (left, vertical), dashboard (top), launcher (bottom), sidebar, session and osd (right), notifications (top-right), utilities and toasts (bottom-right), and bar popouts (beside the bar).
  - Input passes through via a `Region` mask: the screen XOR each panel's current rectangle (`Regions.qml`).
  - Four 1 px windows reserve the border width (`Exclusions.qml`).
  - Each screen also gets a separate background window.
- **Panel motion.** Every panel has `offsetScale` (0 = open, 1 = hidden) on a `Behavior` with the default spatial curve. The margin is `(-size - 5) * offsetScale` and opacity is `1 - offsetScale`.
- **State.**
  - `ScreenState` (`components/ScreenState.qml`) holds per-screen `PersistentProperties` booleans (`bar osd session launcher dashboard utilities sidebar`), `dashboardTab` and `dashboardDate`.
  - `ShellState` maps screens to states and component references.
  - Singletons in `services/` wrap Quickshell services (Pipewire, Mpris, UPower, Bluetooth, Notifications, Hyprland).
  - C++ services are reference-counted: `Service::ref/unref` starts and stops them, and `TickingService` polls at `dashboard.resourceUpdateInterval` (default 1000 ms) only while a `ServiceRef` exists. CPU, GPU, memory and network are therefore read only while a panel shows them.
- **Config.** `~/.config/caelestia/shell.json` uses a typed C++ schema (`Config/*.hpp`, `CONFIG_PROPERTY` macros). Per-monitor overlays live in `monitors/<name>/shell.json` and tokens in `shell-tokens.json` (radii, spacing, durations, bezier points, sizes). Files are watched and hot-reloaded. Invalid keys are quarantined: kept in the file, ignored, and a warning is logged. Writes from the settings app go back to the file. All UI sizes are tokens times a user scale.
- **Theming.** The `caelestia` CLI writes `~/.local/state/caelestia/scheme.json` (Material 3 roles plus `success*` plus `term0–15`). `Colours.qml` watches that file. Previews load a second palette (`caelestia wallpaper -p`) and swap `Colours.palette` live. Colour changes animate through `CAnim` (300 ms).
- **IPC.** `IpcHandler` targets are exposed through `caelestia shell …` / `qs ipc`:
  - `drawers` (toggle/list/isOpen), `nexus`, `toaster` (info/success/warn/error)
  - `notifs` (clear/DND), `mpris`, `wallpaper`, `brightness` (accepts brightnessctl syntax such as `+10%`), `audio cycleOutput`
  - `hypr`, `picker` (open/openFreeze/openClip/openFreezeClip), `lock`, `gameMode`, `idleInhibitor`

  Keybinds are Hyprland global shortcuts (`appid caelestia`). The launcher opens on key *release* and is cancelled by a `launcherInterrupt` shortcut, so Super+X combinations do not open it.
- **Persistence.** `notifs.json` (1 s debounce), `apps.sqlite` (launch counts), `cities.json`, a lyrics map and cache, and a KTX thumbnail cache.
- **i18n.** gettext through `Tr.tr/trCtx/trN`. `scripts/trs.fish` extracts strings, `scripts/trs-check.py` lints the translation calls, and `scripts/qml-lint-conventions.py` enforces Qt's member order in QML.

## 2. Feature inventory

**Shell and drawers**
- Drawer host with blob border, mask regions and focus grab: `modules/drawers/{ContentWindow,Panels,Regions,Interactions,Exclusions}.qml`
- Edge interactions: hover the top to show the dashboard, hover the bottom corner for utilities, hover the right edge for the OSD, hover the top-right for the sidebar. Drags past thresholds show or hide the bar (20 px), session (30), dashboard (50), launcher (50) and sidebar (80). Panels opened by shortcut stay open until the pointer enters them: `Interactions.qml`

**Bar** (`modules/bar/`)
- Configurable entry list (logo, workspaces, spacer, activeWindow, tray, clock, statusIcons, power): `Bar.qml`
- Persistent, show-on-hover or drag-reveal modes, hidden when a window is fullscreen: `BarWrapper.qml`
- Workspaces as shapes, text or icons, with window icons per workspace, gap markers, occupied background and a special-workspace overlay (blur and scale 0.8): `components/workspaces/*`
- Active indicator whose top and bottom edges animate separately: `ActiveIndicator.qml`
- Vertical active-window title (rotated 90°, cross-fades between two text items): `ActiveWindow.qml`
- Vertical clock with optional date, seconds and AM/PM: `Clock.qml`
- Tray with compact or expanded mode: `Tray.qml`, `TrayItem.qml`
- Status icons for caps/num lock, audio, mic, kb layout, network, bluetooth (connecting devices pulse) and battery (shows a power-profile icon on desktops): `StatusIcons.qml`, `status/*`
- Power button opens the session menu: `Power.qml`
- Scroll actions: workspaces, top half for volume, bottom half for brightness: `Bar.qml handleWheel`
- Popouts:
  - network with Wi-Fi, ethernet and rescan; Wi-Fi password dialog: `popouts/Network.qml`, `WirelessPassword.qml`
  - bluetooth, audio devices, battery (time left, power profile, performance-degraded reason): `Bluetooth.qml`, `AudioPopout.qml`, `Battery.qml`
  - tray menu with submenu stack, active window, lock status, kb layouts (XKB 4-layout limit warning): `TrayMenu.qml`, `ActiveWindow.qml`, `LockStatus.qml`, `kblayout/*`
- Detach: a popout can become a centred window-info or settings panel: `popouts/Wrapper.qml`

**Dashboard** (`modules/dashboard/`, tabs drawn from `Tabs.qml`, swipeable)
- Dash tab: user/pfp (`~/.face`, file picker), weather, date/time, calendar (wheel or arrows, middle-click for today, "Sunny" shape marks today), resources, media with wavy arc and beat-synced bongocat: `Dash.qml`, `dash/*`
- Media tab: cover art with circular visualiser, drifting background shapes, details, lyrics list with backend picker and offset: `Media.qml`, `media/*`
- Performance tab: CPU and GPU hero cards (usage shape, temperature), memory, storage, network sparkline, battery tank: `Performance.qml`, `performance/*`
- Weather tab: current conditions, sunrise/sunset, humidity, wind, 7-day forecast: `WeatherTab.qml`

**Launcher** (`modules/launcher/`)
- Apps with fzf or fuzzysort, launch frequency, favourites and hidden lists; `@i @c @d @e @w @g @k @t` field prefixes: `services/Apps.qml`
- `>` actions (calc, scheme, variant, wallpaper, random, light/dark, shutdown, reboot and logout gated as dangerous, lock, sleep, settings): `services/Actions.qml`
- Calculator via libqalculate, async; Enter copies, a button opens `qalc -i`: `items/CalcItem.qml`, `plugin/.../qalculator.cpp`
- Scheme and variant pickers: `services/Schemes.qml`, `M3Variants.qml`, `items/*`
- Wallpaper carousel (PathView) with live wallpaper and palette preview: `WallpaperList.qml`, `items/WallpaperItem.qml`
- Empty states and vim keys: `ContentList.qml`, `Content.qml`

**Notifications**
- Popups with swipe, expand, actions, image, app badge and progress ring: `modules/notifications/*`
- Sidebar dock: grouped by app, preview 3 per group, expand, clear all, empty state "All up to date!": `modules/sidebar/*`
- D-Bus server with persistence and image cache: `services/Notifs.qml`, `NotifData.qml`

**OSD:** vertical filled sliders for volume, mic and brightness; shown on change, 2000 ms hide delay unless hovered: `modules/osd/*`

**Session menu:** logout, shutdown, hibernate and reboot plus a gif; keyboard navigation: `modules/session/*`

**Utilities** (`modules/utilities/`)
- Toasts (max 4): `toasts/*`
- Quick toggles (wifi, bt, mic, settings, game mode, dnd, vpn): `cards/Toggles.qml`
- Recorder card (fullscreen/region, with or without sound, pause, timer): `cards/Record.qml`
- Recordings list (play, open folder, delete with confirm): `cards/RecordingList.qml`, `RecordingDeleteModal.qml`
- Keep-awake with "active since": `cards/IdleInhibit.qml`

**Lock** (`modules/lock/`)
- ext-session-lock with PAM (passwd plus faillock, fprint, howdy): `Lock.qml`, `Pam.qml`, `assets/pam.d/*`
- Animated card on a blurred screenshot: `LockSurface.qml`
- Centre: clock, profile picture, password input with shape glyphs, state messages: `center/*`
- Widgets: weather and hourly forecast, fetch (OS/WM/USER/UP/BATT), media, resources, notifications, session buttons: `weather/*`, `Fetch.qml`, `Media.qml`, `Resources.qml`, `NotifDock.qml`, `NotifGroup.qml`

**Background**
- Wallpaper with 27 transitions, image or video: `modules/background/Wallpaper.qml`, `components/widgets/WallpaperImpl.qml`, `plugin/.../Multimedia/*`
- Desktop clock in 9 positions, optional blurred backdrop and shadow: `DesktopClock.qml`
- Desktop cava bars: `Visualiser.qml`

**Other modules**
- Area picker: screenshot by region or window, freeze option, clipboard option: `modules/areapicker/*`
- Window info: live preview, details, move/float/pin/kill: `modules/windowinfo/*`
- Nexus settings app. Pages: wallpaper & style, network (wifi/ethernet/VPN/IPv4/hidden/saved), bluetooth pairing and device info, audio app volumes, apps, panels, services, language & region, about (animated logo); updates and plugins are registered but not built yet: `modules/nexus/*`

**Daemons**
- Battery warning ladder and critical hibernate: `daemons/BatteryMonitor.qml`
- Idle timeouts: `IdleMonitors.qml`
- Idle inhibit: `IdleInhibit.qml`
- Game mode (Hyprland options): `GameMode.qml`
- Shortcuts and IPC: `Shortcuts.qml`

**Services**
- Audio (Pipewire, per-stream volume, device-change toasts): `services/Audio.qml`
- Brightness (brightnessctl, ddcutil, asdbctl): `Brightness.qml`
- Network and VPN (wireguard, tailscale, netbird, warp): `Nmcli.qml`, `VPN.qml`
- Players (MPRIS, aliases, YouTube art fallback, now-playing toast): `Players.qml`
- Recorder (gpu-screen-recorder through the CLI): `Recorder.qml`
- Weather: `Weather.qml`
- Wallpapers: `Wallpapers.qml`
- Hyprland events, keyboard and special workspaces: `Hypr.qml`
- Time, colours, screens, state: `Time.qml`, `Colours.qml`, `Screens.qml`, `ShellState.qml`

**Plugin services**
- `Services/{cpu,gpu,memory,storage,diskinfo,networkusage,sensorslib,lyrics,cavaprovider,beattracker,audiocollector,sessionmanager,hyprextras,hyprdevices}.cpp`
- `Images/imageanalyser.cpp` (dominant colour and luminance)
- `Models/{appdb,filesystemmodel}.cpp`
- `cutils.cpp`, `requests.cpp` (HTTP), `toaster.cpp`, `qalculator.cpp`

## 3. Motion and feel

**Curve tokens** (`plugin/src/Caelestia/Config/tokens.hpp`): cubic beziers, all overridable.

| Token | Bezier control points | Duration | Overshoot |
|---|---|---|---|
| standard | (0.2, 0, 0, 1) | small 200, normal 400, large 600, extraLarge 1000 ms | none |
| standardAccel / standardDecel | (0.3, 0, 1, 1) / (0, 0, 0, 1) | same set | none |
| emphasized | 2 segments: (0.05, 0)(0.133, 0.06)→(0.167, 0.4); (0.208, 0.82)(0.25, 1)→(1, 1) | same set | none |
| emphasizedAccel / Decel | (0.3, 0, 0.8, 0.15) / (0.05, 0.7, 0.1, 1) | same set | none |
| expressiveFastSpatial | (0.42, 1.67, 0.21, 0.9) | 350 ms | about 9% |
| expressiveDefaultSpatial | (0.38, 1.21, 0.22, 1.0) | 500 ms | about 1.5% |
| expressiveSlowSpatial | (0.39, 1.29, 0.35, 0.98) | 650 ms | about 2% |
| expressiveFastEffects | (0.31, 0.94, 0.34, 1) | 150 ms | none |
| expressiveDefaultEffects | (0.34, 0.8, 0.34, 1) | 200 ms | none |
| expressiveSlowEffects | (0.34, 0.88, 0.34, 1) | 300 ms | none |

The overshoot column is my estimate from sampling y(t). The curve values are the public Material 3 Expressive tokens. `appearance.anim.durations.scale` multiplies every duration.

**How animations are built.**
- `Anim.qml` is a NumberAnimation with a `type` enum. The default type is **DefaultSpatial (500 ms, slight overshoot)**. Things that move use the spatial types; opacity and colour use the effects types (never overshoot).
- `CAnim` animates every colour change over 300 ms on the slow-effects curve. `StyledRect` and `StyledText` animate colour automatically, so a theme switch is always a cross-fade.
- **Fade-swap.** `StyledText.animate` and `AnimLoader` fade out over 150 ms (fast effects), swap the content, then fade in over 200 ms (default effects). The same pattern is used for lyric lists, popouts (out 200 ms, in 300 ms), launcher modes and the calendar.
- **`nonAnimWidth/Height`.** Every container computes its *target* size separately from its animated size. Parents lay out against targets, which avoids jitter when nested sizes animate.
- **Entering and leaving lists.**
  - `LazyListView` and `AnimatedRepeater` give each delegate `adding/removing` flags and drive opacity (200 ms), scale 0.7→1 and `visibleHeight`.
  - Notifications leave by sliding x to ±2× width over 400 ms on the emphasized curve, after first collapsing their height to 0.
  - Launcher list mode change: opacity 1→0 and scale 1→0.9 over 200 ms accel, swap the delegate, then reverse with decel.
- **Springs.**
  - Blob deformation is a semi-implicit spring on a 2×2 matrix: `v = (v − k(x − target)dt) / (1 + c·dt)` with **k = 200, c = 16**. The target is a stretch along the velocity, `1 + min(speed·deformScale, 0.35)`, with compression `1/stretch` on the other axis. The rest threshold is 0.002, and it stays inactive below 5 px/s.
  - `deformScale` per panel is 0.03 (sidebar), 0.1 (dashboard, launcher), 0.15 (popouts, utilities), 0.2 (session) and 0.25 (osd), each ×10⁻⁴ × the user's `deformScale`.
  - The loading indicator uses an analytic spring with **stiffness 180, ζ 0.6**, settling at 0.075. Morph progress is clamped to ≤1. Each morph adds 60° of rotation. The shape changes every 650 ms. Base rotation is linear, 4666 ms per turn. Scale is `1 + vel·0.14/vmax`.
- **Asymmetric indicator.** On the active workspace, the leading edge animates in 500 ms and the trailing edge in 500 ms, or 750 ms when `activeTrail` is on. The pill stretches like a worm (`ActiveIndicator.qml`).
- **Press physics.**
  - Button radius goes 16 → 8 on press and 12 when checked. Round buttons use height/2. The change takes 200 ms.
  - `shapeMorph` expands the button by 24 px with the fast spatial curve.
  - The switch thumb grows to 1.2× width while pressed. Its check/cross glyph morphs its line endpoints over 350 ms fast spatial.
  - Session buttons use radius 20, 28 when focused, 12 when pressed.
- **Ripple** (`StateLayer.qml`).
  - Hover layer: opacity 0.08, animated over 200 ms.
  - On press: a radial gradient grows from the pointer to 1.3× the farthest corner over **600 ms** (standard curve). It starts at opacity 0.1 with a soft rim 20% of the radius wide, then fades over 300 ms after release.
- **Other numbers.**
  - Media cover rotates once per 23.5 s, pausing when playback pauses.
  - Wavy progress phase repeats every 2000 ms. Amplitude goes 0.5→0 when paused (200 ms).
  - Visualiser smoothing: `α = 1 − exp(−dt/τ)` with τ = 400/3 ms.
  - Sparklines slide one sample step continuously between samples.
  - Scrollbars show at opacity 0.6 while moving, 0.8 on hover, 1 while dragging, and hide 600 ms after movement stops.
  - Fullscreen: the border width, rounding and shadow all multiply by `(1 − fsTransitionProg)`, animated, so the frame dissolves instead of popping.
- **Lock entry.** The lock icon spins 180→360° while scaling 0→1 (350 ms). The card then grows to 70% of screen height at 16:9, and the radius goes to 42. The blurred background fades in over 600 ms. Unlock runs the same steps in reverse.
- **Why it feels finished.**
  - Every property change, including colour, radius, gap and text, has a Behavior.
  - Movement and opacity use different curves (spatial vs effects).
  - Size changes cascade without jitter because of the target-size properties.
  - Exits are faster than entries (150 vs 200–300 ms).
  - Nothing appears or disappears without a fade plus a 0.5–0.7 scale.

## 4. Visual techniques

**Blob frame** (`plugin/.../Blobs/shaders/blob.frag`) is the signature look.
- The screen border (10 px, radius 25) is an inverted rounded rect. Each panel is a rounded rect. All are merged with a **circular smooth-min**: `smin(a, b, k) = max(k, min(a, b)) − |max(k − (a, b), 0)|`. The fillet is a true circular arc of radius k, where k = `border.smoothing` = 20.
- Pairs listed in `exclude` skip the blend.
- Each panel's SDF is evaluated after an inverse deformation matrix and scaled by its smallest eigenvalue.
- Near the border, the SDF is compressed on that axis by up to 4×, so drawers merge tightly.
- "Sinks" pull the border's inner wall back by `(2 − √2)·k/2` before a panel pocket forms.
- Antialiasing: `alpha = 1 − smoothstep(−fwidth, fwidth, d)`.
- Each shape's quad draws only the pixels it owns, plus the blend zone.
- The whole group gets one MultiEffect drop shadow (blurMax 15, shadow α 0.7).

**Wallpaper transitions** (`plugin/.../Shaders/*.frag`). Each mixes `from` and `to` by `progress`. Duration is the large token (600 ms) unless noted.

| Transition | What it does (math) | Curve |
|---|---|---|
| crossfade | `mix(a, b, p)` | slow effects (default transition) |
| iris | aspect-corrected circle, r = 1.2p, 0.05 feather; chromatic RGB split ±0.012 at the rim, weighted `exp(−100·\|d − r\|)` | emphasized accel, 400 ms |
| ink-splash | fbm at 3.5× and 14× warps a radial front `1.7p − 0.15`; dark ink rim plus "fingers" ahead of the front | linear |
| inkwell-drop | 3 damped ripple rings `sin(80(d − front))·exp(−6..10·\|d − front\|)` distort UVs around an impact point | linear |
| voronoi-shatter | 14× cells; each shard flies along a hashed direction with staggered start `smoothstep(s/2, s/2 + 0.5, p)` | linear |
| smoke | domain-warped fbm (6 octaves); radial visibility threshold; distortion `sin(πp)·0.35` | linear |
| chromatic-bloom | radial RGB split `sin(πp)·0.15` plus a 16-tap cross bloom | linear |
| zoom-blur-pull | 12-tap radial blur toward a centre moving 0.25→0.75; exponential dissolve | linear |
| pixelate / pixelfade-wave | block count `mix(800, 12, bump)`; the wave version staggers along the diagonal | linear |
| heat-melt | simplex-noise drip front; only pixels darker than luma 0.65 melt first | linear |
| morph, plasma-flow, soft-warp-fade | UV offsets from colour or noise, scaled by `sin(πp)` | various |
| glitch / glitch-displace / parametric-glitch | block or voronoi displacement with RGB offsets | linear |
| crosshatch, crosswarp, directional, directional-wipe, fade-colour, colour-distance, perlin, polka-dots, puzzle-right, random-squares | classic gl-transitions-style effects | linear (directional 300 ms; perlin 400 ms) |

The previous frame is captured into one of two `ShaderEffectSource`s, so a new change during a transition captures the transition itself (`WallpaperImpl.qml`).

**Masks and clipping.**
- `RoundedMask` (`roundedmask.frag`) computes a per-corner SDF with 0.5 px AA and backs the content with a fill colour.
- `ClipRect` wraps it for clipping with real antialiased rounding.
- Scroll lists fade 20% at the top and bottom through a gradient mask, which turns off at the ends.
- The area picker dims the screen with an inverted mask.

**Shapes.**
- M3Shapes (`qt6-m3shapes`) provides morphing polygons: Cookie4/6/7/9/12, Sunny, VerySunny, SoftBurst, Clover, Gem, Ghostish, ClamShell and more.
- They are used for: random focused-workspace shapes, the calendar today marker, usage tiers (Cookie4 below 40% usage, Sunny at 40–80%, SoftBurst at 80% or more), cover art, the loading indicator, password characters, and drifting shapes (14 shapes, 4–18 px/s, ±12°/s).
- `distanceAtAngle()` lets the circular visualiser follow the cookie outline.
- `WavyTopRect` uses quad-bezier sine edges.

**Elevation** (`effects/Elevation.qml`). dp per level is `[0, 1, 3, 6, 8, 12]`, then `blur = (5dp)^0.7`, `spread = −0.3dp + (0.1dp)²`, `offset.y = dp/2`, colour = shadow α 0.7. dp changes animate.

**Blur.** MultiEffect: lock background blurMax 64, special workspace blurMax 32, desktop clock backdrop 64, current lyric line blur 0.4 plus shadow-glow 0.6 in the primary colour. Hyprland layer rules blur the drawer window when transparency is on.

**Colour.**
- Material 3 roles come from the CLI ("smart" scheme from the wallpaper, plus variants).
- Transparency mode: base 0.85, layers 0.4. `alterColour` shifts luminance per layer by `(light ? 0.2 : 0.3)·(1 − base)·(1 + wallLuminance·k)`, so glass layers stay readable over bright wallpapers.
- `ImageAnalyser` downsamples to 128 px, quantises to 5 bits per channel, and returns the dominant colour and mean perceived luminance `sqrt(.299r² + .587g² + .114b²)`.
- `ColouredIcon` recolours symbolic icons: brightness `1 − L` of the dominant colour, then colorise.
- `Colouriser` recolours *text under an indicator* by drawing the same items again in the "on" colour, clipped to the indicator. Used on the workspace pill and the calendar today marker.

**Typography.**
- Google Sans Flex variable font (`ROND 25`), shipped in assets under OFL.
- Rubik for the clock and workspaces. CaskaydiaCove NF for mono.
- Material Symbols Rounded with animated `FILL` (0→1 on selection) and `GRAD` (−25 dark, 0 light, 200 for large glyphs).
- Font builder API: `.scale().width().letterSpacing()`.
- The bar clock uses the variable *width* axis so every digit pair renders at equal width ("11" gets ×1.15). The bar title gets letter-spacing 1.4.

**Visualisers.**
- cava core runs with bars from config (default 60), 44.1 kHz mono, noise reduction 0.85, 50–10000 Hz.
- A "monstercat" filter then runs both directions: `carry = max(v, carry/1.5)`.
- The desktop version draws two mirrored halves, 40% width each, bars up to 40% height, gradient primary→inversePrimary at α 0.7. It shows only when every window on the workspace floats, sliding 20% of screen height.
- aubio tempo detection drives the gif speed (`bpm / 300`).

**Thumbnails.** Wallpaper thumbnails are cached as BC3 KTX textures (rgbcx) for fast GPU upload.

## 5. System integration

| Area | Implementation |
|---|---|
| Lock | `WlSessionLock` (ext-session-lock). PAM through `PamContext` with the shipped `pam.d`: passwd with `pam_faillock`, `pam_fprintd` (3 tries, auto-retry), `pam_howdy` (on Enter with an empty buffer, and on resume). Background is a blurred `ScreencopyView` or the wallpaper. Ctrl+U or Ctrl+Backspace clears the buffer. Error states reset after 4 s; PAM errors retry after 800 ms, up to 5 times. |
| Idle | `IdleMonitor` (ext-idle-notify) list: 180 s lock, 300 s `dpms off`/`on`, 600 s `suspendThenHibernate`. Inhibited when any MPRIS player is playing or when charging; per-timeout `respectInhibitors`. Lock before sleep through logind `PrepareForSleep`. logind session `Lock`/`Unlock` signals are honoured. |
| Inhibit | Wayland `IdleInhibitor` on a 0×0 window; records "active since". |
| Power | `SessionManager` makes direct logind D-Bus calls (`Suspend`, `SuspendThenHibernate` falling back to suspend, `Hibernate` with a `CanHibernate` check and a toast on failure, `PowerOff`, `Reboot`, session `Terminate`). `systemctl`/`loginctl` strings are mapped to D-Bus calls. |
| Battery | UPower. Warnings at 20%, 10% and 5% (critical); at 3%, a toast reads "Hibernating in 5 seconds" and hibernate follows. Charger plug/unplug toasts. power-profiles-daemon profile and performance-degraded reason. |
| Notifications | Quickshell `NotificationServer` (actions, markup, images, persistence). Popups are suppressed under DND or while the sidebar is open; fullscreen policy On/Off (2000 ms timeout when fullscreen). Images are rendered offscreen and cached as PNG under a 64-bit hash. Persisted to JSON. |
| Media | MPRIS through Quickshell: default player, aliases, YouTube thumbnail fallback (`img.youtube.com/vi/<id>/hqdefault.jpg`), now-playing toast deduplicated by artist and title. |
| Lyrics | Local `.lrc` files (recursive in `~/Music/lyrics`), LRCLIB `/api/get` and `/search`, NetEase search and lyrics. Auto mode chains backends. Per-track offset and chosen candidate are persisted; results are cached. Clicking a line seeks. |
| Audio | Native Pipewire: sinks, sources, per-app streams, `maxVolume`, `preferredDefault*`. Device-change toasts. Audio capture through `pw_stream` (512-sample chunks) feeds cava and aubio. |
| Network | `nmcli` wrapper plus `nmcli monitor`: scan, connect with password detection, hidden SSIDs, saved list, autoconnect, IPv4 config, ethernet details and speed. Rescan every 15 s while the settings page is open. |
| VPN | Providers: WireGuard or other NetworkManager connections, tailscale, netbird, Cloudflare warp. Status parsing, auth-URL extraction, toasts. |
| Bluetooth | `Quickshell.Bluetooth` (BlueZ): adapter toggle, discovery, pairing with PIN, device battery and info. |
| Brightness | `brightnessctl`; `ddcutil` per I2C bus for external monitors (500 ms throttle with a queued last value); `asdbctl` for Apple Studio Display. |
| Screenshot | Own area picker with freeze mode, saved through `CUtils.saveItem` to `/tmp` PNG, then `swappy` or `wl-copy` plus `notify-send`. |
| Recording | `gpu-screen-recorder` through `caelestia record [-p]`. `pidof` polling only while the utilities panel is open; elapsed time counted on the `Time` seconds tick. |
| Wallpaper | `caelestia wallpaper -f/-r/-p`; `path.txt` watched; recursive directory model (images and videos); video via `QMediaPlayer` loop; fallback asset. |
| Colour | `caelestia scheme set` and `scheme.json`; light/dark via `--notify`. Pushes Hyprland layer rules (blur, `ignore_alpha = base − 0.03`) with a 30 ms cooldown. |
| Weather | Open-Meteo forecast (current, hourly, 7-day). Location from config (coords or city geocode) or ip-api (rate-limit aware via `x-rl`/`x-ttl`). Nominatim reverse geocode with a User-Agent and a cached city name. Hourly refresh. |
| Calendar | Qt `MonthGrid` only. No events. |
| Keyboard | Hyprland devices: caps/num lock, layout; `base.lst` parsed for names; caps/num key binds injected to refresh state. |
| Game mode | Hyprland options (`animations:enabled 0`, blur and shadow off, rounding and gaps 0, `allow_tearing 1`); reload restores them. |
| Sensors | lm_sensors (CPU temperature), `nvidia-smi` or `/sys/class/drm` (GPU), `/proc/stat`, `/proc/meminfo`, `/proc/net/dev`, statvfs per disk. |
| Calculator | libqalculate, async. |
| Absent | Clipboard history, OCR, polkit agent, emoji picker, calendar events. |

## 6. Polish details

- **Empty states everywhere, each with icon and two lines.**
  - Launcher: "No results / Try searching for something else", or "Try putting some wallpapers in ~/…" (pops in from scale 0.5).
  - Lyrics: loading indicator, then "No lyrics found" with a sad icon.
  - Sidebar: "All up to date!" with the dino image.
  - Lock: "Unlock for notifications".
  - Media: "Nothing playing / Play something for it to show up here!"
  - Recordings: "No recordings found".
  - Window info: "No active client / Try switching to a window".
  - Background: "Wallpaper missing? Set it now!" with a file dialog.
- **Notification handling.**
  - Hover pauses the expiry timer. Drag left or right past 30% of the width dismisses; anything shorter snaps back. Dragging vertically more than 20 px expands or collapses. Middle-click dismisses; right-click expands a group.
  - A progress ring around the app badge shows the `value` hint.
  - Markdown is detected by `/[<*_`#\[\]]/`; links show a pointer cursor.
  - Age strings ("now", "5m", "2h", "1d") update at adaptive intervals: 5 s, 30 s, 60 s, 5 min, then 1 h.
  - "+N" badges show at the top and bottom of an overflowing popup list.
- **Toasts.** Info, success, warning and error types. Max 4, with a collapsed preview. Any click closes one. Fullscreen policy: off, important, or all. Toasts exist for config loaded, charging, game mode, DND, audio in/out change, caps/num lock, kb layout, kb-layout limit, VPN and now playing.
- **Keyboard.** Launcher: Up/Down, Enter, Esc, optional vim keys (Ctrl+J/K/N/P, Tab). Session menu: arrow and Tab navigation, focus starts on logout, Enter runs. Popouts: Esc closes, and the password dialog keeps focus.
- **Hover details.**
  - The calculator's "Open in calculator" label slides out on hover (width animates on the emphasized curve).
  - Slider handles show their numeric value while moving, then turn back into the icon after 500 ms (a scale 0.3 pop between the two).
  - The handle's elevation rises on hover.
- **Errors and safety.**
  - Weather survives bad JSON and rate limits. Brightness IPC returns parse errors in a format users can read.
  - Lock messages combine method, tries ("(2/3)") and caps/num-lock/layout hints.
  - Hibernate shows a toast when the system cannot hibernate.
  - Dangerous launcher actions are hidden unless enabled.
- **Small touches.**
  - The today marker and active workspace recolour the glyph underneath.
  - Workspace scrolling skips to special workspaces correctly.
  - The OSD and dashboard can be opened by shortcut and then handed over to hover control.
  - Bluetooth devices pulse while connecting (600 ms fade out, 600 ms fade in).
  - The bar hides and the frame dissolves on fullscreen.
  - The launcher opens on Super *release* and is cancelled by a combo.
  - Terminal apps launched from the launcher get the colour escape sequences first (`assets/wrap_term_launch.sh`).
- **First run.** If no wallpaper exists, it sets the bundled wallpaper. If `notifs.json` or `cities.json` is missing, it creates `[]` or `{}`. The profile picture can be set by clicking the user card. There are no sounds anywhere.

## 7. Port list for loka

Ordered by value divided by effort. "loka today" was checked against `loka/shell/src`.

| # | Idea | Why it is good | loka today | Effort | loka file |
|---|---|---|---|---|---|
| 1 | Hover pauses toast expiry; middle-click and swipe dismiss | You never lose a toast you are reading | `Toast.until` is fixed; hover is ignored while a toast shows (`island.rs motion`) | S | island.rs, app.rs |
| 2 | Notification age string ("now/5m/2h") with adaptive refresh | Time since arrival reads faster than the arrival time | `Notif.time = "%H:%M"` (notify.rs:49) | S | model.rs, pages.rs |
| 3 | `value` hint as a progress ring on toasts | Download, volume and sync progress from apps for free | Only `urgency` is read; `Toast.ring` already exists | S | notify.rs, island.rs |
| 4 | Stretchy workspace indicator: separate start and end Tweens, leading edge 250 ms, trailing edge 375 ms (×1.5) | One gesture shows the direction of travel; very visible | Per-pill width Tweens (`bar.rs ws_target`) | S | bar.rs |
| 5 | Label recolouring under the moving pill: draw labels twice, the second pass clipped to the pill rect in the "on" colour | Text stays readable while the pill moves under it | Labels coloured per state, no clipping | S | bar.rs, canvas.rs |
| 6 | Effects vs spatial split: add `Ease::Bezier(x1, y1, x2, y2)` (Newton solve) plus `FAST_SPATIAL` (0.42, 1.67, 0.21, 0.9, 350 ms) for small pops only (switch thumb, badges, toggles) | A controlled overshoot on small parts; keeps the no-overshoot rule for panels | FADE, STANDARD (unused), SLOW; `OutBack` exists | S | anim.rs |
| 7 | Fade-swap content on page change: keep the old pixmap, 150 ms out, 200 ms in | Page changes stop snapping while the spring resizes | Content is redrawn instantly; only the open/close fade exists | S | island.rs |
| 8 | Calendar month slide: 150 ms fade out plus 28 px shift, then 400 ms in from the other side | Shows direction when moving through months | `cal_shift` redraws instantly | S | pages.rs, island.rs |
| 9 | Button radius morph on press (16→8, checked 12) and switch thumb ×1.2 while pressed | Clicks feel physical at almost no cost | Fill colour change only (`ui.rs button/toggle`) | S | ui.rs |
| 10 | Audio device change toast ("Now using: X"), caps/num lock toasts | Confirms things that are otherwise invisible | Toasts exist; no sink-change or lock-key toasts | S | app.rs, audio.rs |
| 11 | Battery ladder 20/10/5 plus critical 3% → toast, then logind `Hibernate` after 5 s | Prevents data loss on an empty battery | 15% and 5% toasts only (app.rs:685) | S | app.rs, services.rs |
| 12 | Battery "tank": fill height on a spring, text drawn twice (normal, and inverted clipped to the fill) | A readable, delightful battery card | Battery page has a history graph | S | pages.rs |
| 13 | Network down/up speed plus per-disk use, from `/proc/net/dev` and statvfs; sliding sparkline with filled area | Answers "is it downloading?" | Stats are cpu, mem and igpu only | S–M | stats.rs, pages.rs |
| 14 | Empty states with icon, title and hint, popping in from scale 0.5 | Explains the blank page | `ui.note` one-liners | S | ui.rs, pages.rs |
| 15 | "+N" overflow badges and list edge fades (20% gradient alpha, animated 300 ms) | Shows there is more content | Lists are truncated (`take(12)`) | S–M | ui.rs, canvas.rs |
| 16 | Toast queue: up to 3 stacked, older ones slide or scale (0.7) out | No toast is overwritten by the next | Single `toast: Option<Toast>`; a new one replaces the old | M | island.rs |
| 17 | Notification grouping by app (preview 3, expand), drag left to clear, persisted list | The notification centre scales to busy days | Flat in-memory `notifs` | M | pages.rs, notify.rs |
| 18 | Ripple state layer: radial fill from press point to 1.3× the farthest corner, 600 ms, α 0.1; hover α 0.08 | Material-quality feedback | Hover colour swap | M | ui.rs (per-`Hit.key` anim map) |
| 19 | Idle pipeline: 180 s lock, 300 s dpms, 600 s suspend; inhibit while MPRIS plays or on AC; lock on `PrepareForSleep` | Media no longer blanks the screen; one timeline | `xset s 600 dpms 900` plus coffee toggle | M | app.rs, services.rs (XScreenSaver idle via x11rb `screensaver` ext) |
| 20 | Screenshot picker: frozen XShm grab, snap to the i3 window under the cursor, selection rect animates between windows (500 ms spatial), 30% dim with a hole, Esc grows to fullscreen and fades | Replaces slop with a native, animated picker | slop + maim | M | new picker.rs, x11.rs, i3.rs |
| 21 | Live preview in the world switcher: arrowing over a card previews wallpaper and palette; Esc reverts | Choosing without committing | walls.rs cards; apply on Enter | M | walls.rs, theme preview path (`apply.py --check`) |
| 22 | Lyrics page: LRCLIB get/search (via `curl`), local `.lrc`, per-track offset, current line highlighted with a glow, click to seek | A big feature on top of the MPRIS you already have | Now playing only | M | new lyrics.rs, pages.rs, mpris.rs |
| 23 | Wavy progress line for media: `y = A·sin(2πf(x/L) + phase)`, A = 0.5·lineWidth, phase period 2 s, A→0 when paused | The playing state is visible at a glance | Linear progress from `position_us` | S | island.rs, pages.rs |
| 24 | Rotating cookie cover: polar `r(θ) = R(1 + a·cos 12θ)`, 23.5 s per turn, paused with playback | Cheap character for the media card | Square art pixmap | S | island.rs, canvas.rs |
| 25 | Morphing loading indicator: lerp two polar shape functions with a spring (k 180, ζ 0.6), +60° per morph, every 650 ms | Better than a spinner for Wi-Fi/BT scans | `wifi_busy` / `bt_scanning` shown as text | M | ui.rs, anim.rs |
| 26 | cava bars: read `cava` raw ASCII output from a fifo, smooth with `α = 1 − e^(−dt/133ms)`, monstercat both ways; draw in the island while playing or around the cover | Music becomes visible in the shell | None (cava runs as a separate program) | M | new viz.rs, island.rs |
| 27 | Velocity squash and stretch on the island: stretch `1 + min(\|v\|·s, 0.35)` along the motion axis from `Spring::state` velocity | The jelly feel of Caelestia's drawers | Springs move w/h; no deformation | M | anim.rs (expose velocity), island.rs |
| 28 | Circular-arc fillets (smin geometry) instead of quad flares, so island and bar merge with one constant radius k | Mathematically clean join; matches the blob look without a GPU | `FLARE` quad curve (island.rs `draw_shape`) | S–M | island.rs, canvas.rs |
| 29 | Window-info page for the focused window: class, pid, geometry, workspace; move/float/sticky/kill via i3 commands | Power-user tool next to the bar title | Title only | M | pages.rs, i3.rs |
| 30 | Weather on the calendar page via Open-Meteo, fixed coords from config (avoid ip-api), 1 h refresh | Useful glance info, no API key | None | M | new weather.rs, pages.rs |
| 31 | Game mode: one toggle that pauses mathwall, stops picom blur/shadows, sets the performance profile; toast | One switch for full performance | Separate controls | S | app.rs |
| 32 | Typed config with hot reload and quarantine of bad keys (warn, keep running) | Safe live tweaking | config.rs load/save; watch.rs only for theme and rec | M | config.rs, watch.rs |
| 33 | Full SDF smooth-min frame (bar, island and panels as one blob, CPU per-pixel inside dirty boxes) | Exact Caelestia look | n/a | L. A 600×800 surface at 144 Hz is likely too slow per-pixel on CPU; prefer #28 | canvas.rs |

**Wayland-only; cannot port as is:**
- ext-session-lock surfaces. On X11, keep `lock.sh` (i3lock or xsecurelock). Do not write a custom locker; X11 lockers are easy to get wrong for security.
- Layer-shell masks and exclusion windows. loka already uses input regions and a dock.
- `ScreencopyView` live previews. X11 needs XComposite pixmaps (M).
- `IdleInhibitor` and `IdleMonitor` protocols. Use XScreenSaver suspend and idle query instead.
- `HyprlandFocusGrab` and global shortcuts. Use i3 binds; i3 has `bindsym --release` for the Super-release launcher trick.
- Hyprland game-mode option injection, `wl-copy`.

Everything else in the table works on X11 with tiny-skia.

## 8. License

- **The repo is GPL-3.0** (`LICENSE`).
- **Ideas, behaviours, layouts, timing numbers and algorithms are free to reuse.** That covers everything described above: the "sink" idea, smin geometry, curve values (they are the public Material 3 Expressive tokens anyway), thresholds and formulas. Copyright does not cover them.
- **Copying code makes loka a GPL-3.0 derivative.** That includes QML, C++ or GLSL text, even translated line by line into Rust (for example `blob.frag`, `LoadingIndicator.qml`, the shaders). Once you publish the dotfiles, all of loka would have to be distributed under GPL-3.0 with source. loka has no license file today, and `loka/scripts`, `sounds` and `card-outline.png` are MIT (Panacea), which is compatible with GPL. Private, undistributed use carries no GPL obligations.
- **Clean route:** reimplement from this description. For transitions, take them from the original gl-transitions sources under their own licenses instead of from this repo.
- **Assets:**
  - Google Sans Flex is OFL (its own `LICENSE` in assets) and is reusable under OFL.
  - rgbcx is MIT/public domain.
  - `bongocat.gif`, `kurukuru.gif`, `dino.png`, the wallpaper and the Caelestia logo have no stated license. Do not copy them.
