// mochi: a pixel-art cat you summon on demand. It walks in, sits and naps until SIGTERM,
// then sprints off screen and exits. Clicks pass straight through it.
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/extensions/shape.h>
#include <ctype.h>
#include <dirent.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define ART_W 16
#define ART_H 12
#define SCALE 4
#define WIN_W (ART_W * SCALE)
#define WIN_H (ART_H * SCALE)

enum { WALK1, WALK2, SIT, SLEEP1, SLEEP2, NFRAMES };

// Facing right. '.' transparent, '#' outline, 'o' fur, 'p' cheek, 'z' snore.
static const char *const ART[NFRAMES][ART_H] = {
    [WALK1] = {"..........#...#.", ".........#o#.#o#", ".........#ooooo#", "##.......#o#o#o#",
               "#o#......#ppopp#", ".#o########oooo#", "..#ooooooooooo#.", "..#ooooooooooo#.",
               "..#ooooooooooo#.", "..#oo#....#oo#..", "..#o#......#o#..", "..##.......##..."},
    [WALK2] = {"..........#...#.", ".........#o#.#o#", ".........#ooooo#", "##.......#o#o#o#",
               "#o#......#ppopp#", ".#o########oooo#", "..#ooooooooooo#.", "..#ooooooooooo#.",
               "..#ooooooooooo#.", "....#oo##oo#....", "....#o#..#o#....", "....##...##....."},
    [SIT] = {"..........#...#.", ".........#o#.#o#", ".........#ooooo#", "##.......#o#o#o#",
             "#o#......#ppopp#", ".#o########oooo#", "..#ooooooooooo#.", "..#ooooooooooo#.",
             "..#ooooooooooo#.", "..#ooooooooooo#.", "..#oooo#ooo#oo#.", "...###..###.##.."},
    [SLEEP1] = {"................", ".zz.............", "..z.............", ".zz.............",
                "...........#.#..", "....#######o#o#.", "...#oooooooooo#.", "..#oooooooo#o#o#",
                "..#ooooooopopo#.", "..#oooooooooooo#", "..#oooooooooooo#", "...############."},
    [SLEEP2] = {"..zz............", "...z............", "..zz............", "................",
                "...........#.#..", "....#######o#o#.", "...#oooooooooo#.", "..#oooooooo#o#o#",
                "..#ooooooopopo#.", "..#oooooooooooo#", "..#oooooooooooo#", "...############."},
};

static Display *dpy;
static Window root, win;
static Pixmap color_pix[NFRAMES][2], mask_pix[NFRAMES][2];
static int screen_w, screen_h;
static volatile sig_atomic_t running = 1;

static void request_exit(int sig) { (void)sig; running = 0; }

static int ignore_x_errors(Display *d, XErrorEvent *e) { (void)d; (void)e; return 0; }

static unsigned long palette_lookup(const char *key, const char *fallback) {
    char path[512], line[256], hex[16] = "";
    snprintf(path, sizeof path, "%s/.config/polybar/colors.ini", getenv("HOME"));
    FILE *f = fopen(path, "r");
    if (f) {
        size_t n = strlen(key);
        while (fgets(line, sizeof line, f)) {
            if (!strncmp(line, key, n) && line[n] == ' ') {
                char *h = strchr(line, '#');
                if (h && sscanf(h + 1, "%15[0-9a-fA-F]", hex) == 1) break;
            }
        }
        fclose(f);
    }
    if (strlen(hex) != 6) strcpy(hex, fallback);
    XColor c;
    char spec[16];
    snprintf(spec, sizeof spec, "#%s", hex);
    Colormap map = DefaultColormap(dpy, DefaultScreen(dpy));
    XParseColor(dpy, map, spec, &c);
    XAllocColor(dpy, map, &c);
    return c.pixel;
}

static void build_frames(void) {
    unsigned long outline = palette_lookup("bg-solid", "10070a");
    unsigned long fur = palette_lookup("accent", "f2ad6c");
    unsigned long cheek = palette_lookup("magenta", "d7a0e3");
    unsigned long snore = palette_lookup("accent2", "adb0f6");
    GC gc = XCreateGC(dpy, root, 0, NULL);
    for (int f = 0; f < NFRAMES; f++) {
        for (int flip = 0; flip < 2; flip++) {
            Pixmap p = XCreatePixmap(dpy, root, WIN_W, WIN_H, DefaultDepth(dpy, DefaultScreen(dpy)));
            Pixmap m = XCreatePixmap(dpy, root, WIN_W, WIN_H, 1);
            GC mgc = XCreateGC(dpy, m, 0, NULL);
            XSetForeground(dpy, mgc, 0);
            XFillRectangle(dpy, m, mgc, 0, 0, WIN_W, WIN_H);
            XSetForeground(dpy, mgc, 1);
            for (int y = 0; y < ART_H; y++) {
                for (int x = 0; x < ART_W; x++) {
                    char ch = ART[f][y][x];
                    if (ch == '.') continue;
                    unsigned long c = ch == 'o' ? fur : ch == 'p' ? cheek : ch == 'z' ? snore : outline;
                    int dx = (flip ? ART_W - 1 - x : x) * SCALE;
                    XSetForeground(dpy, gc, c);
                    XFillRectangle(dpy, p, gc, dx, y * SCALE, SCALE, SCALE);
                    XFillRectangle(dpy, m, mgc, dx, y * SCALE, SCALE, SCALE);
                }
            }
            XFreeGC(dpy, mgc);
            color_pix[f][flip] = p;
            mask_pix[f][flip] = m;
        }
    }
    XFreeGC(dpy, gc);
}

static int is_locked(void) {
    DIR *d = opendir("/proc");
    if (!d) return 0;
    struct dirent *e;
    int found = 0;
    char path[300], comm[32];
    while (!found && (e = readdir(d))) {
        if (!isdigit((unsigned char)e->d_name[0])) continue;
        snprintf(path, sizeof path, "/proc/%s/comm", e->d_name);
        FILE *f = fopen(path, "r");
        if (!f) continue;
        if (fgets(comm, sizeof comm, f) && !strcmp(comm, "i3lock\n")) found = 1;
        fclose(f);
    }
    closedir(d);
    return found;
}

static void draw(int frame, int flip, int x, int y) {
    XMoveWindow(dpy, win, x, y);
    XShapeCombineMask(dpy, win, ShapeBounding, 0, 0, mask_pix[frame][flip], ShapeSet);
    XCopyArea(dpy, color_pix[frame][flip], win, DefaultGC(dpy, DefaultScreen(dpy)), 0, 0, WIN_W, WIN_H, 0, 0);
    XFlush(dpy);
}

static void nap(int ms) { usleep((useconds_t)ms * 1000); }
static int pick_target(void) { return screen_w * 45 / 100 + rand() % (screen_w * 40 / 100); }

int main(void) {
    if (!(dpy = XOpenDisplay(NULL))) return 1;
    XSetErrorHandler(ignore_x_errors);
    struct sigaction sa = {.sa_handler = request_exit};
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);
    root = DefaultRootWindow(dpy);
    screen_w = DisplayWidth(dpy, DefaultScreen(dpy));
    screen_h = DisplayHeight(dpy, DefaultScreen(dpy));
    srand((unsigned)time(NULL));

    XSetWindowAttributes attrs = {.override_redirect = True, .background_pixmap = None};
    win = XCreateWindow(dpy, root, screen_w, screen_h, WIN_W, WIN_H, 0, CopyFromParent, InputOutput,
                        CopyFromParent, CWOverrideRedirect | CWBackPixmap, &attrs);
    XClassHint hint = {"mochi", "mochi"};
    XSetClassHint(dpy, win, &hint);
    XStoreName(dpy, win, "mochi");
    XShapeCombineRectangles(dpy, win, ShapeInput, 0, 0, NULL, 0, ShapeSet, Unsorted);
    build_frames();

    int y = screen_h - WIN_H - 10;
    int x = screen_w, target = pick_target(), sat = 0, flip = 1, slept = 0;
    enum { WALKING, SITTING, SLEEPING } state = WALKING;
    XMapRaised(dpy, win);
    for (int tick = 0; running; tick++) {
        if (tick % 16 == 15) {
            // Never draw over the lock screen.
            if (is_locked()) { XUnmapWindow(dpy, win); XFlush(dpy); nap(2000); continue; }
            XMapRaised(dpy, win);
        }
        if (state == WALKING) {
            int dir = target > x ? 1 : -1;
            flip = dir < 0;
            x += dir * 12;
            draw(tick % 2 ? WALK2 : WALK1, flip, x, y);
            if (abs(target - x) < 12) { state = SITTING; sat = 0; }
            nap(120);
        } else if (state == SITTING) {
            draw(SIT, flip, x, y);
            if (++sat > 28) {
                if (rand() % 2) { target = pick_target(); state = WALKING; }
                else { state = SLEEPING; slept = 0; }
            }
            nap(120);
        } else {
            draw(tick % 2 ? SLEEP2 : SLEEP1, flip, x, y);
            if (++slept > 40) { target = pick_target(); state = WALKING; }
            nap(700);
        }
    }
    // Dismissed: sprint off the right edge.
    while (x < screen_w) { x += 56; draw(x / 56 % 2 ? WALK2 : WALK1, 0, x, y); nap(30); }
    XUnmapWindow(dpy, win);
    XFlush(dpy);
    return 0;
}
