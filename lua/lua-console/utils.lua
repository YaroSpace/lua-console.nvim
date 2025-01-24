local config = require('lua-console.config')
local get_ctx, lua_evaluator

local to_string = function(tbl, sep, trim)
  tbl = tbl or {}
  sep = sep or '\n'

  if type(tbl) ~= 'table' then tbl = { tbl } end

  local line = table.concat(tbl, sep)
  local patterns = { '\\r', '\\t', '\\n' }

  if trim then
    for _, pat in ipairs(patterns) do
      line = line:gsub(pat, '')
    end
    -- compact strings by removing redundant spaces
    line = line:gsub('(["\'])%s+', '%1'):gsub('%s+(["\'])', '%1'):gsub('%s%s+', ' ')
  end

  return line
end

---@param obj string|string[]
---@return string[]
local to_table = function(obj)
  obj = type(obj) == 'string' and { obj } or obj

  return vim.iter(obj):map(function(line)
    return vim.split(line or '', '\n', { trimempty = true })
  end):flatten():totable()
end

local function remove_indentation(tbl)
  local indent = tbl[1]:match('(%s*)%w') or tbl[1]:match('(\t*)%w')
  return vim.tbl_map(function(line)
    return line:sub(#indent + 1)
  end, tbl)
end

---Shows virtual text in the buffer
---@param buf number buffer
---@param id number namespace id
---@param text string text to show
---@param lnum number line number
---@param position string virtual text position
---@param highlight string higlight group
local show_virtual_text = function(buf, id, text, lnum, position, highlight)
  local ns = vim.api.nvim_create_namespace('Lua-console')
  local ext_mark = vim.api.nvim_buf_get_extmark_by_id(0, ns, id, {})

  if #ext_mark > 0 then vim.api.nvim_buf_del_extmark(0, ns, id) end

  vim.api.nvim_buf_set_extmark(buf, ns, lnum, 0, {
    id = id,
    virt_text = { { text, highlight } },
    virt_text_pos = position,
    virt_text_hide = true,
    undo_restore = false,
    invalidate = true,
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

    message =
      [[%s - eval a line or selection, %s - eval buffer, %s - open file, %s - load messages, %s - save console, %s - load console, %s/%s - resize window, %s - toggle help]]
    message =
      string.format(message, cm.eval, cm.eval_buffer, cm.open, cm.messages, cm.save, cm.load, cm.resize_up, cm.resize_down, cm.help)

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

  local dnum = line:match(':(%d+)', cnum)
  if dnum then return tonumber(dnum) end

  line = vim.fn.getline(lnum - 5)
  if #line == 0 then return 1 end

  lnum = line:match('(%d+),$')
  return lnum and tonumber(lnum) or 1
end

local get_path_lnum = function(path)
  local lnum = get_source_lnum()
  lnum = math.max(1, lnum)

  if path:find('^%.%.%.') then path = infer_truncated_path(path) end

  return path, lnum
end

---Determines if there is an assigment on the line and returns its value
---@param line string[]
local get_assignment = function(line)
  if not line or #line == 0 then return end

  local lhs = line[1]:match('^(.-)%s*=')
  local ret

  if lhs then
    ret = lua_evaluator { lhs }
    local is_error = ret[1]:find('[string "Lua console: "]', 1, true) -- means we could not evaluate the lhs
    return not is_error and to_string(ret, '', true) or nil
  end
end

local print_buffer = {}

---@param buf number
---@param lines string[] Text to append to current buffer after current selection
local append_current_buffer = function(buf, lines)
  if not lines or #lines == 0 then return end

  local lnum = vim.fn.line('.')
  local prefix = config.buffer.result_prefix
  local empty_results = { 'nil', '', '""', "''" }

  local virtual_text
  local line = lines[#lines]

  if vim.tbl_contains(empty_results, line) then
    table.remove(lines)
    virtual_text = line
  end

  local assignment_value = get_assignment(vim.fn.getbufline(buf, lnum, lnum))
  if assignment_value ~= nil then virtual_text = assignment_value end

  if virtual_text then show_virtual_text(buf, 3, prefix .. virtual_text, lnum - 1, 'eol', 'Comment') end

  if #lines == 0 then return end

  lines[1] = prefix .. lines[1]
  table.insert(lines, 1, '') -- insert an empty line

  vim.api.nvim_buf_set_lines(buf, lnum, lnum, false, lines)
end

---Pretty prints objects and appends to print_buffer
---@param ... any[]
---@return string[]
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

  result = to_table(result)
  vim.list_extend(print_buffer, result)

  -- return result
end

local function remove_empty_lines(tbl)
  return vim.tbl_filter(function(el)
    return vim.fn.trim(el) ~= ''
  end, tbl)
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
      if lines[i - 1]:find("[C]: in function 'xpcall'", 1, true) then
        table.remove(lines, i - 1)
        break
      end
    else
      table.remove(lines, i)
    end
  end

  return lines
end

local function add_return(tbl, lnum)
  if to_string(tbl[lnum], '', true):match('^%s*end') then return tbl end

  local ret = vim.deepcopy(tbl)
  ret[lnum] = 'return ' .. ret[lnum]

  return ret
end

function get_ctx(buf)
  buf = buf or vim.fn.bufnr()

  local lc = _G.Lua_console
  lc.ctx = lc.ctx or {}

  local ctx = lc.ctx[buf]
  if config.buffer.preserve_context and ctx then return ctx end

  local env, mt = {}, {}

  mt = {
    print = pretty_print,
    _ctx = function()
      return vim.tbl_extend('force', {}, env)
    end,
    _ctx_clear = function()
      lc.ctx[buf] = nil
    end,
    __index = function(_, key)
      return mt[key] and mt[key] or _G[key]
    end,
  }

  lc.ctx[buf] = env
  return setmetatable(env, mt)
end

--- Evaluates Lua code and returns pretty printed result with errors if any
--- @param lines string[] table with lines of Lua code
--- @param ctx? table environment to execute code in
--- @return string[]
function lua_evaluator(lines, ctx)
  vim.validate { lines = { lines, 'table' } }

  local env = ctx or get_ctx()
  env._reset_last_assignment()

  local lines_with_return_first_line = add_return(lines, 1)
  local lines_with_return_last_line = add_return(lines, #lines)

  if not select(2, load(to_string(lines_with_return_first_line), '', 't', env)) then
      lines = lines_with_return_first_line
  elseif not select(2, load(to_string(lines_with_return_last_line), '', 't', env)) then
    lines = lines_with_return_last_line
  end

  local code, error = load(to_string(lines), 'Lua console: ', 't', env)
  if error then return to_table(error) end

  print_buffer = {}

  ---@cast code function
  local result = { xpcall(code, debug.traceback) }
  local status, err = result[1], result[2]

  if status then
    table.remove(result, 1)

    if #result > 0 then
      print_to_buffer(unpack(result))
    else
      print_to_buffer(nil)
    end
  else
    vim.list_extend(print_buffer, clean_stacktrace(err))
  end

  return print_buffer
end

local function process_external_result(buf, ret, lang_config)
  ret = to_table(ret)
  ret = trim_empty_lines(ret)

  if #ret == 0 then return end

  local formatter = lang_config.formatter
  if formatter then ret = formatter(ret) end

  append_current_buffer(buf, ret)
end

---Returns default handler for processing external evaluator's output
---@param buf number
---@param _ string 'out|err'
---@param lang_config table
---@return function function(err, result)
local function default_handler(buf, _, lang_config)
  return function(_, ret)
    if not ret then return end

    vim.schedule(function()
      process_external_result(buf, ret, lang_config)
    end)
  end
end

---Gets external evaluator for requested language
---@param lang string
---@return function|nil evaluator function(lines:string[]):string[]
local get_external_evaluator = function(buf, lang)
  local eval_config = config.external_evaluators
  local lang_config = eval_config[lang]

  if not (lang_config and lang_config.cmd) then
    vim.notify(string.format("No external evaluator for language '%s' found", lang), vim.log.levels.WARN)
    return
  end

  local opts = vim.tbl_extend('force', {}, eval_config.default_process_opts)
  opts = vim.tbl_extend('force', opts, lang_config)

  opts.stdout = opts.stdout or default_handler(buf, 'out', lang_config)
  opts.stderr = opts.stderr or default_handler(buf, 'err', lang_config)
  opts.on_exit = opts.on_exit or function() end

  return function(lines)
    local cmd = vim.tbl_extend('force', {}, lang_config.cmd)
    local code = (lang_config.code_prefix or '') .. to_string(remove_indentation(lines)) -- some languages, like python are concerned with indentation
    table.insert(cmd, code)

    local status, id = pcall(vim.system, cmd, opts, opts.on_exit)
    if not status then
      vim.notify(('Could not run external evaluator for lang: %s.  Error: %s'):format(lang, id), vim.log.levels.ERROR)
    end

    return {}, id
  end
end

---Determines the language of the code/console/buffer
---mutates lines array to remove the lang_prefix
---@param buf number
---@param range number[]
---@return string
local function get_lang(buf, range)
  local pattern = ('^.*' .. config.external_evaluators.lang_prefix .. '(.-)%s*$')
  local line, lang

  line = vim.api.nvim_buf_get_lines(buf, math.max(0, range[1] - 2), range[2], false)[1]
  lang = line:match(pattern)
  if lang then return lang end

  line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  lang = line:match(pattern)
  if lang then return lang end

  return vim.bo[buf].filetype
end

local get_evaluator = function(buf, range)
  local lang = get_lang(buf, range)

  if lang == '' then
    vim.notify('Plese specify the language to evaluate or set the filetype', vim.log.levels.WARN)
  elseif lang == 'lua' then
    return lua_evaluator
  else
    return get_external_evaluator(buf, lang)
  end
end

---Evaluates code in the current line or visual selection and appends to buffer
---@param buf number
---@param full? boolean evaluate full buffer
local eval_code_in_buffer = function(buf, full)
  buf = buf or vim.fn.bufnr()
  local win = vim.fn.bufwinid(buf)

  if vim.api.nvim_get_mode().mode == 'V' then vim.api.nvim_input('<Esc>') end

  local v_start, v_end
  if full then
    v_start, v_end = 1, vim.api.nvim_buf_line_count(buf)
  else
    v_start, v_end = vim.fn.line('.', win), vim.fn.line('v', win)
    if v_start > v_end then
      v_start, v_end = v_end, v_start
    end
  end

  vim.api.nvim_win_set_cursor(win, { v_end, 0 })

  local lines = vim.api.nvim_buf_get_lines(buf, v_start - 1, v_end, false)
  lines = remove_empty_lines(lines)
  if #lines == 0 then return end

  local evaluator = get_evaluator(buf, { v_start, v_end })
  if not evaluator then return end

  local result = evaluator(lines)
  if #result == 0 then return end

  append_current_buffer(buf, result)
end

---Load messages into console
local load_messages = function(buf)
  local ns = vim.api.nvim_create_namespace('Lua-console')

  ---This way we catch the output of messages command, in case it was overriden by some other plugin, like Noice
  vim.ui_attach(ns, { ext_messages = true }, function(event, entries) ---@diagnostic disable-line
    if event ~= 'msg_history_show' then return end

    local messages = vim.tbl_map(function(e)
      return e[2][1][2]
    end, entries)

    if #messages == 0 then return end

    vim.schedule(function()
      vim.api.nvim_input('<Down>') -- forcing to redraw buffer
      append_current_buffer(buf, to_table(messages))
    end)
  end)

  vim.api.nvim_exec2('messages', {})
  vim.ui_detach(ns)
end

local get_plugin_path = function()
  local path = debug.getinfo(1, 'S').source:sub(2)
  return vim.fs.root(path, '.git')
end

---Attaches evaluator (mappings and context) to a buffer
---@param buf? number buffer number, current buffer is used if omitted
local attach_toggle = function(buf)
  buf = buf or vim.fn.bufnr()

  local mappings = require('lua-console.mappings')
  local name = vim.fn.bufname()

  local maps = vim.tbl_map(function(map)
    return map.lhs
  end, vim.api.nvim_buf_get_keymap(buf, 'n'))

  local toggle
  if not vim.tbl_contains(maps, config.mappings.eval) then
    toggle = true
  else
    toggle = false
    _G.Lua_console.ctx[buf] = nil
  end

  mappings.set_evaluator_mappings(buf, toggle)
  vim.api.nvim_set_option_value('syntax', 'on', { buf = buf })

  vim.notify(
    ('Evaluator %s for buffer [%s:%s]'):format(toggle and 'attached' or 'dettached', name, buf),
    vim.log.levels.INFO
  )
end

return {
  toggle_help = toggle_help,
  load_saved_console = load_saved_console,
  append_current_buffer = append_current_buffer,
  pretty_print = pretty_print,
  lua_evaluator = lua_evaluator,
  eval_code_in_buffer = eval_code_in_buffer,
  get_plugin_path = get_plugin_path,
  load_messages = load_messages,
  get_path_lnum = get_path_lnum,
  attach_toggle = attach_toggle,
}
