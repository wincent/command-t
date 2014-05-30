rubyfiles   := $(shell find ruby -name '*.rb')
cfiles      := $(shell find ruby -name '*.c')
cheaders    := $(shell find ruby -name '*.h')
depends     := $(shell find ruby -name depend)
txtfiles    := $(shell find doc -name '*.txt')
vimfiles    := $(shell find autoload plugin -name '*.vim')

vimball:	command-t.vba

command-t.recipe: $(rubyfiles) $(cfiles) $(cheaders) $(depends) $(txtfiles) $(vimfiles)
	echo "$^" | perl -pe 's/ /\n/g' > $@
command-t.vba: command-t.recipe
	vendor/vimball/vimball.rb -d . -b . vba $^

.PHONY: spec
spec:
	rspec spec

.PHONY: clean
clean:
	rm -f command-t.vba
