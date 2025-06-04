test=nvim -l tests/minit.lua tests -o utfTerminal -Xoutput --color -v 
#--shuffle-tests 

tag ?= wip
watch = '*.lua'

.PHONY: api_documentation luacheck stylua test

all: test luacheck stylua

api_documentation:
	nvim -u scripts/make_api_documentation/init.lua -l scripts/make_api_documentation/main.lua

llscheck:
	@$(set_luals_path) && llscheck --configpath .luarc.json .

luacheck:
	luacheck lua tests scripts

stylua:
	stylua --check lua scripts spec

test:
	@$(test)

watch:
	@while sleep 0.1; do find . -name $(watch) | entr -d -c $(test); done

watch_tag:
	@while sleep 0.1; do find . -name $(watch) | entr -d -c $(test) --tags=$(tag); done

test_nvim:
	@$(test_nvim) spec/unit
