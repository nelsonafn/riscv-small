# Forwarding Makefile for Convenience
# Proxies root make commands directly into the generated build system

# The single default target 
all: check_build
	$(MAKE) -C build

# Force everything to proxy via a double-colon pattern matcher
# Phony declaration is purposely not used so it always triggers.
%:: check_build
	$(MAKE) -C build $@

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


