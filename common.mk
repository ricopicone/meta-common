# ifdef commondir # going away from support for building from within common-dir
# else
# commondir = .
# endif

define uniq
  $(eval seen :=)
  $(foreach _,$1,$(if $(filter $_,${seen}),,$(eval seen += $_)))
  ${seen}
endef

# load book-def.json book editions
# define GetFromPkg
# $(shell node -p "require('$(2)/book-def.json').$(1)")
# endef
# BOOK_NAME      	:= $(call GetFromPkg,book-name,$(commondir))
# BOOK_SHORT_NAME := $(call GetFromPkg,book-short-name,$(commondir))
# EDITIONS  		:= $(call GetFromPkg,editions,$(commondir))
# PROJECT_URL  := $(call GetFromPkg,editions.hp1,$(commondir))

versioned_sources = $(shell find $(commondir)/versioned -type f -name '*source.md')
versioned_targets_tex = $(versioned_sources:source.md=index.tex)
versioned_targets_html = $(versioned_sources:source.md=index.html)
versioned_targets = $(versioned_targets_tex) $(versioned_targets_html)
faux_sources = $(shell find $(commondir)/faux -type f -name '*source.md')
faux_targets_html = $(faux_sources:source.md=index.html)
book_json_sources = $(shell find $(commondir)/book-json -type f -name '*raw.json')
book_json_targets = $(book_json_sources:raw.json=cleaned.json)
# $(info $$book_json_sources is [${book_json_sources}])
# $(info $$book_json_targets is [${book_json_targets}])
apocrypha_json = $(commondir)/book-json/apocrypha.json
# matlab_source_targets = $(shell find $(commondir)/source -type f \( -name '*make.dat' -o -name '*make.tex' \) )
# matlab_source_sources = $(call uniq,$(patsubst %,%make.m,$(dir $(matlab_source_targets))))
# $(info $$matlab_source_targets is [${matlab_source_targets}])
# common_makefiles = $(shell find . -type f -name '*Makefile')
hardware_list_targets = $(shell find $(commondir) -type f -name 'versions-list-*')
software_list_targets = $(hardware_list_targets)

source_files = $(versioned_sources) $(matlab_source_make_sources)

.PHONY: versioned versioned-tex versioned-html faux apocrypha_rm extract-parameters

versioned: apocrypha_rm $(book_json_targets) $(commondir)/book-defs.tex $(commondir)/versions-inherited-flat.json $(hardware_list_targets) $(software_list_targets) $(versioned_targets) faux $(faux_targets_html)
versioned-tex: $(book_json_targets) $(commondir)/versions-inherited-flat.json $(hardware_list_targets) $(software_list_targets) $(versioned_targets_tex)
versioned-html: $(book_json_targets) $(commondir)/versions-inherited-flat.json $(hardware_list_targets) $(software_list_targets) $(versioned_targets_html) faux $(faux_targets_html)	

# Clean/process the book.json files
%-cleaned.json: $(book_json_sources)
	python $(commondir)/json-clean.py $< $@
	python $(commondir)/scripts/extract_chapter_section_hash_order.py $@

# Make tex versions of json files
$(commondir)/book-defs.tex: $(commondir)/book-defs.json
	json2latex $< data $@
	
common_pandoc_opts = --lua-filter $(commondir)/lua-filters/include-files/include-files.lua -M no-relative=true --lua-filter=$(commondir)/lua-filters/include-code-files/include-code-files.lua --lua-filter $(commondir)/section-divs.lua --lua-filter $(commondir)/filter.lua -F pandoc-crossref
html_pandoc_opts = -t html -f markdown+raw_tex -t html+raw_tex $(common_pandoc_opts) --citeproc --bibliography $(commondir)/book.bib --default-image-extension=svg --mathjax -o
latex_pandoc_opts = -t latex -f markdown-markdown_in_html_blocks+raw_tex $(common_pandoc_opts) --lua-filter $(commondir)/lua-filters/minted/minted.lua --biblatex -M cref=True -o

# Pandoc versioned files' markdown source to html
%index.html: %source.md
	rm -f $@
	pandoc $(html_pandoc_opts) $@ $<

# Pandoc versioned files' markdown source to LaTeX
common/versioned/%index.tex: common/versioned/%source.md source/%main.md source/%main.py
	rm -f $@
	pandoc $(latex_pandoc_opts) $@ $<

%index.tex: %source.md # source/%mains don't exist
	rm -f $@
	pandoc $(latex_pandoc_opts) $@ $<

common/versioned/%source.md: source/%main.md

source/%main.md: source/%main.py
	cd source/$*; publish 'main.py' md
	
common/versioned/lab%-problems-wrap/index.tex: common/versioned/lab%-problems-wrap/source.md common/versioned/lab%-problems/source.md
	rm -f $@
	pandoc $(latex_pandoc_opts) $@ $<

# Extra dependencies for the hardware list
# $(commondir)/versioned/ef/index.tex: $(hardware_list_targets)
# $(commondir)/versioned/ef/index.html: $(hardware_list_targets)

# Extra dependencies for the software list
# $(commondir)/versioned/uh/index.tex: $(software_list_targets)
# $(commondir)/versioned/uh/index.html: $(software_list_targets)

# Process versions.json into versions-inherited-flat.json
$(commondir)/versions-inherited-flat.json: $(commondir)/versions.json
	python $(commondir)/versions-inheriter.py $(commondir)/versions.json

# Process versions-inherited-flat.json to generate versions-list-<edition>-<version>.md files
$(hardware_list_targets): $(commondir)/versions-inherited-flat.json $(commondir)/book-defs.json
	python $(commondir)/versions-lister.py $(commondir)/versions-inherited-flat.json $(commondir)/versions.json $(commondir)/book-defs.json

# Extract parameters for MATLAB and C
extract-parameters: $(commondir)/versions-inherited-flat.json
	python $(commondir)/parameters_extractor.py --file_versions_inherited_json $<
	cp $(commondir)/parameters/*.mat $(commondir)/source/matlab/elmech_params
	cd $(commondir)/source/matlab/elmech_params && $(MAKE) -B
	cd $(commondir) && python parameters_to_c_headers.py

# Extra dependencies for labs because lab problems are markdown included
# $(commondir)/versioned/ph/index.tex: $(commondir)/versioned/lab1-problems/source.md

# Extra dependency for markdown (filter)
%source.md: $(commondir)/filter.lua
%index.tex: $(commondir)/filter.lua
%index.html: $(commondir)/filter.lua