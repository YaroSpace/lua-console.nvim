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
- Show normal and error output in the console, including output of `print()`, errors and stacktraces. 
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
otherwise, install with your favorite package manager and add
`require('lua-console').setup({opts})` somewhere in your config.


## ⚙️  Configuration

> [!NOTE]
> All settings are very straight forward, but please read below about [`preserve_context`](#-notes-on-globals-locals-and-preserving-execution-context) option.

Mappings are local to the console, except the one for toggling, which is - `` ` `` by default.

<details><summary>Default Settings</summary>

<!-- config:start -->

```lua
opts = {
  buffer = {
    prepend_result_with = '=> ',
    save_path = vim.fn.stdpath('state') .. '/lua-console.lua',
    load_on_start = true, -- load saved session on first entry
    preserve_context = true -- preserve context between executions
  },
  window = {
    border = 'double',  -- single|double|rounded
    height = 0.6, -- percentage of main window
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

- Install, press the mapped key `` ` `` and start exploring. 
- Enter code as normal, in insert mode.
- Hit `Enter` in normal mode to evaluate a variable, statement or an expression in the current line. 
- Visually select a range of lines and press `Enter` to evaluate the code in the range. 
- The evaluation of the last line is returned and printed, so no `return` is needed in most cases.  
  To avoid noise, if the only return of your execution is `nil`, e.g. from an assignment, like `a = 1`, it will not be printed, but shown as virtual text.
- Use `print()` in your code to output the results into the console.  Accepts variable number of arguments, e.g. `print(var_1, var_2, ...)`.
- Objects and functions are pretty printed, with function source paths.
- Press `gf` to follow the paths in stack traces and to function sources. Truncated paths work too.

> [!NOTE]
> This is especially useful when you want to see where a function was redefined at runtime.  So, if you evaluate `vim.lsp.handlers['textDocument/hover']` for 
  example, you can jump to its current definition, while Lsp/tags would take you to the original one.

- Press `M` to load Neovim messages into the console. 
- Use `S` and `L` to save / load the console session to preserve history of your hacking. 
- You can resize the console with `<C-Up>` and `<C-Down>`.


## 📓 Notes on globals, locals and preserving execution context

> [!IMPORTANT]
> By default, the option `preserve_context` is on, which means that the context is preserved between executions. 

All the code executed in the console is evaluated in isolated environment.  This means that any variables you declare will not be persisted in Neovim's global 
environment, although all global variables are accessible.  If you want purposefully to alter the global state, use `_G.My_variable = ..`.

The option `preserve_context` means that if you assign variables without `local`, they will be stored in console's local context and preserved between separate executions. 
So, if you first execute `a = 1`, then `a = a + 1` and then `a` - you will get `2`. Variables with `local` are not preserved.  

If you want a classic REPL experience, when the context is cleared on every execution, set `preserve_context = false`.

There are two functions available within the console:

- `_ctx()` - will print the contents of the context
- `_ctx_clear()` - clears the context


## Alternatives and comparison

There are a number of alternatives available, notably:

- [Luapad](https://github.com/rafcamlet/nvim-luapad)
- [Luadev](https://github.com/bfredl/nvim-luadev)
- [SnipRun](https://github.com/michaelb/sniprun)

Initially, when starting with Lua and Neovim, I tried all the REPLs/code runners I could find.  However, I was not satisfied with all of them in one way or another.  
Lua-console is an attempt to combine the best features of all of them, like REPL / scratch pad / code runner / debug console, while leaving the UX and config simple.


## 🔥 All feedback and feature requests are very welcome!  Enjoy!
