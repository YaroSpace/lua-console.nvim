# 💻 Lua console

**lua-console.nvim** is yet another REPL console to execute Lua, configure Neovim, explore its API and settings.  
Acts as a user friendly replacement of Command mode - Messages loop. 

## 💡 Motivation

After installing Neovim, it took me some time to configure it, learn its settings, structure and API, while learning Lua in the process. 
I got fed up of constantly hitting `:`, typing `lua= command`, then typing `:messages` to see the output, only to find out that a made a typo or a syntax error and retyping the whole thing again, copying the paths from error stacktraces and so on.  I needed something better, so there it is.

## ✨ Features

- Evaluate single line expressions
- Evaluate visually selected lines of code
- Pretty print Lua objects, including function details and their source path
- Show normal and error output in the console, including output of print(), errors and stacktraces. 
- Syntax highlighting and autocompletion
- Load Neovim’s messages into console
- Save / Load console session


## 📦 Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "yarospace/lua-console.nvim",
  lazy = true, keys = "`", opts = {},
}
```
otherwise: `require('lua-console').setup({opts})`


## ⚙️  Configuration

Default settings:

```lua
opts = {
  buffer = {
    prepend_result_with = '=> ',
    save_path = vim.fn.stdpath('state') .. '/lua-console.lua',
    load_on_start = true -- load saved session on first entry
  },
  window = {
    -- @field height number Percentage of main window
    height = 0.6,
    border = { '╔', '═' ,'╗', '║', '╝', '═', '╚', '║' },
  },
  mappings = {
    toggle = '`',
    eval = '<CR>',  -- or <C-J> for <C-Enter>
    clear = 'C',
    messages = 'M',
    save = 'S',
    load = 'L'
  }
}
```

## 🚀 Usage (with default mappings)

- Install, hit the mapped key `` ` `` and start exploring. 
- Enter code as normal, in insert mode.
- Hit `Enter` in normal mode to evaluate a variable or an expression in the current line. 
- Visually select a range of lines and press `Enter` to evaluate the code in the range. 
- Use `print()` in your code to output the result into the console.  Objects and functions are pretty printed. 
- Use `return …` at the end of multiline code to return a result instead of nil. 
- Press `M` to load Neovim messages into the console. 
- Press `gf` to follow the paths in stack traces and to function sources. 
- Use `S` and `L` to save / load the console session to preserve history of your hacking. 
- You can resize the console with `<C-Up>` and `<C-Down>`.
