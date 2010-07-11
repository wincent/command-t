rubyfiles   := $(shell find ruby -name '*.rb')
cfiles      := $(shell find ruby -name '*.c')
cheaders    := $(shell find ruby -name '*.h')
depends     := $(shell find ruby -name depend)
txtfiles    := $(shell find doc -name '*.txt')
vimfiles    := $(shell find plugin -name '*.vim')

vimball:	command-t.vba

command-t.vba: $(rubyfiles) $(cfiles) $(cheaders) $(depends) $(txtfiles) $(vimfiles)
	mkvimball $(basename $@) $^

.PHONY: spec
spec:
	rspec spec

.PHONY: clean
clean:
	rm -f command-t.vba
