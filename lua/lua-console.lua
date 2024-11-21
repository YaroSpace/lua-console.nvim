local config, mappings, utils

local get_or_create_buffer = function()
  --- @type number
  local buf = Lua_console.buf
  if buf and vim.fn.bufloaded(buf) == 1 then return buf end

  local buf_name = utils.get_plugin_path() .. '/console'

  buf = vim.fn.bufnr(buf_name)
  if buf ~= -1 then vim.api.nvim_buf_delete(buf, { force = true }) end

  buf = vim.api.nvim_create_buf(false, false)

  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].buftype = 'nowrite'

  vim.api.nvim_buf_set_name(buf, buf_name) -- the name is only needed so the buffer is picked up by Lsp with correct root

  vim.api.nvim_set_option_value('filetype', 'lua', { buf = buf })
  vim.diagnostic.enable(false, { bufnr = buf })

  mappings.set_buf_keymap(buf)
  mappings.set_buf_autocommands(buf)

  if config.buffer.load_on_start then utils.load_saved_console(buf) end
  utils.toggle_help(buf)

  Lua_console.buf = buf
  return buf
end

local get_win_size_pos = function()
  local height = vim.o.lines
  local width = vim.o.columns

  return {
    row = height - 1,
    col = 0,
    width = width - 2,
    height = (Lua_console.height > 0) and Lua_console.height or math.floor(height * config.window.height)
  }
end

local create_window = function(buf)
  local win_config = vim.tbl_extend('force', config.window, get_win_size_pos())
  local win = vim.api.nvim_open_win(buf, true, win_config)

  vim.wo[win].foldcolumn = 'auto:9'
  vim.wo[win].cursorline = true
  vim.wo[win].foldmethod = 'indent'
  vim.wo[win].winbar = ''

  Lua_console.win = win
  return win
end

local toggle_console = function()
  if Lua_console.win and vim.api.nvim_win_is_valid(Lua_console.win) then
    vim.api.nvim_win_close(Lua_console.win, false)
    Lua_console.win = false
  else
    local buf = get_or_create_buffer()
    create_window(buf)
  end
end

local setup = function(opts)
  _G.Lua_console = { buf = false, win = false, height = 0 }

  config = require("lua-console.config").setup(opts)
  mappings = require("lua-console.mappings")
  utils = require("lua-console.utils")

  vim.keymap.set("n", config.mappings.toggle, "", {
    callback = toggle_console,
    desc = "Toggle Lua console"
  })

  return config
end

local deactivate = function()
  if Lua_console and vim.api.nvim_buf_is_valid(Lua_console.buf or -1) then
    vim.api.nvim_buf_delete(Lua_console.buf, { force = true } )
  end

  Lua_console = nil --luacheck: ignore

	package.loaded['lua-console'] = nil
	package.loaded['lua-console.config'] = nil
	package.loaded['lua-console.mappings'] = nil
	package.loaded['lua-console.utils'] = nil
end

 return {
  toggle_console = toggle_console,
  setup = setup,
  deactivate = deactivate,
}
