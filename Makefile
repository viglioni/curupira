EMACS = emacs
EMACS_FLAGS = -Q --batch

.PHONY: release-major release-minor release-patch help

release-major:
	$(EMACS) $(EMACS_FLAGS) \
		--load scripts/release.el \
		--eval "(release-version 'major)"

release-minor:
	$(EMACS) $(EMACS_FLAGS) \
		--directory $(EMACS_DIR) \
		--load scripts/release.el \
		--eval "(release-version 'minor)"

release-patch:
	$(EMACS) $(EMACS_FLAGS) \
		--directory $(EMACS_DIR) \
		--load scripts/release.el \
		--eval "(release-version 'patch)"

help:
	@echo "Available targets:"
	@echo "  release-major - Release a major version update"
	@echo "  release-minor - Release a minor version update"
	@echo "  release-patch - Release a patch version update"
	@echo "  help          - Show this help message"
