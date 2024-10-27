local config = require('lua-console.config')

---Loads saved console
local load_console = function()
  if vim.fn.filereadable(config.buffer.save_path) == 0 then return end

  local file = vim.fn.readfile(config.buffer.save_path)
  vim.api.nvim_buf_set_lines(Lua_console.buf, 0, -1, false, file)
end

--Gets the line number in debug info for a function
local get_file_line = function()
  local cur_line = vim.api.nvim_win_get_cursor(Lua_console.win)[1]
  local lines = vim.api.nvim_buf_get_lines(Lua_console.buf, cur_line - 6, cur_line, false)
  return tonumber(lines[1]:match('(%d+),$'))
end

local line_offset

---@param text string Text to append to buffer
local append_current_buffer = function(text)
  local line = math.max(vim.fn.line('.'), vim.fn.line('v'))

  if line_offset == 0 then
    vim.api.nvim_buf_set_lines(Lua_console.buf, line, line, false, {''})
    line_offset = 1
  end

  --- @diagnostic disable-next-line
  text = vim.split(config.buffer.prepend_result_with .. text, '\n')
  vim.api.nvim_buf_set_lines(Lua_console.buf, line + line_offset, line + line_offset, false, text)
end

---Appends pretty printed text to current buffer
---@param ... any[]
local pretty_print = function(...)
  local result, var_no = '', ''
  local nargs = select('#', ...)

  for i=1, nargs do
    local o = select(i, ...)

    if i > 1 then result = result .. ', ' end
    if nargs > 1 then var_no = string.format('[%s] ', i) end

    o = type(o) == 'function' and debug.getinfo(o) or o
    result = result .. var_no .. vim.inspect(o)

    i = i + 1
  end

  append_current_buffer(result)
  line_offset = line_offset + 1
end

local function remove_empty_lines(tbl)
  return vim.tbl_filter(function(el) return vim.fn.trim(el) ~= '' end, tbl)
end

local function format_error(error)
  local lines = vim.split(error, '\n', { trimempty = true })

  for i = #lines, 1, -1 do
    if lines[i]:find('lua-console.nvim', 1, true) or lines[i]:find("[C]: in function 'xpcall'", 1, true) then
      table.remove(lines, i)
    else
      break
    end
  end

  return table.concat(lines, '\n')
end

local function add_return(tbl)
  if vim.fn.trim(tbl[#tbl]) == 'end' then return tbl end

  local ret = vim.deepcopy(tbl)
  table.insert(ret, 'return ' .. table.remove(ret))
  return ret
end

--- Evaluates Lua code and returns pretty printed result with errors if any
--- @param lines string[] String with Lua code
local eval_lua = function(lines)
  local env = setmetatable({ print = pretty_print }, { __index = _G })
  local lines_with_return = add_return(lines)

  if not select(2, load(table.concat(lines_with_return, '\n'), '', 't', env)) then
    lines = lines_with_return
  end

  local code, error = load(table.concat(lines, '\n'), 'Lua console: ', "t", env)
  if error then return error end

  line_offset = 0
  ---@cast code function
  local status, result = xpcall(code, debug.traceback)
  if not status then return format_error(result) end

  result = type(result) == 'function' and debug.getinfo(result) or result
  return vim.inspect(result)
end

---Evaluates lua in the current line or visual selections and appends to current buffer
local eval_lua_in_buffer = function()
  local buf  = vim.fn.bufnr()

  if vim.api.nvim_get_mode().mode == "V" then
    vim.api.nvim_input("<Esc>")
  end

  local v_start, v_end = vim.fn.line('.'), vim.fn.line('v')
  if v_start > v_end then
    v_start, v_end = v_end, v_start
  end

  local lines = vim.api.nvim_buf_get_lines(buf, v_start - 1, v_end, false)
  lines = remove_empty_lines(lines)

  if not vim.tbl_isempty(lines) then append_current_buffer(eval_lua(lines)) end
end

---Load messages into console
local load_messages = function()
	local ns = vim.api.nvim_create_namespace('Lua-console')
  local messages = {}

	---This way we catch the output of messages command, in case it was overriden by some other plugin, like Noice
	vim.ui_attach(ns, { ext_messages = true }, function(event, entries)
		if event ~= "msg_history_show" then return end
    messages = vim.tbl_map(function(e) return e[2][1][2] end, entries)
	end)

	vim.cmd.messages()
	append_current_buffer(table.concat(messages, '\n'))

	vim.ui_detach(ns)
end

local get_plugin_path = function()
  local path = debug.getinfo(1, 'S').source
  local _, pos = path:find('lua%-console.nvim')

  return path:sub(2,pos)
end

---@return table<string, any> locals Table of local variables and their values
local get_locals = function()
  local i, locals = 1, {}
  while true do
    local name, value = debug.getlocal(2, i)

    if name then locals[name] = value
    else break end

    i = i +1
  end

  return locals
end

return {
  load_console = load_console,
  append_current_buffer = append_current_buffer,
  eval_lua = eval_lua,
  eval_lua_in_buffer = eval_lua_in_buffer,
  get_locals = get_locals,
  get_plugin_path = get_plugin_path,
  load_messages = load_messages,
  get_file_line = get_file_line
}
