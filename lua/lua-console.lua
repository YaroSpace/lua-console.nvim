local config = require('lua-console.config')
local mappings = require('lua-console.mappings')

local set_welcome_message = function(buf)
  local message = [[-- Use '%s' to eval a line or selection, '%s' to clear the console, '%s' to load messages, '%s' to save console, '%s' to load console.]]
  message = string.format(message, config.mappings.eval, config.mappings.clear,
    config.mappings.messages, config.mappings.save, config.mappings.load)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { message, '' })
end

local find_or_create_buffer = function()
	local buf = vim.fn.bufnr(config.buffer.name)
	if buf ~= -1 then return buf end

  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, config.buffer.name)
  vim.api.nvim_set_option_value("filetype", "lua", { buf = buf })

  set_welcome_message(buf)
  mappings.set_buf_keymap(buf)
  mappings.set_buf_autocommands(buf)

  return buf
end

local get_win_size_pos = function()
    local height = vim.api.nvim_list_uis()[1].height
    local width = vim.api.nvim_list_uis()[1].width

    return {
      row = height - 1,
      col = 0,
      width = width - 2,
      height = math.floor(height * 0.5),
    }
end

local find_or_create_window = function(buf)
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 then return win end

  win = vim.api.nvim_open_win(buf, true, vim.tbl_extend('keep', config.window, get_win_size_pos()))

  local line = vim.api.nvim_buf_line_count(buf) == 1 and 1 or math.max(2, vim.fn.line('.'))
  vim.api.nvim_win_set_cursor(win, { line, 0 })

  return win
end

local toggle_console = function()
  local current_buffer = vim.fn.bufnr()
  local buf = find_or_create_buffer()
  local win = find_or_create_window(buf)

  if buf == current_buffer then
    vim.api.nvim_win_close(win, false)
  else
    vim.api.nvim_set_current_win(win)
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
  vim.api.nvim_buf_delete(find_or_create_buffer(), { force = true } )
end

 return {
  toggle_console = toggle_console,
  setup = setup,
  deactivate = deactivate,
}
