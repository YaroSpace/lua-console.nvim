local config = require('lua-console.config')
local mappings = require('lua-console.mappings')
local utils = require('lua-console.utils')

_G.Lua_console = { buf = false, win = false, height = 0 }

local set_welcome_message = function()
  local cm = config.mappings
  local message = [[-- Use '%s' to eval a line or selection, '%s' to clear the console, '%s' to load messages, '%s' to save console, '%s' to load console.]]
  message = string.format(message, cm.eval, cm.clear, cm.messages, cm.save, cm.load)

  vim.api.nvim_buf_set_lines(Lua_console.buf, 0, -1, false, { message, '' })
end

local get_buffer = function()
  --- @type number
  local buf = Lua_console.buf
  if buf and vim.fn.bufloaded(buf) == 1 then return end

  local buf_name = utils.get_plugin_path()..'/console'

  buf = vim.fn.bufnr(buf_name)
  if buf ~= -1 then vim.api.nvim_buf_delete(buf, { force = true }) end

  buf = vim.api.nvim_create_buf(false, false)

  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value('buflisted', false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", 'hide', { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nowrite", { buf = buf })
  vim.api.nvim_buf_set_name(buf, buf_name) -- the name is only needed so the buffer is picked up by Lsp with correct root

  vim.api.nvim_set_option_value("filetype", "lua", { buf = buf })
  vim.diagnostic.enable(false, { bufnr = buf })

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
    height = (Lua_console.height > 0) and Lua_console.height or math.floor(height * config.window.height)
  }
end

local get_window = function()
  local win = vim.api.nvim_open_win(Lua_console.buf, true, vim.tbl_extend('force', config.window, get_win_size_pos()))

  vim.wo[win].foldcolumn = 'auto:9'
  vim.wo[win].cursorline = true
  vim.wo.foldmethod = 'indent'

  local line = vim.api.nvim_buf_line_count(Lua_console.buf) == 1 and 1 or math.max(2, vim.fn.line('.'))
  vim.api.nvim_win_set_cursor(win, { line, 0 })

  Lua_console.win = win
end

local toggle_console = function()
  if Lua_console.win and vim.api.nvim_win_is_valid(Lua_console.win) then
    vim.api.nvim_win_close(Lua_console.win, false)
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
  Lua_console = {}
end

 return {
  toggle_console = toggle_console,
  setup = setup,
  deactivate = deactivate,
}
