local config = require('lua-console.config')

local to_string = function(tbl)
  return table.concat(tbl or {}, '\n')
end

local to_table = function(str)
  return vim.split(str or '', '\n', { trimempty = true })
end

local toggle_help = function()
  local ns = vim.api.nvim_create_namespace('Lua-console')
  local ids = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})

  if not vim.tbl_isempty(ids) then
    vim.api.nvim_buf_del_extmark(0, ns, ids[1][1])
    return
  end
  
  local cm = config.mappings
  local message = [['%s' - eval a line or selection, '%s' - clear the console, '%s' - load messages, '%s' - save console, '%s' - load console, '%s'/'%s - resize window, '%s' - toggle help]]
  message = string.format(message, cm.eval, cm.clear, cm.messages, cm.save, cm.load, cm.resize_up, cm.resize_down, cm.help)

  vim.api.nvim_buf_set_extmark(0, ns, 0, 0, { id=1, virt_text = { { message, 'Comment' } }, virt_text_pos = 'overlay', undo_restore = false, invalidate = true })
end

---Loads saved console
local load_console = function()
  if vim.fn.filereadable(config.buffer.save_path) == 0 then return end
  local file = vim.fn.readfile(config.buffer.save_path)
  vim.api.nvim_buf_set_lines(Lua_console.buf, 0, -1, false, file)
end

--Gets the line number for a function in debug info
local get_source_lnum = function()
  local cur_line = vim.api.nvim_win_get_cursor(Lua_console.win)[1]
  local lines = vim.api.nvim_buf_get_lines(Lua_console.buf, cur_line - 6, cur_line, false)
  return tonumber(lines[1]:match('(%d+),$'))
end

local print_buffer = {}

---@param lines string[] Text to append to buffer after current selection
local append_current_buffer = function(lines)
  local line = math.max(vim.fn.line('.'), vim.fn.line('v'))

  lines[1] = config.buffer.prepend_result_with .. lines[1]
  table.insert(lines, 1, '') -- insert an empty line

  vim.api.nvim_buf_set_lines(Lua_console.buf, line, line, false, lines)
end

---Pretty prints objects
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
  end

  vim.list_extend(print_buffer, to_table(result))
  return result
end

local function remove_empty_lines(tbl)
  return vim.tbl_filter(function(el) return vim.fn.trim(el) ~= '' end, tbl)
end

--- Remove the stacktrace preceeding the call from lua-console
local function clean_stacktrace(error)
  local lines = to_table(error)

  for i = #lines, 1, -1 do
    if lines[i]:find('lua-console.nvim', 1, true) then
      table.remove(lines, i)
      if lines[i-1]:find("[C]: in function 'xpcall'", 1, true) then
        table.remove(lines, i - 1)
        break
      end
    else
      table.remove(lines, i)
    end
  end

  return lines
end

local function add_return(tbl)
  if vim.fn.trim(tbl[#tbl]) == 'end' then return tbl end

  local ret = vim.deepcopy(tbl)
  ret[#ret] = 'return ' .. ret[#ret]

  return ret
end

--- Evaluates Lua code and returns pretty printed result with errors if any
--- @param lines string[] table with lines of Lua code
--- @return string[]
local eval_lua = function(lines)
  vim.validate({ lines = { lines, 'table'} })

  lines = remove_empty_lines(lines)
  if vim.tbl_isempty(lines) then return {} end

  local env = setmetatable({ print = pretty_print }, { __index = _G })
  local lines_with_return = add_return(lines)

  if not select(2, load(to_string(lines_with_return), '', 't', env)) then
    lines = lines_with_return
  end

  local code, error = load(to_string(lines), 'Lua console: ', "t", env)
  if error then return to_table(error) end

	print_buffer = {}

  ---@cast code function
  local status, result = xpcall(code, debug.traceback)
  if not status then return clean_stacktrace(result) end

  pretty_print(result)
  return print_buffer
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
  local result = eval_lua(lines)

  if not vim.tbl_isempty(result) then append_current_buffer(result) end
end

---Load messages into console
local load_messages = function()
	local ns = vim.api.nvim_create_namespace('Lua-console')

	---This way we catch the output of messages command, in case it was overriden by some other plugin, like Noice
	vim.ui_attach(ns, { ext_messages = true }, function(event, entries) ---@diagnostic disable-line
		if event ~= "msg_history_show" then return end
    local messages = vim.tbl_map(function(e) return e[2][1][2] end, entries)
	  if not vim.tbl_isempty(messages) then append_current_buffer(messages) end
	end)

	vim.cmd.messages()
	vim.ui_detach(ns)
end

local get_plugin_path = function()
  local path = debug.getinfo(1, 'S').source
  local _, pos = path:find('lua%-console.nvim')

  return path:sub(2,pos)
end

return {
  toggle_help = toggle_help,
  load_console = load_console,
  append_current_buffer = append_current_buffer,
  eval_lua = eval_lua,
  eval_lua_in_buffer = eval_lua_in_buffer,
  get_plugin_path = get_plugin_path,
  load_messages = load_messages,
  get_source_lnum = get_source_lnum,
}
