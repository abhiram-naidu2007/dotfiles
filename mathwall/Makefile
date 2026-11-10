# mathwall: live wallpapers.  rice-curtain: the dissolve between two looks of the desktop.
# Needs libgl-dev, libx11-dev, libxext-dev.
#   make install   -> ~/.local/bin/mathwall, ~/.local/bin/rice-curtain   (turn it on with: rice live on)
CFLAGS ?= -O2 -Wall -Wextra
all: mathwall rice-curtain
mathwall: mathwall.c
	$(CC) $(CFLAGS) -o $@ $< -lGL -lX11 -lXext -lm
rice-curtain: curtain.c
	$(CC) $(CFLAGS) -o $@ $< -lX11 -lXext
install: all
	install -D -m755 mathwall $(HOME)/.local/bin/mathwall
	install -D -m755 rice-curtain $(HOME)/.local/bin/rice-curtain
clean:
	rm -f mathwall rice-curtain
.PHONY: all install clean
