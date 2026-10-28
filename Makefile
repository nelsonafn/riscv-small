# Forwarding Makefile for Convenience
# Proxies root make commands directly into the generated build system

# The single default target 
all: check_build
	$(MAKE) -C build

# Do not let the match-anything rule try to remake this Makefile.
Makefile: ;

# Force everything to proxy via a double-colon pattern matcher
# Phony declaration is purposely not used so it always triggers.
%:: check_build
	$(MAKE) -C build $@

# Documentation targets do not require an EDA environment or a configured build/.
# They render figures from their sources and validate the documentation set.
docs-figs:
	@./scripts/docs/figs.sh --all

docs-figs-check:
	@./scripts/docs/figs.sh --check

docs-check:
	@./scripts/docs/check_md.sh

check_build:
	@if [ ! -d "build" ] || [ ! -f "build/Makefile" ]; then \
		echo "ERROR: Please run ./configure first."; \
		exit 1; \
	fi


