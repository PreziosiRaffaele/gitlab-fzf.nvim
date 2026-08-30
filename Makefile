.PHONY: quality test check deps

MINI_NVIM := deps/mini.nvim
MINI_NVIM_REF := v0.17.0
FZF_LUA := deps/fzf-lua
FZF_LUA_REF := 05e44d38de0a79c11fba5f7bf8138791b1dbdd1e

quality:
	luacheck lua/ plugin/
	stylua --check .
	lua-language-server --check lua/ --configpath $(CURDIR)/.luarc.json --checklevel=Error

deps: $(MINI_NVIM) $(FZF_LUA)

$(MINI_NVIM):
	git clone --filter=blob:none --branch $(MINI_NVIM_REF) https://github.com/echasnovski/mini.nvim $(MINI_NVIM)

$(FZF_LUA):
	git clone --filter=blob:none --no-checkout https://github.com/ibhagwan/fzf-lua $(FZF_LUA)
	git -C $(FZF_LUA) checkout --detach $(FZF_LUA_REF)

test: deps
	nvim --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run()"

check: quality test
