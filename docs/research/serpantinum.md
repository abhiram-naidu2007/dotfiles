# Serpantinum: full study and port plan for loka

Serpantinum v2.5.1, by ilyamiro, licensed AGPL-3.0-or-later. It is a Quickshell (Qt6 QML) desktop shell for Wayland. It runs on Hyprland, Niri, Sway and Mango.

**How much I read.** The repo has 1018 files.
- **Read in full:** every one of the 31 `.frag` shaders. The entry files: `Shell.qml`, `Main.qml`, `WindowRegistry.js`, `Dim.qml`, `qmldir`. Most singletons: Config, Caching, Scaler, ThemeBackend, Matugen, AppTheming, Wallpaper, Audio, MprisController, Sounds, Spectrum, SurfaceField, ShellSurfaces, Compositor, CompositorStateBase. Also `AttachedSurface`, `SpringProgress`, `LoaderIcon`, `NotificationManager`, `art_fetch.sh`, the OCR language picker in `screenshot.sh`, `PolkitService`, the idle pipeline, `telemetry.sh`, and a sample app-theme manifest.
- **Read through targeted grep and partial reads, not line by line:** every other QML, JS, shell and Python file. That includes the very large ones: Launcher 91 KB, WallpaperPicker 111 KB, Floating 100 KB, ScreenshotOverlay 76 KB, and the settings tabs. Numbers I quote from these come from the lines I actually looked at.
- **Skipped:** `.qsb` files, fonts, sounds, images, `EmojiData.js`, translations, most of the website, and CHANGELOG.

---

## 1. Architecture

**Runtime.** `bin/serpantinumd` starts `quickshell` on `src/quickshell/Shell.qml`. `Shell.qml` is a `ShellRoot` that creates these top-level windows: `Main`, `Bar`, `Lock`, `WidgetRedactor`, `LockRedactor`, `Launcher`, `Clipboard`, `Dashboard`, `Polkit`, `WellbeingLimitOverlay`, `PopoutManager`, `Dock`, `Idle`, the per-screen desktop `WidgetLoader`, `WallpaperEngine` and `Floating`. A "performance mode" turns off widgets, the wallpaper engine and quick actions.

**One master popup window (`Main.qml`).** This is the most important pattern in the repo.
- One full-screen overlay layer-shell window hosts every large popup: network, volume, settings ("guide"), wallpaper, music, notifications and system.
- `WindowRegistry.js` maps each name to a size, an anchor and a QML file. Each popup has its own anchor table for each bar position.
- Popups are created once, then cached (`widgetCache`). The guide is preloaded with `Qt.callLater`.
- Moving from one popup to another morphs one clipped container: x, y, w and h each animate over 300 ms `OutCubic`. Opening from hidden snaps the geometry, then fades and scales the content.
- The input mask is the container XOR a hole over the bar, so the bar stays clickable while a popup is open.
- `switchGeneration` counters drop stale async switches. A popup can run `startExit(cb)`; a 450 ms safety timer forces the close if it never calls back.

**State.** QML singletons, registered in `qmldir`:
- **Config:** `~/.config/serpantinum/settings.json`, watched with `FileView`. Writes are atomic (tmp file, then `mv`) through `bash -c`. Writes are coalesced with `pendingPayload`. The shell ignores the change event caused by its own write by comparing with `lastWrittenContent`. Settings changes go out as one `settingsLoaded` signal.
- **Caching:** cache, state, run and log directories, each overridable per widget with `QS_CACHE_<NAME>`.
- Other singletons hold domain state: Audio (Pipewire), MprisController, Weather, Gamma, WindowTracker, FocusTimer, and so on.

**External helpers.** These binaries are **not in this repo** but the shell depends on them:
- `serpantinum-core`: compositor event stream as JSON lines, idle and sleep watch, launcher rank, clipboard pin, screentime tracking, notify, brightness.
- `serpantinum-audio`: a PipeWire DSP that replaces EasyEffects. It runs a 10-band EQ, balance, mono, channel swap, dynamics and dynamic EQ, and emits a 64-bar spectrum as JSON at 60 fps.
- `serpantinum-gamma`: a Wayland gamma daemon.
- `ski`: an xdg-desktop-portal backend.

**Theming flow.**
1. The chosen preset (`assets/themes/*.json`, 22 Catppuccin-style keys from base to teal) or matugen (`matugen image … -t scheme-tonal-spot`, run at `nice 15`) writes `qs_colors.json`.
2. `ThemeBackend` watches that file and applies the colours **3 per frame** (`FrameAnimation`), so the rebinding cost is spread over frames.
3. A static preset is mapped onto Material 3 roles (`Matugen.toMd3`). Each `on_*` colour is chosen by luma > 0.5.
4. `apptheme.py` renders the same palette into about 50 apps through manifests (`app.json`: detect binary, templates, an `integrate` line inserted between marker comments, a reload command such as `pkill -USR1 kitty`).

**IPC.**
- Quickshell `IpcHandler` targets: `main`, `screenshotOverlay`, `wallpaper`, `theme`, `fonts`, `matugen`, `idle`, and others.
- `bin/serpantinum` is a large CLI over these: `ipc`, `config get/set/dump/edit`, `caffeine`, `set notifications dnd`, `info idle`, and more.
- The current popup is written to `$XDG_RUNTIME_DIR/serpantinum/current_widget` as JSON, so scripts can query it.

**Surface registry.**
- `ShellSurfaces` keeps the bar and dock windows for each screen.
- `SurfaceField` publishes the rounded-rect shapes of attached surfaces for each screen. Other surfaces read them to merge their outlines (section 4).

**Installer.** The installer covers pacman, dnf and xbps, plus Nix (flake, NixOS and Home Manager modules) and AUR PKGBUILDs.

**Telemetry is on by default.** `install/modules/telemetry.sh` sends an ID, the OS, CPU, GPU, RAM, kernel, DE, session and failed packages to `dots-telemetry.ilyamiro-work.workers.dev`. It can be switched off in the installer menu, and it never runs on Fedora. Do not copy this.

---

## 2. Feature inventory

All paths are under `src/quickshell/` unless stated.

**Core**
- `Shell.qml`: root, builds every surface.
- `Runner.qml`: loads one QML file named by `SERPANTINUM_TARGET_FILE`. Used for previews and tests.
- `Main.qml` + `WindowRegistry.js`: the morphing popup host and its layout table.
- `Dim.qml`: idle dim, a 50% black overlay faded over 250 ms `InOutQuad`.
- `serp/Start.qml`: first-run cinematic with typewriter text and sounds.
- `serp/Serpantinum.qml`: logo and brand screen.
- `singletons/system/FirstLaunch.qml` + `scripts/first_launch.sh`: first-run detection.

**Bar** (`bar/`)
- `Bar.qml`, `TopBar.qml` (horizontal), `SideBar.qml` (vertical). The bar can sit on any of the 4 edges.
- Styles: modular, solid or fill. Optional distinct pills. Nested arrays in the module list make grouped pills.
- Autohide with a timeout (default 1000 ms). Hidden while fullscreen.
- `BarModuleRegistry.qml` and `BarModule.qml`: module geometry animates over 250 ms `OutCubic`.
- Faces:
  - `left/LeftFace`: menu buttons.
  - `workspaces/`: `PillsFace`, `NumbersFace`, `PacmanFace` (shader Pac-Man that eats workspace dots).
  - `focus/FocusFace`: active window.
  - `media/MediaFace`.
  - `vis/VisFace`: spectrum.
  - `tray/TrayFace`.
  - `timedate/`: `ClassicFace`, `MaterialFace` (diagonal digits), `BadgeFace` (segmented capsules).
  - `info/InfoFace`, `weather/WeatherFace`, `sysmon/SysMonFace`.
  - `kb/KbFace`: keyboard layout.
  - `wifi/WifiFace`, `bt/BtFace`, `vol/VolFace`.
  - `bat/BatFace`: liquid fill with a moving wave while charging.

**Popups in the master window**
- `network/NetworkPopup.qml`, `NetworkCoreLayer.qml`, `NetworkCardLayer.qml`, `NetworkControls.qml`, `LoadingDots.qml`: an orbital layout. Networks and devices orbit a core node, with sonar rings and breathing. Uses `Quickshell.Networking` and `Quickshell.Bluetooth`. `bluetooth_panel_logic.sh` reads A2DP/HFP profiles with `pactl`.
- `volume/VolumePopup.qml`: outputs, inputs, per-app streams, EQ entry.
- `media/MusicPopup.qml` and its parts:
  - `MusicCover`: spring-driven disc that beats with bass and kick.
  - `MusicEqView`: 10-band EQ with presets and a "lightning" shader.
  - `MusicAudioView`: balance, mono, swap, dynamics, channel test.
  - `MusicLyricsView`, `MusicBlurCrossfader`, `MusicBorder`, `MusicTrackControls`, `MusicBottomHeader`.
  - `art_fetch.sh`: hi-res art and a 3-colour gradient.
  - `equalizer.sh`: drives `serpantinum-audio ctl`.
- `notifications/NotificationCenter.qml`: grouped history.
- `syspanel/SystemPanel.qml`, `SystemPanelSliders`, `SystemPanelQuickActions`, `SystemPanelPowerActions`: control centre.
- `wallpaper/WallpaperPicker.qml`: skewed carousel, video previews, DuckDuckGo image search (`scripts/wallpaper/ddg_search.sh`, `get_ddg_links.py`).
- `guide/GuidePopup.qml`: the settings app (see Settings below).

**Popouts** (`popouts/`)
- `Osd.qml`: volume, mic, brightness, caps lock, num lock, airplane. It is interactive and can attach to the bar.
- `TrayBase.qml`: tray menus.
- `SideMusicPopout.qml`.
- `DesktopMenu.qml`: desktop right-click menu.
- `DockAppMenu.qml`.
- `PopoutManager.qml`.

**Launcher** (`launcher/`)
- `Launcher.qml` has tabs for Apps, Files and Emojis, a last-tab memory, an inline calculator, web search through `SearchProviders.js` (11 engines), and shell widgets as entries.
- Ranking: focus time + launch count + 0.5 × context, from `serpantinum-core launcher rank`.
- `EmojiSearch.qml`, `EmojiData.js`.

**Other panels**
- `clipboard/Clipboard.qml`: cliphist with pins (pinned section first, +500000 score), search, full-text expand, images, `wl-paste --watch`.
- `calendar/CalendarPopup.qml`, `Dashboard.qml`, `SunArc.qml` (sun position on a sunrise-to-sunset arc), hourly forecast.
- `dock/`: Dock, DockWindow, DockContainer, DockAppButton (magnification: 1 + Δ for the hovered icon, 0.45Δ for neighbours, 0.15Δ two away), DockRunningButton, DockAppPicker, DockPickerRow, DockExclusionWindow, DockWindowApps, DockWindowState.

**Lock** (`lock/`)
- `Lock.qml`: `WlSessionLock` + PAM, run in parallel with a fingerprint PAM (fprintd). `scripts/system/pam_without_fingerprint.sh` generates a no-fingerprint stack. Optional attempt limit with lockout.
- `LockScreen`, `LockBackdrop`, `LockClock`, `LockDashboard` (system-stat "wings"), `LockPowerControls`, `FingerprintIndicator` (shader ring and success burst), `VideoLock`, `LockSurface`.
- `lock/redactor/*`: a lockscreen layout editor with elements for user, avatar, password, notifications, battery, keyboard, fingerprint and lock status.

**Idle, auth, wellbeing**
- `idle/Idle.qml`: dim at 120 s, lock at 300 s, DPMS at 360 s, suspend at 600 s. Each step has warning, before and resume commands. Custom actions are supported. Respects MPRIS playback, `org.freedesktop.ScreenSaver` inhibitors (games, Steam) and lock-on-sleep. Caffeine can run with an end time.
- `polkit/Polkit.qml` + `PolkitService.qml`: a polkit agent using Quickshell `PolkitAgent`.
- `guide/wellbeing/*`: screen time per app, day, week and month charts, app limits with `WellbeingLimitOverlay`, tracked through `serpantinum-core screentime`.

**Notifications** (`notifications/`)
- `NotificationManager.qml`: the server.
- `NotificationPopups.qml`: the popup stack.
- `Notification.qml`: the card. Swipe to dismiss, drag to expand, right-click to close.
- `types/`: Default, Battery, Weather, Screenshot, Update.
- `weather/Wx*.qml` + `WeatherKinds.js`: procedural weather illustrations (sun, moon, cloud, bolt, precipitation, fog, wind, waves, flame, crystal, shield, thermometer, particles).
- `battery/`: battery illustrations.

**Quick actions** (`quickactions/`)
- `Floating.qml` + `FloatingEdgeTrigger.qml`: a panel opened from a screen edge.
- Actions:
  - `DrawAction`: pen, eraser, rectangle, undo and redo, save as PNG.
  - `SystemUsage`.
  - `Timer`: timer, stopwatch and pomodoro through `FocusTimer`.
  - `Notes` + `NotesFormat.js`.
  - `Calculator` + `CalculatorEngine.js` + `ConverterEngine.js`: units and currency from the fawazahmed0 currency-api.

**Desktop widgets** (`widgets/`)
- `WidgetLoader`, `Widget`, `WidgetRegistry`, `WidgetPicker`.
- `redactor/*`: an editor with snapping, z-order, undo and redo, and a wavy `SelectionOutline`.
- Faces: clock (8 styles, including Material Lumen and lockscreen), music (round, lyrics), weather (3 styles), image (3 styles), user, CPU, RAM, disk and temperature (bar or circle), timer, notes, text, battery, visualizer, GitHub contributions.
- `assets/widgets/*.json`: preset layouts.

**Screenshot** (`screenshot/ScreenshotOverlay.qml`, `scripts/screenshot.sh`)
- Region, full screen or monitor capture with grim. Editing in satty.
- Recording with wf-recorder or gpu-screen-recorder, with desktop and mic volume and device choice.
- OCR with tesseract, with automatic language choice. QR scanning with zbarimg.

**Wallpaper**
- `wallpaper/WallpaperEngine.qml`: two layers, images or video (`MediaPlayer`, looping, paused on request), shader transitions. Writes a per-screen snapshot that the blur uses.

**Settings app** (`guide/`)
- Tabs: Welcome, General (profile, time, location, weather, audio, behaviour, presets), Bar (placement, style, autohide, layout drag editor, module cards), Display (monitors, widgets and presets, lockscreen), Theme (presets, appearance, editor, app theming, font picker), Wallpaper (transition effects), Notifications (position, sounds, behaviour), Screenshot (OCR languages), OSD, Launcher, Dock, Idle, Wellbeing, About.
- A global search index over all settings (`GuideSearchResults`).
- A guided tour from `assets/tutorial.json`: each step names a target and plays a sound.

**Shared components** (`reusables/`)
- Buttons: `ClickButton`, `FillButton` (hold to confirm), `IconButton`, `CanvasIconButton`.
- Inputs: `Toggle`, `Switch`, `Checkbox` (shader), `Input`, `PasswordInput`, `Dropdown`, `NumberSelector`, `TimeSelector`, `TimeRangeSlider`, `SliderProgress`, `FilePicker`, `ImagePicker`, `LyricsPicker`.
- Behaviour: `Draggable` (slider with ticks), `ScreenPositionSelector`, `SpringProgress`, `SubscriptionGate`.
- Display: `MarqueeText` (3 s pause, then scroll), `FlipIcon`, `MaterialDigitGrid`, `LoaderIcon`, `GlassFill`, `GlassLens`, `LiquidGlass`, `LiquidFill`, `FluidWave`, `WallpaperBlur`, `AttachedSurface`, `NotificationBox`, `SystemUsageCard`, `SystemUsageCircle`, `BoundedImage`, `ImageBox`, the focus timer panels.
- Media: `Visualizer`, `WavySeekBar`, `LyricsView`.
- Settings rows: `SettingsRow`, `SettingsGroup`, `DragChipEditor`, `CollapsibleSection`.

**Services and singletons** (`singletons/`)
- `Weather` + `weather.sh` (Open-Meteo forecast and air quality).
- `WeatherAlerts` + `WeatherRules.js`: rain or snow soon, storm, ice, fog, heat or cold, wind, UV, AQI. Quiet hours 22:00 to 05:00.
- `GovAlerts` + `GovAlertsLib.js`: NWS, Environment Canada, BrightSky, met.no, KDE alerts, MeteoAlarm, alert-hub.
- `Location` + `location.sh`: ipapi, ip-api and ipwho.is, or a manual location.
- `Gamma`: night light per monitor with a schedule.
- `Lyrics` + `LyricsMatch.js`: lrclib and NetEase, word-level timing.
- `KeyboardLayout`, `WindowTracker` (window groups and MRU), `CurrentFocus`, `DateTime`, `I18n`.
- `Updater` + `updater.py`: hourly check.
- `SysNotif`: battery full, ≤20% and ≤5% notifications.
- `RecordingState`, `TimerState`, `FocusTimer`.
- Compositor state for Niri, Sway and Mango through `CompositorStateBase`.

**Other directories**
- `config/sddm/themes/material-you/Main.qml`: SDDM theme using the fluid-wave and wallpaper-transition shaders.
- `config/kitty`: kitty config.
- `compositors/*`: keybinds and settings for Hyprland (Lua), Niri, Sway and Mango.
- `install/*`, `nix/*`, `packaging/aur/*`.
- `website/`: Docusaurus site with a WebGL `FluidBackground`.

---

## 3. Motion and feel

**The base vocabulary.** I counted easing types and durations across all QML:

| Easing | Uses |
|---|---|
| OutCubic | 345 |
| OutQuint | 172 |
| OutQuad | 84 |
| OutExpo | 75 |
| OutBack | 67 |
| OutQuart | 39 |
| InOutSine | 37 |
| InCubic | 24 |

| Duration | Uses |
|---|---|
| 250 ms | 423 |
| 150 ms | 252 |
| 400 ms | 153 |
| 800 ms | 63 |
| 600 ms | 37 |

In practice: **150 ms** for colour and opacity, **250 ms `OutCubic`** for small moves and presses, **400 ms `OutQuint`** for size changes, **600 to 800 ms `OutQuint`** for numbers and gauges. This matches loka's FADE, STANDARD and SLOW tokens closely; serpantinum just uses OutCubic or OutQuint where loka's SLOW uses OutExpo. The main difference is that serpantinum *also* uses the patterns below everywhere.

**Popup open and close (`Main.qml`)**
- Geometry morph between popups: 300 ms `OutCubic`.
- Content scale 0.96 → 1: 280 ms `OutCubic` on open, 160 ms `InCubic` on close.
- Opacity: 200 ms on open, 140 ms on close.
- Exit runs 180 ms.
- Closing is about half as long as opening, everywhere in the repo.

**SpringProgress** (`reusables/behavior/SpringProgress.qml`)
- Used by the launcher, clipboard, dashboard, tray, dock and side music popout.
- Open curve: `v(t) = 1 − e^(−7t)·(cos 5.62t + 1.2456·sin 5.62t)` over 700 ms. That is an underdamped spring, ζ ≈ 0.78, ω ≈ 9 rad/s, about 2% overshoot. It restarts from the current value.
- Close: 180 ms `InQuad`, then a 60 ms linger before the surface is unmapped.

**Asymmetric "caterpillar" workspace marker** (`PillsFace.qml`)
- The marker has two animated edges, `actualStart` and `actualEnd`, each `OutQuint`.
- Moving right: the start edge takes 400 ms and the end edge 300 ms. Moving left, the other way round. The leading edge always arrives first, so the pill stretches and then catches up.
- Pills: 36 px active, 18 px inactive.
- Dot x and y move over 650 ms `OutQuint`. Lift is 250 ms.

**Press, pulse and pop micro-interactions** (used in the system panel, buttons and lock)
- Pop on press: scale 1.1 over 110 ms `OutQuad`, back to 1.0 over 400 ms `OutQuint`. The fill button uses 0.95 instead of 1.1.
- Toggle pulse: 0 → 1 over 90 ms `OutQuad`, back to 0 over 560 ms `OutCubic`. It drives a glow in the glass shader.
- Password type pulse: 0.55 over 60 ms, back over 380 ms `OutCubic`. Error pulse: 1.0 over 90 ms, back over 620 ms.
- Wrong password shake: x = 0 → −6 → 6 → −4 → 4 → 0, each step 50 ms (250 ms total).
- Focus pop: 1.02 over 120 ms, back over 250 ms.
- Show or hide password: dots morph to characters with `OutBack`, overshoot 1.25, 250 ms.
- Character slots: staggered 20 ms per index, `OutBack` 1.35.

**Hold to confirm** (`FillButton.qml`)
- Holding fills the button over `fillDuration` = 800 ms, with a looping `charge_loop.wav`.
- The fill edge is a liquid wave: amplitude `min(10, …)·sin(fill·π)`, phase loop 800 ms.
- Releasing early drains the fill. Completing it flashes the button (opacity 400 ms `OutExpo`) and pops it (0.95, then 1.0).

**Notification stack** (`NotificationPopups.qml`)
- Arrival: opacity 250 ms, x from ±0.35 × 350 px, y from ±24 px, all `OutCubic`.
- Removal: opacity 150 ms, slide 250 ms.
- When a card leaves, the others move up over 250 ms.

**Notification card gestures** (`Notification.qml`)
- One `expandProgress` value drives every sub-element through its own opacity window, for example `(p − 0.25)/0.75`, `1 − 3p`, `(p − 0.15)/0.85`. The result is a staged crossfade from one tween.
- Dragging down maps `dy/90px` straight onto that value. On release it settles with hysteresis: it opens past 0.35 and closes below 0.65.
- Horizontal swipe dismisses past 18% of the width, flying to 1.2 × width.

**Real springs** (Qt `SpringAnimation`, used where the motion should feel physical)
- Album disc, driven by bass and kick:
  - Bounce: spring 4.8, damping 0.38, mass 0.85.
  - Tilt: spring 2.8, damping 0.52, mass 0.95.
  - Scale: spring 5.2, damping 0.35, mass 0.75.
  - Halo rings: spring 4.2 and 5.2, damping 0.38 and 0.34.
- Loader blob: spring 6.0, damping 0.5.
- Targets: scale = 1 + 0.0135·bass + 0.027·kick, bounce = −kick·r·0.02025, tilt = (bass − 0.3)·0.9°.

**OSD**
- Show: 450 ms `OutQuint`. Hide: 300 ms `InCubic`. Hides after 1800 ms.

**Network popup ambience**
- Sonar ring: scale 1 → 2.5, opacity 0.8 → 0, 2000 ms `OutSine`, looping.
- Core breathing: 1.0 ↔ 1.1, 2000 ms `InOutSine`.
- Mode switch: 1400 ms `OutExpo`. Orbit angle: 1000 ms `InOutExpo`.

**Gauges and numbers**
- Battery fill: 600 ms `OutQuint`.
- Lock stats: 800 ms `OutQuint`, but only after the reveal reaches 0.98, so values do not move while the panel slides in.

**First run** (`Start.qml`)
- A choreographed `SequentialAnimation`: panel reveal 2000 ms `InOutCubic`, welcome 850 ms, logo scale 0.94 → 1 over 1800 ms `OutExpo`. Each beat has a sound. Typed characters drop in with y 550 ms `OutQuint`.

**Why it feels finished**
1. Every change animates, including colour (150 ms).
2. Closing is shorter than opening and uses an `In*` curve.
3. Interruptible values restart from the current value: SpringProgress `origin = value`, and `Behavior` retargets.
4. Pause timers stop while the card is hovered, expanded or dragged.
5. Updates are throttled: volume commands every 50 ms, brightness every 120 ms, slider ticks every 50 ms.
6. Panel contents wait until their container finishes moving (the `wingsReveal > 0.98` gate).
7. Sound is tied to almost every action.

---

## 4. Visual techniques

**Shaders** (`src/assets/shaders/`). All compute anti-aliasing with `clamp(0.5 − d, 0, 1)` on a signed distance d.

| Shader | What it does | Math |
|---|---|---|
| `effects/liquid_glass` | Liquid-glass panel | Rounded-box SDF (or a field of up to 6 shapes merged by smooth-min). Edge normal from the SDF gradient, bezel slope `om³/(1−om⁴)^0.75`. `refract()` with an index of refraction displaces samples. Dispersion samples R and B at `dG·(1±spread)`. Frost blur: 6 to 10 golden-angle taps on a mip level picked as `log2(gap)`. Fresnel `(1−n.z)^1.5` blends in a farther sample. Rim light: hairline `e^(−t/1.1)` + wide `e^(−t/5)` from light direction (−0.55, −0.83), biased towards the cursor while hovered. A cursor-following gaussian bulge. A spectral fringe band `0.5+0.5cos(2π(x+[0, .33, .67]))`. Grain ±0.004. |
| `ui/surface_field(_tex)` | Panels melt into each other | Up to 6 rounded-rect SDFs. Pairwise smooth-min `smin(a,b,k)=max(k,min(a,b))−‖max(k−(a,b),0)‖` with k capped at the smaller rect side. Roles: own, owner, dependent. Final coverage is own minus owner, so each surface draws only its part of the merged shape. |
| `transitions/wallpaper_transition` + `wallpaper_blend` | Wallpaper change masks | Fade; split wipe `halfSpan − |x − c|`; circle `p·maxCornerDist − |p − o|`; directional swipe in 8 directions via dot product; **paint** (below). |
| — paint transition | Paint spreading from a point | Cells of `max(3, h/270)` px. Arrival time = minimum over a 3×3 Voronoi neighbourhood of seeded colonies (site jitter 0.15 + 0.7·hash, start delay 0.45·hash^1.5), plus `0.55·(d/1.9)^1.3`, warped by fbm (0.52/0.30/0.18 octaves) times roughness. A cell shows when arrival ≤ progress. A "burn" glow lasts 0.06 of progress at the front. |
| `effects/curtain_wipe` | 5 coloured curtains then a reveal | Per layer: `prog=(reveal − i·0.079)·1.65`, front `y = h·smooth(prog) + (0.62 sin(2πf₁u+φ) + 0.38 sin(2πf₂u+φ))·amp·sin(πprog)^0.7`. Soft shadow ahead of the front, `0.24·e^(−d/…)`, and a crest highlight. |
| `effects/screen_wipe` | Horizontal 5-layer wipe | Cubic Bézier front in y with sin and cos control points. Stagger 0.05, speed 2.5. |
| `effects/vignette` | Radial darkening | Linear from inner 0.4 to outer 0.75 of max(w, h). |
| `fluid/fluid_wave` | Battery and progress liquid | Rounded box ∩ a fill line displaced by the cubic Bernstein weights b1 and b2 times sin and cos of the phase. |
| `fluid/liquid_fill` | Same, with lighting | Meniscus hairline and lens highlight, rim spec, sheen, caustics `sin(0.11x + 1.3φ + 0.05y)`. |
| `fluid/logo_water_wave` | Logo fill | 5 layers of 3 summed sines. |
| `audio/visualizer_bars` | Bars in a row or around a ring | 128 levels packed in eight `mat4` uniforms. Per-pixel bar index, rounded free end, edge fade `sin(i/n·π)·2` smoothstepped, tint towards white by `(i/n·0.4 + level·0.6)`. |
| `audio/visualizer_wave` | Smooth wave | Quadratic curves through midpoints. Distance = `(t − y)/√(1+slope²)`, which gives an exact-width stroke without tessellation. |
| `audio/visualizer_ring_wave` | Radial wave | Linear interpolation between angular samples, distance corrected by the angular slope. |
| `audio/seekbar_wave` | Wavy seek bar | Two sine layers on top of a capsule track. Quintic envelope `t³(6t²−15t+10)` tapers both ends. A swell modulates at k/6. |
| `gauges/circular_wave_gauge(_smooth)` | Ring gauge with a wavy arc | `r = R + amp·sin(cycles·θ)`. The smooth version finds the nearest point on the wavy curve with a 16-sample search plus 4 bisection steps. |
| `gauges/clock_lumen_dial` | 12-bump clock rim | `r = rBase + rAmp·(0.28 + 0.72·w_h)·½(1 + cos(diff/15°·π))`. Each hour bump has its own weight. |
| `gauges/clock_second_arc` | Seconds arc with round caps | Arc SDF from tail to head. |
| `lock/fingerprint_ring` | Scanning ring | Two modes. "Orbit": a comet with tail `(1 − behind·1.15)^2.2`, bloom `e^(−38d)`. "Liquid": a wobbling ring `Σ sin(kθ + t)` plus 3 satellite blobs merged by polynomial smooth-min. A burst shock ring. |
| `lock/fingerprint_success` | Firework on unlock | 2 expanding rings + 16 sparks with gravity `0.1·pt²`, twinkle, `easeOut³`. |
| `ui/checkbox` | Checkbox | Radial fill wave + check mark drawn progressively along 2 segments. |
| `ui/loader_blob` | Morphing spinner | Rose curve `r = 1 + d·cos(pθ)` with x/y stretch, blending between 7 configs (p = 7, 9, 5, 2, 8, 4, 0). |
| `ui/dashed_ellipse` | Even dashes on an ellipse | Arc length by 32-step numeric integration. |
| `ui/grid_pattern`, `ui/marquee_scroll`, `ui/rounded_mask` | Grid, scrolling text, per-corner rounded mask | Straightforward. |
| `vfx/eq_lightning` | Lightning through EQ band points | 4 strands (glow to core) of jittered segments, `sin(t·π)` envelope. |
| `vfx/node_beams_clipped` | Beams from the network core to nodes | Same strand idea for up to 16 beams. |
| `widgets/pacman` | Pac-Man | Circle SDF minus a mouth wedge, plus an eye. |
| `widgets/widget_outline` | Wavy selection outline | Exact arc-length parameter around a rounded rect (corner arcs via atan); offset = `amp·sin(freq·s + phase)`, frequency picked so a whole number of waves fits. |

**Blur is fake, and that is the useful part** (`reusables/display/WallpaperBlur.qml`)
- It never samples the windows behind a panel. It samples the **wallpaper** only.
- Each wallpaper layer (or a frame of a video wallpaper) is rendered off-screen at **¼ screen resolution** (½ in liquid-glass mode).
- It is placed in the panel's local coordinates through `mapFromItem`. That accounts for the panel's offset, scale and rotation and is recomputed every frame.
- Then a `MultiEffect` blur runs (`blurMax` 64, 64 px padding, cropped). During a wallpaper transition it blends both layers with the same transition mask.
- Nested glass gets weaker: `nest = min(1, level·0.5)`. Glass mode forces white text.

**Shapes**
- Corner radius is clamped softly: `r ≤ 24 ? r : 24 + (r−24)^0.55`.
- Per-corner radii everywhere.
- Fillets where a surface meets a screen edge: the screen edges themselves are registered as huge rectangles in the field (`edges: ["top"]`), and smooth-min does the rest.
- Corners that touch a neighbour are flattened to 0 (`flattenTouching`).

**Typography**
- About 40 bundled fonts. The default is Adwaita Mono. Also Google Sans Flex, SF Pro, IBM Plex and Nerd Fonts.
- Fonts are scanned with `fc-scan` into a cache.
- Icons come from the Symbols Nerd Font loaded through `FontLoader`.
- `MaterialDigitGrid` draws clock digits from measured glyph ink rectangles.
- Marquee text pauses 3 s, then scrolls at a speed based on distance (at least 1000 ms).
- Monospace digits keep time from jittering.

**Colour generation**
- matugen with Material You tonal-spot from the wallpaper; for video wallpapers it uses an ffmpeg frame grabbed at 1 s.
- 70 or more preset themes (gemstone names plus Nord, Gruvbox, Catppuccin and others), sorted by hue bucket in `theme_sorter.py`. Hue is ignored below saturation 0.12.
- Album art: ImageMagick quantizes a 50×50 thumbnail to 3 colours, which become a 45° gradient. Text colour comes from 6 Rec.601 brightness bands, for example <70 gives `#fff` and ≥235 gives `#1e1e2e`.

---

## 5. System integration

| Area | Implementation |
|---|---|
| Lock | `WlSessionLock` (ext-session-lock), `Quickshell.Services.Pam` with the `serpantinum` PAM service if present. Fingerprint PAM runs in parallel; a no-fingerprint stack is built at runtime. Optional attempt limit with lockout. Video lock background. Lock-on-sleep from `serpantinum-core watch idle`. |
| Idle | Quickshell idle monitors per action. Inhibited by MPRIS playback or `org.freedesktop.ScreenSaver` (seen through `serpantinum-core`). Dim through an overlay, DPMS through compositor commands. Suspend locks first. |
| Polkit | `Quickshell.Services.Polkit.PolkitAgent`. Exclusive keyboard focus, 55% scrim, Escape cancels, shows the action ID and supplementary errors. |
| Notifications | `Quickshell.Services.Notifications.NotificationServer` with body, actions and images. Grouping by desktop entry, with an alias table and `heuristicLookup`; channel suffixes such as canary or beta are stripped. Critical notifications are never grouped and never time out. Flood guard: drops non-critical notifications under 100 ms apart. 500 ms startup grace. Popups are cleared while the system panel is open. The shell sends its own alerts with `notify-send --icon battery-kind-low` or `weather-kind-…`, and the card type is chosen by matching that icon name. |
| Media | `Quickshell.Services.Mpris`. Active player = playing, else last playing, else loaded, else controllable. Position polled at 1 s. Art upgraded to the largest size per CDN (YouTube maxres, Spotify ab67…b273, Apple 1400×1400bb, Deezer, Bandcamp, Tidal, SoundCloud, Amazon). Local files fall back to the embedded cover through ffmpeg, then `cover.jpg` or `folder.jpg`. Cache keeps 35 entries. Output device detected through `wpctl inspect` (Bluetooth, USB or built-in). |
| Lyrics | lrclib `/api/get` and NetEase cloudsearch, word-level timing. Position polling: 25 ms within 0.3 s of a line boundary, 100 ms otherwise, 250 ms when paused. |
| Audio | `Quickshell.Services.Pipewire` nodes for outputs, inputs and streams. The shell's own sound streams are filtered out by `application.id`. Volume can go to 150%. DSP and spectrum come from `serpantinum-audio`, with crash restart (at most 5 times, 500 ms backoff) and a 1200 ms decay after playback stops. |
| Network and Bluetooth | `Quickshell.Networking` (Wi-Fi on or off, devices) and `Quickshell.Bluetooth` (adapter, devices, battery). Airplane mode = both off. A2DP/HFP profile from `pactl`. |
| Power | UPower display device; power-profiles. Power scripts in `scripts/system/*.sh`. |
| Brightness | `serpantinum-core brightness set` (throttled at 120 ms). |
| Night light | `serpantinum-gamma set <kelvin> <monitor> <mode> <lat> <lon>`, per monitor, scheduled from sunrise and sunset. |
| Screenshot | grim with a crop of a frozen frame. Edit in satty. `wl-copy`. |
| Recording | wf-recorder or gpu-screen-recorder; desktop and mic sources with volume and mute; state in `RecordingState`. |
| OCR | tesseract. Up to 24 installed languages are each scored with `conf·√(chars/maxchars)`, grouped by script (Latin, Cyrillic, CJK, Arabic), and a `lang+lang` string is built. QR codes through zbarimg. |
| Clipboard | cliphist + `wl-paste --watch`. Pins through `serpantinum-core clipboard pin`. |
| Wallpaper | Built-in QML engine: images plus `MediaPlayer` video. 5 transitions with duration settings (fade 1000 ms, wipe, circle and swipe 1600 ms, paint 2400 ms). Random pick from a folder. DuckDuckGo image search. |
| Weather | Open-Meteo forecast (hourly, daily sunrise and sunset, one past day) and air quality. Location from IP (3 providers) or set manually. Rule-based alerts with quiet hours. Official warnings from 7 regional APIs. |
| Calendar | Local calendar only. No ICS or CalDAV. |
| Wellbeing | Per-app focus time through `serpantinum-core screentime track`, plus app limits. |
| Keyboard | Layout through the compositor (`hyprctl` or `swaymsg`). OSD for caps lock and num lock. |
| Updates | Hourly check, shown as an "Update" notification card. |
| App theming | `apptheme.py` with about 50 manifests, marker-delimited config insertion, reload signals. |

---

## 6. Polish details

- **Sound design.** Every widget type has its own sound:
  - Click, icon button, toggle, switch, dropdown open and list, a tick while typing, a slider tick throttled to 50 ms, a looping charge sound for hold buttons.
  - Network power on and off, connect, disconnect, error.
  - A swoosh for the music popup, 7 notification sounds to choose from.
  - Sounds play through `pw-play` with `media.role=event` and a global sound-effect volume and mute.
  - A notification sound plays only if the notification is under 3 s old and DND is off.
- **Empty states.** `RedactorEmptyState`, loader dots, morphing blob spinners, a placeholder gradient for missing art.
- **Hover and press.** Every glass control has `press` and `pulse` inputs; hover sets press to 0.25 to 0.3.
- **Keyboard.** Escape closes every popup. The launcher switches between keyboard and mouse navigation. Settings search.
- **Notification card.** Relative time ("just now", "N min ago", "yesterday"). The time moves to its own row when it does not fit. An expand button flips. Right-click closes (configurable).
- **Timeouts.** Default 5 s, 10 s for battery cards, 0 (never) for critical notifications.
- **Interactive OSD.** The OSD can be dragged and scrolled. Raising a muted volume above 0 unmutes it.
- **Fullscreen.** The bar hides and the OSD knows it is fullscreen. Popups move 46 px towards the edge when the bar is hidden.
- **Robustness.** Generation counters, safety timers, crash backoff, de-duplicated matugen requests (identical requests are skipped, the latest pending one wins), atomic config writes, and a shell reload that suppresses the error popup.
- **First run.** A cinematic intro, then a guided tour that highlights each area with a sound per step. Settings presets can be saved and applied, with a confirmation popup.
- **Internationalisation.** RTL support (`I18n.layoutDirection`), with fallback strings everywhere.

---

## 7. Port list for loka (best value for effort first)

Effort assumes Rust + tiny-skia on X11. "loka today" is what I checked in the source.

| # | Idea | Why it is good | loka today | Effort | Target file |
|---|---|---|---|---|---|
| 1 | Pause the toast timer while hovered; resume with the time left | The most noticed notification bug | `Toast.until` is fixed; `tick` drops it on time even while hovered | S | `island.rs` (`tick`, `motion`) |
| 2 | Asymmetric workspace marker: leading edge 300 ms, trailing 400 ms `OutQuint` | Makes switching workspaces feel alive | Tweens each workspace width with one duration; no separate marker | S | `bar.rs` (`set_focused`, render) |
| 3 | Press pop (0.95, 110 ms `OutQuad`, then 1.0, 400 ms `OutQuint`) and toggle pulse (90 / 560 ms) | Every tap visibly responds | Hover fade only (`hover_k`, FADE) | S | `ui.rs` (`button`, `toggle`, `tile`), `anim.rs` (add a two-phase pulse) |
| 4 | Relative timestamps ("just now", "N min", "yesterday") | Easier to scan history | Absolute `%H:%M` | S | `notify.rs` (store an `Instant`), `pages.rs` |
| 5 | Group history by app; never group critical; 100 ms flood guard | Keeps a noisy chat app from filling the list | Flat list, last 10 | S | `app.rs` (`Msg::Notify`), `pages.rs` (`notifications`) |
| 6 | Wrong-password shake (−6, 6, −4, 4, 0 × 50 ms) + error pulse | Clear error feedback | Wi-Fi password entry has none | S | `pages.rs` (wifi), `ui.rs` |
| 7 | Hold to confirm for power off, reboot, logout: 800 ms fill, drain on release, flash | No misclicks, no confirmation dialog | Click runs the action immediately | S | `pages.rs` (`power`), `ui.rs` |
| 8 | Draggable and scrollable OSD; raising from 0 unmutes; 50 ms volume / 120 ms brightness throttle | OSD becomes a control, not just a display | 1400 ms read-only OSD | S | `island.rs` (`show_osd`, `press`), `app.rs` (`slider`) |
| 9 | Slider tick sound throttled to 50 ms | Feels physical | `sound()` exists; no ticks | S | `app.rs` (`slider`) |
| 10 | Close faster than open (≈0.6×, `In*` curve) | A snappier close | One spring (0.42 s, ζ 0.82) both ways | S | `island.rs` (`retarget`: `Spring::new` per direction) |
| 11 | Notification app icons and `image-data` / `image-path` hints | Recognise a toast at a glance | `_app_icon` ignored; no image hints | M | `notify.rs`, `icons.rs` (already has `lookup` and `decode_png`), `island.rs` |
| 12 | Drag down to expand a toast (dy/90 px), hysteresis 0.35 / 0.65, staged opacity windows | Read long toasts without opening the centre | Toast is fixed size | M | `island.rs` |
| 13 | Swipe to dismiss toasts (> 18% of width, fly to 1.2× width) | Fast dismissal | Click only | S | `island.rs` |
| 14 | **Wallpaper-sampled blur** behind the island and pages: ¼-scale blur done once per wallpaper change, cropped by screen position | The glass look at almost no runtime cost; needs no compositor | Solid `pal.bg` | M | new `blur.rs` (box blur ×3 ≈ gaussian on a ¼-size `Pixmap`), `island.rs` (`draw_shape` as clip mask), `walls.rs` (trigger) |
| 15 | Rim light: hairline `e^(−t/1.1)` + wide `e^(−t/5)` lighter edge on top-left faces | Gives depth to the flat pill | None | S | `canvas.rs` (gradient `stroke_round`) |
| 16 | Wavy seek bar for now playing (two sines, quintic end tapers, amplitude tweened to 0 when paused) | A cheerful, distinctive media line | Media peek has no progress wave | M | `island.rs` (media peek), new path helper in `canvas.rs` |
| 17 | Liquid battery fill with a moving wave while charging | Charging state is visible | Glyph and percent | S | `bar.rs` (battery part) |
| 18 | Sonar rings while scanning Wi-Fi / Bluetooth (scale 1 → 2.5, alpha 0.8 → 0, 2 s `OutSine`, looping) | Shows a scan is running | Static list | S | `pages.rs` (wifi, bt) |
| 19 | Morphing blob spinner (rose curve `1 + d·cos pθ`, 7 shapes, spring morph every 650 ms) | Finished-looking loading state | None | S | `ui.rs` |
| 20 | Gradient and text colour from album art (3-colour quantize, Rec.601 bands) | Media card matches the cover | `loka-art` makes thumbnails only | S | `bin/loka-art` (add a palette line), `mpris.rs`, `island.rs` |
| 21 | Hi-res art URL rewriting per CDN (YouTube maxres, Spotify b273, Apple 1400bb, …) | Sharp covers | Uses the URL as given | S | `bin/loka-art` |
| 22 | Timed caffeine with time remaining shown | Common need | Coffee on/off via `systemd-inhibit` + `xset` | S | `app.rs` (`set_coffee`), `pages.rs` |
| 23 | Idle pipeline dim → lock → DPMS → suspend, with warnings and MPRIS inhibit | Proper idle handling | `xset s 600` + DPMS only | M | `app.rs`, new `idle.rs` (X11 ScreenSaver extension via x11rb; dim with an ARGB overlay window) |
| 24 | Night light schedule from sunrise and sunset | Eye comfort, automatic | None | M | new `gamma.rs` (RandR `set_crtc_gamma` via x11rb; Kelvin to RGB). Portable; Serpantinum's daemon is Wayland-only. |
| 25 | Clipboard pins (pinned section first) | Keep snippets | Search, images, delete, wipe; no pins | S | `clip.rs` (pin flag file), `pages.rs` |
| 26 | OCR and QR from a screen region with automatic tesseract language scoring | Very handy | Screenshot exists; no OCR or QR | S | `loka/scripts/` + an `Act::Exec` entry in `pages.rs` |
| 27 | Synced lyrics in the island peek (lrclib, adaptive 25 / 100 / 250 ms polling) | A strong "dynamic island" moment | None | M | new `lyrics.rs`, `mpris.rs`, `island.rs` |
| 28 | Spectrum visualizer (64 bars, edge fade `sin(iπ/n)`, 1.2 s decay) | Ambient life while music plays | None | M | `audio.rs` (record the monitor source over the pulse protocol + FFT with the `rustfft` crate) or `cava` raw output; `island.rs` |
| 29 | Disc "beat" springs (scale += 0.0135·bass + 0.027·kick, spring ζ ≈ 0.35) | Art pulses with the music | — | S (after #28) | `island.rs` with `anim::Spring` (≈ response 0.3, ζ 0.35) |
| 30 | Weather in the calendar page + rule-based alerts (rain within 3 h, storm, heat or cold, UV) with quiet hours 22–05 | Useful, low noise | None | M | new `weather.rs` (Open-Meteo through a `curl` subprocess), `pages.rs` (`calendar`) |
| 31 | Sun arc (sun position between sunrise and sunset) | A pleasant calendar detail | Calendar grid only | S (after #30) | `pages.rs` (`calendar`) |
| 32 | Attach the tray menu, OSD and toasts to the bar with smooth-min fillets | One continuous shape, like the island flare | Island has a quad-curve flare; `menu.rs` is a separate box | M | `canvas.rs` (raster smooth-min of 2 rounded-rect SDFs into a mask), `menu.rs` |
| 33 | Settings search across every page | Scales as settings grow | Settings page, no search | M | `pages.rs` (`settings`), `app.rs` key handling |
| 34 | Pomodoro and timer in the island with a ring | Fits loka's toast-ring design | Toast has a `ring` field | M | `island.rs`, `app.rs`, `pages.rs` |
| 35 | Paint wallpaper transition (Voronoi colonies + fbm arrival field, 2.4 s) | Distinctive look | mathwall has a 0.9 s circle | M | `mathwall/` GLSL, not loka |
| 36 | Screen time per i3 window class | Wellbeing data from i3 focus events loka already receives | Focus is tracked for the bar only | M | new `screentime.rs`, `i3.rs` |
| 37 | Polkit agent page | Avoids a separate agent | None found in loka | L | new `polkit.rs` (zbus `org.freedesktop.PolicyKit1.AuthenticationAgent` + `polkit-agent-helper-1`) |
| — | First-run cinematic, desktop widgets editor, dock magnification | Low value on i3 | — | — | skip |

**Wayland-only. These cannot be ported as written:**
- `WlSessionLock` lock screen. On X11 keep i3lock and xss-lock. A custom X11 locker would only be a keyboard grab, which is weaker.
- Layer-shell masks, exclusion zones and `ToplevelManager`.
- `serpantinum-gamma` (wlr-gamma). Use RandR instead (#24).
- grim, wf-recorder and gpu-screen-recorder's Wayland paths. Use maim or ffmpeg x11grab.
- `hyprctl`, `niri msg`, `swaymsg` calls.
- Real refraction of the *windows* behind a panel. Serpantinum does not do this either; it samples the wallpaper (#14), and that part does port.

---

## 8. Licence

`LICENSE.md` is **GNU AGPL v3, or any later version**, copyright 2026 Illia Miroshnichenko.

- **Ideas, behaviours, timings and the maths** (spring constants, easing choices, the stretchy marker, hold to confirm, the OCR scoring approach, SDF and smooth-min formulas, which are standard published techniques) are not covered by copyright. Re-implement them in Rust from the descriptions above.
- **Copying code** makes loka a derivative work under AGPL-3.0. That covers QML, JS, GLSL, shell or Python, and close line-by-line translations of them into Rust. loka would then have to ship under AGPL with source, and the network-use clause would apply. Write the shader maths fresh, not by transliterating the GLSL.
- **Assets** (about 40 fonts including SF Pro and TT Commons, 60 MB of sounds, images, theme JSONs) may have their own licences. SF Pro's licence, for example, limits use to Apple platforms. Do not copy any of them; use your own sounds and fonts.
- Do not copy the installer telemetry pattern.
