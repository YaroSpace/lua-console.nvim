local config = require('lua-console.config')
local mappings = require('lua-console.mappings')
local utils = require('lua-console.utils')

Lua_console = { buf = false, win = false, height = 0 }

local set_welcome_message = function()
  local cm = config.mappings
  local message = [[-- Use '%s' to eval a line or selection, '%s' to clear the console, '%s' to load messages, '%s' to save console, '%s' to load console.]]
  message = string.format(message, cm.eval, cm.clear, cm.messages, cm.save, cm.load)

  vim.api.nvim_buf_set_lines(Lua_console.buf, 0, -1, false, { message, '' })
end

local start_lsp = function()
  local lua_ls = require("lspconfig").lua_ls
	local root_dir = function(filename, bufnr)
	  return filename == "/Lua console" and vim.fn.stdpath("config") or lua_ls.config_def.default_config.root_dir(filename, bufnr)
	end

	lua_ls.setup{ root_dir = root_dir }
end

local get_buffer = function()
  local buf = Lua_console.buf
  if buf then return end

  buf = vim.api.nvim_create_buf(false, false)

  vim.api.nvim_buf_set_name(buf, 'Lua console')
  vim.api.nvim_set_option_value("buftype", "nowrite", { buf = buf })

  if config.buffer.lsp then start_lsp() end
  vim.diagnostic.enable(false, { bufnr = buf })
  vim.api.nvim_set_option_value("filetype", "lua", { buf = buf })

  Lua_console.buf = buf

  mappings.set_buf_keymap()
  mappings.set_buf_autocommands()

  set_welcome_message()
  if config.buffer.load_on_start then utils.load_console() end
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

local get_window = function()
  local win = Lua_console.win
  if win then return end

  win = vim.api.nvim_open_win(Lua_console.buf, true, vim.tbl_extend('keep', config.window, get_win_size_pos()))

  local line = vim.api.nvim_buf_line_count(Lua_console.buf) == 1 and 1 or math.max(2, vim.fn.line('.'))
  vim.api.nvim_win_set_cursor(win, { line, 0 })

  Lua_console.win = win
end

local toggle_console = function()
  if Lua_console.buf == vim.fn.bufnr() then
    vim.api.nvim_win_close(Lua_console.win, false)
    Lua_console.win = false
  else
    get_buffer()
    get_window()
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
