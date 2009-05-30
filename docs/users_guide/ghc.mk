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

docs/users_guide_DOCBOOK_SOURCES := \
    $(wildcard docs/users_guide/*.xml) \
    $(basename $(wildcard docs/users_guide/*.xml.in))

$(eval $(call docbook,docs/users_guide,users_guide))

# Hack: dblatex normalises the name of the input file using
# os.path.realpath, which means that if we're in a linked build tree,
# it won't be able to find ug-book.xml which is in the build tree but
# not in the source tree.  Hence, we copy ug-book.xml to the source
# tree.  This is a horrible hack, but I can't find a better way to do
# it --SDM (2009-05-11)

build_ug_book = docs/users_guide/ug-book.xml
src_ug_book  = $(dir $(realpath $(dir $(build_ug_book))/ug-book.xml.in))ug-book.xml

ifneq "$(build_ug_book)" "$(src_ug_book)"
$(src_ug_book) : $(build_ug_book)
	"$(CP)" $< $@
docs/users_guide/users_guide.pdf docs/users_guide/users_guide.ps: $(src_ug_book)
endif
