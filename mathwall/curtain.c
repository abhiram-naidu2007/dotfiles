// rice-curtain: hold the screen still while the desktop changes its looks underneath.
//
// A change of mood or wallpaper restarts the bar, reloads the window manager and sometimes the
// compositor: a second of things blinking in and out. This program copies the screen into a
// window that covers everything, stays on top while that happens, and on SIGUSR1 (or after
// four seconds, whatever happened to its caller) dissolves over a third of a second. What you
// see is the old desktop melting into the new one. Clicks pass through it.
// It prints "up" once the copy is on screen. Build: make -C ~/dotfiles/mathwall install
#define _GNU_SOURCE
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/extensions/shape.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <time.h>

static volatile sig_atomic_t lift;
static void on_signal(int sig) { (void)sig; lift = 1; }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }

int main(void) {
    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) return 1;
    int screen = DefaultScreen(dpy), w = DisplayWidth(dpy, screen), h = DisplayHeight(dpy, screen);
    Window root = RootWindow(dpy, screen);
    // the screen as it is now, copied inside the X server
    Pixmap copy = XCreatePixmap(dpy, root, w, h, DefaultDepth(dpy, screen));
    XGCValues values = {.subwindow_mode = IncludeInferiors};
    GC gc = XCreateGC(dpy, root, GCSubwindowMode, &values);
    XCopyArea(dpy, root, copy, gc, 0, 0, w, h, 0, 0);
    XSetWindowAttributes attrs = {.override_redirect = True, .background_pixmap = copy};
    Window win = XCreateWindow(dpy, root, 0, 0, w, h, 0, CopyFromParent, InputOutput, CopyFromParent,
                               CWOverrideRedirect | CWBackPixmap, &attrs);
    XClassHint hint = {"rice-curtain", "rice-curtain"};
    XSetClassHint(dpy, win, &hint);
    XStoreName(dpy, win, "rice-curtain");
    XShapeCombineRectangles(dpy, win, ShapeInput, 0, 0, NULL, 0, ShapeSet, Unsorted);   // no input: clicks go through
    XSelectInput(dpy, root, SubstructureNotifyMask);
    XMapRaised(dpy, win);
    XSync(dpy, False);
    puts("up");
    fflush(stdout);

    struct sigaction sa = {.sa_handler = on_signal};
    sigaction(SIGUSR1, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);
    double start = now();
    while (!lift && now() - start < 4.0) {
        // a bar that restarts or a new window lands above us: go back on top
        while (XPending(dpy)) {
            XEvent ev;
            XNextEvent(dpy, &ev);
            if ((ev.type == MapNotify && ev.xmap.window != win) || (ev.type == ConfigureNotify && ev.xconfigure.window != win))
                XRaiseWindow(dpy, win);
        }
        XFlush(dpy);
        struct pollfd fd = {ConnectionNumber(dpy), POLLIN, 0};
        poll(&fd, 1, 50);
    }
    // dissolve: the compositor reads this property; without one the window simply goes
    Atom opacity = XInternAtom(dpy, "_NET_WM_WINDOW_OPACITY", False);
    const int steps = 20;
    for (int i = steps - 1; i >= 0; i--) {
        double x = (double)i / steps;
        unsigned long value = (unsigned long)(0xffffffffu * (x * x * (3 - 2 * x)));
        XChangeProperty(dpy, win, opacity, XA_CARDINAL, 32, PropModeReplace, (unsigned char *)&value, 1);
        XFlush(dpy);
        nanosleep(&(struct timespec){0, 16 * 1000 * 1000}, NULL);
    }
    XDestroyWindow(dpy, win);
    XFreePixmap(dpy, copy);
    XCloseDisplay(dpy);
    return 0;
}
