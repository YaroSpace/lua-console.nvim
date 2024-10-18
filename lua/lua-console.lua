local config = require('lua-console.config')
local mappings = require('lua-console.mappings')

Lua_console = { buf = false, win = false, height = 0 }


local set_welcome_message = function()
  local message = [[-- Use '%s' to eval a line or selection, '%s' to clear the console, '%s' to load messages, '%s' to save console, '%s' to load console.]]
  message = string.format(message, config.mappings.eval, config.mappings.clear,
    config.mappings.messages, config.mappings.save, config.mappings.load)

  vim.api.nvim_buf_set_lines(Lua_console.buf, 0, -1, false, { message, '' })
end

local start_lsp = function()
  require('lspconfig').lua_ls.setup{ root_dir = function() return vim.fn.stdpath('config') end }
end

local create_buffer = function()
  if Lua_console.buf then return end

  Lua_console.buf = vim.api.nvim_create_buf(false, false)

  vim.api.nvim_buf_set_name(Lua_console.buf, 'Lua console')
  vim.api.nvim_set_option_value("buftype", "nowrite", { buf = Lua_console.buf })
  vim.api.nvim_set_option_value("filetype", "lua", { buf = Lua_console.buf })

  if config.buffer.lsp then start_lsp() end
  vim.diagnostic.enable(false, { bufnr = Lua_console.buf })

  set_welcome_message()
  mappings.set_buf_keymap()
  mappings.set_buf_autocommands()
end

local get_win_size_pos = function()
  local height = vim.api.nvim_list_uis()[1].height
  local width = vim.api.nvim_list_uis()[1].width

  return {
    row = height - 1,
    col = 0,
    width = width - 2,
    height = (Lua_console.height > 0) and Lua_console.height or math.floor(height * 0.5)
  }
end

local create_window = function()
  if Lua_console.win then return end

  Lua_console.win = vim.api.nvim_open_win(Lua_console.buf, true, vim.tbl_extend('keep', config.window, get_win_size_pos()))

  local line = vim.api.nvim_buf_line_count(Lua_console.buf) == 1 and 1 or math.max(2, vim.fn.line('.'))
  vim.api.nvim_win_set_cursor(Lua_console.win, { line, 0 })
end

local toggle_console = function()
  local current_buffer = vim.fn.bufnr()

  create_buffer()
  create_window()

  if Lua_console.buf == current_buffer then
    vim.api.nvim_win_close(Lua_console.win, false)
    Lua_console.win = false
  else
    vim.api.nvim_set_current_win(Lua_console.win)
  end
end

local setup = function(opts)
  config = vim.tbl_extend("force", config, opts or {})

  vim.keymap.set("n", config.mappings.toggle, "", {
    callback = toggle_console,
    desc = "Toggle Lua console"
  })
end

local deactivate = function()
  vim.api.nvim_buf_delete(Lua_console.buf, { force = true } )
end

 return {
  toggle_console = toggle_console,
  setup = setup,
  deactivate = deactivate,
}
