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
# They are mirrored in CMakeLists.txt section 11 for a configured build/; this
# copy is what makes `make docs-check` work without Vivado.
docs-figs:
	@./scripts/docs/figs.sh --all

docs-figs-check:
	@./scripts/docs/figs.sh --check

docs-check:
	@./scripts/docs/check_md.sh

# The signoff gate only reads documents and artefacts: it needs neither a
# configured build/ nor an EDA environment, so it bypasses the proxy exactly
# like the documentation targets do. Running it on a clean tree is a valid
# answer ("blocked: no regression"), not an error.
signoff-check:
	@cmake -P scripts/verify/signoff_check.cmake $(SIGNOFF_ARGS)

# Everything else is proxied into build/ by the pattern rule below, including
# the verification targets declared in CMakeLists.txt section 12:
#   make regress / sanity / coverage
#   make -C build <same target>
# Arguments travel as make variables, e.g.
#   make regress REGRESS_ARGS="--test T-01 --wave 0"
#
# A missing build/ bootstraps itself: the target then pulls its own chain
# (configure -> compile -> elaborate -> ctest / coverage / images). Only the EDA
# environment has to exist beforehand, because ./configure validates it.
check_build:
	@if [ ! -d "build" ] || [ ! -f "build/Makefile" ]; then \
		echo "build/ is not configured; bootstrapping with ./configure"; \
		./configure || exit 1; \
	fi


