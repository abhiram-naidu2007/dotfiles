# mathwall: animated strange-attractor wallpaper. Needs libgl-dev, libx11-dev, libxext-dev.
#   make install   -> ~/.local/bin/mathwall        (turn it on with: rice live on)
CFLAGS ?= -O2 -Wall -Wextra
mathwall: mathwall.c
	$(CC) $(CFLAGS) -o $@ $< -lGL -lX11 -lXext -lm
install: mathwall
	install -D -m755 mathwall $(HOME)/.local/bin/mathwall
clean:
	rm -f mathwall
.PHONY: install clean
