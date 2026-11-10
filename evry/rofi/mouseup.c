// mouseup: return once no mouse button is held (or after a second).
//
// A menu opened by a click starts while that button is still down. rofi, which grabs the
// pointer, then receives the release: it takes it for a click outside its window and closes
// at once (click-to-exit), or it accepts whichever row has just appeared under the pointer.
// From the outside that is "the picker needs two clicks" and "it chose something else".
// ~/.local/bin/rofi runs this first, so every menu of the desktop starts with the buttons up.
#include <X11/Xlib.h>
#include <time.h>

int main(void) {
    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) return 0;
    const unsigned buttons = Button1Mask | Button2Mask | Button3Mask;
    for (int i = 0; i < 100; i++) {
        Window root, child;
        int rx, ry, wx, wy;
        unsigned mask = 0;
        XQueryPointer(dpy, DefaultRootWindow(dpy), &root, &child, &rx, &ry, &wx, &wy, &mask);
        if (!(mask & buttons)) break;
        nanosleep(&(struct timespec){0, 10 * 1000 * 1000}, NULL);
    }
    XCloseDisplay(dpy);
    return 0;
}
