local config = require('lua-console.config')

local to_string = function(tbl)
  return table.concat(tbl or {}, '\n')
end

local to_table = function(str)
  return vim.split(str or '', '\n', { trimempty = true })
end

local pack = function(...)
  local ret = {}
  for i = 1, select("#", ...) do
    local el = select(i, ...)
    table.insert(ret, el)
  end

  return ret
end

local show_virtual_text = function(id, text, line, position, highlight)
  local ns = vim.api.nvim_create_namespace('Lua-console')
  vim.api.nvim_buf_set_extmark(Lua_console.buf, ns, line, 0, {
    id = id,
    virt_text = { { text, highlight } },
    virt_text_pos = position,
    virt_text_hide = true,
    undo_restore = false,
    invalidate = true
  })
end

local toggle_help = function()
  local buf = Lua_console.buf or 0
  local cm = config.mappings
  local ns = vim.api.nvim_create_namespace('Lua-console')
  local ids = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
  local message

  if vim.tbl_isempty(ids) or ids[1][1] == 2 then
    vim.api.nvim_buf_del_extmark(buf, ns, 2)

    message = cm.help .. ' - help  '
    show_virtual_text(1, message, 0, 'right_align', 'Comment')
  elseif ids[1][1] == 1 then
    vim.api.nvim_buf_del_extmark(buf, ns, 1)

    message = [['%s' - eval a line or selection, '%s' - clear the console, '%s' - load messages, '%s' - save console, '%s' - load console, '%s'/'%s - resize window, '%s' - toggle help]]
    message = string.format(message, cm.eval, cm.clear, cm.messages, cm.save, cm.load, cm.resize_up, cm.resize_down, cm.help)

    show_virtual_text(2, message, 0, 'overlay', 'Comment')
  end
end

---Loads saved console
---@param on_start boolean
local load_console = function(on_start)
  if on_start == false then return end

  if vim.fn.filereadable(config.buffer.save_path) == 0 then return end

  local file = vim.fn.readfile(config.buffer.save_path)
  vim.api.nvim_buf_set_lines(Lua_console.buf, 0, -1, false, file)

  if not on_start then toggle_help() end
end

local infer_truncated_path = function(truncated_path)
  local path = truncated_path:match('.+/(lua/.+)')
  local found = vim.api.nvim_get_runtime_file(path, false)

  return #found > 0 and found[1] or truncated_path
end

--Gets the line number for a function in debug info
local get_source_lnum = function()
  local cursor = vim.api.nvim_win_get_cursor(Lua_console.win)
  local cur_line_no = cursor[1]
  local cur_line = vim.fn.getline(cur_line_no)

  local lnum = cur_line:match(":(%d+)", cursor[2])
  if lnum then return tonumber(lnum) end

  local lines = vim.api.nvim_buf_get_lines(Lua_console.buf, cur_line_no - 6, cur_line_no, false)
  if vim.tbl_isempty(lines) then return 1 end

  lnum = lines[1]:match('(%d+),$')
  return lnum and tonumber(lnum) or 1
end

local get_path_lnum = function(path)
  local lnum = get_source_lnum()
  lnum = math.max(1, lnum)

  if path:find("^%.%.%.") then
    path = infer_truncated_path(path)
  end

  return path, lnum
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

local get_ctx = function()
  if config.buffer.preserve_context and Lua_console.ctx then return Lua_console.ctx end
  local env, mt = {}, {}

  mt = {
    print = pretty_print,
    _ctx = function()
      local ctx = {}
      ctx = vim.tbl_extend('force', ctx, env)
      return ctx
    end,
    _ctx_clear = function()
      Lua_console.ctx = nil
    end,
    __index = function(_, key)
      return mt[key] and mt[key] or _G[key]
    end
  }

  Lua_console.ctx = env
  return setmetatable(env, mt)
end

--- Evaluates Lua code and returns pretty printed result with errors if any
--- @param lines string[] table with lines of Lua code
--- @return string[]
local eval_lua = function(lines)
  vim.validate({ lines = { lines, 'table'} })

  lines = remove_empty_lines(lines)
  if vim.tbl_isempty(lines) then return {} end

  local lines_with_return = add_return(lines)
  local env = get_ctx()

  if not select(2, load(to_string(lines_with_return), '', 't', env)) then
    lines = lines_with_return
  end

  local code, error = load(to_string(lines), 'Lua console: ', "t", env)
  if error then return to_table(error) end

	print_buffer = {}

  ---@cast code function
  local result = pack(xpcall(code, debug.traceback))
  if result[1] then
    table.remove(result, 1)
    if #result > 0 then pretty_print(unpack(result))
    else pretty_print(nil) end
  else
    vim.list_extend(print_buffer, clean_stacktrace(result[2]))
  end

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

  if #result == 0 then return end

  if #result == 1 and result[1]:find('nil') then
    local text = '  ' .. config.buffer.prepend_result_with .. result[1]
    show_virtual_text(nil, text, v_end - 1, 'eol', 'Comment')
  else append_current_buffer(result) end
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
  get_path_lnum = get_path_lnum
}
