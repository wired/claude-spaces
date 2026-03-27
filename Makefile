PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
DEV_BINDIR ?= $(HOME)/.local/bin

install:
	install -Dm755 claude-spaces $(DESTDIR)$(BINDIR)/claude-spaces

dev:
	ln -sf $(CURDIR)/claude-spaces $(DEV_BINDIR)/claude-spaces

test:
	./run_tests

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/claude-spaces
