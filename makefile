prefix := /usr/local
lib := $(prefix)/lib

CUR_DIR = $(shell readlink -f "$(CURDIR)")
LIB_DIR = $(shell readlink -f "$$(test '$(lib)' = '$$(pwd)' && echo $(lib) || echo $(lib))")
SCRIPT = aeten-cli.sh
COMMANDS = $(shell . $$(pwd)/$(SCRIPT) ; __api $(SCRIPT))
LINKS = $(addprefix $(prefix)/bin/,$(COMMANDS))
MAKE_INCLUDE = $(addprefix $(LIB_DIR)/,$(SCRIPT:%.sh=%.mk))

.PHONY: install uninstall
install: $(LINKS) $(MAKE_INCLUDE)

uninstall:
	rm -f $(filter-out $(CUR_DIR)/$(SCRIPT),$(LIB_DIR)/$(SCRIPT)) $(LINKS) $(MAKE_INCLUDE)

test:
	@./test.sh

ifneq ($(LIB_DIR),$(CUR_DIR)) # Prevent circular dependency
$(LIB_DIR)/%: %
	cp $< $@
endif

$(LINKS): $(LIB_DIR)/$(SCRIPT)
	ln -s $< $@

$(LIB_DIR)/%.mk: %.sh
	( . ./$^ ; __api ./$^ ) | awk '{print $$0" = @$(LIB_DIR)/$^ "$$0}' > $@
