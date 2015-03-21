prefix := /usr/local
lib := $(prefix)/lib

CUR_DIR = $(shell readlink -f "$(CURDIR)")
LIB_DIR = $(shell readlink -f "$$(test '$(lib)' = '$$(pwd)' && echo $(lib) || echo $(lib))")
SCRIPT = aeten-shell-log.sh
COMMANDS = $(shell . $$(pwd)/$(SCRIPT) ; __api $(SCRIPT))
LINKS = $(addprefix $(prefix)/bin/,$(COMMANDS))

.PHONY: install uninstall
install: $(LINKS)

uninstall:
	rm -f $(filter-out $(CUR_DIR)/$(SCRIPT),$(LIB_DIR)/$(SCRIPT)) $(LINKS)

test:
	@./test.sh

ifneq ($(LIB_DIR),$(CUR_DIR)) # Prevent circular dependency
$(LIB_DIR)/%: %
	cp $< $@
endif

$(LINKS): $(LIB_DIR)/$(SCRIPT)
	ln -s $< $@
