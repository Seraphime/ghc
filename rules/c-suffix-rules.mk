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


define c-suffix-rules 
# $1 = dir
# $2 = distdir
# $3 = way
# $4 = use GHC (YES/NO)

# UseGhcForCc is only relevant when not booting from HC files.
ifeq "$4 $$(BootingFromHc)" "YES NO"

$1/$2/build/%.$$($3_osuf) : $1/%.c $$(MKDIRHIER) $$($1_$2_HC_DEP)
	"$$(RM)" $$(RM_OPTS) $$@
	"$$(MKDIRHIER)" $$(dir $$@)
	"$$($1_$2_HC)" $$($1_$2_$3_GHC_CC_OPTS) -c $$< -o $$@

$1/$2/build/%.$$($3_osuf) : $1/$2/build/%.c $$($1_$2_HC_DEP)
	"$$(RM)" $$(RM_OPTS) $$@
	"$$($1_$2_HC)" $$($1_$2_$3_GHC_CC_OPTS) -c $$< -o $$@

$1/$2/build/%.$$($3_osuf) : $1/$2/build/%.$$($3_way_)s $$($1_$2_HC_DEP)
	"$$(RM)" $$(RM_OPTS) $$@
	"$$($1_$2_HC)" $$($1_$2_$3_GHC_CC_OPTS) -c $$< -o $$@

$1/$2/build/%.$$($3_osuf) : $1/%.S $$(MKDIRHIER) $$($1_$2_HC_DEP)
	"$$(RM)" $$(RM_OPTS) $$@
	"$$(MKDIRHIER)" $$(dir $$@)
	"$$($1_$2_HC)" $$($1_$2_$3_GHC_CC_OPTS) -c $$< -o $$@

$1/$2/build/%.$$($3_way_)s : $1/$2/build/%.c $$($1_$2_HC_DEP)
	"$$(RM)" $$(RM_OPTS) $$@
	"$$($1_$2_HC)" $$($1_$2_$3_GHC_CC_OPTS) -S $$< -o $$@

$1/$2/build/%.$$($3_way_)s : $1/%.c $$($1_$2_HC_DEP)
	"$$(RM)" $$(RM_OPTS) $$@
	"$$($1_$2_HC)" $$($1_$2_$3_GHC_CC_OPTS) -S $$< -o $$@

else

$1/$2/build/%.$$($3_osuf) : $1/%.c $$(MKDIRHIER)
	"$$(RM)" $$(RM_OPTS) $$@
	"$$(MKDIRHIER)" $$(dir $$@)
	"$$(CC)" $$($1_$2_$3_ALL_CC_OPTS) -c $$< -o $$@

$1/$2/build/%.$$($3_osuf) : $1/$2/build/%.c
	"$$(RM)" $$(RM_OPTS) $$@
	"$$(CC)" $$($1_$2_$3_ALL_CC_OPTS) -c $$< -o $$@

$1/$2/build/%.$$($3_osuf) : $1/$2/build/%.$$($3_way_)s
	"$$(RM)" $$(RM_OPTS) $$@
	"$$(AS)" $$($1_$2_$3_ALL_AS_OPTS) -o $$@ $$<

$1/$2/build/%.$$($3_osuf) : $1/%.S $$(MKDIRHIER)
	"$$(RM)" $$(RM_OPTS) $$@
	"$$(MKDIRHIER)" $$(dir $$@)
	"$$(CC)" $$($1_$2_$3_ALL_CC_OPTS) -c $$< -o $$@

$1/$2/build/%.$$($3_way_)s : $1/$2/build/%.c
	"$$(RM)" $$(RM_OPTS) $$@
	"$$(CC)" $$($1_$2_$3_ALL_CC_OPTS) -S $$< -o $$@

endif

endef

