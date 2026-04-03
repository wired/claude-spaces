PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
DEV_BINDIR ?= $(HOME)/.local/bin

install:
	mkdir -p $(DESTDIR)$(BINDIR)
	install -m755 claude-spaces $(DESTDIR)$(BINDIR)/claude-spaces

dev:
	ln -sf $(CURDIR)/claude-spaces $(DEV_BINDIR)/claude-spaces

test:
	./run_tests

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/claude-spaces

# Release targets (Linux only — sed -i without suffix is GNU sed)
AUR_DIR ?= $(HOME)/devel/aur/claude-spaces
BREW_DIR ?= $(HOME)/devel/homebrew-tap

release:
	@test -n "$(V)" || { echo "Usage: make release V=x.y.z"; exit 1; }
	@grep -q "$(V)-dev" claude-spaces || { echo "ERROR: version $(V)-dev not found in claude-spaces"; exit 1; }
	@git diff --quiet && git diff --cached --quiet || { echo "ERROR: working tree not clean"; exit 1; }
	@if [ -n "$(DRY_RUN)" ]; then \
		echo "[dry-run] sed: $(V)-dev -> $(V) in claude-spaces README.md"; \
		echo "[dry-run] git commit v$(V)"; \
		echo "[dry-run] git tag v$(V)"; \
		echo "[dry-run] git push && git push origin v$(V)"; \
		NEXT=$$(echo "$(V)" | awk -F. '{print $$1"."$$2"."$$3+1}'); \
		echo "[dry-run] sed: $(V) -> $${NEXT}-dev in claude-spaces README.md"; \
		echo "[dry-run] git commit Bump version to $${NEXT}-dev"; \
		echo "[dry-run] git push"; \
	else \
		set -e; \
		sed -i 's/# Version $(V)-dev/# Version $(V)/' claude-spaces; \
		sed -i 's/VERSION="$(V)-dev"/VERSION="$(V)"/' claude-spaces; \
		sed -i 's/v$(V)-dev/v$(V)/' README.md; \
		git add claude-spaces README.md; \
		git commit -m "v$(V)"; \
		git tag "v$(V)"; \
		git push && git push origin "v$(V)"; \
		NEXT=$$(echo "$(V)" | awk -F. '{print $$1"."$$2"."$$3+1}'); \
		sed -i "s/# Version $(V)/# Version $${NEXT}-dev/" claude-spaces; \
		sed -i "s/VERSION=\"$(V)\"/VERSION=\"$${NEXT}-dev\"/" claude-spaces; \
		sed -i "s/v$(V)/v$${NEXT}-dev/" README.md; \
		git add claude-spaces README.md; \
		git commit -m "Bump version to $${NEXT}-dev"; \
		git push; \
	fi

update-packages:
	@test -n "$(V)" || { echo "Usage: make update-packages V=x.y.z"; exit 1; }
	@test -d "$(AUR_DIR)" || { echo "ERROR: AUR_DIR not found: $(AUR_DIR)"; exit 1; }
	@test -d "$(BREW_DIR)" || { echo "ERROR: BREW_DIR not found: $(BREW_DIR)"; exit 1; }
	@cd $(AUR_DIR) && git diff --quiet && git diff --cached --quiet || { echo "ERROR: $(AUR_DIR) has uncommitted changes"; exit 1; }
	@cd $(BREW_DIR) && git diff --quiet && git diff --cached --quiet || { echo "ERROR: $(BREW_DIR) has uncommitted changes"; exit 1; }
	@SHA=$$(curl -fsSL https://github.com/wired/claude-spaces/archive/refs/tags/v$(V).tar.gz 2>/dev/null | sha256sum | cut -d' ' -f1); \
	test -n "$${SHA}" && test "$${SHA}" != "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" || { echo "ERROR: failed to fetch tarball for v$(V)"; exit 1; }; \
	if [ -n "$(DRY_RUN)" ]; then \
		echo "[dry-run] SHA256: $${SHA}"; \
		echo "[dry-run] Update $(AUR_DIR)/PKGBUILD: pkgver=$(V), sha256=$${SHA}"; \
		echo "[dry-run] Update $(BREW_DIR)/Formula/claude-spaces.rb: v$(V), sha256=$${SHA}"; \
		echo "[dry-run] Commit both repos: claude-spaces v$(V)"; \
	else \
		set -e; \
		echo "SHA256: $${SHA}"; \
		sed -i 's/pkgver=.*/pkgver=$(V)/' $(AUR_DIR)/PKGBUILD; \
		sed -i "s/sha256sums=('.*')/sha256sums=('$${SHA}')/" $(AUR_DIR)/PKGBUILD; \
		sed -i 's|/tags/v.*\.tar\.gz|/tags/v$(V).tar.gz|' $(BREW_DIR)/Formula/claude-spaces.rb; \
		sed -i 's/sha256 ".*"/sha256 "'$${SHA}'"/' $(BREW_DIR)/Formula/claude-spaces.rb; \
		cd $(AUR_DIR) && git add PKGBUILD && git commit -m "claude-spaces v$(V)"; \
		cd $(BREW_DIR) && git add Formula/claude-spaces.rb && git commit -m "claude-spaces v$(V)"; \
		echo "Committed. Push when ready:"; \
		echo "  cd $(AUR_DIR) && git push"; \
		echo "  cd $(BREW_DIR) && git push"; \
	fi
