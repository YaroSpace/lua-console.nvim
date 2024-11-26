local assert = require("luassert.assert")
local colors = require 'term.colors'

local M = {}

_G.LOG = function(...) --luacheck: ignore
  local caller = debug.getinfo(2)
  local result = string.format('\nLOG (%s:%s) => ', caller.name or vim.fs.basename(caller.short_src) or '', caller.currentline or '')
  local nargs = select('#', ...)
  local var_no = ''

  for i = 1, nargs do
    local o = select(i, ...)

    if i > 1 then result = result .. ',\n' end
    if nargs > 1 then var_no = string.format('[%s] ', i) end

    o = type(o) == 'function' and debug.getinfo(o) or o
    result = result .. var_no .. vim.inspect(o)
  end

  io.write(colors.cyan(result), '\n')
  return result
end

M.get_root = function()
  local path = debug.getinfo(1, "S").source:sub(2)
  return vim.fs.root(path, '.git')
end

---@param tbl string[]|string
M.to_string = function(tbl)
  tbl = tbl or {}

  if type(tbl) == 'string' then
    tbl = { tbl }
  end
  return vim.trim(table.concat(tbl, '\n'):gsub('\t', ''))
end

M.to_table = function(str)
  str = vim.trim(str:gsub('\t', ''))
  return vim.split(str or '', '\n', { trimempty = true })
end

M.get_buffer = function(buf)
  ---@diagnostic disable-next-line
  return vim.fn.getbufline(buf, 0, '$')
end

---@param lines string[]
M.set_buffer = function(buf, lines)
  return vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

M.send_keys = function(keys)
  local cmd = "'normal " .. keys .. "'"
  vim.cmd.exe(cmd)
end

M.get_virtual_text = function(buf, line_start, line_end)
  local ns = vim.api.nvim_create_namespace('Lua-console')
  local ids = vim.api.nvim_buf_get_extmarks(buf, ns, { line_start or 0, 0 }, { line_end or 0, -1 }, {})

  if vim.tbl_isempty(ids) then
  	_G.LOG('No extmarks found')
  	return ''
  end

  local mark = vim.api.nvim_buf_get_extmark_by_id(buf, ns, ids[1][1], { details = true })

  return mark[3].virt_text[1][1]
end

---Collects paths for nested keys
local get_key_paths
get_key_paths = function(tbl, path, paths)
  path = path or {}
  paths = paths or {}

  if type(tbl) ~= 'table' then
    return
  end

  for k, v in pairs(tbl) do
    local nested_path = vim.list_extend({ path }, { k })

    if not get_key_paths(v, nested_path, paths) then
      table.insert(paths, vim.fn.flatten(nested_path))
    end
  end
  return paths
end

---Checks if an object contains properties with values
---@param state any
---@param args table { table, table { property_name = value } }
M.has_properties = function(state, args)
  vim.validate {
    arg_1 = { args[1], 'table' },
    arg_2 = { args[2], 'table' },
  }

  local mod = state.mod
  local o, properties = args[1], args[2]
  local missing = {}
  local result = true

  local key_paths = get_key_paths(properties) or {}

  for _, path in ipairs(key_paths) do
    local prop_value = vim.tbl_get(properties, unpack(path))
    if vim.tbl_get(o, unpack(path)) ~= prop_value then
      result = false
      missing[path] = prop_value
    end
  end

  if not (mod and result) then
    local _not = mod and '' or ' not '
    state.failure_message =
      string.format('\n\n**Expected "%s"\n\n**%sto have properties "%s"', vim.inspect(o), _not, vim.inspect(missing))
  end

  return result
end

assert:register('assertion', 'has_properties', M.has_properties, '', '')

---Asserts if object contains a string
---@param state table
---@param args table { table|string, string }
---@return boolean
M.has_string = function(state, args)
  vim.validate {
    arg_1 = { args[1], { 'string', 'table' } },
    arg_2 = { args[2], 'string' },
  }

  local mod = state.mod
  local o, pattern = args[1], args[2]
  local result

  if type(o) == 'table' then
    o = M.to_string(o)
  end

  o = vim.trim(o:gsub('\t', ''))
  pattern = vim.trim(pattern:gsub('\t', ''))

  result = o:find(pattern, 1, true) and true or false

  if not (mod and result) then
    local _not = mod and '' or ' not '
    state.failure_message = string.format('\n\n**Expected "%s"\n\n**%sto have string "%s"', o, _not, pattern)
  end

  return result
end

assert:register('assertion', 'has_string', M.has_string, '', '')

return M
