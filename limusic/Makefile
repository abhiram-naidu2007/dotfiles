# limusic in the rice: rice.so restyles it (theme/templates/limusic-css), the launcher entry gets its icon.
#   make -C ~/dotfiles/limusic install
PREFIX ?= $(HOME)/.local
APPIMAGE ?= $(PREFIX)/bin/limusic.AppImage

rice.so: rice.c
	$(CC) -O2 -Wall -Wextra -fPIC -shared -o $@ $< $(shell pkg-config --cflags --libs gio-2.0) -ldl

install: rice.so
	install -D -m644 rice.so $(PREFIX)/lib/limusic-rice/rice.so
	@if [ -x "$(APPIMAGE)" ]; then \
	  t=$$(mktemp -d) && cd $$t && "$(APPIMAGE)" --appimage-extract limusic.png >/dev/null && \
	  install -D -m644 squashfs-root/limusic.png $(PREFIX)/share/icons/hicolor/256x256/apps/limusic.png; rm -rf $$t; \
	fi

clean:
	rm -f rice.so
