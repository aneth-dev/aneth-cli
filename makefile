prefix := /usr/local
lib := $(prefix)/lib

CUR_DIR = $(shell readlink -f "$(CURDIR)")
LIB_DIR = $(shell readlink -f "$$(test '$(lib)' = '$$(pwd)' && echo $(lib) || echo $(lib))")
CLI = aeten-cli.sh
COMMANDS = $(shell . $$(pwd)/$(CLI) ; __api $(CLI))
LINKS = $(addprefix $(prefix)/bin/,$(COMMANDS))
MAKE_INCLUDE = $(addprefix $(LIB_DIR)/,$(CLI:%.sh=%.mk))
check = @./$(CLI) check

.PHONY: all clean test install uninstall

all: $(CLI:%.sh=%.mk) test

clean:
	$(check) -m "Delete Æten CLI make include" rm -f $(CLI:%.sh=%.mk)

install: $(LINKS) $(MAKE_INCLUDE)

uninstall:
	$(check) -m "Uninstall Æten CLI lib" '[ "$(CUR_DIR)" = "$(LIB_DIR)" ] || rm $(LIB_DIR)/$(CLI)'
	$(check) -m "Uninstall Æten CLI symlinks" rm $(LINKS)
	$(check) -m "Uninstall Æten CLI make include" rm -f $(MAKE_INCLUDE)

test:
	$(check) -m "Run Æten CLI tests" ./test.sh

ifneq ($(LIB_DIR),$(CUR_DIR)) # Prevent circular dependency
$(LIB_DIR)/%: %
	$(check) -m "Install Æten CLI lib $@" cp $< $@
endif

$(LINKS): $(LIB_DIR)/$(CLI)
	$(check) -m "Install Æten CLI symlink $@" ln -s $< $@

%.mk: %.sh
	$(check) -m "Generate Æten CLI make include" '( . ./$^ ; __api ./$^ ) | awk '"'"'{print $$0" = '$$(dirname $@)'/$^ "$$0}'"'"' > $@'

$(LIB_DIR)/%.mk: %.mk
	$(check) -m "Install Æten CLI make include" sed "s@$$(dirname $<|sed 's@.@\\.@g')@$(LIB_DIR)@" $< > $@
