# -----------------------------------------------------------------------------
#
# (c) 2009 The University of Glasgow
#
# This file is part of the GHC build system.
#
# To understand how the build system works and how to modify it, see
#      http://hackage.haskell.org/trac/ghc/wiki/Building/Architecture
#      http://hackage.haskell.org/trac/ghc/wiki/Building/Modifying
#
# -----------------------------------------------------------------------------

# ToDo List.
#
# Before we can merge the new build system into HEAD:
#
#   * finish installation
#     * other documentation
#     * create doc index and contents
#     * Windows: should we have ghc-pkg-<version>?
#     * should we be stripping things?
#     * install libgmp.a, gmp.h
#   * finish binary distributions
#   * need to fix Cabal for new Windows layout, see
#     Distribution/Simple/GHC.configureToolchain.
#
# Once the new build system is in HEAD, and before 6.12:
#
#   * separate the logic of whether to do something from the test for
#     existence of the tool to do it. For example, rather than checking
#     if $DIR_DOCBOOK_XSL or $XSLTPROC is "", we should have a variable
#     for controlling the building of the docs.
#   * remove old Makefiles, add new stubs for building in subdirs
#     * utils/hsc2hs/Makefile
#     * utils/haddock/Makefile
#     * docs/Makefile
#     * docs/docbook-cheat-sheet/Makefile
#     * docs/ext-core/Makefile
#     * docs/man/Makefile
#     * docs/storage-mgmt/Makefile
#     * docs/vh/Makefile
#     * driver/Makefile
#     * rts/dotnet/Makefile
#     * utils/Makefile
#   * GhcProfiled
#   * optionally install stage3?
#   * shared libraries, way dyn
#   * get HC bootstrapping working
#   * add Makefiles for the rest of the utils/ programs that aren't built
#     by default (need to exclude them from 'make all' too)
#
# Tickets we can now close, or fix and close:
#
#   * 1693 make distclean
#   * 3173 make install with DESTDIR

# Possible cleanups:
#
#   * per-source-file dependencies instead of one .depend file?
#   * eliminate undefined variables, and use --warn-undefined-variables?
#   * perhaps we should make all the output dirs in the .depend rule, to
#     avoid all these mkdirhier calls?
#   * put outputs from different ways in different subdirs of distdir/build,
#     then we don't have to use -osuf/-hisuf.  We would have to install
#     them in different places too, so we'd need ghc-pkg support for packages
#     of different ways.
#   * make PACKAGES generated by configure or sh boot?
#   * we should use a directory of package.conf files rather than a single
#     file for the inplace package database, so that we can express
#     dependencies more accurately.  Otherwise it's possible to get into
#     a state where the package database is out of date, and the build
#     system doesn't know.

# Approximate build order.
#
# The actual build order is defined by dependencies, and the phase
# ordering used to ensure correct ordering of makefile-generation; see
#    http://hackage.haskell.org/trac/ghc/wiki/Building/Architecture/Idiom/PhaseOrdering
#
#     * With bootstrapping compiler:
#           o Build utils/ghc-cabal
#           o Build utils/ghc-pkg
#           o Build utils/hsc2hs
#     * For each package:
#	    o configure, generate package-data.mk and inplace-pkg-info
#           o register each package into inplace/lib/package.conf
#     * build libffi
#     * With bootstrapping compiler:
#	    o Build libraries/{filepath,hpc,extensible-exceptions,Cabal}
#           o Build compiler (stage 1)
#     * With stage 1:
#           o Build libraries/*
#	    o Build rts
#           o Build utils/* (except haddock)
#           o Build compiler (stage 2)
#     * With stage 2:
#           o Build utils/haddock
#           o Build compiler (stage 3) (optional)
#     * With haddock:
#           o libraries/*
#           o compiler

.PHONY: default all haddock

default : all

# Just bring makefiles up to date:
.PHONY: just-makefiles
just-makefiles:
	@:

# -----------------------------------------------------------------------------
# Misc GNU make utils

nothing=
space=$(nothing) $(nothing)
comma=,

# Cancel all suffix rules.  Ideally we'd like to have 'make -r' turned on
# by default, because that disables all the implicit rules, but there doesn't
# seem to be a good way to do that.  This turns off all the old-style suffix
# rules, which does half the job and speeds up make quite a bit:
.SUFFIXES:

# -----------------------------------------------------------------------------
# 			Makefile debugging
# to see the effective value used for a Makefile variable, do
#  make show VALUE=MY_VALUE
#

show:
	@echo '$(VALUE)="$($(VALUE))"'

# -----------------------------------------------------------------------------
# Include subsidiary build-system bits

include mk/tree.mk

ifeq "$(findstring clean,$(MAKECMDGOALS))" ""
include mk/config.mk
ifeq "$(ProjectVersion)" ""
$(error Please run ./configure first)
endif
endif

# (Optional) build-specific configuration
include mk/custom-settings.mk

ifeq "$(findstring clean,$(MAKECMDGOALS))" ""
ifeq "$(GhcLibWays)" ""
$(error $$(GhcLibWays) is empty, it must contain at least one way)
endif
endif

# -----------------------------------------------------------------------------
# Macros for standard targets

include rules/all-target.mk
include rules/clean-target.mk

# -----------------------------------------------------------------------------
# The inplace tree

$(eval $(call clean-target,inplace,,inplace))

# -----------------------------------------------------------------------------
# Whether to build dependencies or not

# When we're just doing 'make clean' or 'make show', then we don't need
# to build dependencies.

ifneq "$(findstring clean,$(MAKECMDGOALS))" ""
NO_INCLUDE_DEPS = YES
NO_INCLUDE_PKGDATA = YES
endif
ifneq "$(findstring bootstrapping-files,$(MAKECMDGOALS))" ""
NO_INCLUDE_DEPS = YES
NO_INCLUDE_PKGDATA = YES
endif
ifeq "$(findstring show,$(MAKECMDGOALS))" "show"
NO_INCLUDE_DEPS = YES
# We want package-data.mk for show
endif

# We don't haddock base3-compat, as it has the same package name as base
libraries/base3-compat_dist-install_DO_HADDOCK = NO

# We don't haddock the bootstrapping libraries
libraries/hpc_dist-boot_DO_HADDOCK = NO
libraries/Cabal_dist-boot_DO_HADDOCK = NO
libraries/extensible-exceptions_dist-boot_DO_HADDOCK = NO
libraries/filepath_dist-boot_DO_HADDOCK = NO

# -----------------------------------------------------------------------------
# Ways

include rules/way-prelims.mk

$(foreach way,$(ALL_WAYS),\
  $(eval $(call way-prelims,$(way))))

# -----------------------------------------------------------------------------
# Compilation Flags

include rules/distdir-opts.mk
include rules/distdir-way-opts.mk

# -----------------------------------------------------------------------------
# Finding source files and object files

include rules/hs-sources.mk
include rules/c-sources.mk
include rules/includes-sources.mk
include rules/hs-objs.mk
include rules/c-objs.mk

# -----------------------------------------------------------------------------
# Suffix rules

# Suffix rules cause "make clean" to fail on Windows (trac #3233)
# so we don't make any when cleaning.
ifneq "$(CLEANING)" "YES"

include rules/hs-suffix-rules-srcdir.mk
include rules/hs-suffix-rules.mk

# -----------------------------------------------------------------------------
# Suffix rules for .hi files

include rules/hi-rule.mk

$(foreach way,$(ALL_WAYS),\
  $(eval $(call hi-rule,$(way))))

#-----------------------------------------------------------------------------
# C-related suffix rules

include rules/c-suffix-rules.mk

endif

# -----------------------------------------------------------------------------
# Building package-data.mk files from .cabal files

include rules/package-config.mk

# -----------------------------------------------------------------------------
# Building dependencies

include rules/build-dependencies.mk

# -----------------------------------------------------------------------------
# Build package-data.mk files

include rules/build-package-data.mk

# -----------------------------------------------------------------------------
# Build and install a program

include rules/build-prog.mk
include rules/shell-wrapper.mk

# -----------------------------------------------------------------------------
# Build a perl script

include rules/build-perl.mk

# -----------------------------------------------------------------------------
# Build a package

include rules/build-package.mk
include rules/build-package-way.mk
include rules/haddock.mk

# -----------------------------------------------------------------------------
# Registering hand-written package descriptions (used in libffi and rts)

include rules/manual-package-config.mk

# -----------------------------------------------------------------------------
# Docs

include rules/docbook.mk

# -----------------------------------------------------------------------------
# Making bindists

include rules/bindist.mk

# -----------------------------------------------------------------------------
# Building libraries

# XXX generate from $(TOP)/packages
PACKAGES = \
	ghc-prim \
	integer-gmp \
	base \
	filepath \
	array \
	bytestring \
	containers

ifeq "$(Windows)" "YES"
PACKAGES += Win32
else
PACKAGES += unix
endif

PACKAGES += \
	old-locale \
	old-time \
	directory \
	process \
	random \
	extensible-exceptions \
	haskell98 \
	hpc \
	packedstring \
	pretty \
	syb \
	template-haskell \
	base3-compat \
	Cabal \
	mtl \
	utf8-string

ifneq "$(Windows)" "YES"
PACKAGES += terminfo
endif

PACKAGES += haskeline

ifneq "$(BootingFromHc)" "YES"
PACKAGES_STAGE2 += \
	dph/dph-base \
	dph/dph-prim-interface \
	dph/dph-prim-seq \
	dph/dph-prim-par \
	dph/dph-seq \
	dph/dph-par
endif

BOOT_PKGS = Cabal hpc extensible-exceptions

# The actual .a and .so/.dll files: needed for dependencies.
ALL_STAGE1_LIBS  = $(foreach lib,$(PACKAGES),$(libraries/$(lib)_dist-install_v_LIB))
ifeq "$(BuildSharedLibs)" "YES"
ALL_STAGE1_LIBS += $(foreach lib,$(PACKAGES),$(libraries/$(lib)_dist-install_dyn_LIB))
endif
BOOT_LIBS = $(foreach lib,$(BOOT_PKGS),$(libraries/$(lib)_dist-boot_v_LIB))

OTHER_LIBS = libffi/libHSffi$(v_libsuf) libffi/HSffi.o
ifeq "$(BuildSharedLibs)" "YES"
OTHER_LIBS  += libffi/libHSffi$(dyn_libsuf)
endif
ifeq "$(HaveLibGmp)" "NO"
GMP_LIB = gmp/libgmp.a
OTHER_LIBS += $(GMP_LIB)
endif

# We cannot run ghc-cabal to configure a package until we have
# configured and registered all of its dependencies.  So the following
# hack forces all the configure steps to happen in exactly the order
# given in the PACKAGES variable above.  Ideally we should use the
# correct dependencies here to allow more parallelism, but we don't
# know the dependencies until we've generated the pacakge-data.mk
# files.
define fixed_pkg_dep
libraries/$1/$2/package-data.mk : $$(GHC_PKG_INPLACE) $$(if $$(fixed_pkg_prev),libraries/$$(fixed_pkg_prev)/$2/package-data.mk)
fixed_pkg_prev:=$1
endef

ifneq "$(BINDIST)" "YES"
fixed_pkg_prev=
$(foreach pkg,$(PACKAGES) $(PACKAGES_STAGE2),$(eval $(call fixed_pkg_dep,$(pkg),dist-install)))

# We assume that the stage2 compiler depends on all the libraries, so
# they all get added to the package database before we try to configure
# it
compiler/stage2/package-data.mk: $(foreach pkg,$(PACKAGES) $(PACKAGES_STAGE2),libraries/$(pkg)/dist-install/package-data.mk)
ghc/stage1/package-data.mk: compiler/stage1/package-data.mk
ghc/stage2/package-data.mk: compiler/stage2/package-data.mk
# haddock depends on ghc and some libraries, but depending on GHC's
# package-data.mk is sufficient, as that in turn depends on all the
# libraries
utils/haddock/dist/package-data.mk: compiler/stage2/package-data.mk

utils/hsc2hs/dist-install/package-data.mk: compiler/stage2/package-data.mk

# add the final two package.conf dependencies: ghc-prim depends on RTS,
# and RTS depends on libffi.
libraries/ghc-prim/dist-install/package-data.mk : rts/package.conf.inplace
rts/package.conf.inplace : libffi/package.conf.inplace
endif

# -----------------------------------------------------------------------------
# Special magic for the ghc-prim package

# We want the ghc-prim package to include the GHC.Prim module when it
# is registered, but not when it is built, because GHC.Prim is not a
# real source module, it is built-in to GHC.  The old build system did
# this using Setup.hs, but we can't do that here, so we have a flag to
# enable GHC.Prim in the .cabal file (so that the ghc-prim package
# remains compatible with the old build system for the time being).
# GHC.Prim module in the ghc-prim package with a flag:
#
libraries/ghc-prim_CONFIGURE_OPTS += --flag=include-ghc-prim

# And then we strip it out again before building the package:
define libraries/ghc-prim_PACKAGE_MAGIC
libraries/ghc-prim_dist-install_MODULES := $$(filter-out GHC.Prim,$$(libraries/ghc-prim_dist-install_MODULES))
endef

PRIMOPS_TXT = $(GHC_COMPILER_DIR)/prelude/primops.txt

libraries/ghc-prim/dist-install/build/GHC/PrimopWrappers.hs : $(GENPRIMOP_INPLACE) $(PRIMOPS_TXT)
	"$(MKDIRHIER)" $(dir $@)
	"$(GENPRIMOP_INPLACE)" --make-haskell-wrappers <$(PRIMOPS_TXT) >$@

libraries/ghc-prim/GHC/Prim.hs : $(GENPRIMOP_INPLACE) $(PRIMOPS_TXT)
	"$(GENPRIMOP_INPLACE)" --make-haskell-source <$(PRIMOPS_TXT) >$@


# -----------------------------------------------------------------------------
# Include build instructions from all subdirs

# For the rationale behind the build phases, see
#   http://hackage.haskell.org/trac/ghc/wiki/Building/Architecture/Idiom/PhaseOrdering

# Setting foo_dist_DISABLE=YES means "in directory foo, for build
# "dist", just read the package-data.mk file, do not build anything".

# We carefully engineer things so that we can build the
# package-data.mk files early on: they depend only on a few tools also
# built early.  Having got the package-data.mk files built, we can
# restart make with up-to-date information about all the packages
# (this is phase 0).  The remaining problem is the .depend files:
#
#   - .depend files in libraries need the stage 1 compiler to build
#   - ghc/stage1/.depend needs compiler/stage1 built
#   - compiler/stage1/.depend needs the bootstrap libs built
#
# GHC 6.11+ can build a .depend file without having built the
# dependencies of the package, but we can't rely on the bootstrapping
# compiler being able to do this, which is why we have to separate the
# three phases above.

# So this is the final ordering:

# Phase 0 : all package-data.mk files
#           (requires ghc-cabal, ghc-pkg, mkdirhier, dummy-ghc etc.)
# Phase 1 : .depend files for bootstrap libs
#           (requires hsc2hs)
# Phase 2 : compiler/stage1/.depend
#           (requires bootstrap libs and genprimopcode)
# Phase 3 : ghc/stage1/.depend
#           (requires compiler/stage1)
#
# The rest : libraries/*/dist-install, compiler/stage2, ghc/stage2

BUILD_DIRS =

ifneq "$(BINDIST)" "YES"
BUILD_DIRS += \
   $(GHC_MKDEPENDC_DIR) \
   $(GHC_MKDIRHIER_DIR)
endif

BUILD_DIRS += \
   gmp \
   docs/users_guide \
   libraries/Cabal/doc \
   $(GHC_UNLIT_DIR) \
   $(GHC_HP2PS_DIR)

ifneq "$(GhcUnregisterised)" "YES"
BUILD_DIRS += \
   $(GHC_MANGLER_DIR) \
   $(GHC_SPLIT_DIR)
endif

ifneq "$(BINDIST)" "YES"
BUILD_DIRS += \
   $(GHC_GENPRIMOP_DIR)
endif

BUILD_DIRS += \
   driver \
   driver/ghci \
   driver/ghc \
   libffi \
   includes \
   rts

ifneq "$(BINDIST)" "YES"
BUILD_DIRS += \
   $(GHC_CABAL_DIR) \
   $(GHC_GENAPPLY_DIR)
endif

BUILD_DIRS += \
   utils/haddock \
   utils/haddock/doc

ifneq "$(CLEANING)" "YES"
BUILD_DIRS += \
   $(patsubst %, libraries/%, $(PACKAGES) $(PACKAGES_STAGE2))
ifneq "$(BootingFromHc)" "YES"
BUILD_DIRS += \
   libraries/dph
endif
endif

BUILD_DIRS += \
   compiler \
   $(GHC_HSC2HS_DIR) \
   $(GHC_PKG_DIR) \
   utils/hpc \
   utils/runghc \
   ghc
ifeq "$(Windows)" "YES"
BUILD_DIRS += \
   $(GHC_TOUCHY_DIR)
endif

# XXX libraries/% must come before any programs built with stage1, see
# Note [lib-depends].

ifeq "$(phase)" "0"
$(foreach lib,$(BOOT_PKGS),$(eval \
  libraries/$(lib)_dist-boot_DISABLE = YES))
endif

ifneq "$(findstring $(phase),0 1)" ""
# We can build deps for compiler/stage1 in phase 2
compiler_stage1_DISABLE = YES
endif

ifneq "$(findstring $(phase),0 1 2)" ""
ghc_stage1_DISABLE = YES
endif

ifneq "$(findstring $(phase),0 1 2 3)" ""
# In phases 0-3, we disable stage2-3, the full libraries and haddock
utils/haddock_dist_DISABLE = YES
utils/runghc_dist_DISABLE = YES
utils/hpc_dist_DISABLE = YES
utils/hsc2hs_dist-install_DISABLE = YES
utils/ghc-pkg_dist-install_DISABLE = YES
compiler_stage2_DISABLE = YES
compiler_stage3_DISABLE = YES
ghc_stage2_DISABLE = YES
ghc_stage3_DISABLE = YES
$(foreach lib,$(PACKAGES) $(PACKAGES_STAGE2),$(eval \
  libraries/$(lib)_dist-install_DISABLE = YES))
endif

include $(patsubst %, %/ghc.mk, $(BUILD_DIRS))

# We need -fno-warn-deprecated-flags to avoid failure with -Werror
GhcLibHcOpts += -fno-warn-deprecated-flags
ifeq "$(ghc_ge_609)" "YES"
GhcBootLibHcOpts += -fno-warn-deprecated-flags
endif

# Add $(GhcLibHcOpts) to all library builds
$(foreach pkg,$(PACKAGES) $(PACKAGES_STAGE2),$(eval libraries/$(pkg)_dist-install_HC_OPTS += $$(GhcLibHcOpts)))

# XXX Hack; remove this
$(foreach pkg,$(PACKAGES_STAGE2),$(eval libraries/$(pkg)_dist-install_HC_OPTS += -Wwarn))

# XXX we configure packages with the bootstrapping compiler (for
# dependency reasons, see the phase ordering), which doesn't
# necessarily support all the extensions we need, and Cabal filters
# out the ones it thinks aren't supported.
libraries/base3-compat_dist-install_HC_OPTS += -XPackageImports

# -----------------------------------------------------------------------------
# Bootstrapping libraries

# We need to build a few libraries with the installed GHC, since GHC itself
# and some of the tools depend on them:

ifneq "$(BINDIST)" "YES"

ifneq "$(BOOTSTRAPPING_CONF)" ""
ifeq "$(wildcard $(BOOTSTRAPPING_CONF))" ""
$(shell echo "[]" >$(BOOTSTRAPPING_CONF))
endif
endif

$(eval $(call clean-target,$(BOOTSTRAPPING_CONF),,$(BOOTSTRAPPING_CONF)))

# These three libraries do not depend on each other, so we can build
# them straight off:

$(eval $(call build-package,libraries/hpc,dist-boot,0))
$(eval $(call build-package,libraries/extensible-exceptions,dist-boot,0))
$(eval $(call build-package,libraries/Cabal,dist-boot,0))

# register the boot packages in strict sequence, because running
# multiple ghc-pkgs in parallel doesn't work (registrations may get
# lost).
fixed_pkg_prev=
$(foreach pkg,$(BOOT_PKGS),$(eval $(call fixed_pkg_dep,$(pkg),dist-boot)))

compiler/stage1/package-data.mk : \
    libraries/Cabal/dist-boot/package-data.mk \
    libraries/hpc/dist-boot/package-data.mk \
    libraries/extensible-exceptions/dist-boot/package-data.mk

# These are necessary because the bootstrapping compiler may not know
# about cross-package dependencies:
$(compiler_stage1_depfile) : $(BOOT_LIBS)
$(ghc_stage1_depfile) : $(compiler_stage1_v_LIB)

$(foreach pkg,$(BOOT_PKGS),$(eval libraries/$(pkg)_dist-boot_HC_OPTS += $$(GhcBootLibHcOpts)))

endif

# -----------------------------------------------------------------------------
# Creating a local mingw copy on Windows

ifeq "$(Windows)" "YES"

# directories don't work well as dependencies, hence a stamp file
$(INPLACE)/stamp-mingw : $(MKDIRHIER)
	$(MKDIRHIER) $(INPLACE_MINGW)/bin
	GCC=`type -p $(WhatGccIsCalled)`; \
	GccDir=`dirname $$GCC`; \
	"$(CP)" -p $$GccDir/{gcc.exe,ar.exe,as.exe,dlltool.exe,dllwrap.exe,windres.exe} $(INPLACE_MINGW)/bin; \
	"$(CP)" -Rp $$GccDir/../include $(INPLACE_MINGW); \
	"$(CP)" -Rp $$GccDir/../lib     $(INPLACE_MINGW); \
	"$(CP)" -Rp $$GccDir/../libexec $(INPLACE_MINGW); \
	"$(CP)" -Rp $$GccDir/../mingw32 $(INPLACE_MINGW)
	touch $(INPLACE)/stamp-mingw

install : install_mingw
.PHONY: install_mingw
install_mingw : $(INPLACE_MINGW)
	"$(CP)" -Rp $(INPLACE_MINGW) $(prefix)

$(INPLACE_LIB)/perl.exe $(INPLACE_LIB)/perl56.dll :
	"$(CP)" $(GhcDir)../{perl.exe,perl56.dll} $(INPLACE_LIB)

endif # Windows

libraries/ghc-prim/dist-install/doc/html/ghc-prim/ghc-prim.haddock: \
    libraries/ghc-prim/dist-install/build/autogen/GHC/Prim.hs \
    libraries/ghc-prim/dist-install/build/autogen/GHC/PrimopWrappers.hs

libraries/ghc-prim/dist-install/build/autogen/GHC/Prim.hs: \
                            $(PRIMOPS_TXT) $(GENPRIMOP_INPLACE) $(MKDIRHIER)
	"$(MKDIRHIER)" $(dir $@)
	"$(GENPRIMOP_INPLACE)" --make-haskell-source < $< > $@

libraries/ghc-prim/dist-install/build/autogen/GHC/PrimopWrappers.hs: \
                            $(PRIMOPS_TXT) $(GENPRIMOP_INPLACE) $(MKDIRHIER)
	"$(MKDIRHIER)" $(dir $@)
	"$(GENPRIMOP_INPLACE)" --make-haskell-wrappers < $< > $@

# -----------------------------------------------------------------------------
# Installation

install: install_packages install_libs install_libexecs install_headers \
	 install_libexec_scripts install_bins

install_bins: $(INSTALL_BINS)
	$(INSTALL_DIR) $(DESTDIR)$(bindir)
	for i in $(INSTALL_BINS); do \
		$(INSTALL_PROGRAM) $(INSTALL_BIN_OPTS) $$i $(DESTDIR)$(bindir) ;  \
                if test "$(darwin_TARGET_OS)" = "1"; then \
                   sh mk/fix_install_names.sh $(libdir) $(DESTDIR)$(bindir)/$$i ; \
                fi ; \
	done

install_libs: $(INSTALL_LIBS)
	$(INSTALL_DIR) $(DESTDIR)$(libdir)
	for i in $(INSTALL_LIBS); do \
		case $$i in \
		  *.a) \
		    $(INSTALL_DATA) $(INSTALL_OPTS) $$i $(DESTDIR)$(libdir); \
		    $(RANLIB) $(DESTDIR)$(libdir)/`basename $$i` ;; \
		  *.dll) \
		    $(INSTALL_DATA) -s $(INSTALL_OPTS) $$i $(DESTDIR)$(libdir) ;; \
		  *.so) \
		    $(INSTALL_SHLIB) $(INSTALL_OPTS) $$i $(DESTDIR)$(libdir) ;; \
		  *.dylib) \
		    $(INSTALL_SHLIB) $(INSTALL_OPTS) $$i $(DESTDIR)$(libdir); \
		    install_name_tool -id $(DESTDIR)$(libdir)/`basename $$i` $(DESTDIR)$(libdir)/`basename $$i` ;; \
		  *) \
		    $(INSTALL_DATA) $(INSTALL_OPTS) $$i $(DESTDIR)$(libdir); \
		esac; \
	done

install_libexec_scripts: $(INSTALL_LIBEXEC_SCRIPTS)
	"$(MKDIRHIER)" $(DESTDIR)$(libexecdir)
	for i in $(INSTALL_LIBEXEC_SCRIPTS); do \
		$(INSTALL_SCRIPT) $(INSTALL_OPTS) $$i $(DESTDIR)$(libexecdir); \
	done

install_libexecs:  $(INSTALL_LIBEXECS)
	"$(MKDIRHIER)" $(DESTDIR)$(libexecdir)
	for i in $(INSTALL_LIBEXECS); do \
		$(INSTALL_PROGRAM) $(INSTALL_BIN_OPTS) $$i $(DESTDIR)$(libexecdir); \
	done

install_headers: $(INSTALL_HEADERS)
	$(INSTALL_DIR) $(DESTDIR)$(headerdir)
	for i in $(INSTALL_HEADERS); do \
		$(INSTALL_HEADER) $(INSTALL_OPTS) $$i $(DESTDIR)$(headerdir); \
	done

INSTALLED_PACKAGE_CONF=$(DESTDIR)$(libdir)/package.conf

# Install packages in the right order, so that ghc-pkg doesn't complain.
# Also, install ghc-pkg first.
ifeq "$(Windows)" "NO"
INSTALLED_GHC_PKG_REAL=$(DESTDIR)$(libexecdir)/ghc-pkg
else
INSTALLED_GHC_PKG_REAL=$(DESTDIR)$(bindir)/ghc-pkg.exe
endif

install_packages: install_libexecs
install_packages: libffi/package.conf.install rts/package.conf.install
	"$(MKDIRHIER)" $(DESTDIR)$(libdir)
	echo "[]" > $(INSTALLED_PACKAGE_CONF)
	"$(INSTALLED_GHC_PKG_REAL)" --force --global-conf $(INSTALLED_PACKAGE_CONF) update libffi/package.conf.install
	"$(INSTALLED_GHC_PKG_REAL)" --force --global-conf $(INSTALLED_PACKAGE_CONF) update rts/package.conf.install
	$(foreach p, $(PACKAGES) $(PACKAGES_STAGE2),\
	    "$(GHC_CABAL_INPLACE)" install \
		 $(INSTALLED_GHC_PKG_REAL) \
		 $(INSTALLED_PACKAGE_CONF) \
		 libraries/$p dist-install \
		 '$(DESTDIR)' '$(prefix)' '$(libdir)' '$(docdir)/libraries' &&) true
	"$(GHC_CABAL_INPLACE)" install \
	 	 $(INSTALLED_GHC_PKG_REAL) \
		 $(INSTALLED_PACKAGE_CONF) \
		 compiler stage2 \
		 '$(DESTDIR)' '$(prefix)' '$(libdir)' '$(docdir)/libraries'

# -----------------------------------------------------------------------------
# Binary distributions

$(eval $(call bindist,.,\
    LICENSE \
    configure config.sub config.guess install-sh \
    extra-gcc-opts.in \
    Makefile \
    mk/config.mk.in \
    $(INPLACE_BIN)/mkdirhier \
    $(INPLACE_BIN)/ghc-cabal \
    utils/ghc-pwd/ghc-pwd \
	$(BINDIST_WRAPPERS) \
	$(BINDIST_LIBS) \
	$(BINDIST_HI) \
	$(BINDIST_EXTRAS) \
    $(INSTALL_HEADERS) \
    $(INSTALL_LIBEXECS) \
    $(INSTALL_LIBEXEC_SCRIPTS) \
    $(INSTALL_BINS) \
    $(filter-out extra-gcc-opts,$(INSTALL_LIBS)) \
    $(filter-out %/project.mk,$(filter-out mk/config.mk,$(MAKEFILE_LIST))) \
	mk/fix_install_names.sh \
	mk/project.mk \
	libraries/dph/LICENSE \
 ))
# mk/project.mk gets an absolute path, so we manually include it in
# the bindist with a relative path

binary-dist:
	"$(RM)" $(RM_OPTS) -r $(BIN_DIST_NAME)
	mkdir $(BIN_DIST_NAME)
	set -e; for i in LICENSE compiler ghc rts libraries utils gmp docs libffi includes driver mk rules Makefile aclocal.m4 config.sub config.guess install-sh extra-gcc-opts.in ghc.mk inplace; do ln -s ../$$i $(BIN_DIST_NAME)/; done
	ln -s ../distrib/configure-bin.ac $(BIN_DIST_NAME)/configure.ac
	cd $(BIN_DIST_NAME) && autoreconf
	"$(RM)" $(RM_OPTS) $(BIN_DIST_TAR)
# h means "follow symlinks", e.g. if aclocal.m4 is a symlink to a source
# tree then we want to include the real file, not a symlink to it
	"$(TAR)" hcf - -T $(BIN_DIST_LIST) | bzip2 -c >$(BIN_DIST_TAR_BZ2)

nTimes = set -e; for i in `seq 1 $(1)`; do echo Try "$$i: $(2)"; if $(2); then break; fi; done

.PHONY: publish-binary-dist
publish-binary-dist:
	$(call nTimes,10,$(PublishCp) $(BIN_DIST_TAR_BZ2) $(PublishLocation)/dist)

# -----------------------------------------------------------------------------
# Source distributions

# Do it like this:
#
#	$ make
#	$ make sdist
#

# A source dist is built from a complete build tree, because we
# require some extra files not contained in a darcs checkout: the
# output from Happy and Alex, for example.
#
# The steps performed by 'make dist' are as follows:
#   - create a complete link-tree of the current build tree in /tmp
#   - run 'make distclean' on that tree
#   - remove a bunch of other files that we know shouldn't be in the dist
#   - tar up first the extralibs package, then the main source package

#
# Directory in which we're going to build the src dist
#
SRC_DIST_NAME=ghc-$(ProjectVersion)
SRC_DIST_DIR=$(shell pwd)/$(SRC_DIST_NAME)

#
# Files to include in source distributions
#
SRC_DIST_DIRS = mk rules docs distrib bindisttest gmp libffi includes utils docs rts compiler ghc driver libraries
SRC_DIST_FILES += \
	configure.ac config.guess config.sub configure \
	aclocal.m4 README ANNOUNCE HACKING LICENSE Makefile install-sh \
	ghc.spec.in ghc.spec extra-gcc-opts.in VERSION boot ghc.mk

SRC_DIST_TARBALL = ghc-$(ProjectVersion)-src.tar.bz2

VERSION :
	echo $(ProjectVersion) >VERSION

sdist : VERSION

# Use:
#     $(call sdist_file,compiler,stage2,cmm,CmmLex,x)
# to copy the generated file that replaces compiler/cmm/CmmLex.x, where
# "stage2" is the dist dir.
sdist_file = \
  if test -f $(TOP)/$1/$2/build/$4.hs; then \
    "$(CP)" $(TOP)/$1/$2/build/$4.hs $1/$3/ ; \
    mv $1/$3/$4.$5 $1/$3/$4.$5.source ;\
  else \
    echo "does not exist: $1/$2//build/$4.hs"; \
    exit 1; \
  fi

.PHONY: sdist-prep
sdist-prep :
	"$(RM)" $(RM_OPTS) -r $(SRC_DIST_DIR)
	"$(RM)" $(SRC_DIST_NAME).tar.gz
	mkdir $(SRC_DIST_DIR)
	( cd $(SRC_DIST_DIR) \
	  && for i in $(SRC_DIST_DIRS); do mkdir $$i; (cd $$i && lndir $(TOP)/$$i ); done \
	  && for i in $(SRC_DIST_FILES); do $(LN_S) $(TOP)/$$i .; done \
	  && $(MAKE) distclean \
	  && if test -f $(TOP)/libraries/haskell-src/dist/build/Language/Haskell/Parser.hs; then "$(CP)" $(TOP)/libraries/haskell-src/dist/build/Language/Haskell/Parser.hs libraries/haskell-src/Language/Haskell/ ; mv libraries/haskell-src/Language/Haskell/Parser.ly libraries/haskell-src/Language/Haskell/Parser.ly.source ; fi \
	  && $(call sdist_file,compiler,stage2,cmm,CmmLex,x) \
	  && $(call sdist_file,compiler,stage2,cmm,CmmParse,y) \
	  && $(call sdist_file,compiler,stage2,main,ParsePkgConf,y) \
	  && $(call sdist_file,compiler,stage2,parser,HaddockLex,x) \
	  && $(call sdist_file,compiler,stage2,parser,HaddockParse,y) \
	  && $(call sdist_file,compiler,stage2,parser,Lexer,x) \
	  && $(call sdist_file,compiler,stage2,parser,Parser,y.pp) \
	  && $(call sdist_file,compiler,stage2,parser,ParserCore,y) \
	  && $(call sdist_file,utils/hpc,dist,,HpcParser,y) \
	  && $(call sdist_file,utils/genprimopcode,dist,,Lexer,x) \
	  && $(call sdist_file,utils/genprimopcode,dist,,Parser,y) \
	  && "$(RM)" $(RM_OPTS) -r compiler/stage[123] mk/build.mk \
	  && "$(FIND)" $(SRC_DIST_DIRS) \( -name _darcs -o -name SRC -o -name "autom4te*" -o -name "*~" -o -name ".cvsignore" -o -name "\#*" -o -name ".\#*" -o -name "log" -o -name "*-SAVE" -o -name "*.orig" -o -name "*.rej" -o -name "*-darcs-backup*" \) -print | xargs "$(RM)" $(RM_OPTS) -r \
	)

.PHONY: sdist
sdist : sdist-prep
	"$(TAR)" chf - $(SRC_DIST_NAME) 2>$src_log | bzip2 >$(TOP)/$(SRC_DIST_TARBALL)

sdist-manifest : $(SRC_DIST_TARBALL)
	tar tjf $(SRC_DIST_TARBALL) | sed "s|^ghc-$(ProjectVersion)/||" | sort >sdist-manifest

# Upload the distribution(s)
# Retrying is to work around buggy firewalls that corrupt large file transfers
# over SSH.
ifneq "$(PublishLocation)" ""
publish-sdist :
	$(call nTimes,10,$(PublishCp) $(SRC_DIST_TARBALL) $(PublishLocation)/dist)
endif

ifeq "$(GhcUnregisterised)" "YES"
SRC_CC_OPTS += -DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=$(ProjectVersionInt)
endif

# -----------------------------------------------------------------------------
# Cleaning

.PHONY: clean

CLEAN_FILES += utils/ghc-pwd/ghc-pwd
CLEAN_FILES += utils/ghc-pwd/ghc-pwd.exe
CLEAN_FILES += utils/ghc-pwd/ghc-pwd.hi
CLEAN_FILES += utils/ghc-pwd/ghc-pwd.o
CLEAN_FILES += libraries/bootstrapping.conf

clean : clean_files clean_libraries

.PHONY: clean_files
clean_files :
	"$(RM)" $(RM_OPTS) $(CLEAN_FILES)

.PHONY: clean_libraries
clean_libraries:
	"$(RM)" $(RM_OPTS) -r $(patsubst %, libraries/%/dist, $(PACKAGES) $(PACKAGES_STAGE2))
	"$(RM)" $(RM_OPTS) -r $(patsubst %, libraries/%/dist-install, $(PACKAGES) $(PACKAGES_STAGE2))
	"$(RM)" $(RM_OPTS) -r $(patsubst %, libraries/%/dist-boot, $(PACKAGES) $(PACKAGES_STAGE2))

distclean : clean
	"$(RM)" $(RM_OPTS) config.cache config.status config.log mk/config.h mk/stamp-h
	"$(RM)" $(RM_OPTS) mk/config.mk mk/are-validating.mk mk/project.mk
	"$(RM)" $(RM_OPTS) extra-gcc-opts docs/users_guide/ug-book.xml
	"$(RM)" $(RM_OPTS) compiler/ghc.cabal ghc/ghc-bin.cabal
	"$(RM)" $(RM_OPTS) libraries/base/include/HsBaseConfig.h
	"$(RM)" $(RM_OPTS) libraries/directory/include/HsDirectoryConfig.h
	"$(RM)" $(RM_OPTS) libraries/process/include/HsProcessConfig.h
	"$(RM)" $(RM_OPTS) libraries/unix/include/HsUnixConfig.h
	"$(RM)" $(RM_OPTS) libraries/old-time/include/HsTimeConfig.h
	"$(RM)" $(RM_OPTS) $(patsubst %, libraries/%/config.log, $(PACKAGES) $(PACKAGES_STAGE2))
	"$(RM)" $(RM_OPTS) $(patsubst %, libraries/%/config.status, $(PACKAGES) $(PACKAGES_STAGE2))
	"$(RM)" $(RM_OPTS) $(patsubst %, libraries/%/include/Hs*Config.h, $(PACKAGES) $(PACKAGES_STAGE2))
	"$(RM)" $(RM_OPTS) -r $(patsubst %, libraries/%/autom4te.cache, $(PACKAGES) $(PACKAGES_STAGE2))

maintainer-clean : distclean
	"$(RM)" $(RM_OPTS) configure mk/config.h.in
	"$(RM)" $(RM_OPTS) -r autom4te.cache libraries/*/autom4te.cache
	"$(RM)" $(RM_OPTS) ghc.spec
	"$(RM)" $(RM_OPTS) $(patsubst %, libraries/%/GNUmakefile, \
	        $(PACKAGES) $(PACKAGES_STAGE2))
	"$(RM)" $(RM_OPTS) $(patsubst %, libraries/%/ghc.mk, $(PACKAGES) $(PACKAGES_STAGE2))
	"$(RM)" $(RM_OPTS) $(patsubst %, libraries/%/configure, \
	        $(PACKAGES) $(PACKAGES_STAGE2))
	"$(RM)" $(RM_OPTS) libraries/base/include/HsBaseConfig.h.in
	"$(RM)" $(RM_OPTS) libraries/directory/include/HsDirectoryConfig.h.in
	"$(RM)" $(RM_OPTS) libraries/process/include/HsProcessConfig.h.in
	"$(RM)" $(RM_OPTS) libraries/unix/include/HsUnixConfig.h.in
	"$(RM)" $(RM_OPTS) libraries/old-time/include/HsTimeConfig.h.in

.PHONY: all_libraries

.PHONY: bootstrapping-files
bootstrapping-files: $(OTHER_LIBS)
bootstrapping-files: includes/ghcautoconf.h
bootstrapping-files: includes/DerivedConstants.h
bootstrapping-files: includes/GHCConstants.h

