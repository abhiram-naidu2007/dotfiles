# evry: file index + search (Rust) and the rofi modes that use it (C).
#   make            build everything
#   make install    evry -> ~/.local/bin, files.so calc.so mouseup -> ~/.local/lib/rofi, act.sh -> ~/.local/lib/evry
# Needs: cargo, gcc, rofi-dev, libglib2.0-dev, libx11-dev
PREFIX ?= $(HOME)/.local
PLUGIN_FLAGS := -DEVRY_ACT_DEFAULT='"$(PREFIX)/lib/evry/act.sh"' -O2 -Wall -Wextra -fPIC -shared $(shell pkg-config --cflags rofi gio-2.0) $(shell pkg-config --libs gio-2.0)

all: target/release/evry rofi/files.so rofi/calc.so rofi/mouseup

target/release/evry: src/main.rs Cargo.toml
	cargo build --release

rofi/files.so: rofi/evry.c
	$(CC) $(PLUGIN_FLAGS) -o $@ $<

rofi/calc.so: rofi/evry.c
	$(CC) $(PLUGIN_FLAGS) -DEVRY_CALC -o $@ $<

# waits until no mouse button is held; ~/.local/bin/rofi runs it before every menu
rofi/mouseup: rofi/mouseup.c
	$(CC) -O2 -Wall -Wextra -o $@ $< -lX11

install: all
	install -D -m755 target/release/evry $(PREFIX)/bin/evry
	install -D -m644 rofi/files.so $(PREFIX)/lib/rofi/files.so
	install -D -m644 rofi/calc.so $(PREFIX)/lib/rofi/calc.so
	install -D -m755 rofi/mouseup $(PREFIX)/lib/rofi/mouseup
	install -D -m755 rofi/act.sh $(PREFIX)/lib/evry/act.sh

clean:
	cargo clean
	rm -f rofi/*.so rofi/mouseup

.PHONY: all install clean
