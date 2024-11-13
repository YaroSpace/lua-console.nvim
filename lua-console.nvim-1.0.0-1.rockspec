rockspec_format = "3.0"
package = "lua-console.nvim"
version = "1.0.0-1"

source = {
	url = "git://github.com/yarospace/" .. package,
	tag = "v1.0.1",
}

description = {
	summary = "lua-console.nvim - a handy scratch pad / REPL / debug console for Lua development and Neovim exploration and configuration.",
	detailed = "Acts as a user friendly replacement of command mode - messages loop and as a handy scratch pad to store and test your code gists.",
	labels = { "neovim", "neovim-plugin" },
}

dependencies = {
	-- Add runtime dependencies here
	-- e.g. "plenary.nvim",
}

test_dependencies = {
	"lua >= 5.1",
	-- 'nlua',
}

build = {
	type = "builtin",
	copy_directories = { "doc", "spec" },
}
