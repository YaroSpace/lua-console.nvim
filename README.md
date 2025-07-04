# 💻 Lua console ![main](https://github.com/yarospace/lua-console.nvim/actions/workflows/test_main.yml/badge.svg?branch=main) ![develop](https://github.com/yarospace/lua-console.nvim/actions/workflows/test_develop.yml/badge.svg?branch=develop) [![LuaRocks](https://img.shields.io/luarocks/v/YaroSpace/lua-console.nvim?logo=lua&color=purple)](https://luarocks.org/modules/YaroSpace/lua-console.nvim)

**lua-console.nvim** - is a REPL / scratch pad / debug console for Neovim. 
Supports Lua natively and can be extended for other languages.

<br/><img src="https://github.com/YaroSpace/assets/blob/main/lua-console.nvim/demo.gif">

## ✨ Features

- Evaluate single line expressions and statements, visually selected lines or characters of code or the whole buffer
- Pretty print Lua objects, including results of assignments, function details and their source paths
- Show normal and error output inline in the console/buffer, including output of `print()`, errors and stacktraces. 
- Syntax highlighting and autocompletion
- Load Neovim’s messages and output of ex commands into console for inspection and copy/paste
- Open links from stacktraces and function sources
- Save / Load / Autosave console session
- Use as a scratch pad for code gists
- Attach code evaluators to any buffer

## 📦 Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "yarospace/lua-console.nvim",
  lazy = true,
  keys = {
    { "`", desc = "Lua-console - toggle" },
    { "<Leader>`", desc = "Lua-console - attach to buffer" },
  },
  opts = {},
}
```
otherwise, install with your favorite package manager and add somewhere in your config:

```lua
require('lua-console').setup { your_custom_options }
``` 

<br>

## ⚙️  Configuration

> [!NOTE]
> All settings are self explanatory, but please read below about [`preserve_context`](#-notes-on-globals-locals-and-preserving-execution-context) option.

Mappings are local to the console, except the ones for toggling the console - `` ` `` and attaching to a buffer - ``<Leader>` ``. 
All mappings can be overridden in your custom config. If you want to delete a mapping - set its value to `false`.

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
    strip_local = true, -- strip `local` from top-level variable declarations
    show_one_line_results = true, -- prints one line results, even if already shown as virtual text
    notify_result = false, -- notify result
    clear_before_eval = false, -- clear output below result prefix before evaluation of the whole buffer
    process_timeout = 2 * 1e5, -- number of instructions to process before timeout
  },
  window = {
    border = 'double', -- single|double|rounded
    height = 0.6, -- percentage of main window
  },
  mappings = {
    toggle = '`', -- toggle console
    attach = '<Leader>`', -- attach console to a buffer
    quit = 'q', -- close console
    eval = '<CR>', -- evaluate code
    eval_buffer = '<S-CR>', -- evaluate whole buffer
    kill_ps = '<Leader>K', -- kill evaluation process
    open = 'gf', -- open link
    messages = 'M', -- load Neovim messages
    save = 'S', -- save session
    load = 'L', -- load session
    resize_up = '<C-Up>', -- resize up
    resize_down = '<C-Down>', -- resize down
    help = '?' -- help
  },
}
```
<!-- config:end -->

</details>

## 🚀 Basic usage (with default mappings)

- Install, press the mapped key `` ` `` and start exploring. 
- Enter code as normal, in insert mode.
- Hit `Enter` in normal mode to evaluate a variable, statement or an expression in the current line. 
- Visually select a region or a range of lines and press `Enter` to evaluate the code in the range or use `<S-Enter>` to evaluate the whole buffer.
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

<br>

## 📓 Notes on globals, locals and preserving execution context

> [!IMPORTANT]
> By default, the option `preserve_context` is on, which means that the execution context is preserved between evaluations. 

All the code executed in the console is evaluated in isolated environment, which means that any global variables that you declare will not be persisted in Neovim's global environment. 
If you purposefully want to alter the global state, use `_G.My_variable = ..`.

The option `preserve_context` implies that variables without `local` will be stored in the console's local context and preserved between executions. 

So, if you first execute `a = 1`, then `a = a + 1` and then `a` - you will get `2`. 

Also, by default, the option `strip_local` is on, which means that `local` modifier is stripped from top-level variable declarations and these variables are also stored in the context.

If you want the context to be cleared before every execution, set `preserve_context = false`.

There are two functions available within the console:

- `_ctx` - will print the contents of the context
- `_ctx_clear()` - clears the context

## ⭐ Extra features

### Attaching code evaluator to other buffers

- The evaluator behind the console can be attached/detached to any buffer by pressing ``<Leader>` `` or executing command `LuaConsole AttachToggle`.
  You will be able to evaluate the code in the buffer as in the console and follow links.  The evaluators and their contexts are isolated for each attached buffer.

### Evaluating other languages

#### Setting up

- It is possible to setup external code executors for other languages.  Evaluators for `ruby`,`racket` and `python` are working out of the box, support for other can be easily added.
- Below is the default configuration, which can be overridden or extended by your custom config, where `default_process_opts` will be 
  replaced by language specific opts, e.g. a possible config for `python` could be:

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

- You can also setup a custom formatter to format the evaluator output before appending results to the console or buffer. Example is in the config.


  #### Usage

- The language evaluator is determined either from (in order of precedence):

  - The code prefix `===lang` on the line above your code snippet, in which case it only applies to the snippet directly below. The prefix can be changed in the config.
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

- Code inside Lua comments will be sytax highlighted.


  ```python
  [[===python
	  list = [1, 3, 5, 7, 9]

	  for val in a:
		  print(list)
  ]]
  ```

<br>

- If you need to kill the evaluation process, press `<Leader>K`.
- You can use `_ex` command to get a reference to the evaluator process, which can be queried for status with `:is_closing()` and stopped with `:kill()`.

## Alternatives and comparison

There are a number of alternatives available, notably:

- [Luapad](https://github.com/rafcamlet/nvim-luapad)
- [Luadev](https://github.com/bfredl/nvim-luadev)
- [SnipRun](https://github.com/michaelb/sniprun)

Lua-console is an attempt to combine the best features of all of them, like REPL / scratch pad / code runner / debug console, while leaving the UX and config simple.

<br>

## 🔥 All feedback and feature requests are very welcome!  Enjoy!
