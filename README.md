# 💻 Lua console ![main](https://github.com/yarospace/lua-console.nvim/actions/workflows/test_main.yml/badge.svg?branch=main) ![develop](https://github.com/yarospace/lua-console.nvim/actions/workflows/test_develop.yml/badge.svg?branch=develop) [![LuaRocks](https://img.shields.io/luarocks/v/YaroSpace/lua-console.nvim?logo=lua&color=purple)](https://luarocks.org/modules/YaroSpace/lua-console.nvim)

**lua-console.nvim** - is a handy scratch pad / REPL / debug console for Lua development and Neovim exploration and configuration.  
Acts as a user friendly replacement of command mode - messages loop and as a handy scratch pad to store and test your code gists.

<img src="doc/demo.gif">

## 💡 Motivation

After installing Neovim, it took me some time to configure it, learn its settings, structure and API, while learning Lua in the process.  
I got fed up of constantly hitting `:`, typing `lua= command`, then typing `:messages` to see the output, only to find out that a made a typo or a 
syntax error and retyping the whole thing again, copying the paths from error stacktraces and so on.  I needed something better, so there it is.

## ✨ Features

- Evaluate single line expressions
- Evaluate visually selected lines of code
- Pretty print Lua objects, including function details and their source paths
- Show normal and error output in the console, including output of print(), errors and stacktraces. 
- Syntax highlighting and autocompletion
- Load Neovim’s messages into console for inspection and copy/paste
- Open links from stacktraces and function sources
- Save / Load console session
- Use as scratch pad for code gists


## 📦 Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "yarospace/lua-console.nvim",
  lazy = true, keys = "`", opts = {},
}
```
otherwise, install with your favourite package manager and add
`require('lua-console').setup({opts})` somewhere in your config.


## ⚙️  Configuration

<details><summary>Default Settings</summary>

<!-- config:start -->

```lua
opts = {
  buffer = {
    prepend_result_with = '=> ',
    save_path = vim.fn.stdpath('state') .. '/lua-console.lua',
    load_on_start = true -- load saved session on first entry
  },
  window = {
    anchor = 'SW',
    border = 'double',  -- single|double|rounded
    height = 0.6, -- percentage of main window
    zindex = 1,
  },
  mappings = {
    toggle = '`',
    quit = 'q',
    eval = '<CR>',
    clear = 'C',
    messages = 'M',
    save = 'S',
    load = 'L',
    resize_up = '<C-Up>',
    resize_down = '<C-Down>',
    help = '?'
  }
}
```

<!-- config:end -->

</details>

## 🚀 Usage (with default mappings)

- Install, hit the mapped key `` ` `` and start exploring. 
- Enter code as normal, in insert mode.
- Hit `Enter` in normal mode to evaluate a variable, statement or an expression in the current line. 
- Visually select a range of lines and press `Enter` to evaluate the code in the range. 
- The evaluation of the last line is returned and printed, so no `return` is needed in most cases.
- Use `print()` in your code to output the result into the console.  Objects and functions are pretty printed. 
- Press `M` to load Neovim messages into the console. 
- Press `gf` to follow the paths in stack traces and to function sources. 
- Use `S` and `L` to save / load the console session to preserve history of your hacking. 
- You can resize the console with `<C-Up>` and `<C-Down>`.
