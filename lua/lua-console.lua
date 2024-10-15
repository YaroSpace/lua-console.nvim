local M = {}
local config = require('config')

local append_current_buffer = function(text)
  local line = math.max(vim.fn.line('.'), vim.fn.line('v'))
  vim.api.nvim_buf_set_lines(0, line, line, false, vim.split(config.buffer.prepend_result_with .. text, "\n"))
end

local pretty_print = function(text)
  append_current_buffer(vim.inspect(text))
end

local eval_lua = function(chunk)
  if select(2, chunk:gsub("\n", "")) < 1 then
    chunk = "return " .. chunk
  end

  local env = setmetatable({ print = pretty_print }, { __index = _G })

  local code, error = load(chunk, config.buffer.name, "t", env)
  if error then return error end

  local status, result = xpcall(code, debug.traceback)
  if not status then return result end

  result = type(result) == 'function' and debug.getinfo(result) or result
  return vim.inspect(result)
end

local eval_lua_in_buffer = function()
  local buf  = vim.fn.bufnr()

  if vim.api.nvim_get_mode().mode == "V" then
    vim.api.nvim_input("<Esc>")
  end

  local v_start, v_end = vim.fn.line('.'), vim.fn.line('v')
  if v_start > v_end then
    v_start, v_end = v_end, v_start
  end

  local chunk = vim.api.nvim_buf_get_lines(buf, v_start - 1, v_end, false)
  chunk = table.concat(chunk, "\n")

  append_current_buffer(eval_lua(chunk))
end

local set_welcome_message = function(buf)
  local message = "-- Use '" .. config.mappings.eval .. "' to eval a line or selection, "
  message = message .. "'" .. config.mappings.clear .. "' to clear the console, "
  message = message .. "'" .. config.mappings.messages .. "' to load messages."

  vim.api.nvim_buf_set_lines(buf, 0, 0, false, { message })
  -- vim.api.nvim_buf_add_highlight(buf, -1, 'Comment', 0, 0, -1)
end

local set_buf_keymap = function(buf)
  vim.api.nvim_buf_set_keymap(buf, "n", "<C-Up>", ":resize +5<cr>", { desc = "Resize window" })
  vim.api.nvim_buf_set_keymap(buf, "n", "<C-Down>", ":resize -5<cr>", { desc = "Resize window" })

  vim.api.nvim_buf_set_keymap(buf, "n", "k", "", {
    desc = "Move up",
    callback = function()
      local new_pos = math.max(2, vim.api.nvim_win_get_cursor(0)[1] - 1)
      vim.api.nvim_win_set_cursor(0, { new_pos, 0 })
    end
  })

  vim.api.nvim_buf_set_keymap(buf, "n", config.mappings.clear, "", {
    desc = 'Clear console',
    callback = function() vim.api.nvim_buf_set_lines(0, 1, -1, false, {''}) end
  })

  vim.api.nvim_buf_set_keymap(buf, "n", config.mappings.messages, "", {
    desc = 'Load messages',
    callback = function()
      local messages = vim.api.nvim_exec2('messages', { output = true }).output
      append_current_buffer(messages)
    end
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "gf", "", {
    desc = "Open file in vertical split",
    callback = function()
      local file = vim.fn.expand "<cfile>"
      vim.api.nvim_win_close(0, false)
      vim.cmd("vs " .. file)
    end,
  })

  vim.keymap.set({"n", "v"}, config.mappings.eval, "", {
    buffer = buf,
    desc = "Eval lua code in current line or visual selection",
    callback = eval_lua_in_buffer
  })
end

local set_buf_autocommands = function(buf)
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    desc = "Close window when focus is lost",
    callback = function() vim.api.nvim_win_close(0, false) end
  })
end

local find_or_create_buffer = function()
	local buf = vim.fn.bufnr(config.buffer.name)
	if buf ~= -1 then return buf end

  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, config.buffer.name)
  vim.api.nvim_set_option_value("filetype", "lua", { buf = buf })

  set_welcome_message(buf)
  set_buf_keymap(buf)
  set_buf_autocommands(buf)

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

  return vim.api.nvim_open_win(buf, true, vim.tbl_extend('keep', config.window, get_win_size_pos()))
end

local toggle_console = function()
  local current_buffer = vim.fn.bufnr()
  local buf = find_or_create_buffer()
  local win = find_or_create_window(buf)

  if buf == current_buffer then
    vim.api.nvim_win_close(win, false)
  else
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_win_set_cursor(win, { vim.fn.line('$'), 0 })
  end
end

local setup = function(opts)
  config = vim.tbl_extend("force", config, opts or {})

  vim.keymap.set("n", config.mappings.open, "", {
    callback = toggle_console,
    desc = "Toggle Lua console"
  })
end

local deactivate = function()
  vim.api.nvim_buf_delete(find_or_create_buffer(), { force = true } )
end

M = {
  toggle_console = toggle_console,
  setup = setup,
  deactivate = deactivate,
}

return M
