# 💻 Lua console ![main](https://github.com/yarospace/lua-console.nvim/actions/workflows/test_main.yml/badge.svg?branch=main) ![develop](https://github.com/yarospace/lua-console.nvim/actions/workflows/test_develop.yml/badge.svg?branch=develop) [![LuaRocks](https://img.shields.io/luarocks/v/YaroSpace/lua-console.nvim?logo=lua&color=purple)](https://luarocks.org/modules/YaroSpace/lua-console.nvim)

**lua-console.nvim** - is a handy scratch pad / REPL / debug console for Lua development and Neovim exploration and configuration.  
Acts as a user friendly replacement of command mode - messages loop and as a handy scratch pad to store and test your code gists.

***Update: Although it originated as a tool for Lua development, it has now evolved into supporting other languages too. See [`evaluating other languages`](#evaluating-other-languages).***

<br/><img src="doc/demo.gif">

## 💡 Motivation

After installing Neovim, it took me some time to configure it, learn its settings, structure and API, while learning Lua in the process.  
I got fed up of constantly hitting `:`, typing `lua= command`, then typing `:messages` to see the output, only to find out that a made a typo or a 
syntax error and retyping the whole thing again, copying the paths from error stacktraces and so on.  I needed something better, so there it is.

## ✨ Features

- Evaluate single line expressions and statements, visually selected lines of code or the whole buffer
- Pretty print Lua objects, including function details and their source paths
- Show normal and error output in the console/buffer, including output of `print()`, errors and stacktraces. 
- Syntax highlighting and autocompletion
- Load Neovim’s messages into console for inspection and copy/paste
- Open links from stacktraces and function sources
- Save / Load / Autosave console session
- Use as a scratch pad for code gists
- Attach code evaluators to any buffer


## 📦 Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "yarospace/lua-console.nvim",
  lazy = true, keys = "`", opts = {},
}
```
otherwise, install with your favorite package manager and add
`require('lua-console').setup { custom_options }` somewhere in your config.


## ⚙️  Configuration

> [!NOTE]
> All settings are self explanatory, but please read below about [`preserve_context`](#-notes-on-globals-locals-and-preserving-execution-context) option.

Mappings are local to the console, except the ones for toggling the console - `` ` `` and attaching to a buffer - ``<Leader>` ``. All mappings can be overridden in your custom 
config. If you want to delete a mapping - set its value to `false`.

<details><summary>Default Settings</summary>

<!-- config:start -->
`config.lua`
```lua
opts = {
  buffer = {
    result_prefix = '=> ',
    save_path = vim.fn.stdpath('state') .. '/lua-console.lua',
    autosave = true, -- autosave on console hide / close
    load_on_start = true, -- load saved session on start
    preserve_context = true,  -- preserve results between evaluations
  },
  window = {
    border = 'double', -- single|double|rounded
    height = 0.6, -- percentage of main window
  },
  mappings = {
    toggle = '`',
    attach = '<Leader>`',
    quit = 'q',
    eval = '<CR>',
    eval_buffer = '<S-CR>',
    open = 'gf',
    messages = 'M',
    save = 'S',
    load = 'L',
    resize_up = '<C-Up>',
    resize_down = '<C-Down>',
    help = '?'
  },
}
```
<!-- config:end -->

</details>


## 🚀 Basic usage (with default mappings)

- Install, press the mapped key `` ` `` and start exploring. 
- Enter code as normal, in insert mode.
- Hit `Enter` in normal mode to evaluate a variable, statement or an expression in the current line. 
- Visually select a range of lines and press `Enter` to evaluate the code in the range or use `<S-Enter>` to evaluate the whole console.
- The evaluation of the last line is returned and printed, so no `return` is needed in most cases.  
  To avoid noise, if the return of your execution is `nil`, e.g. from a loop or a function without return, it will not be printed, but shown as virtual text. 
  The result of assignments on the last line will be also shown as virtual text.
- Use `print()` in your code to output the results into the console.  It accepts variable number of arguments, e.g. `print(var_1, var_2, ...)`.
- Objects and functions are pretty printed, with function details and their source paths.
- Press `gf` to follow the paths in stack traces and to function sources. Truncated paths work too.

> [!NOTE]
> This is especially useful when you want to see where a function was redefined at runtime.  So, if you evaluate `vim.lsp.handlers['textDocument/hover']` for 
  example, you can jump to its current definition, while Lsp/tags would take you to the original one.

- Press `M` to load Neovim messages into the console. 
- Use `S` and `L` to save / load the console session to preserve history of your hacking.  If the `autosave` option is on, the contents of the console will be 
  saved whenever it is toggled or closed. 
- You can resize the console with `<C-Up>` and `<C-Down>`.


## 📓 Notes on globals, locals and preserving execution context

> [!IMPORTANT]
> By default, the option `preserve_context` is on, which means that the execution context is preserved between evaluations. 

All the code executed in the console is evaluated in isolated environment.  This means that any variables you declare without the `local` keyword will not be persisted 
in Neovim's global environment, although all global variables are accessible.  If you want purposefully to alter the global state, use `_G.My_variable = ..`.

The option `preserve_context` means that although you declare variables without `local`, they will be stored in console's local context and preserved between separate executions. 
So, if you first execute `a = 1`, then `a = a + 1` and then `a` - you will get `2`. Variables with `local` are not preserved.  

If you want the context to be cleared before every execution, set `preserve_context = false`.

There are two functions available within the console:

- `_ctx()` - will print the contents of the context
- `_ctx_clear()` - clears the context


## ⭐ Extra features

### Attaching code evaluator to other buffers

- The evaluator behind the console can be attached/detached to any buffer by pressing ``<Leader>` `` or executing command `LuaConsole AttachToggle`.
  You will be able to evaluate the code in the buffer as in the console and follow links.  The evaluators and their contexts are isolated for each attached buffer.

### Evaluating other languages

#### Setting up

- It is possible to setup external code executors for other languages.  Evaluators for `ruby` and `racket` are working out of the box, support for other languages is coming. 
  Meanwhile, you can easily setup your own language.  
- Below is the default configuration which can be overridden or extended by your custom config (`default_process_opts` will be 
  replaced by language specific opts), e.g. a possible config for `python` could be:

  ```lua
  require('lua-console').setup { 
    external_evaluators = {
      python = {
        cmd = { 'python3', '-c' },
        env = { PYTHONPATH = '~/projects' },
        timeout = 100000,
        formatter = function(result) do_something; return result end,
      },
    }
  }
  ```

- You can also setup a custom formatter to format the evaluator output before appending results to the console or buffer. Example is in the config.

  <details><summary>Default External Evaluators Settings</summary>

  <!-- config:start -->
  `exev_config.lua`
  ```lua
  ---Formats the output of external evaluator
  ---@param result string[]
  ---@return string[]
  local function generic_formatter(result)
    local width = vim.o.columns
    local sep_start = ('='):rep(width)
    local sep_end = ('='):rep(width)

    table.insert(result, 1, sep_start)
    table.insert(result, sep_end)

    return result
  end

  local external_evaluators = {
    lang_prefix = '===',
    default_process_opts = {
      cwd = nil,
      env = { EMPTY = '' },
      clear_env = false,
      stdin = false,
      stdout = false,
      stderr = false,
      text = true,
      timeout = nil,
      detach = false,
      on_exit = nil,
    },

    ruby = {
      cmd = { 'ruby', '-e' },
      env = { RUBY_VERSION = '3.3.0' },
      code_prefix = '$stdout.sync = true;',
      formatter = generic_formatter,
    },

    racket = {
      cmd = { 'racket', '-e' },
      formatter = generic_formatter,
    },
  }

  return external_evaluators
  ```
  <!-- config:end -->

  </details>

  #### Usage

- The language evaluator is determined either from (in order of precedence):

  - The code prefix `===lang` on the line above your code snippet, in which case it only applies to the snippet directly below and it should be included in the selection 
  for evaluation. The prefix can be changed in the config.
  - The code prefix on the top line of the console/buffer, in which case it applies to the whole buffer.
  - The file type of the buffer. 
  <br/> 

  ```racket
  ===racket


    (define (log str)
      (displayln (format "~v" str)))


    (define (fact n)
      (if (= n 0)
          1
          (* n (fact (- n 1)))))

    (displayln (fact 111))
  ```

  ```ruby
  ===ruby
    5.times { puts 'Hey' }
  ```

## Alternatives and comparison

There are a number of alternatives available, notably:

- [Luapad](https://github.com/rafcamlet/nvim-luapad)
- [Luadev](https://github.com/bfredl/nvim-luadev)
- [SnipRun](https://github.com/michaelb/sniprun)

Initially, when starting with Lua and Neovim, I tried all the REPLs/code runners I could find.  However, I was not satisfied with all of them in one way or another.  
Lua-console is an attempt to combine the best features of all of them, like REPL / scratch pad / code runner / debug console, while leaving the UX and config simple.


## 🔥 All feedback and feature requests are very welcome!  Enjoy!
