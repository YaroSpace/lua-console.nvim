set_lua_paths = eval $$(luarocks path --lua-version 5.1 --bin)
test_unit = busted -o spec/utfTerminal.lua --run unit
tag ?= wip

watch = '*.lua'

.PHONY: api_documentation luacheck stylua test

all: test luacheck

api_documentation:
	nvim -u scripts/make_api_documentation/minimal_init.lua -l scripts/make_api_documentation/main.lua

llscheck:
	llscheck --configpath .luarc.json .

luacheck:
	luacheck lua spec scripts

stylua:
	stylua --check lua scripts spec

test:
	@$(set_lua_paths); $(test_unit)

watch:
	@$(set_lua_paths); while sleep 0.1; do find . -name $(watch) | entr -d -c $(test_unit); done

watch_tag:
	@$(set_lua_paths); while sleep 0.1; do find . -name $(watch) | entr -d -c $(test_unit) -t=$(tag); done
