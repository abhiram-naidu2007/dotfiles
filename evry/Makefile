# evry: file index + search (Rust) and the rofi modes that use it (C).
#   make            build everything
#   make install    evry -> ~/.local/bin, files.so calc.so -> ~/.local/lib/rofi
# Needs: cargo, gcc, rofi-dev, libglib2.0-dev
PREFIX ?= $(HOME)/.local
PLUGIN_FLAGS := -O2 -Wall -Wextra -fPIC -shared $(shell pkg-config --cflags rofi gio-2.0) $(shell pkg-config --libs gio-2.0)

all: target/release/evry rofi/files.so rofi/calc.so

target/release/evry: src/main.rs Cargo.toml
	cargo build --release

rofi/files.so: rofi/evry.c
	$(CC) $(PLUGIN_FLAGS) -o $@ $<

rofi/calc.so: rofi/evry.c
	$(CC) $(PLUGIN_FLAGS) -DEVRY_CALC -o $@ $<

install: all
	install -D -m755 target/release/evry $(PREFIX)/bin/evry
	install -D -m644 rofi/files.so $(PREFIX)/lib/rofi/files.so
	install -D -m644 rofi/calc.so $(PREFIX)/lib/rofi/calc.so

clean:
	cargo clean
	rm -f rofi/*.so

.PHONY: all install clean
