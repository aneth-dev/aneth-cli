prefix := /usr/local
bin := bin
lib := lib

SCRIPT = aeten-shell-log.sh
COMMANDS = $(shell sed --quiet --regexp-extended 's/(^[[:alnum:]][[:alnum:]_-]*)\s*\(\)\s*\{/\1/p' $(SCRIPT))
LIB_DIR = $(shell readlink -f $(prefix)/$(lib))
LINKS = $(addprefix $(prefix)/$(bin)/,$(COMMANDS))

.PHONY: install uninstall
install: $(LINKS)

uninstall:
	rm -f $(LIB_DIR)/$(SCRIPT) $(LINKS)

test:
	@./test.sh

$(LIB_DIR)/%: %
	cp -f $< $@

$(LINKS): $(LIB_DIR)/$(SCRIPT)
	ln -fs $< $@
