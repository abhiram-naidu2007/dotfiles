# Builds the on-demand desktop cat. Run: make -C ~/dotfiles/mochi install
CFLAGS ?= -O2 -Wall -Wextra
mochi: mochi.c
	$(CC) $(CFLAGS) -o $@ $< -lX11 -lXext
install: mochi
	install -D -m755 mochi $(HOME)/.local/bin/mochi
