local config = require('lua-console.config')

local to_string = function(tbl)
  return table.concat(tbl or {}, '\n')
end

local to_table = function(str)
  return vim.split(str or '', '\n', { trimempty = true })
end

local pack = function(...)
  return { ... }
end

local show_virtual_text = function(buf, id, text, line, position, highlight)
  local ns = vim.api.nvim_create_namespace('Lua-console')
  local ext_mark = vim.api.nvim_buf_get_extmark_by_id(0, ns, id, {})

  if #ext_mark > 0 then vim.api.nvim_buf_del_extmark(0, ns, id) end

  vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
    id = id,
    virt_text = { { text, highlight } },
    virt_text_pos = position,
    virt_text_hide = true,
    undo_restore = false,
    invalidate = true
  })
end

local toggle_help = function(buf)
  local cm = config.mappings
  local ns = vim.api.nvim_create_namespace('Lua-console')
  local ids = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
  local message

  if #ids == 0 or ids[1][1] == 2 then
    vim.api.nvim_buf_del_extmark(buf, ns, 2)

    message = cm.help .. ' - help  '
    show_virtual_text(buf, 1, message, 0, 'right_align', 'Comment')
  elseif ids[1][1] == 1 then
    vim.api.nvim_buf_del_extmark(buf, ns, 1)

    message = [['%s' - eval a line or selection, '%s' - clear the console, '%s' - load messages, '%s' - save console, '%s' - load console, '%s'/'%s - resize window, '%s' - toggle help]]
    message = string.format(message, cm.eval, cm.clear, cm.messages, cm.save, cm.load, cm.resize_up, cm.resize_down, cm.help)

    local visible_line = vim.fn.line('w0')
    show_virtual_text(buf, 2, message, visible_line - 1, 'overlay', 'Comment')
  end
end

---Loads saved console
---@param buf number
local load_saved_console = function(buf)
  if vim.fn.filereadable(config.buffer.save_path) == 0 then return end

  local file = vim.fn.readfile(config.buffer.save_path)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, file)
end

local infer_truncated_path = function(truncated_path)
  local path = truncated_path:match('^.*/(lua/.+)$')
  local found = vim.api.nvim_get_runtime_file(path, false)

  return #found > 0 and found[1] or truncated_path
end

--Gets the line number for a function in debug info
local get_source_lnum = function()
  local lnum, cnum = vim.fn.line('.'), vim.fn.col('.')
  local line = vim.fn.getline(lnum)

  local dnum = line:match(":(%d+)", cnum)
  if dnum then return tonumber(dnum) end

  line = vim.fn.getline(lnum - 5)
  if #line == 0 then return 1 end

  lnum = line:match('(%d+),$')
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
  local buf = vim.fn.bufnr()
  local lnum = math.max(vim.fn.line('.'), vim.fn.line('v'))

  lines[1] = config.buffer.prepend_result_with .. lines[1]

  if #lines == 1 and lines[1]:find('nil') then
    show_virtual_text(buf, 3, lines[1], lnum - 1, 'eol', 'Comment')
    return
  end

  table.insert(lines, 1, '') -- insert an empty line
  vim.api.nvim_buf_set_lines(buf, lnum, lnum, false, lines)
end

---Pretty prints objects
---@param ... any[]
local pretty_print = function(...)
  local result, var_no = '', ''
  local nargs = select('#', ...)

  for i = 1, nargs do
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

local function trim_empty_lines(tbl)
  if #tbl == 0 then return tbl end

  if vim.trim(tbl[#tbl] or '') == '' then table.remove(tbl, #tbl) end
  if vim.trim(tbl[1] or '') == '' then table.remove(tbl, 1) end

  return tbl
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

local get_ctx = function(buf)
  buf = buf or vim.fn.bufnr()
  local status, ctx = pcall(vim.api.nvim_buf_get_var, buf, 'ctx')

  if config.buffer.preserve_context and status and ctx then
    local ctx_mt = vim.api.nvim_buf_get_var(buf, 'ctx_mt')
    return setmetatable(ctx, ctx_mt)
  end

  local env, mt = {}, {}

  mt = {
    print = pretty_print,
    _ctx = function()
      return vim.api.nvim_buf_get_var(buf, 'ctx')
    end,
    _ctx_clear = function()
      vim.api.nvim_buf_set_var(buf, 'ctx', nil)
    end,
    __index = function(_, key)
      return mt[key] and mt[key] or _G[key]
    end
  }

  vim.api.nvim_buf_set_var(buf, 'ctx', {})
  vim.api.nvim_buf_set_var(buf, 'ctx_mt', mt)
  return setmetatable(env, mt)
end

--- Evaluates Lua code and returns pretty printed result with errors if any
--- @param lines string[] table with lines of Lua code
--- @param ctx table environment to execute code in
--- @return string[]
local eval_lua = function(lines, ctx)
  vim.validate({ lines = { lines, 'table'} })

  local lines_with_return = add_return(lines)
  local env = ctx or get_ctx()

  if not select(2, load(to_string(lines_with_return), '', 't', env)) then
    lines = lines_with_return
  end

  local code, error = load(to_string(lines), 'Lua console: ', "t", env)
  if error then return to_table(error) end

	print_buffer = {}

  ---@cast code function
  local result = pack(xpcall(code, debug.traceback))
  vim.api.nvim_buf_set_var(vim.fn.bufnr(), 'ctx', env)

  if result[1] then
    table.remove(result, 1)
    if #result > 0 then pretty_print(unpack(result))
    else pretty_print(nil) end
  else
    vim.list_extend(print_buffer, clean_stacktrace(result[2]))
  end

  return print_buffer
end

local get_external_evaluator = function(lang)
  local eval_config = config.external_evaluators[lang]
  if not (eval_config and eval_config.cmd) then
    vim.notify(string.format("No external evaluator for language '%s' found", lang), vim.log.levels.WARN)
    return
  end

  local job_opts = {
    env = eval_config.env or { EMPTY = '' },
	  on_stdout = function(_, ret, _)
      ret = trim_empty_lines(ret or {})
	    if #ret == 0 then return end

	    local formatter = eval_config.formatter
	    if formatter and type(formatter) == 'function' then
	      ret = formatter(ret)
	    end
	    append_current_buffer(ret)
	  end,

	  on_stderr = function(_, ret, _)
      ret = trim_empty_lines(ret or {})
	    if #ret > 0 then append_current_buffer(ret) end
	  end,

    on_exit = function() end,
	  stderr_buffered = true,
	  stdout_buffered = true,
  }

  return function(lines)
    local code = eval_config.prepend_code .. ' ' .. to_string(lines)
    local cmd = eval_config.cmd

    vim.list_extend(cmd, { code })
    vim.fn.jobstart(cmd, job_opts)

    return {}
  end
end

local get_evaluator = function(buf, lines)
  local evaluator
  local lang = lines[1]:match("```(.+)")

  if lang then table.remove(lines, 1) end
  lang = lang and lang or vim.bo[buf].filetype

  if lang == '' then
    vim.notify('Plese specify the language to evaluate', vim.log.levels.WARN)
    return
  end

  if lang == 'lua' then
    evaluator = eval_lua
  else
    evaluator = get_external_evaluator(lang)
  end

  return evaluator
end

---Evaluates code in the current line or visual selection and appends to current buffer
local eval_code_in_buffer = function()
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
  if #lines == 0 then return end

  local evaluator = get_evaluator(buf, lines)
  if not evaluator then return end

  local result = evaluator(lines)
  if #result == 0 then return end

  append_current_buffer(result)
end

---Load messages into console
local load_messages = function()
	local ns = vim.api.nvim_create_namespace('Lua-console')

	---This way we catch the output of messages command, in case it was overriden by some other plugin, like Noice
	vim.ui_attach(ns, { ext_messages = true }, function(event, entries) ---@diagnostic disable-line
		if event ~= "msg_history_show" then return end
    local messages = vim.tbl_map(function(e) return e[2][1][2] end, entries)
	  if #messages > 0 then append_current_buffer(messages) end
	end)

	vim.cmd.messages()
	vim.ui_detach(ns)
end

local get_plugin_path = function()
  local path = debug.getinfo(1, 'S').source:sub(2)
  return vim.fs.root(path, '.git')
end

return {
  toggle_help = toggle_help,
  load_saved_console = load_saved_console,
  append_current_buffer = append_current_buffer,
  eval_lua = eval_lua,
  eval_code_in_buffer = eval_code_in_buffer,
  get_plugin_path = get_plugin_path,
  load_messages = load_messages,
  get_path_lnum = get_path_lnum
}
